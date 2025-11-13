// Simple microphone-based pitch detector that emits MIDI-like note on/off events
// Uses autocorrelation to estimate fundamental frequency.

export type MicNoteCallback = (pitch: number) => void

export class MicrophoneInput {
    private ctx: AudioContext
    private mediaStream: MediaStream | null = null
    private source: MediaStreamAudioSourceNode | null = null
    private analyser: AnalyserNode | null = null
    private rafId: number | null = null
    private buffer: Float32Array | null = null

    private onNoteOn: MicNoteCallback | null = null
    private onNoteOff: MicNoteCallback | null = null

    private currentPitch: number | null = null
    private stableFrames = 0

    // Tuning and detection parameters
    private minFreq = 50 // Hz
    private maxFreq = 1200 // Hz
    private minCorrelation = 0.75
    private silenceThreshold = 0.01 // RMS below this considered silence
    private stabilityFrames = 3 // frames of stable pitch before NoteOn
    private offFramesThreshold = 4 // consecutive frames of silence before NoteOff
    private offFrames = 0
    private centHysteresis = 35 // cents deviation allowed to keep same note

    constructor(ctx: AudioContext) {
        this.ctx = ctx
    }

    setCallbacks(onNoteOn: MicNoteCallback | null, onNoteOff: MicNoteCallback | null) {
        this.onNoteOn = onNoteOn
        this.onNoteOff = onNoteOff
    }

    async start(): Promise<void> {
        if (this.mediaStream) return
        const stream = await navigator.mediaDevices.getUserMedia({ audio: {
            echoCancellation: false,
            noiseSuppression: false,
            autoGainControl: false,
        }})
        this.mediaStream = stream
        this.source = this.ctx.createMediaStreamSource(stream)
        const analyser = this.ctx.createAnalyser()
        analyser.fftSize = 2048
        analyser.smoothingTimeConstant = 0.0
        this.source.connect(analyser)
        this.analyser = analyser
        this.buffer = new Float32Array(analyser.fftSize)
        this.loop()
    }

    stop() {
        if (this.rafId !== null) cancelAnimationFrame(this.rafId)
        this.rafId = null
        if (this.source && this.analyser) {
            try { this.source.disconnect() } catch {}
            try { this.analyser.disconnect() } catch {}
        }
        this.analyser = null
        this.source = null
        if (this.mediaStream) {
            this.mediaStream.getTracks().forEach(t => t.stop())
        }
        this.mediaStream = null
        this.buffer = null
        this.noteOffIfAny()
        this.currentPitch = null
        this.stableFrames = 0
        this.offFrames = 0
    }

    private loop = () => {
        if (!this.analyser || !this.buffer) return
        this.analyser.getFloatTimeDomainData(this.buffer)
        const freq = this.estimateFrequency(this.buffer, this.ctx.sampleRate)
        if (freq > 0) {
            const midi = this.freqToMidi(freq)
            const amp = this.rms(this.buffer)
            // Treat as valid if amplitude is reasonable
            if (amp > this.silenceThreshold) {
                this.offFrames = 0
                if (this.currentPitch === null) {
                    // wait for stability
                    this.stableFrames++
                    if (this.stableFrames >= this.stabilityFrames) {
                        this.currentPitch = midi
                        this.stableFrames = 0
                        if (this.onNoteOn) this.onNoteOn(midi)
                    }
                } else {
                    const cents = this.centsDiff(this.currentPitch, midi)
                    if (Math.abs(cents) <= this.centHysteresis) {
                        // keep same note
                        this.stableFrames = 0
                    } else {
                        // pitch changed to a different note -> note off then start stabilizing for new
                        const prev = this.currentPitch
                        this.currentPitch = null
                        this.stableFrames = 1 // count this frame as first for new note
                        if (this.onNoteOff) this.onNoteOff(prev)
                    }
                }
            } else {
                // low amplitude
                this.handleSilence()
            }
        } else {
            // no reliable pitch
            this.handleSilence()
        }
        this.rafId = requestAnimationFrame(this.loop)
    }

    private handleSilence() {
        this.offFrames++
        if (this.offFrames >= this.offFramesThreshold) {
            this.offFrames = 0
            this.stableFrames = 0
            this.noteOffIfAny()
        }
    }

    private noteOffIfAny() {
        if (this.currentPitch !== null) {
            const p = this.currentPitch
            this.currentPitch = null
            if (this.onNoteOff) this.onNoteOff(p)
        }
    }

    private freqToMidi(freq: number): number {
        const midi = 69 + 12 * Math.log2(freq / 440)
        // round to nearest semitone
        return Math.max(0, Math.min(127, Math.round(midi)))
    }

    private centsDiff(midiA: number, midiB: number): number {
        // difference in cents between two MIDI note numbers by converting to frequency
        const fa = 440 * Math.pow(2, (midiA - 69) / 12)
        const fb = 440 * Math.pow(2, (midiB - 69) / 12)
        return 1200 * Math.log2(fb / fa)
    }

    private rms(buf: Float32Array): number {
        let s = 0
        for (let i = 0; i < buf.length; i++) s += buf[i] * buf[i]
        return Math.sqrt(s / buf.length)
    }

    private estimateFrequency(buf: Float32Array, sampleRate: number): number {
        // Autocorrelation method
        let SIZE = buf.length
        // Compute RMS to quickly rule out silence
        const rms = this.rms(buf)
        if (rms < this.silenceThreshold * 0.5) return 0

        let r1 = 0, r2 = SIZE - 1, thres = 0.2
        for (let i = 0; i < SIZE / 2; i++) {
            if (Math.abs(buf[i]) < thres) { r1 = i; break }
        }
        for (let i = 1; i < SIZE / 2; i++) {
            const ii = SIZE - i
            if (Math.abs(buf[ii]) < thres) { r2 = ii; break }
        }

        const bufClipped = buf.slice(r1, r2)
        SIZE = bufClipped.length
        if (SIZE < 32) return 0

        const c = new Array<number>(SIZE).fill(0)
        for (let i = 0; i < SIZE; i++) {
            for (let j = 0; j < SIZE - i; j++) c[i] = c[i] + bufClipped[j] * bufClipped[j + i]
        }

        let d = 0
        while (d < SIZE && c[d] > c[d + 1]) d++
        let maxval = -1, maxpos = -1
        for (let i = d; i < SIZE; i++) {
            if (c[i] > maxval) { maxval = c[i]; maxpos = i }
        }
        if (maxpos <= 0) return 0

        const T0 = maxpos
        const x1 = c[T0 - 1] || 0
        const x2 = c[T0]
        const x3 = c[T0 + 1] || 0
        const a = (x1 + x3 - 2 * x2) / 2
        const b = (x3 - x1) / 2
        const shift = a ? -b / (2 * a) : 0
        const period = T0 + shift
        if (!isFinite(period) || period <= 0) return 0
        const freq = sampleRate / period
        if (freq < this.minFreq || freq > this.maxFreq) return 0

        // normalize correlation peak strength to gate low-confidence pitches (rough approximation)
        const confidence = maxval / c[0]
        if (confidence < this.minCorrelation) return 0
        return freq
    }
}
