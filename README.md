# crawler

A multi-threaded command-line web crawler for macOS. Give it a URL, it follows same-host links in no guaranteed order (queue draining is hash-order, not FIFO — a `-limit`ed crawl isn't a stable "closest N pages" sample across runs), and writes every URL it found — fetched, filtered, or errored — to a report file with full parent/child discovery tracking.

Typical uses: link-rot audits, orphan-page detection, cache-header review, mapping a site's internal link graph before a migration.

## Build

```bash
xcodebuild -project crawler.xcodeproj -scheme crawler -configuration Debug build
# or -configuration Release
```

Equivalently, open `crawler.xcodeproj` in Xcode and build/run with Cmd+B / Cmd+R — the command above is just the CLI form of the same project and scheme, useful for scripting or CI.

Swift 5.0, macOS 13+ (lowered from an accidental 26.0/26.5 bump — see CLAUDE.md). Dependency resolution requires network access on first build (Swift Package Manager fetches SwiftyRequest and its transitive packages — AsyncHTTPClient, SwiftNIO, NIOSSL — into DerivedData).

## Usage

```bash
./crawler -v -t 10 -retry 3 -filter "/fileadmin/,tx_news,tx_t3events_events" -keywords "login,admin,contact" -o ~/Desktop/list.txt https://example.com/
```

| Option | Default | Meaning |
|---|---|---|
| `-t <n>` | 1 | Pages fetched concurrently. |
| `-v` | off | Print progress to the console as pages are fetched. |
| `-filter <list>` | none | Comma-separated substrings. Any discovered URL containing one is blacklisted — still recorded, never fetched. |
| `-keywords <list>` | none | Comma-separated strings. Each fetched page's HTML is scanned (case-insensitive) and matches are recorded per-URL. |
| `-limit <n>` | 0 (unlimited) | Stop once this many pages have been fetched or are in flight. |
| `-retry <n>` | 3 | Total attempts per URL, including the first. `1` disables retrying. Only transport failures retry (connection refused, TLS handshake failure, timeout) — an HTTP error status like 404 or 500 is a real answer and is never retried. |
| `-o <file>` | none | Report file path. Without it, nothing is written to disk. |
| `-h`, `--help` | — | Print usage and exit. |

Run `./crawler --help` any time for this table from the binary itself.

The crawler only follows links whose host matches the seed URL's host — it does not cross domains. It also only resolves links that are absolute (`https://same-host/...`) or root-relative (`/path`); a page-relative link like `page.html` or `../about/` is silently dropped, not queued. `Ctrl-C` triggers a clean shutdown that writes the report with everything discovered so far.

Redirects are never followed silently. A `3xx` response is recorded as its own row with the real status code, and its `Location` header is queued as a new discovered URL — parented to the redirecting page, same-host-only rule included — so a redirect chain shows up in the report exactly like any other link, instead of just resolving to its final destination's `200`.

## Console output (`-v`)

```
[19:16:17] (o:0|f:1|b:0|a:1) 200 - -1 - 559b 143.130417ms https://example.com/ [domain]
[19:16:17] (o:0|f:1|b:0|a:1) 404 - -1 - 559b 93.80675ms https://example.com/nonexistent-page-xyz
[19:16:18] (o:0|f:1|b:0|a:1) ERR - -1 - 0b 3.033084ms https://bad-host.invalid/ <connectionFailed after 2 attempts>
```

(Captured from real runs of the built binary — `Request_Time_MS` is a raw `Double`, so it prints with whatever precision the timer gave, not rounded. `example.com` sends no `Cache-Control` or `Expires` header at all, hence the two `-`s.)

`(o:open|f:finished|b:blacklisted|a:all)`, then HTTP code (or `ERR` if the server never answered), raw `Cache-Control` header (`-` if absent), `max-age` value (`-1` if absent), raw `Expires` header (`-` if absent), bytes received, response time, URL. Console output isn't a positional format the way the report file is, so this order is chosen for readability, not compatibility. The trailing `[keyword,...]` and `<...>` segments only appear when there's something to show — matched keywords, or a retry/error note.

## Report file format

Space-separated columns, one header row:

```
ID Parent_Ids HTTP_CODE Cache_Control Max_Age Request_Time_MS URL Keywords Attempts Error Expires Bytes
```

`Expires` and `Bytes` are appended at the end rather than grouped next to the other cache/size columns — they were added after the original ten columns shipped, and appending keeps every pre-existing column's position stable (a script written against the old format, e.g. `awk '{print $7}'` for URL, still works unchanged).

Real rows from the built binary (single-page fetches — assembled here into one illustrative table; the multi-parent and blocked-path rows are invented to show the shape, everything else is an actual captured value):

```
ID Parent_Ids HTTP_CODE Cache_Control Max_Age Request_Time_MS URL Keywords Attempts Error Expires Bytes
0 - 200 - -1 143.130417 https://example.com/ domain 1 - - 559
1 0 404 - -1 93.80675 https://example.com/nonexistent-page-xyz - 1 - - 559
2 0,1 0 - -1 3.033084 https://bad-host.invalid/ - 2 connectionFailed - 0
3 1 0 - -1 0.0 https://example.com/blocked-path - 0 - - 0
```

- **ID**: sequential, stable for a given URL across the whole run.
- **Parent_Ids**: comma-separated IDs of pages this URL was linked from, or `-` for the seed URL (no parent). A URL found from multiple pages lists all of them.
- **HTTP_CODE**: the status the server actually returned. `0` means the server never answered at all — check **Error** and **Attempts** to see why.
- **Cache_Control**: the raw `Cache-Control` header value(s), or `-` if the header was absent. Deliberately raw, not a derived `cacheable` flag: per RFC 9111, no header does not mean "cacheable" (heuristic caching may still apply depending on `Expires`/`Last-Modified`/`ETag`, which this column can't tell you either — cross-check with `curl -I` for those), and a single bool can't distinguish `no-cache` (may store, must revalidate) from `no-store` (must not store). Spaces in the header value are replaced with `_` so the column stays positionally parseable.
- **Max_Age**: the `max-age` directive's value parsed out of `Cache_Control`, or `-1` if there wasn't one (no header, or a header without `max-age`) — that includes rows with no response at all (transport failures, never-fetched URLs).
- **Request_Time_MS**: response time in milliseconds, printed as a raw `Double` (full float precision, `0.0` if never fetched).
- **Keywords**: comma-separated `-keywords` matches found in the page's HTML, or `-` if none (or none configured).
- **Attempts**: how many times this URL was fetched. `0` means it was never fetched at all.
- **Error**: a short stable token (e.g. `readTimeout`, `tlsHandshakeFailed`, `connectionFailed`) when the transport never got a response, or `-` otherwise.
- **Expires**: the raw `Expires` header value, or `-` if absent, same `_`-for-space substitution as `Cache_Control`. RFC 9111 gives this priority over heuristic caching when `Cache-Control` is missing.
- **Bytes**: size of the received response body — the exact wire byte count for any real HTTP response (2xx through 5xx), and `0` for transport failures (nothing was received).

Every column is always present — `-` is the placeholder for "nothing here" — so the file stays parseable by fixed column position (`awk '{print $3}'`, etc.) regardless of content.

**Disambiguating `HTTP_CODE 0`:** a row with `Attempts ≥ 1` and a value in `Error` was fetched but the transport never got a response (`Attempts` may be more than 1 if it was retried). A row with `Attempts 0` and `Error -` was *never fetched* — it's either blacklisted by `-filter`, or it was still queued when `-limit` or `Ctrl-C` ended the run. The report has no separate blacklist marker, so cross-reference against your `-filter` list to tell those two apart.

Note `-limit` counts pages *fetched or in flight*, not URLs discovered — a run can (and usually does) report far more rows than the limit, since every linked URL is recorded even if it was never crawled.

## Testing

```bash
xcodebuild test -project crawler.xcodeproj -scheme crawler -destination 'platform=macOS'
```

32/34 tests pass. The 2 known failures (`CrawlerSystemTests.testInvalidURLHandling`) reflect a real gap in `Crawler.crawl()`'s URL validation (it accepts `ftp://` URLs and a couple of malformed scheme strings), not a broken test — see CLAUDE.md for the exact mechanism. See crawlerTests/README.md for what each test file covers.
