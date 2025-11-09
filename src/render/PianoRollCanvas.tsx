import React, { useEffect, useRef, useState } from 'react'
import type {Song} from '../types'
import { Transport } from '../transport'
import type {NoteStateMap} from "../grade/Grader.ts";

// Simple, readable piano-roll renderer.
// Time = vertical (future downward). Pitch = horizontal.
// The bottom has a fixed keyboard lane; notes "fall" into it.

type Props = {
    song: Song
    transport: Transport
    windowMs?: number          // how much future time is visible (default 6000ms)
    pressed?: Set<number>
    noteStates?: NoteStateMap
    showNoteNames?: boolean    // overlay note names on falling bars
}

export default function PianoRollCanvas({ song, transport, windowMs = 6000, pressed, noteStates, showNoteNames = true }: Props) {
    const canvasRef = useRef<HTMLCanvasElement | null>(null)
    const [size, setSize] = useState<{ w: number; h: number }>({ w: 800, h: 500 })
    const keyboardLane = 80

    // Fixed full 88-key range (A0=21 .. C8=108)
    const minPitch = 21
    const maxPitch = 108

    // Resize to container
    useEffect(() => {
        const el = canvasRef.current?.parentElement
        if (!el) return
        const ro = new ResizeObserver(() => {
            const rect = el.getBoundingClientRect()
            setSize({ w: Math.max(300, rect.width), h: Math.max(260, rect.height) })
        })
        ro.observe(el)
        return () => ro.disconnect()
    }, [])

    // Draw loop (static first frame, then animate)
    useEffect(() => {
        const canvas = canvasRef.current
        if (!canvas) return
        const ctx = canvas.getContext('2d')
        if (!ctx) return

        let raf = 0

        const draw = () => {
            // Handle canvas backing store size for crisp rendering
            const dpr = window.devicePixelRatio || 1
            if (canvas.width !== Math.floor(size.w * dpr) || canvas.height !== Math.floor(size.h * dpr)) {
                canvas.width = Math.floor(size.w * dpr)
                canvas.height = Math.floor(size.h * dpr)
                canvas.style.width = `${size.w}px`
                canvas.style.height = `${size.h}px`
            }

            const W = canvas.width
            const H = canvas.height
            const PR = dpr

            // Clear
            ctx.clearRect(0, 0, W, H)

            // Background
            fillRect(ctx, 0, 0, W, H, '#0b1023')
            // Play area (above keyboard)
            const playH = H - keyboardLane * PR
            fillRect(ctx, 0, 0, W, playH, '#0f172a')

            const nowMs = transport.currentMs()
            const pxPerMs = playH / windowMs
            const pitchCount = maxPitch - minPitch + 1
            const pxPerPitch = W / pitchCount

            // Grid: octaves
            for (let p = minPitch; p <= maxPitch; p++) {
                const x = Math.floor((p - minPitch) * pxPerPitch)
                if ((p % 12) === 0) {
                    drawLine(ctx, x, 0, x, playH, 'rgba(255,255,255,0.08)')
                }
            }
            // Time grid: 1s lines
            for (let t = 0; t <= windowMs; t += 1000) {
                const y = Math.floor(playH - t * pxPerMs)
                drawLine(ctx, 0, y, W, y, 'rgba(255,255,255,0.06)')
            }

            // Notes: draw only those intersecting [nowMs, nowMs + windowMs]
            const tEnd = nowMs + windowMs
            for (const tr of song.tracks) {
                for (const n of tr.events) {
                    if (n.startMs === undefined || n.endMs === undefined) continue
                    if (n.endMs < nowMs || n.startMs > tEnd) continue

                    const x = Math.floor((n.pitch - minPitch) * pxPerPitch)

                    // Clamp the note’s start/end to the visible window [nowMs, nowMs+windowMs]
                    const startR = Math.max(0, Math.min(windowMs, n.startMs - nowMs))
                    const endR   = Math.max(0, Math.min(windowMs, n.endMs   - nowMs))

                    // Convert to screen coords with time-origin at the bottom (hit line)
                    // Bottom corresponds to note START time; Top corresponds to note END time.
                    const yBottom = playH - startR * pxPerMs
                    const yTop    = playH - endR   * pxPerMs

                    const y = Math.max(0, Math.min(yTop, yBottom)) // safe ordering
                    const h = Math.max(2 * PR, Math.min(playH - y, Math.abs(yBottom - yTop)))

                    const state = noteStates?.get(n.id) ?? 0
                    const color =
                        state === 1 ? 'rgba(34, 197, 94, 0.95)'  // green: hit
                            : state === 2 ? 'rgba(239, 68, 68, 0.95)'  // red: miss
                                :              'rgba(99, 102, 241, 0.9)'   // indigo: pending

                    const rectX = x + 1
                    const rectY = y + 1
                    const rectW = Math.max(2, pxPerPitch - 2)
                    const rectH = h - 2
                    fillRect(ctx, rectX, rectY, rectW, rectH, color)

                    // Note name label (overlay, always visible)
                    if (showNoteNames) {
                        const label = midiToNoteName(n.pitch)
                        // Draw label on top of the bar regardless of its size (no clipping)
                        const fontPx = Math.max(12 * PR, Math.min(16 * PR, Math.floor(13 * PR)))
                        ctx.save()
                        ctx.font = `${fontPx}px system-ui, -apple-system, Segoe UI, Roboto, sans-serif`
                        ctx.textAlign = 'center'
                        ctx.textBaseline = 'middle'
                        const cx = rectX + rectW / 2
                        const cy = rectY + rectH / 2
                        // Strong outline for readability over any color
                        ctx.lineWidth = Math.max(1, Math.floor(2 * PR))
                        ctx.strokeStyle = 'rgba(0,0,0,0.9)'
                        ctx.strokeText(label, cx, cy)
                        ctx.fillStyle = 'rgba(255,255,255,0.98)'
                        ctx.fillText(label, cx, cy)
                        ctx.restore()
                    }
                }
            }

            // "Hit line" where keys are (top of keyboard lane)
            drawLine(ctx, 0, playH, W, playH, 'rgba(255,255,255,0.3)')

            // Keyboard lane
            drawKeyboard(ctx, 0, playH, W, keyboardLane * PR, minPitch, maxPitch, pressed)

            // Continue animating if transport is running
            raf = requestAnimationFrame(draw)
        }

        // First static paint, then continuous
        draw()
        return () => cancelAnimationFrame(raf)
    }, [song, size.w, size.h, minPitch, maxPitch, keyboardLane, windowMs, transport, noteStates, pressed])

    return (
        <div style={{ width: '100%', height: '80vh', minHeight: 300, borderRadius: 12, overflow: 'hidden', border: '1px solid rgba(255,255,255,0.15)' }}>
            <canvas ref={canvasRef} />
        </div>
    )
}

// --- helpers (pure canvas) ---

function fillRect(ctx: CanvasRenderingContext2D, x: number, y: number, w: number, h: number, fill: string) {
    ctx.fillStyle = fill
    ctx.fillRect(x, y, w, h)
}

function drawLine(ctx: CanvasRenderingContext2D, x1: number, y1: number, x2: number, y2: number, stroke: string) {
    ctx.strokeStyle = stroke
    ctx.beginPath()
    ctx.moveTo(x1 + 0.5, y1 + 0.5)
    ctx.lineTo(x2 + 0.5, y2 + 0.5)
    ctx.stroke()
}

function drawKeyboard(
    ctx: CanvasRenderingContext2D,
    x: number, y: number, w: number, h: number,
    minPitch: number, maxPitch: number,
    pressed?: Set<number>
) {
    const pitchCount = maxPitch - minPitch + 1
    const pxPerPitch = w / pitchCount

    // Base background
    fillRect(ctx, x, y, w, h, '#111827')

    const isBlack = (p: number) => [1, 3, 6, 8, 10].includes(p % 12)

    for (let p = minPitch; p <= maxPitch; p++) {
        const xx = Math.floor(x + (p - minPitch) * pxPerPitch)
        const ww = Math.ceil(pxPerPitch)

        const black = isBlack(p)
        const pressedHere = pressed?.has(p)

        if (!black) {
            // White key background
            fillRect(ctx, xx, y, ww, h, 'rgba(255,255,255,0.06)')
            if (pressedHere) {
                // Brighten + subtle glow
                fillRect(ctx, xx, y, ww, h, 'rgba(236, 72, 153, 0.45)') // pinkish layer
                fillRect(ctx, xx, y, ww, 6, 'rgba(255,255,255,0.35)')   // spec highlight
            }
        }
    }

    // Black keys drawn on top
    for (let p = minPitch; p <= maxPitch; p++) {
        const black = [1, 3, 6, 8, 10].includes(p % 12)
        if (!black) continue
        const xx = Math.floor(x + (p - minPitch) * pxPerPitch)
        const ww = Math.ceil(pxPerPitch * 0.9)
        const hh = Math.floor(h * 0.62)
        const pressedHere = pressed?.has(p)

        fillRect(ctx, xx, y, ww, hh, pressedHere ? 'rgba(236, 72, 153, 0.85)' : 'rgba(0,0,0,0.7)')
        // Small bevel
        drawLine(ctx, xx, y, xx + ww, y, 'rgba(255,255,255,0.12)')
    }

    // C boundaries for orientation
    for (let p = minPitch; p <= maxPitch; p++) {
        if ((p % 12) === 0) {
            const xx = Math.floor(x + (p - minPitch) * pxPerPitch)
            drawLine(ctx, xx, y, xx, y + h, 'rgba(255,255,255,0.18)')
        }
    }
}



function midiToNoteName(pitch: number): string {
    const names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    const name = names[(pitch % 12 + 12) % 12]
    const octave = Math.floor(pitch / 12) - 1
    return `${name}${octave}`
}
