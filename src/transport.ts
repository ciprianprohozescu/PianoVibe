// A tiny clock/transport driven by AudioContext time.
// No audio yet — we only use it for a stable clock.

export class Transport {
    private ctx: AudioContext
    private running = false
    private startCtxTime = 0      // AudioContext.currentTime at play()
    private startSongMs = 0       // song time (ms) at play()
    private tempoMul = 1          // 1.0 = 100%

    constructor() {
        // Reuse an AudioContext if the browser suspends it when tab is inactive.
        this.ctx = new (window.AudioContext || (window as any).webkitAudioContext)()
    }

    get isRunning() { return this.running }
    get tempoMultiplier() { return this.tempoMul }
    get audioContext() { return this.ctx }

    // Current song time in ms (derived from AudioContext time + offsets)
    currentMs(): number {
        if (!this.running) return this.startSongMs
        const elapsedCtxSec = this.ctx.currentTime - this.startCtxTime
        return this.startSongMs + elapsedCtxSec * 1000 * this.tempoMul
    }

    setTempoMultiplier(mul: number) {
        const now = this.currentMs()
        this.tempoMul = Math.max(0.25, Math.min(2, mul))
        // reset anchor so currentMs() is continuous
        if (this.running) {
            this.startCtxTime = this.ctx.currentTime
            this.startSongMs = now
        }
    }

    seek(ms: number) {
        const clamped = Math.max(0, ms)
        if (this.running) {
            this.startCtxTime = this.ctx.currentTime
            this.startSongMs = clamped
        } else {
            this.startSongMs = clamped
        }
    }

    async play() {
        if (this.ctx.state === 'suspended') await this.ctx.resume()
        if (!this.running) {
            this.startCtxTime = this.ctx.currentTime
            this.running = true
        }
    }

    pause() {
        if (this.running) {
            this.startSongMs = this.currentMs()
            this.running = false
        }
    }

    async toggle() {
        if (this.running) {
            this.pause()
        } else {
            await this.play()
        }
    }
}
