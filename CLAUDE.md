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

`crawlerTests` is a real Unit Testing Bundle target (`xcodebuild test -project crawler.xcodeproj -scheme crawler -destination 'platform=macOS'`). All tests pass. (`CrawlerSystemTests.testInvalidURLHandling` used to fail — `Crawler.crawl()` accepted `ftp://` and `://invalid`; validation was since tightened to require an `http`/`https` scheme and a host.)

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
| `Modules/DTO/CacheControl.swift` | Parses `Cache-Control`/`Expires` headers into raw values + `maxAge` |
| `Modules/HTMLLinkParser.swift` | Regex-based `<a href>` extraction, relative→absolute resolution, same-host filtering |
| `Modules/Network/NetworkLoader.swift` | HTTP fetch directly via AsyncHTTPClient (redirects disallowed, `Location` handled as a discovered link), retry with backoff, error classification |
| `Modules/Helper/CommandArgumentParser.swift`, `CommandArgumentResult.swift` | CLI flag parsing |
| `Modules/OutputGenerator.swift` | Report file rendering (see README's column table) |
| `Modules/Visualizer/Visualizer.swift` | `crawler visual`: embeds a report into the HTML template, writes `<dir>/<report>.html` |
| `Modules/Visualizer/VisualizerTemplate.swift` | The whole viewer page (HTML/CSS/JS) as one Swift raw string |
| `Modules/Visualizer/D3Hierarchy.swift` | Vendored, unmodified `d3-hierarchy` v3.1.2 (ISC) as a raw string — layout maths only |

### Dependencies

Only `SwiftyRequest` (`upToNextMajor(3.2.200)`) is a declared package dependency (project.pbxproj). `AsyncHTTPClient`, `NIO`, `NIOHTTP1`, `NIOSSL` are imported directly in code but arrive **transitively** through SwiftyRequest — there's no separate package reference to bump for them. Note that no source file actually calls into SwiftyRequest's own API anymore (`NetworkLoader` talks to `AsyncHTTPClient.HTTPClient` directly, see the invariant below) — SwiftyRequest's only remaining job is being the package-graph entry point that pulls in the others. Don't remove the dependency without first re-pointing the project at `AsyncHTTPClient`/`NIOSSL` directly.

## Invariants that matter when changing this code

**All `TaskPool` mutation happens on the main queue — there is no locking, and none is needed as long as that holds.** The call chain `crawl()` → `warmupThreads()` → `execute()` → `processOpenTask()` runs from three places: `crawl()` (main), the `completion:` closure of `DispatchQueue.background` (main), and `NetworkLoader.complete()` (explicitly wrapped in `DispatchQueue.main.async` — check the current line, this file gets edited). The only things touched off-main are `task.url` (read-only, inside `process(task:)` on the background queue) and, for a redirect, the same `task.url` plus a read of the delegate's base URL inside `discoverRedirectTarget(from:task:)` (also read-only, called before the `DispatchQueue.main.async` hop in `complete()` — same pattern the existing `HTMLLinkParser.parse` call already used). Adding a feature that *mutates* a `CrawlerTask` or `TaskPool` off the main queue reintroduces a race that today doesn't exist.

**`NetworkLoader` talks to `AsyncHTTPClient.HTTPClient` directly — it used to go through SwiftyRequest's `RestRequest`, and that's gone now, on purpose.** Two reasons: (1) `RestRequest` builds its own `HTTPClient` internally with `redirectConfiguration` hardcoded to follow up to 5 redirects, with no public override — so a 3xx was always silently resolved to its final destination, and the crawler never saw the redirect, never recorded it, and never queued its target as its own discovered URL. That made redirect chains invisible to the migration/link-rot audits this tool exists for. (2) It eliminates a lifetime hazard that used to live here: `RestRequest` owned a *per-request* `HTTPClient` whose `deinit` tears down with a *blocking* `syncShutdown()`, which had to be kept alive until its own request finished and then dropped on a plain Dispatch queue — never a NIO event-loop thread (deadlock) and never `main` (stalls the crawl loop). `NetworkLoader.sharedHTTPClient` is now a single `HTTPClient` built once with `redirectConfiguration: .disallow`, for the whole process's lifetime — there's no per-request instance to race, so there's nothing to `dispose(_:)` anymore. If you ever reintroduce per-request `HTTPClient`/`RestRequest` construction, that hazard comes back with it.

**A 3xx is a terminal, recorded result — not something `NetworkLoader` resolves for you.** `attempt(task:attempt:)`'s `case 300..<400` branch reads the `Location` header, resolves it against the request URL with real RFC 3986 relative resolution (`URL(string:relativeTo:)` — not `HTMLLinkParser`'s limited absolute-or-root-relative string match, which is fine for editorial `<a href>` content but wrong here), and treats the result as the one URL this response "discovered" — same-host only, dropped if it points off-host, exactly like any other cross-host link. The redirecting URL's own row gets the real 3xx status code; the target shows up as its own row with the redirecting URL as its parent. Like any other real HTTP status, a 3xx is never retried.

**Half-open range for thread warmup.** `Crawler.swift:164` iterates `processedCount..<numOfThreads`. It used to be a closed range and started one request more than asked — `-t 4` ran 5 in flight, `-limit 250` fetched 251. If you touch `warmupThreads()`, keep it half-open.

**`code == 0` is not "unknown," it's "the server never answered."** `CrawlerTask.transportError` (CrawlerTask.swift:20-28) exists specifically so a transport failure (refused connection, TLS handshake failure, timeout) is never confused with a real server-sent status — `code` is only ever set from `response.status.code` inside the `.success` branches of `attempt(task:attempt:)` (NetworkLoader.swift), never fabricated for the `.failure` (transport) branch. Don't reintroduce a fabricated status code for transport failures; it previously sent debugging effort at the wrong system.

**Retry is transport-failure-only, and selective even then.** `NetworkLoader.isRetryable` never retries `invalidURL`/`emptyHost`/`emptyScheme`/redirect errors — those aren't transient (the `redirectLimitReached`/`redirectCycleDetected` cases are currently unreachable in practice since `redirectConfiguration: .disallow` means AsyncHTTPClient never attempts to follow a redirect in the first place, but they're harmless to leave in case that ever changes). Any real HTTP status the server sent — 2xx, 3xx, 404, 500, ... — is a real answer and is never retried. Backoff is exponential with jitter, scheduled off the event loop.

**`CacheControl` reports raw header values, not a derived `cacheable` bool.** It used to default to `cacheable = true, maxAge = -1` whenever no `Cache-Control` header was present — which fired for transport failures and never-fetched URLs just as much as for a real cache-friendly response, so `cacheable true` in the report was never evidence the page was actually cacheable. Per RFC 9111, "no header" doesn't mean cacheable (heuristic caching may or may not apply depending on `Expires`/`Last-Modified`/`ETag`) and a single bool can't distinguish `no-cache` (may store, must revalidate) from `no-store` (must not store) — so `CacheControl` (CacheControl.swift) now exposes `raw` (the joined `Cache-Control` header value, `-` if absent) and `expires` (the raw `Expires` header, `-` if absent) instead, with `maxAge` still parsed out of `raw` (`-1` if there's no `max-age` directive, header present or not). Both `raw` and `expires` collapse spaces to `_` because the report is space-separated and parsed by column position — an unescaped header value like `"max-age=3600, public"` would shift every later column. If you need real cacheability (e.g. distinguishing a TYPO3 page-cache miss from "no HTTP cache headers"), this report only gets you the raw signal — cross-check `Last-Modified`/`ETag`/`X-TYPO3-*` with a manual `curl -I` on a sample.

**`HTMLLinkParser.parse` only resolves two link shapes**: absolute same-host (`http(s)://<seed-host>/...`) and root-relative (`/path`) (HTMLLinkParser.swift:51-55). A page-relative link (`page.html`, `../about/`) matches neither branch and is silently dropped — not queued, not blacklisted, not in the report at all. Anyone debugging "why didn't it crawl X" should check this first. (A redirect's `Location` header does NOT go through this function — it gets proper relative-URL resolution instead, see the invariant above.)

**`HTMLLinkParser` no longer percent-decodes hrefs.** It used to call `.removingPercentEncoding` on the whole href, which corrupts already-encoded query values — e.g. a literal `+` in a station name like `S+U Warschauer Straße` is correctly sent by the server as `%2B`, decoding it to a bare `+` changes the byte TYPO3's `cHash` was computed over, and `cHash` validation then 404s a page that actually exists. The href must round-trip byte-for-byte back onto the wire; only HTML-entity escaping (`&amp;` → `&`) is undone now.

**Output field count must stay constant across rows.** `OutputGenerator` renders `-` for empty `Parent_Ids`/`Keywords`/`Error` (OutputGenerator.swift:35-39) instead of leaving the field blank — a blank seed-URL parent field used to shift every later column left by one for that row, breaking positional parsing. Any new column needs the same placeholder treatment.

**Timeouts are set explicitly because the library default is "forever."** `HTTPClient.Configuration.Timeout()` defaults to no timeout at all unless given one. `NetworkLoader.timeouts` (connect 10s / read 30s) is passed into `NetworkLoader.sharedHTTPClient`'s configuration to stop a crawl from parking a thread slot on a dead peer indefinitely.

## Visualizer (`crawler visual`)

**The page parses the report, Swift doesn't.** `Visualizer.render()` only drops the raw report text into the template as a JS string literal; the JS in `VisualizerTemplate.swift` is the one and only reader of the format. It locates columns **by header name**, so appending a report column is harmless, but **renaming or removing one breaks the visualizer** — grep the template for the column name before touching `OutputGenerator.generateOutputLineHeader()`. It also re-joins surplus tokens into `Error` if a row has too many fields — `OutputGenerator.field()` now escapes whitespace in `Error` and `Keywords` (`NetworkLoader.describe()`'s `httpClient(...)` fallback could contain spaces), but reports written before that fix still exist.

**Older report formats load, but degrade honestly.** The report header changed five times (see `git log -- crawler/Modules/OutputGenerator.swift`). `parseReport()` records which columns exist (`caps`); a missing column must never be read as "header absent" or "not fetched". Without `Cache_Control` the hatch is off, without `Attempts` code 0 gets its own "not fetched or no response" bucket, and the page shows a banner naming the missing columns. Keep that rule for any new column-dependent feature.

**One self-contained file, on purpose.** No CDN, no asset folder, no build phase: the viewer is a raw string (`#"""…"""#`, closing delimiter at column 0) and `d3-hierarchy` is vendored the same way. The rest of d3 (selection/transition) was deliberately replaced by plain DOM so only ~15 KB has to be embedded. Edit the JS directly in the raw string; it must never contain `"""#` (ends the string) or `\#` (interpolation). The trade-off accepted for zero build infrastructure: no JS syntax highlighting in Xcode, and every JS change needs a rebuild + `crawler visual …` to see it.

**Five placeholders, each exactly once** (`Visualizer.placeholders`; `VisualizerTests` enforces it), filled in **one pass over the template** — positions are located in the template and slices concatenated, so inserted report data is never scanned again. Don't go back to sequential `replace` calls: with two embedded reports (current + `-compare` baseline), placeholder-looking text inside the first report's URLs would get expanded. Data goes in as a JSON literal with `<` (and U+2028/2029) escaped so `</script>` in the data can't end the script early. Don't switch back to `<script type="text/plain">` embedding — that has no escape mechanism at all.

**`Visualizer` throws, never `exit()`s** — same reason as `Crawler.exitHandler`: it compiles into the test bundle. `main.swift`'s `runVisual` maps errors to stderr + exit 1, and is dispatched **before** any crawl setup, because the crawl path takes the *last* positional argument as the seed URL.

**Diff (`-compare` / *Compare with…*) matches URLs by path + query — never by ID, never by host.** IDs restart at 0 in every crawl and are assigned in hash order, and v13/v14 run on different hosts. TYPO3's `cHash` depends on the instance's `encryptionKey`, so the same page has a different cHash on another instance (measured: 0 of the cHash URLs matched between the v13 and v14 crawls) — *Ignore cHash* (default on) drops that parameter from the key. Rows that collide on a key stay unmatched and are counted, never merged. Inside the page, node identity is the node object or its side-qualified key (`c:42` / `b:42`); a node's parent/child IDs resolve only in its own report (`n.pool`). Categories compare **classes**, not raw values — TYPO3's `max-age` is a countdown, so the raw string differs between any two crawls. Baseline-only URLs join the tree **only in Diff mode**, so every other mode still matches the current report's totals. Sanity check that worked: diff two crawls of the same version — it should show ~0 status changes (it found the press-gallery route-enhancer change and nothing else).

**Cacheability in the viewer is read from the raw headers only** (same limit as `CacheControl`): `no-store` / `private|no-cache|max-age=0` / neither header. It says what a cache *may* do, not whether TYPO3 actually served from its page cache.

## Threading model

Two independent concurrency layers:
- **User-controlled (`-t`)**: how many `CrawlerTask`s are in flight at once. Managed by `Crawler`/`TaskPool` on the main queue.
- **Internal (`NetworkLoader.sharedEventLoopGroup`)**: a single `MultiThreadedEventLoopGroup` shared across all requests, sized to `ProcessInfo.processInfo.processorCount`. This is NIO's I/O layer, unrelated to `-t`; don't create a new `EventLoopGroup` per request — that's the memory leak this shared instance replaced.

## Development Notes

- Manually managed Xcode project (no SPM package manifest at the project root — dependencies are XCRemoteSwiftPackageReference entries in project.pbxproj).
- Hardened runtime enabled.
- `visual` is the only subcommand. `ArgumentParser` has no subcommand concept — `main.swift` checks whether the first positional argument is `visual`. Its `-o` means an output *directory*, unlike the crawl's `-o <file>`; `-compare <file>` only exists for `visual`. Quirk: `ArgumentParser` drops positional arguments equal to any option value, so `visual a.txt -compare a.txt` loses the report path.
- When adding a CLI option, update all four: `main.swift`'s `ArgumentParser` config, `main.swift`'s `printHelp()`, `Crawler.init`, and the options table in README.md. `printHelp()` and the README table are independent copies of the same information — touching only one leaves the other stale.
- When adding an output column, update `OutputGenerator.generateOutputLineHeader()` and `generateOutputLine(forTask:inPool:)` together, keep the `-` placeholder convention, and update README.md's column table.
