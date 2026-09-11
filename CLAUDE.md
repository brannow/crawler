# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Project Overview

Swift command-line web crawler. Crawls a site within one host, extracts links from `<a href>` tags, and writes a report with every discovered URL, its HTTP result, and its full parent-discovery chain. See README.md for user-facing usage, the CLI options table, and the report format.

Queue draining is dictionary hash order, not FIFO (`TaskPool.processOpenTask()` uses `openTask.popFirst()`) — there is no breadth-first guarantee. Don't describe or rely on crawl order as deterministic.

## Build

```bash
xcodebuild -project crawler.xcodeproj -scheme crawler -configuration Debug build
```

Single target: `crawler`, a `com.apple.product-type.tool` command-line binary. Swift 5.0. `MACOSX_DEPLOYMENT_TARGET = 13.0` on both `crawler` and `crawlerTests` (project-level default is 10.15). This was found at 26.0/26.5 — almost certainly an accidental bump from Xcode's own "upgrade to recommended settings" on opening in a newer Xcode — and lowered deliberately so CI (GitHub Actions macOS runners) isn't gambling on a bleeding-edge SDK being available. Check `project.pbxproj` directly before quoting this value; it has already drifted once.

## Testing

`crawlerTests` is a real Unit Testing Bundle target (`xcodebuild test -project crawler.xcodeproj -scheme crawler -destination 'platform=macOS'`). 32/34 tests pass. The 2 known failures (`CrawlerSystemTests.testInvalidURLHandling`) are a real product gap, not a broken test: `Crawler.crawl()`'s validation (`host == nil || scheme == nil`) accepts `ftp://example.com` (has both, just not http/https) and `://invalid` (Swift's URL parser gives it `scheme = Optional("")` — empty, not nil). Needs a decision on whether to tighten validation or relax the test.

**Important: `crawlerTests` compiles `crawler/Modules/**/*.swift` directly into the test bundle** (multi-target membership, set in the project's target membership settings) — it does **not** use `@testable import crawler` or a `TEST_HOST`. Testing this command-line tool via `TEST_HOST`/`BUNDLE_LOADER` (the standard pattern for testing an app-hosted framework) hits a hard `xcodebuild`/XCBuild validation failure ("Could not find test host") with zero build tasks ever executed — confirmed via xcresult analysis, not just circumstantial. Don't reintroduce that pattern; `main.swift` is deliberately excluded from the test target's membership (its top-level code would run inside the test process otherwise).

**`Crawler.exitHandler` exists because of this.** `Crawler.swift` used to call `exit()` directly on completion/invalid input — harmless as a separate CLI process, fatal now that its sources compile into the test bundle (kills the whole XCTest run). `exitHandler: (Int32) -> Void` defaults to real `exit()`, so shipped CLI behavior is unchanged; `TestCrawler` (in `CrawlerSystemTests.swift`) overrides it via its own `init` to drive `onCompletion` instead. If you add a new terminal path to `Crawler`, route it through `exitHandler`, not a bare `exit()`.

**`Crawler.hasFinished` guards against a latent multi-completion bug `exit()` used to mask.** `execute()` schedules a `warmupThreads()` call for every dispatched task regardless of that task's own network completion, so several stale calls can still be pending when the pool empties — each would otherwise re-enter the "crawl done" branch and call `generateOutput()`/`exitHandler(0)` again. In production this never mattered because the first `exit(0)` killed the process before a second call was possible; removing that safety net for testability made it a real, observable bug (spurious test failures from stale `onCompletion` closures firing during a later test). `finish(withCode:)` makes completion one-shot. Keep using it for any future terminal path in `warmupThreads()`.

## Architecture

| File | Responsibility |
|---|---|
| `main.swift` | CLI parsing, `SIGINT` handler that writes the report before exit |
| `Modules/Crawler.swift` | Orchestrator: thread pool warmup, blacklist/keyword matching, delegate callback from `NetworkLoader` |
| `Modules/DTO/TaskPool.swift` | URL → ID assignment, task state machine (`open`/`process`/`finish`/`blacklist`/`all`) |
| `Modules/DTO/CrawlerTask.swift` | Per-URL record: parents, HTTP result, retry/error state, matched keywords |
| `Modules/DTO/CacheControl.swift` | Parses `Cache-Control` header into `cacheable` + `maxAge` |
| `Modules/HTMLLinkParser.swift` | Regex-based `<a href>` extraction, relative→absolute resolution, same-host filtering |
| `Modules/Network/NetworkLoader.swift` | HTTP fetch via SwiftyRequest/AsyncHTTPClient, retry with backoff, error classification |
| `Modules/Helper/CommandArgumentParser.swift`, `CommandArgumentResult.swift` | CLI flag parsing |
| `Modules/OutputGenerator.swift` | Report file rendering (see README's column table) |

### Dependencies

Only `SwiftyRequest` (`upToNextMajor(3.2.200)`) is a declared package dependency (project.pbxproj). `AsyncHTTPClient`, `NIO`, `NIOHTTP1`, `NIOSSL` are imported directly in code but arrive **transitively** through SwiftyRequest — there's no separate package reference to bump for them.

## Invariants that matter when changing this code

**All `TaskPool` mutation happens on the main queue — there is no locking, and none is needed as long as that holds.** The call chain `crawl()` → `warmupThreads()` → `execute()` → `processOpenTask()` runs from three places: `crawl()` (main), the `completion:` closure of `DispatchQueue.background` (main), and `NetworkLoader.complete()` (explicitly wrapped in `DispatchQueue.main.async`, NetworkLoader.swift:205). The only thing touched off-main is `task.url`, read-only, inside `process(task:)` on the background queue. Adding a feature that mutates a `CrawlerTask` or `TaskPool` off the main queue reintroduces a race that today doesn't exist.

**`RestRequest` lifetime in `NetworkLoader.attempt(task:attempt:)`** (NetworkLoader.swift:66-116, see the comment there for the full incident). `RestRequest` owns an `HTTPClient` that its `deinit` tears down with a *blocking* `syncShutdown()`. It must be kept alive until its own request finishes, and the last reference must be dropped on a plain Dispatch queue — never a NIO event-loop thread (a blocking shutdown there deadlocks) and never `main` (it would stall the crawl loop). This is why `dispose(_:)` exists; don't inline `RestRequest` construction without routing its teardown through it.

**Half-open range for thread warmup.** `Crawler.swift:139` iterates `processedCount..<numOfThreads`. It used to be a closed range and started one request more than asked — `-t 4` ran 5 in flight, `-limit 250` fetched 251. If you touch `warmupThreads()`, keep it half-open.

**`code == 0` is not "unknown," it's "the server never answered."** `CrawlerTask.transportError` (CrawlerTask.swift:20-28) exists specifically so a transport failure (refused connection, TLS handshake failure, timeout) is never confused with a real server-sent status — `code` is now *only* ever set from an actual HTTP response (NetworkLoader.swift:87-96). Don't reintroduce a fabricated status code for transport failures; it previously sent debugging effort at the wrong system.

**Retry is transport-failure-only, and selective even then.** `NetworkLoader.isRetryable` (NetworkLoader.swift:131-146) never retries `invalidURL`/`emptyHost`/`emptyScheme`/redirect errors — those aren't transient. An HTTP error status (404, 500, ...) is a real answer and is never retried (NetworkLoader.swift:92-98). Backoff is exponential with jitter (`NetworkLoader.swift:106`), scheduled off the event loop.

**`CacheControl` defaults to `cacheable = true`, `maxAge = -1`** (CacheControl.swift:17-18) and only overrides those when a `cache-control` header is actually present. That default fires for transport failures (`NetworkLoader.swift:113` passes an empty `HTTPHeaders()`, not nil) and for never-fetched URLs (`task.header` is nil) just as much as for a real cache-friendly response — `cacheable true` in the report is not evidence the page was actually fetched or actually cacheable.

**`HTMLLinkParser.parse` only resolves two link shapes**: absolute same-host (`http(s)://<seed-host>/...`) and root-relative (`/path`) (HTMLLinkParser.swift:52-58). A page-relative link (`page.html`, `../about/`) matches neither branch and is silently dropped — not queued, not blacklisted, not in the report at all. Anyone debugging "why didn't it crawl X" should check this first.

**Output field count must stay constant across rows.** `OutputGenerator` renders `-` for empty `Parent_Ids`/`Keywords`/`Error` (OutputGenerator.swift:35-39) instead of leaving the field blank — a blank seed-URL parent field used to shift every later column left by one for that row, breaking positional parsing. Any new column needs the same placeholder treatment.

**Timeouts are set explicitly because the library default is "forever."** SwiftyRequest passes `timeout: nil` to `HTTPClient.Configuration` unless told otherwise, which `async-http-client` reads as no timeout. `NetworkLoader.timeouts` (connect 10s / read 30s) exists to stop a crawl from parking a thread slot on a dead peer indefinitely.

## Threading model

Two independent concurrency layers:
- **User-controlled (`-t`)**: how many `CrawlerTask`s are in flight at once. Managed by `Crawler`/`TaskPool` on the main queue.
- **Internal (`NetworkLoader.sharedEventLoopGroup`)**: a single `MultiThreadedEventLoopGroup` shared across all requests, sized to `ProcessInfo.processInfo.processorCount`. This is NIO's I/O layer, unrelated to `-t`; don't create a new `EventLoopGroup` per request — that's the memory leak this shared instance replaced.

## Development Notes

- Manually managed Xcode project (no SPM package manifest at the project root — dependencies are XCRemoteSwiftPackageReference entries in project.pbxproj).
- Hardened runtime enabled.
- When adding a CLI option, update all four: `main.swift`'s `ArgumentParser` config, `main.swift`'s `printHelp()`, `Crawler.init`, and the options table in README.md. `printHelp()` and the README table are independent copies of the same information — touching only one leaves the other stale.
- When adding an output column, update `OutputGenerator.generateOutputLineHeader()` and `generateOutputLine(forTask:inPool:)` together, keep the `-` placeholder convention, and update README.md's column table.
