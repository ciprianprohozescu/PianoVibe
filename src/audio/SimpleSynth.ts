// Minimal poly synth using plain OscillatorNode + GainNode envelopes.
// Not realistic piano — just clean tones to prove timing & scheduling.

const A4 = 440
const midiToHz = (n: number) => A4 * Math.pow(2, (n - 69) / 12)

type Voice = {
    osc: OscillatorNode
    gain: GainNode
}

export class SimpleSynth {
    private ctx: AudioContext
    private master: GainNode
    private voices = new Map<string, Voice>() // key = `${pitch}:${channel}`

    // Simple envelope (seconds)
    private a = 0.002  // attack
    private d = 0.06   // decay
    private s = 0.7    // sustain level (0..1)
    private r = 0.12   // release

    constructor(ctx: AudioContext) {
        this.ctx = ctx
        this.master = ctx.createGain()
        this.master.gain.value = 0.6
        this.master.connect(ctx.destination)
    }

    setMasterGain(g: number) {
        this.master.gain.value = Math.max(0, Math.min(1, g))
    }

    noteOn(pitch: number, velocity = 100, whenSec?: number, channel = 0) {
        const t0 = whenSec ?? this.ctx.currentTime
        const freq = midiToHz(pitch)
        const key = `${pitch}:${channel}`

        // If voice exists, steal it (release old)
        if (this.voices.has(key)) this.noteOff(pitch, t0, channel)

        const osc = new OscillatorNode(this.ctx, { type: 'triangle', frequency: freq })
        const gain = new GainNode(this.ctx, { gain: 0 })

        osc.connect(gain).connect(this.master)
        osc.start(t0)

        // Velocity to amplitude (very rough)
        const vel = Math.max(0.05, Math.min(1, velocity / 127))

        // ADSR
        const g = gain.gain
        g.cancelAndHoldAtTime(t0)
        g.setValueAtTime(0, t0)
        g.linearRampToValueAtTime(vel, t0 + this.a) // attack
        g.linearRampToValueAtTime(vel * this.s, t0 + this.a + this.d) // decay->sustain

        this.voices.set(key, { osc, gain })
    }

    noteOff(pitch: number, whenSec?: number, channel = 0) {
        const t0 = whenSec ?? this.ctx.currentTime
        const key = `${pitch}:${channel}`
        const v = this.voices.get(key)
        if (!v) return

        const g = v.gain.gain
        g.cancelAndHoldAtTime(t0)
        // release to silence, then stop osc a bit later
        g.setTargetAtTime(0, t0, this.r / 3)
        v.osc.stop(t0 + this.r * 2)
        // disconnect later to be safe
        v.osc.onended = () => {
            v.gain.disconnect()
            this.voices.delete(key)
        }
    }

    allNotesOff(whenSec?: number) {
        const t = whenSec ?? this.ctx.currentTime
        for (const key of Array.from(this.voices.keys())) {
            const [p] = key.split(':')
            this.noteOff(Number(p), t)
        }
    }
}
