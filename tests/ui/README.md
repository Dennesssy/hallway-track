# tests/ui

Manual UI verification for the Merge Forward track. `CHECKLIST.md` is worked through by the human in Safari Technology Preview and records pass/fail, notes and screenshots for: keyboard-only run, 390px width, light and dark, forced-colors, 200% text size, VoiceOver, reduced motion, agenda and demo beats.

Automated checks live with the product: the server routes are exercised by `swift test` (see `swift-server/Tests/`), and search/filter/escape behaviour is verified against the live API in this checklist's A-rows. The front end itself is static HTML + plain JS (`swift-server/Public/`), so UI behaviour is verified in the browser; there is no headless browser step.
