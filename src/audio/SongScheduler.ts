import type {Song} from '../types'
import { Transport } from '../transport'
import { SimpleSynth } from './SimpleSynth'

// Schedules note on/off inside a look-ahead window, ticking every ~25ms.
// Small windows adapt quickly to tempo/seek changes.

export class SongScheduler {
    private song: Song | null = null
    private transport: Transport
    private synth: SimpleSynth

    private timer: number | null = null
    private lookAheadMs = 120
    private tickMs = 25
    private scheduledThroughMs = 0 // song-time (ms) up to which we've scheduled

    constructor(transport: Transport, synth: SimpleSynth) {
        this.transport = transport
        this.synth = synth
    }

    setSong(song: Song | null) {
        this.song = song
        this.reset()
    }

    start() {
        if (this.timer != null) return
        this.scheduledThroughMs = Math.max(this.scheduledThroughMs, this.transport.currentMs())
        const tick = () => {
            // If paused, don't schedule (but keep timer so we resume quickly)
            if (!this.transport.isRunning || !this.song) {
                this.timer = window.setTimeout(tick, this.tickMs)
                return
            }

            const nowSongMs = this.transport.currentMs()
            const windowStart = this.scheduledThroughMs
            const windowEnd = nowSongMs + this.lookAheadMs

            if (windowEnd > windowStart) {
                this.scheduleWindow(windowStart, windowEnd)
                this.scheduledThroughMs = windowEnd
            }

            this.timer = window.setTimeout(tick, this.tickMs)
        }
        this.timer = window.setTimeout(tick, 0)
    }

    stop() {
        if (this.timer != null) {
            clearTimeout(this.timer)
            this.timer = null
        }
        this.synth.allNotesOff()
    }

    reset() {
        // Called on new song or seek: clear future scheduling and silence
        this.scheduledThroughMs = this.transport.currentMs()
        this.synth.allNotesOff()
    }

    private scheduleWindow(winStartMs: number, winEndMs: number) {
        if (!this.song) return
        const ctx = this.transport.audioContext
        const nowSongMs = this.transport.currentMs()

        // Schedule all notes whose start/end fall into [winStartMs, winEndMs]
        for (const tr of this.song.tracks) {
            for (const n of tr.events) {
                if (n.startMs == null || n.endMs == null) continue

                // Note On
                if (n.startMs >= winStartMs && n.startMs < winEndMs) {
                    const dtSec = Math.max(0, (n.startMs - nowSongMs) / 1000)
                    const when = ctx.currentTime + dtSec
                    this.synth.noteOn(n.pitch, n.velocity, when)
                }
                // Note Off
                if (n.endMs >= winStartMs && n.endMs < winEndMs) {
                    const dtSec = Math.max(0, (n.endMs - nowSongMs) / 1000)
                    const when = ctx.currentTime + dtSec
                    this.synth.noteOff(n.pitch, when)
                }
            }
        }
    }
}
