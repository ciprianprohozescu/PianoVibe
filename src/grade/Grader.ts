import type {Song} from '../types'
import { Transport } from '../transport'

export type NoteJudge = 0 | 1 | 2 // 0=pending, 1=hit, 2=miss
export type NoteStateMap = Map<number, NoteJudge>

type PressEvent = { pitch: number; timeMs: number }

export class Grader {
    private transport: Transport
    private song: Song | null = null
    private states: NoteStateMap = new Map()
    private timer: number | null = null
    private tickMs = 25
    private tolMs = 120       // ± window for a hit
    private missGraceMs = 80  // extra grace after start before calling a miss
    private recentPresses: PressEvent[] = []
    private onUpdate?: (states: NoteStateMap) => void

    constructor(transport: Transport, onUpdate?: (s: NoteStateMap) => void) {
        this.transport = transport
        this.onUpdate = onUpdate
    }

    setSong(song: Song | null) {
        this.song = song
        this.states = new Map()
        if (song) {
            for (const tr of song.tracks) {
                for (const n of tr.events) this.states.set(n.id, 0)
            }
        }
        this.recentPresses = []
        this.emit()
    }

    addPress(pitch: number, timeMs?: number) {
        const t = timeMs ?? this.transport.currentMs()
        // keep only last ~2s for matching
        this.recentPresses.push({ pitch, timeMs: t })
        const cutoff = t - 2000
        while (this.recentPresses.length && this.recentPresses[0].timeMs < cutoff) {
            this.recentPresses.shift()
        }
    }

    start() {
        if (this.timer != null) return
        const tick = () => {
            this.step()
            this.timer = window.setTimeout(tick, this.tickMs)
        }
        this.timer = window.setTimeout(tick, 0)
    }

    stop() {
        if (this.timer != null) { clearTimeout(this.timer); this.timer = null }
    }

    reset() {
        // on seek: leave hits/misses? For now, recompute from scratch.
        if (!this.song) return
        this.states.clear()
        for (const tr of this.song.tracks) for (const n of tr.events) this.states.set(n.id, 0)
        this.recentPresses = []
        this.emit()
    }

    getStates(): NoteStateMap { return this.states }

    private step() {
        if (!this.song) return
        const now = this.transport.currentMs()
        let changed = false

        for (const tr of this.song.tracks) {
            for (const n of tr.events) {
                if (n.startMs == null) continue
                const s = this.states.get(n.id) ?? 0
                if (s !== 0) continue // already judged

                // Check for HIT: any press with same pitch within ±tolMs of startMs
                const dtMin = n.startMs - this.tolMs
                const dtMax = n.startMs + this.tolMs
                const hit = this.recentPresses.find(pe =>
                    pe.pitch === n.pitch && pe.timeMs >= dtMin && pe.timeMs <= dtMax
                )
                if (hit) {
                    this.states.set(n.id, 1)
                    changed = true
                    continue
                }

                // Check for MISS: we've gone past start + grace
                if (now > n.startMs + this.missGraceMs) {
                    this.states.set(n.id, 2)
                    changed = true
                }
            }
        }

        // Garbage collect very old presses
        const cutoff = now - 2000
        while (this.recentPresses.length && this.recentPresses[0].timeMs < cutoff) {
            this.recentPresses.shift()
        }

        if (changed) this.emit()
    }

    private emit() { this.onUpdate?.(new Map(this.states)) }
}
