import type {Song, Track, NoteEvent, TempoChange} from '../types'

/**
 * Minimal Standard MIDI File (SMF) parser:
 * - Handles header (MThd), tracks (MTrk)
 * - Meta events: tempo (0xFF 0x51), track name (0xFF 0x03)
 * - Channel voice: Note On (0x9n), Note Off (0x8n), running status
 * - Computes duration in ticks and ms using tempo map
 */
export function parseMidi(buf: ArrayBuffer): Song {
    const data = new DataView(buf)
    let off = 0

    const readStr = (len: number) => {
        let s = ''
        for (let i = 0; i < len; i++) s += String.fromCharCode(data.getUint8(off + i))
        off += len
        return s
    }

    const readU16 = () => { const v = data.getUint16(off); off += 2; return v }
    const readU32 = () => { const v = data.getUint32(off); off += 4; return v }

    const readVarLen = () => {
        let v = 0
        while (true) {
            const b = data.getUint8(off++); v = (v << 7) | (b & 0x7f)
            if ((b & 0x80) === 0) break
        }
        return v
    }

    // --- Header ---
    const hdrId = readStr(4); if (hdrId !== 'MThd') throw new Error('Not a MIDI file')
    const hdrLen = readU32(); if (hdrLen !== 6) off += hdrLen // be lenient
    const format = readU16()
    const ntrks = readU16()
    const division = readU16()

    if ((division & 0x8000) !== 0) {
        throw new Error('SMPTE timebase is not supported in this minimal parser')
    }
    const ppq = division

    // --- Track parser ---
    const tracks: Track[] = []
    const tempoMap: TempoChange[] = [{ atTick: 0, bpm: 120 }] // default 120 BPM
    let maxEndTick = 0
    let nextId = 1

    for (let t = 0; t < ntrks; t++) {
        const id = readStr(4); if (id !== 'MTrk') throw new Error('Missing MTrk')
        const len = readU32()
        const trackEnd = off + len
        let tick = 0
        let runningStatus = -1
        const openNotes = new Map<number, NoteEvent[]>() // key per pitch*16 + channel

        const track: Track = { events: [] }

        while (off < trackEnd) {
            const delta = readVarLen()
            tick += delta

            let status = data.getUint8(off++)
            if ((status & 0x80) === 0) {
                // Running status
                off--
                status = runningStatus
                if (status < 0) throw new Error('Invalid running status')
            } else {
                runningStatus = status
            }

            if (status === 0xFF) {
                // Meta
                const type = data.getUint8(off++)
                const len = readVarLen()
                switch (type) {
                    case 0x03: { // Track name (text)
                        const name = readStr(len)
                        track.name = name
                        break
                    }
                    case 0x51: { // Set Tempo (microseconds per quarter note), length must be 3
                        if (len !== 3) { off += len; break }
                        const usPerQN = (data.getUint8(off) << 16) | (data.getUint8(off + 1) << 8) | data.getUint8(off + 2)
                        off += 3
                        const bpm = 60_000_000 / usPerQN
                        tempoMap.push({ atTick: tick, bpm })
                        break
                    }
                    default:
                        off += len // skip
                }
                continue
            }

            if (status === 0xF0 || status === 0xF7) {
                // SysEx
                const len = readVarLen()
                off += len
                continue
            }

            const hi = status & 0xF0
            const ch = status & 0x0F

            if (hi === 0x80 || hi === 0x90) {
                const pitch = data.getUint8(off++)
                const vel = data.getUint8(off++)
                const key = (pitch << 4) | ch

                if (hi === 0x90 && vel > 0) {
                    // Note On
                    const ev: NoteEvent = {
                        id: nextId++,
                        pitch, startTick: tick, endTick: tick, channel: ch, velocity: vel,
                    }
                    if (!openNotes.has(key)) openNotes.set(key, [])
                    openNotes.get(key)!.push(ev)
                } else {
                    // Note Off (0x80) or 0x90 with vel 0
                    const stack = openNotes.get(key)
                    if (stack && stack.length) {
                        const ev = stack.pop()!
                        ev.endTick = tick
                        track.events.push(ev)
                        if (ev.endTick > maxEndTick) maxEndTick = ev.endTick
                    }
                }
                continue
            }

            // Skip other 2-data-byte channel messages (CC, Program, Pitch Bend, etc.)
            if (hi === 0xA0 || hi === 0xB0 || hi === 0xE0) { off += 2; continue }
            if (hi === 0xC0 || hi === 0xD0) { off += 1; continue }

            // Unknown — bail safely by breaking the track
            break
        }

        tracks.push(track)
        off = trackEnd
    }

    // Normalize ticks -> ms using tempo map
    const durationTicks = maxEndTick
    const durationMs = ticksToMs(durationTicks, tempoMap, ppq)

    // Optionally annotate each note with startMs/endMs
    for (const tr of tracks) {
        for (const n of tr.events) {
            n.startMs = ticksToMs(n.startTick, tempoMap, ppq)
            n.endMs = ticksToMs(n.endTick, tempoMap, ppq)
        }
    }

    return { format, tracks, ppq, tempoMap, durationTicks, durationMs }
}

function ticksToMs(ticks: number, tempoMap: TempoChange[], ppq: number): number {
    // tempoMap must be sorted by atTick
    const tm = [...tempoMap].sort((a, b) => a.atTick - b.atTick)
    let ms = 0
    let lastTick = 0
    let lastBpm = tm[0]?.bpm ?? 120

    for (let i = 1; i < tm.length; i++) {
        const segTick = Math.min(ticks, tm[i].atTick)
        if (segTick > lastTick) {
            ms += ticksSpanToMs(segTick - lastTick, lastBpm, ppq)
            lastTick = segTick
        }
        if (ticks <= tm[i].atTick) return ms
        lastBpm = tm[i].bpm
    }

    // Tail segment
    if (ticks > lastTick) {
        ms += ticksSpanToMs(ticks - lastTick, lastBpm, ppq)
    }
    return ms
}

function ticksSpanToMs(deltaTicks: number, bpm: number, ppq: number): number {
    const beats = deltaTicks / ppq
    const minutes = beats / bpm
    return minutes * 60_000
}
