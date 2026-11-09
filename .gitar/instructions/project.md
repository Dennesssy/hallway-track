# Project context for every Gitar agent

- Language: Swift 6 on SwiftNIO. Front end: HTMX 2 with server-rendered HTML fragments, no JavaScript framework, no build step.
- A successful CI run means `swift build` and `swift test` both pass in `swift-server/`.
- Failures caused by a missing Elasticsearch key are not code failures: those tests must be skipped, not failed.
- Do not "fix" a failure by deleting a test, loosening an assertion, or lowering the relevance baseline in `eval/`.
- The intentionally naive first version of My agenda and the Keynote Rush load generator are demo material; changes to them need a clear PR description.
