import React, { useEffect, useMemo, useState } from 'react'
import { parseMidi } from './midi/parseMidi'
import type {Song} from './types'
import { Transport } from './transport'
import PianoRollCanvas from './render/PianoRollCanvas'
import { SimpleSynth } from './audio/SimpleSynth'
import { SongScheduler } from './audio/SongScheduler'
import { Grader, type NoteStateMap } from './grade/Grader'
import { LearnGate } from './learn/LearnGate'


type Mode = 'learn' | 'play'

type MidiInputInfo = {
    id: string
    name: string
}

export default function App() {
    const transportRef = React.useRef<Transport | null>(null)
    if (!transportRef.current) transportRef.current = new Transport()
    const transport = transportRef.current

    const synthRef = React.useRef<SimpleSynth | null>(null)
    const schedulerRef = React.useRef<SongScheduler | null>(null)
    if (!synthRef.current) synthRef.current = new SimpleSynth(transport.audioContext)
    if (!schedulerRef.current) schedulerRef.current = new SongScheduler(transport, synthRef.current)
    const synth = synthRef.current
    const scheduler = schedulerRef.current

    const currentInputRef = React.useRef<WebMidi.MIDIInput | null>(null)
    const [midiSupported, setMidiSupported] = useState<boolean | null>(null)
    const [midiAccess, setMidiAccess] = useState<WebMidi.MIDIAccess | null>(null)
    const [inputs, setInputs] = useState<MidiInputInfo[]>([])
    const [selectedInputId, setSelectedInputId] = useState<string>('')

    const [mode, setMode] = useState<Mode>('learn')
    const [file, setFile] = useState<File | null>(null)
    const [song, setSong] = useState<Song | null>(null)
    const [isPlaying, setIsPlaying] = useState(false)
    const [tempoPct, setTempoPct] = useState(100)

    const [pressed, setPressed] = useState<Set<number>>(new Set())
    const [noteStates, setNoteStates] = React.useState<NoteStateMap>(new Map())

    const graderRef = React.useRef<Grader | null>(null)
    if (!graderRef.current) graderRef.current = new Grader(transport, setNoteStates)
    const grader = graderRef.current

    const learnGateRef = React.useRef<LearnGate | null>(null)

    // Feature detection + request permission
    useEffect(() => {
        const hasWebMIDI = !!navigator.requestMIDIAccess
        setMidiSupported(hasWebMIDI)
        if (!hasWebMIDI) return

        navigator.requestMIDIAccess({ sysex: false })
            .then(access => {
                setMidiAccess(access)
            })
            .catch(err => {
                console.error('WebMIDI permission/request failed:', err)
                setMidiAccess(null)
            })
    }, [])

    // Keep a stable updater to rebuild the inputs array
    const rebuildInputs = useMemo(() => {
        return (access: WebMidi.MIDIAccess) => {
            const arr: MidiInputInfo[] = []
            access.inputs.forEach((inp) => {
                arr.push({
                    id: inp.id,
                    name: inp.name || `MIDI Input (${inp.manufacturer ?? 'Unknown'})`,
                })
            })
            setInputs(arr)
            // If nothing selected, auto-select the first input
            if (!selectedInputId && arr.length > 0) {
                setSelectedInputId(arr[0].id)
            }
            // If the selected input vanished, clear it
            if (selectedInputId && !arr.find(x => x.id === selectedInputId)) {
                setSelectedInputId(arr[0]?.id ?? '')
            }
        }
    }, [selectedInputId])

    // Build device list + listen for hot-plug changes
    useEffect(() => {
        if (!midiAccess) return

        // Initial fill
        rebuildInputs(midiAccess)

        const onStateChange = (e: WebMidi.MIDIConnectionEvent) => {
            // When a device connects/disconnects, rebuild list
            rebuildInputs(midiAccess)
        }

        midiAccess.addEventListener('statechange', onStateChange)
        return () => midiAccess.removeEventListener('statechange', onStateChange)
    }, [midiAccess, rebuildInputs])

    const onFileChange = (e: React.ChangeEvent<HTMLInputElement>) => {
        const f = e.target.files?.[0] ?? null
        setFile(f)
    }

    const onClickPlay = async () => {
        if (!file) {
            alert('Choose a MIDI file first')
            return
        }

        // Parse only once per file selection
        if (!song) {
            let parsed: Song
            try {
                const buf = await file.arrayBuffer()
                parsed = parseMidi(buf)
            } catch (e) {
                console.error(e)
                alert('Failed to parse MIDI: ' + (e as Error).message)
                return
            }

            if (mode === 'learn') {
                learnGateRef.current = new LearnGate(transport, parsed)
                learnGateRef.current.enable()
            }
            scheduler.setSong(parsed)
            grader.setSong(parsed)
            setSong(parsed)
        }

        // Toggle transport + start/stop scheduler
        await transport.toggle()
        setIsPlaying(transport.isRunning)
        if (transport.isRunning) {
            scheduler.start()
            grader.start()
        } else {
            // keep scheduled notes, but stop sounding ones
            synth.allNotesOff()
            grader.stop()
            setPressed(new Set())
        }
    }

    function bindSelectedMidiInput(access: WebMidi.MIDIAccess, inputId: string) {
        // Clear old listener
        if (currentInputRef.current) {
            currentInputRef.current.onmidimessage = null as any
            currentInputRef.current = null
        }
        if (!inputId) return

        const input = Array.from(access.inputs.values()).find(i => i.id === inputId) || null
        if (!input) return

        currentInputRef.current = input
        input.onmidimessage = (e: WebMidi.MIDIMessageEvent) => {
            const [status, data1, data2] = e.data
            const hi = status & 0xF0
            // Note On
            if (hi === 0x90 && data2 > 0) {
                const pitch = data1
                setPressed(prev => {
                    const next = new Set(prev)
                    next.add(pitch)
                    return next
                })
                const timeMs = transport.currentMs()
                grader.addPress(pitch, timeMs)
            } else if (hi === 0x80 || (hi === 0x90 && data2 === 0)) {
                // Note Off (or Note On with velocity 0)
                const pitch = data1
                setPressed(prev => {
                    if (!prev.has(pitch)) return prev
                    const next = new Set(prev)
                    next.delete(pitch)
                    return next
                })
            }
            // (Optional) sustain pedal, etc., can be handled later if needed
        }
    }

    useEffect(() => {
        if (!midiAccess) return
        bindSelectedMidiInput(midiAccess, selectedInputId)
    }, [midiAccess, selectedInputId])

    useEffect(() => {
        if (!song) return
        if (mode === 'learn') {
            learnGateRef.current = new LearnGate(transport, song)
            learnGateRef.current.enable()
        } else {
            learnGateRef.current?.disable()
            learnGateRef.current = null
        }
    }, [mode, song, transport])

    useEffect(() => {
        learnGateRef.current?.onStatesUpdate(noteStates)
    }, [noteStates])

    return (
        <div style={styles.page}>
            <div style={styles.card}>
                <h1 style={{ margin: 0 }}>Piano Learner (prototype)</h1>
                <p style={{ marginTop: 8, opacity: 0.8 }}>
                    Upload a MIDI file, choose a mode, select your MIDI keyboard, then hit Play.
                </p>

                {/* MIDI support notice */}
                {midiSupported === false && (
                    <div style={styles.notice}>
                        Web MIDI is not supported in this browser. Try Chrome/Edge on desktop, or enable it via flags.
                    </div>
                )}
                {midiSupported && !midiAccess && (
                    <div style={styles.notice}>
                        Waiting for MIDI permission or no MIDI available.
                    </div>
                )}

                {/* File picker */}
                <section style={styles.section}>
                    <label style={styles.label}>MIDI file</label>
                    <input
                        type="file"
                        accept=".mid,.midi,audio/midi"
                        onChange={onFileChange}
                    />
                    {file && <div style={styles.hint}>Selected: {file.name}</div>}
                </section>

                {/* Mode select */}
                <section style={styles.section}>
                    <label style={styles.label}>Mode</label>
                    <div style={styles.row}>
                        <label style={styles.radio}>
                            <input
                                type="radio"
                                name="mode"
                                value="learn"
                                checked={mode === 'learn'}
                                onChange={() => setMode('learn')}
                            />
                            <span>Learn (wait for correct notes)</span>
                        </label>
                        <label style={styles.radio}>
                            <input
                                type="radio"
                                name="mode"
                                value="play"
                                checked={mode === 'play'}
                                onChange={() => setMode('play')}
                            />
                            <span>Play (free run)</span>
                        </label>
                    </div>
                </section>

                {/* MIDI input device */}
                <section style={styles.section}>
                    <label style={styles.label}>MIDI input device</label>
                    <select
                        value={selectedInputId}
                        onChange={(e) => setSelectedInputId(e.target.value)}
                        disabled={!midiAccess || inputs.length === 0}
                    >
                        {inputs.length === 0 ? (
                            <option value="">No MIDI inputs found</option>
                        ) : (
                            inputs.map((i) => (
                                <option key={i.id} value={i.id}>{i.name}</option>
                            ))
                        )}
                    </select>
                    <div style={styles.hint}>
                        Tip: Connect your keyboard via USB or a MIDI→USB interface, then refresh this page.
                    </div>
                </section>

                <section style={styles.section}>
                    <div style={{ display: 'flex', gap: 12, alignItems: 'center', flexWrap: 'wrap' }}>
                        <button
                            style={styles.button}
                            onClick={onClickPlay}
                            disabled={!file}
                            title={!file ? 'Choose a MIDI file first' : 'Ready'}
                        >
                            {isPlaying ? 'Pause' : 'Play'}
                        </button>

                        <button
                            style={styles.button}
                            onClick={() => { synth.allNotesOff(); setPressed(new Set()); transport.seek(0); scheduler.reset(); grader.reset(); learnGateRef.current?.resetToStart(); setIsPlaying(transport.isRunning) }}
                            disabled={!song}
                            title="Seek to start"
                        >
                            ⏮︎
                        </button>

                        <label style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
                            Tempo {tempoPct}%
                            <input
                                type="range"
                                min={50}
                                max={150}
                                value={tempoPct}
                                onChange={(e) => {
                                    const v = Number(e.target.value)
                                    setTempoPct(v)
                                    transport.setTempoMultiplier(v / 100)
                                }}
                            />
                        </label>
                    </div>
                </section>
            </div>

            {song && (
                <section style={styles.fullBleedSection}>
                    <PianoRollCanvas song={song} transport={transport} windowMs={9000} pressed={pressed} noteStates={noteStates} />
                    <div style={{ opacity: 0.7, fontSize: 12, marginTop: 6, paddingInline: 16 }}>
                        Showing next 9 seconds. Notes fall into the keyboard lane. Physical MIDI keys highlight below.
                    </div>
                </section>
            )}
        </div>
    )
}

const styles: Record<string, React.CSSProperties> = {
    page: {
        minHeight: '100dvh',
        display: 'block',
        background: 'linear-gradient(180deg, #0f172a, #0b1023)',
        color: '#e5e7eb',
        fontFamily: 'system-ui, -apple-system, Segoe UI, Roboto, Ubuntu, Cantarell, Noto Sans, sans-serif',
        padding: 16,
        overflowX: 'hidden',
    },
    card: {
        width: '100%',
        maxWidth: 900,
        margin: '0 auto',
        background: 'rgba(255,255,255,0.06)',
        border: '1px solid rgba(255,255,255,0.12)',
        borderRadius: 16,
        padding: 20,
        boxShadow: '0 10px 30px rgba(0,0,0,0.3)',
    },
    section: { marginTop: 16 },
    label: { display: 'block', marginBottom: 6, fontWeight: 600 },
    row: { display: 'flex', gap: 24, alignItems: 'center' },
    radio: { display: 'flex', alignItems: 'center', gap: 8, cursor: 'pointer' },
    button: {
        padding: '10px 18px',
        borderRadius: 10,
        border: '1px solid rgba(255,255,255,0.2)',
        background: 'rgba(255,255,255,0.1)',
        color: 'white',
        cursor: 'pointer',
    },
    notice: {
        padding: 10,
        background: 'rgba(255, 193, 7, 0.15)',
        border: '1px solid rgba(255, 193, 7, 0.35)',
        borderRadius: 12,
        marginTop: 12,
        fontSize: 14,
    },
    hint: { marginTop: 6, opacity: 0.75, fontSize: 12 },
    footer: { marginTop: 22, opacity: 0.6 },
    fullBleedSection: {
        width: '100vw',
        position: 'relative',
        left: 0,
        right: '50%',
        marginLeft: 'calc(50% - 50vw)',
        marginRight: 'calc(50% - 50vw)',
        marginTop: 16,
    },
}
