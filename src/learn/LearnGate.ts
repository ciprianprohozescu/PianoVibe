import type {Song} from '../types';
import { Transport } from '../transport'
import type {NoteStateMap} from '../grade/Grader';

type NoteGroup = { startMs: number; noteIds: number[] }

export class LearnGate {
    private transport: Transport
    private song: Song
    private groups: NoteGroup[] = []
    private idx = 0
    private requireAllInChord = true // set true to require all chord notes to be hit
    private enabled = false

    constructor(transport: Transport, song: Song) {
        this.transport = transport
        this.song = song
        this.groups = buildGroups(song, 12) // group notes starting within 12ms into “chords”
        this.idx = 0
    }

    enable() { this.enabled = true }
    disable() { this.enabled = false }

    resetToStart() {
        this.idx = 0
        this.transport.seek(0)
    }

    onStatesUpdate(states: NoteStateMap) {
        if (!this.enabled || !this.groups.length) return

        const g = this.groups[this.idx]
        if (!g) return

        const now = this.transport.currentMs()

        // 1) Auto-pause when we reach the target note start
        if (this.transport.isRunning && now >= g.startMs) {
            this.transport.pause()
            return
        }

        // 2) If we’re paused at/after this note’s start, check if it’s satisfied
        if (!this.transport.isRunning && now >= g.startMs) {
            const hits = g.noteIds.map(id => states.get(id) === 1)
            const satisfied = this.requireAllInChord ? hits.every(Boolean) : hits.some(Boolean)
            if (satisfied) {
                // Advance to next group and resume
                this.idx = Math.min(this.idx + 1, this.groups.length - 1)
                this.transport.play()
            }
        }
    }
}

function buildGroups(song: Song, groupTolMs = 12): NoteGroup[] {
    const all = song.tracks.flatMap(tr => tr.events).filter(n => n.startMs != null)
    all.sort((a, b) => (a.startMs! - b.startMs!))

    const groups: NoteGroup[] = []
    for (const n of all) {
        const t = n.startMs!
        const last = groups[groups.length - 1]
        if (!last || Math.abs(last.startMs - t) > groupTolMs) {
            groups.push({ startMs: t, noteIds: [n.id] })
        } else {
            last.noteIds.push(n.id)
        }
    }
    return groups
}
