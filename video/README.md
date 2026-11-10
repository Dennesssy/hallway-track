# Demo video source

Rebuilds the 3-minute narrated walkthrough in `../docs`-style slides.

| Step | Command | What it does |
|---|---|---|
| 1 | `npm install` | installs Remotion |
| 2 | `npm run svgs` | writes the ten 1920x1080 slide SVGs to `public/svg/` (logo, date, author and team in the footer) |
| 3 | `NVIDIA_API_KEY=... npm run narrate` | calls NVIDIA's hosted Riva (Magpie multilingual TTS) once per sentence, writes `public/audio/*.wav` and `public/timing.json` |
| 4 | `npm run render` | renders `out/hallway-track.mp4` with Remotion (captions timed to each sentence, transitions between slides) |

Notes
- The narration text is `narration.json`; it only claims what is built or says what is still being verified.
- If Remotion cannot download its headless browser, pass any Chromium-based browser: `--browser-executable=<path> --chrome-mode=chrome-for-testing`.
- The audio files are generated, so they are not committed. The finished video is a GitHub release asset: `demo-video-1`.
