import React from "react";
import { Composition } from "remotion";
import timing from "../public/timing.json";
import { HallwayTrack, TRANSITION_FRAMES, slideFrames } from "./Video";

const total = () => timing.slides.reduce((sum, s) => sum + slideFrames(s.seconds), 0) - TRANSITION_FRAMES * (timing.slides.length - 1);

export const RemotionRoot: React.FC = () => (
  <Composition id="HallwayTrack" component={HallwayTrack} durationInFrames={total()} fps={timing.fps} width={1920} height={1080} />
);
