// falling bars view (PixiJS mounted here)
import { useEffect, useRef } from "react";
import * as PIXI from "pixi.js";
import useLessonStore from "../../store/useLessonStore";
import * as Tone from "tone";

const KEY_MIN = 21, KEY_MAX = 108;
const LANE_WIDTH = 16;
const PX_PER_SEC = 180;   // visual speed

export default function PianoRoll() {
    const ref = useRef<HTMLDivElement>(null);
    const lesson = useLessonStore(s => s.lesson);

    useEffect(() => {
        if (!ref.current) return;
        const app = new PIXI.Application({ resizeTo: ref.current, backgroundAlpha: 0 });
        ref.current.appendChild(app.view as HTMLCanvasElement);

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
        const ticker = app.ticker.add(() => {
            const t = Tone.Transport.seconds;
            stage.y = hitLineY + (t * PX_PER_SEC);
        });

        return () => {
            app.ticker.remove(ticker);
            app.destroy(true);
        };
    }, [lesson]);

    return <div ref={ref} className="w-full h-full" />;
}
