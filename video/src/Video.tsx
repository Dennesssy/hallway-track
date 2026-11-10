import React from "react";
import { AbsoluteFill, Audio, Img, Sequence, interpolate, staticFile, useCurrentFrame, useVideoConfig } from "remotion";
import { TransitionSeries, linearTiming } from "@remotion/transitions";
import { fade } from "@remotion/transitions/fade";
import { slide } from "@remotion/transitions/slide";
import timing from "../public/timing.json";

export const TRANSITION_FRAMES = 12;
export const slideFrames = (seconds: number) => Math.ceil(seconds * timing.fps);

type Part = { text: string; audio: string; start: number; duration: number };
type SlideT = { id: string; title: string; seconds: number; parts: Part[] };

const Caption: React.FC<{ text: string; frames: number }> = ({ text, frames }) => {
  const frame = useCurrentFrame();
  const opacity = interpolate(frame, [0, 6, frames - 6, frames], [0, 1, 1, 0], { extrapolateLeft: "clamp", extrapolateRight: "clamp" });
  return (
    <div style={{ position: "absolute", left: 140, right: 140, bottom: 125, display: "flex", justifyContent: "center", opacity }}>
      <div style={{ background: "rgba(8,18,30,0.86)", border: "2px solid #2B4560", borderRadius: 18, padding: "18px 34px", color: "#EAF1F8", fontFamily: "Inter, 'Helvetica Neue', Helvetica, Arial, sans-serif", fontSize: 42, lineHeight: 1.3, textAlign: "center", maxWidth: 1560 }}>
        {text}
      </div>
    </div>
  );
};

const SlideScene: React.FC<{ slide: SlideT }> = ({ slide }) => {
  const frame = useCurrentFrame();
  const { fps, durationInFrames } = useVideoConfig();
  const zoom = interpolate(frame, [0, durationInFrames], [1, 1.025]);
  return (
    <AbsoluteFill style={{ background: "#0D1B2A" }}>
      <AbsoluteFill style={{ transform: `scale(${zoom})`, transformOrigin: "50% 40%" }}>
        <Img src={staticFile(`svg/${slide.id}.svg`)} style={{ width: 1920, height: 1080 }} />
      </AbsoluteFill>
      {slide.parts.map((p, i) => {
        const from = Math.round(p.start * fps);
        const frames = Math.round((p.duration + 0.3) * fps);
        return (
          <React.Fragment key={i}>
            <Sequence from={from} durationInFrames={frames} layout="none">
              <Audio src={staticFile(p.audio)} />
            </Sequence>
            <Sequence from={from} durationInFrames={frames}>
              <Caption text={p.text} frames={frames} />
            </Sequence>
          </React.Fragment>
        );
      })}
    </AbsoluteFill>
  );
};

export const HallwayTrack: React.FC = () => (
  <AbsoluteFill style={{ background: "#0D1B2A" }}>
    <TransitionSeries>
      {(timing.slides as SlideT[]).flatMap((s, i) => {
        const items: React.ReactNode[] = [
          <TransitionSeries.Sequence key={s.id} durationInFrames={slideFrames(s.seconds)}>
            <SlideScene slide={s} />
          </TransitionSeries.Sequence>,
        ];
        if (i < timing.slides.length - 1) {
          items.push(
            <TransitionSeries.Transition
              key={`t-${i}`}
              presentation={i % 2 === 0 ? fade() : slide({ direction: "from-right" })}
              timing={linearTiming({ durationInFrames: TRANSITION_FRAMES })}
            />,
          );
        }
        return items;
      })}
    </TransitionSeries>
  </AbsoluteFill>
);
