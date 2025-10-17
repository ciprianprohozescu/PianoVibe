// falling bars view (PixiJS mounted here)
import { useEffect, useRef } from "react";
import * as PIXI from "pixi.js";
import useLessonStore from "../../store/useLessonStore";
import * as Tone from "tone";

const KEY_MIN = 21;
const LANE_WIDTH = 16;
const PX_PER_SEC = 180;   // visual speed

export default function PianoRoll() {
    const ref = useRef<HTMLDivElement>(null);
    const lesson = useLessonStore(s => s.lesson);

    useEffect(() => {
        if (!ref.current) return;
        
        let app: PIXI.Application | null = null;
        let tickerCallback: (() => void) | null = null;
        
        const initPixi = async () => {
            try {
                app = new PIXI.Application();
                await app.init({ resizeTo: ref.current, backgroundAlpha: 0 });
                
                if (ref.current) {
                    ref.current.appendChild(app.canvas);
                }

                const stage = new PIXI.Container();
                app.stage.addChild(stage);

                if (lesson) {
                    for (const n of lesson.notes) {
                        const lane = (n.pitch - KEY_MIN) * LANE_WIDTH;
                        const h = Math.max(6, (n.end - n.start) * PX_PER_SEC);
                        const rect = new PIXI.Graphics();
                        rect.beginFill(0x22ccff);
                        rect.drawRoundedRect(lane, -h, LANE_WIDTH - 2, h, 3);
                        rect.endFill();
                        rect.y = - (n.start * PX_PER_SEC); // start above
                        stage.addChild(rect);
                        // store for highlighting on hit if you want (map by pitch & time)
                    }
                }

                const hitLineY = app.renderer.height - 140; // where keys are
                tickerCallback = () => {
                    const t = Tone.Transport.seconds;
                    stage.y = hitLineY + (t * PX_PER_SEC);
                };
                if (app.ticker) {
                    app.ticker.add(tickerCallback);
                }
            } catch (error) {
                console.error('Failed to initialize PixiJS:', error);
            }
        };

        initPixi();

        return () => {
            if (app && tickerCallback) {
                try {
                    if (app.ticker) {
                        app.ticker.remove(tickerCallback);
                    }
                    app.destroy(true);
                } catch (error) {
                    console.error('Error during PixiJS cleanup:', error);
                }
            }
        };
    }, [lesson]);

    return <div ref={ref} className="w-full h-full" />;
}
