# Kavita GDS

This release provides the Kavita official `0.9.0.6` based GDS build as a Docker image archive and GHCR Docker image.

Version: `9.0.6-1`

## Included Platforms

- `linux/amd64`
- `linux/arm64` on GHCR

## Asset

`kavita-gds.tar.gz`

Use the repository `SHA256SUMS` file or the release checksum note to verify the downloaded asset.

## Verification

- Built from the official Kavita `0.9.0.6` source with the GDS patch set ported forward.
- `linux/amd64` image startup was smoke-tested in `kavita-test` and then applied to production.
- `linux/arm64` was built from the same source and prebuilt production UI bundle, then added to the GHCR `9.0.6-1` and `latest` multi-arch manifests.
- GDS library scans now use a low-memory sequential processing path for DB updates and cover generation to reduce OOM risk on large rclone-backed libraries.
- GDS file discovery now avoids the highest-memory scanner paths by streaming directory traversal, parsing large GDS folders sequentially, and releasing retained file lists after parse.
- GDS library scans skip forced word-count analysis during the scan path; word-count can still be run separately through analyze actions. This keeps cover-focused forced scans from re-reading large remote EPUBs for minutes per series.
- Fixture reader validation passed 3 full passes across the expanded LOCAL-FIXTURES corpus: CBZ `10` series, ZIP `10` series, EPUB `10` series, TXT `10` series, plus retained problem EPUB samples.
- Production Web UI, NPM proxy access, EPUB reader page rendering, table-of-contents, and duplicate manifest repair were verified.
- rclone RC remained read-only: `deletes=0`, `renames=0`, server-side copy/move counters `0`. Later production scan attempts accumulated Google Drive rate-limit errors, not write/delete activity.
- The package does not include intermediate test images.

## Changes Since `0.9.0.2-8`

### 2026-06-01 `9.0.6-1` official `0.9.0.6` port

- Ported the maintained GDS/rclone patch set from `0.9.0.2-8` onto official Kavita `0.9.0.6`.
- Added on-read EPUB page-count repair so GDS EPUBs that scanned as `1/1` update their chapter/file/volume/series page totals when opened.
- Expanded malformed EPUB manifest repair to duplicate exact items, duplicate ids, and duplicate `href + media-type` entries.
- Applied the EPUB repair path across `book-info`, `book-page`, table-of-contents, resource, metadata, and word-count paths.
- Normalized EPUB resource keys so relative `../Images/...` links can resolve correctly.
- Kept GDS media mounts read-only and avoided scanner-side full EPUB reads against `/mnt/gds`.
- Fixed GDS archive cover regeneration so later volumes/chapters do not reuse the first volume cover.
- Fixed Korean TXT title-cover rendering by bundling Nanum Gothic Regular/Bold/ExtraBold in the runtime image.
- Added a low-memory GDS scan path that keeps per-series DB update, cover generation, and word-count work sequential instead of running all post-scan work in parallel.
- Added a GDS-only low-memory file discovery path that streams bottom-up directory traversal and avoids one parse task per file in large folders.
- Split GDS word-count analysis out of the library scan path after production `production-library-c` showed 13,675 series and per-series EPUB word-count work taking up to 130 seconds. Cover generation remains part of the forced scan path.
- Included `sqlite3` in the runtime image for operational DB/API verification inside the container.
- Made cache cleanup tolerate concurrent directory deletion.
- Validated `reported page-count EPUB sample` and `reported duplicate-manifest EPUB sample` production EPUBs after deployment.
- Built the public release package as a `linux/amd64` Docker archive and published GHCR tags as `linux/amd64` + `linux/arm64` multi-arch manifests.

## GHCR

```text
ghcr.io/suikano1304/kavita-gds:9.0.6-1
ghcr.io/suikano1304/kavita-gds:latest
multiarch digest=sha256:aa0a9e6c2991fc3e85d097477245762e1068f4971db6bdd7a03d2d5e0dafc4d4

linux/amd64=sha256:b56821e4faa2c0a24f3ecabf75b57bfa2ed6f133f759681db723b22ca9e542ec
linux/arm64=sha256:0e994cc2b327fddbe10c5d0a615a06b4c6ad643abb6dc546af8d29c59044ba20
```

## Historical Changes Since `kavita-gds-0.9.0.2-scan-20260528`

### 2026-05-31 `0.9.0.2-8` default series sort hotfix

- Fixed the default series sort so empty/new filter state uses last modified descending instead of sort-name ascending.
- Fixed the Web UI filter state handling that converted an explicit descending value (`false`) back to ascending.
- Updated backend null-sort fallbacks for series and bookmarks to last modified descending.
- Verified the production API returns the same first page as `Series.LastModified desc` when no sort option is supplied.
- Rebuilt `linux/amd64` and `linux/arm64` self-contained runtime packages.
- Built a new multi-platform OCI archive with both `linux/amd64` and `linux/arm64`.
- Passed a local `linux/amd64` startup smoke test for `0.9.0.2-8`.

### 2026-05-31 `0.9.0.2-7` GDS archive cover fallback hotfix

- Fixed GDS cover generation so archive-based series without a YAML/base64 cover or TXT title cover fall back to the normal ZIP/CBZ first-page cover extraction path.
- This fixes newly discovered GDS archive series being registered with valid files and page counts but no `Series`, `Volume`, or `Chapter` cover reference.
- Existing GDS TXT title-cover behavior is preserved.
- Verified the focused word-count regression test still passes.
- Rebuilt `linux/amd64` and `linux/arm64` self-contained runtime packages.
- Built a new multi-platform OCI archive with both `linux/amd64` and `linux/arm64`.
- Passed a local `linux/amd64` startup smoke test for `0.9.0.2-7`.

### 2026-05-31 `0.9.0.2-6` mixed-format word-count hotfix

- Fixed the word-count analyzer so an EPUB-format series skips non-EPUB files instead of opening PDF/TXT files with the EPUB reader.
- This prevents misleading "There was an issue counting words on an epub" errors when a GDS mixed-format series contains non-EPUB chapters.
- Added a regression test for non-EPUB files inside an EPUB-format series.
- Verified `linux/amd64` and `linux/arm64` self-contained publish.
- Built a new multi-platform OCI archive with both `linux/amd64` and `linux/arm64`.
- Passed a local `linux/amd64` startup smoke test and confirmed the Web UI bundle does not contain `localhost:5000`, `:5000/api`, or Angular development-mode strings.

### 2026-05-31 `0.9.0.2-5` Web UI production hotfix

- Fixed the public Docker image Web UI bundle so it uses the production environment.
- The broken `0.9.0.2-4` image could call `localhost:5000/api` from the browser when accessed through a host port such as `5657:5000`.
- Rebuilt the Angular UI after deleting stale `dist` output, then rebuilt the image after deleting the old `/kavita/wwwroot` contents.
- Verified the container no longer contains `localhost:5000`, `:5000/api`, or Angular development-mode strings in `/kavita/wwwroot`.
- Verified the production environment chunk uses the document base URL and resolves API calls as same-origin `/api/`.
- Built a new `linux/amd64` and `linux/arm64` OCI archive for `0.9.0.2-5`.

### 2026-05-31 `0.9.0.2-4` source/release alignment

- Added GDS handling to chapter-title routing in continue-reading and volume-detail views.
- Added GDS handling to the old file-type migration so legacy databases include Archive, EPub, Pdf, Images, and Text groups for GDS libraries.
- Built `linux/amd64` and `linux/arm64` runtime tarballs from the same source snapshot.
- Built a multi-platform OCI archive containing both `linux/amd64` and `linux/arm64`.
- Passed a local `linux/amd64` startup smoke test.
- Separated the Oracle A1 startup FK report from generic x86/NAS behavior. If the same database or image starts on x86/NAS but fails on Oracle A1, compare the existing DB migration state, volume mapping, previous shutdown state, and foreign-key diagnostics first.

### 2026-05-31 startup FK diagnostics and duplicate cleanup

- Separated startup migration execution from later BaseUrl setting persistence so a failed migration is not hidden behind a later settings save.
- Startup migration exceptions are now logged and rethrown instead of being swallowed and surfacing as a misleading later `SaveChanges` failure.
- If BaseUrl persistence fails with a database update exception, Kavita logs `PRAGMA foreign_key_check` output to make existing DB damage or migration-state issues visible.
- Same-volume duplicate file path cleanup now preserves the chapter selected by the current scan instead of retaining an arbitrary earlier duplicate.
- The read-only diagnostic script now prints SQLite foreign-key violations and classifies duplicate file path groups into cleanup-safe and cross-series cases.
- The read-only diagnostic script now includes EF migration history, manual migration history, selected server settings, and core table row counts to compare x86/NAS and Oracle A1 startup reports.
- The read-only diagnostic script now classifies MediaError rows into EPUB structure, PDF metadata/encryption, archive support, and scanner-unrecognized buckets.
- The preflight collector records host architecture and Docker engine details, which helps separate Oracle A1-only startup reports from generic x86 or image architecture issues.
- Postflight comparison can now print explicit `PASS`, `WARN`, and `FAIL` gates for integrity, foreign keys, `Pages=0`, duplicate file paths, media errors, GDS config cover references, and TXT missing-cover debt.
- Archive validation can be written into the JSON baseline, so postflight gates can separate recoverable direct-image `Pages=0` archives from nested archive structures.
- Added a read-only scan-log timing summarizer that reports library scan, file discovery, series update timings, and slow reader HTTP requests without exposing library or series names by default.
- Added a read-only reader latency correlator that maps slow reader requests to DB file size, format, page count, and cache-folder state without exposing titles or paths by default.
- Built and packaged as `0.9.0.2-4` for `linux/amd64` and `linux/arm64`.

### 2026-05-31 GDS TXT fallback cover and scan debt recovery

- Added a local title-cover generator for GDS TXT series that have no folder cover and no YAML base64 cover.
- Treated `cover: TEXT` and external cover URLs as non-image hints, so the scanner does not mistake them for embedded cover data.
- Generated fallback covers are written only to Kavita config cover storage, never to the GDS/rclone media mount.
- Bundled Nanum Gothic in the Docker image so generated Korean title covers render correctly.
- Preserved existing config cover cache when the GDS source folder has no `cover.*` file.
- Forced a real rescan for GDS series that still have `Pages=0` files, allowing stale scan debt to recover on the next library scan.
- Verified backend build, UI production build, generated-cover smoke test, `linux/amd64` container startup, and multi-arch OCI manifest contents.

### 2026-05-31 GDS incremental scan stabilization

- Matched GDS format subfolders back to their parent series folder when checking no-change scan state.
- Replaced direct unchanged-folder path lookups with a safe fallback lookup so missing alias paths do not trigger repeated scan retries.
- Matched split sibling folders by normalized directory name for GDS libraries, reducing repeated processing when physical folder names differ slightly.
- Test verification: repeated normal scan for the affected mixed-format library dropped from `5 Series / 108 files / about 7-10 seconds` to `0 Series / 0 files / about 0.8 seconds`.

### 2026-05-31 GDS light-novel mixed folder/readability patch

- Fixed GDS `chapter-info` handling for `LibraryType.GDS` so book/PDF reader routing does not hit an unsupported library type path.
- Preserved existing GDS volumes when their files still exist on disk, even if one side of a split folder layout is not present in an incremental scan result.
- Added a fast minimum page count for unchanged GDS EPUB/PDF/TXT files so they do not remain at `Pages=0` and appear unreadable.
- Allowed `force=true` GDS scans to perform a real filesystem rescan, which is slower but can recover files missed by an earlier incremental scan.
- Operational verification: a split-folder light-novel series now keeps 8 files total: 3 ZIP files and 5 EPUB files. The EPUB continue-point returns `pages=1` and the EPUB page endpoint returns content.

### 2026-05-31 GDS rescan speed patch

- Avoided recalculating page count and KOReader hash for unchanged GDS files during forced scans.
- Kept normal GDS/rclone rescans fast by avoiding unnecessary file stat/hash work on unchanged files.
- Excluded bracketed cover files such as `[Cover].jpg` from GDS media parsing.
- Skipped repeated folder-cover copy/color analysis when the local cover and colors are already present.
- Operational verification: `production-library-a` forced scan completed `11 files / 187 series` in about 2.8 seconds, and `production-library-e` completed `2 files / 2061 series` in about 4.5 seconds.

### 2026-05-31 operational verification

- Documented the production cover recovery and YAML metadata validation process.
- Added the GDS YAML metadata fix to the operational notes.
- GDS sidecar YAML now supplies safe metadata fields such as summary, tags, people, publisher, release date, and age rating.
- YAML `meta.Name` is no longer used to overwrite chapter titles.
- GDS chapter titles are derived from file names with common distribution/quality suffixes removed.
- Verified that publisher/category-prefixed folders did not create duplicate series during validation.

### 2026-05-29 fixes

- Added EPUB manifest duplicate ID recovery for malformed/generated EPUB files.
- Added PDF XRef recursion depth guard to prevent hangs on damaged PDFs.
- Reworked large rclone/FUSE directory enumeration to avoid recursive scan hangs.

### 2026-05-30 GDS scanfix

- Fixed GDS reader/runtime issues.
- Reduced series splitting when multiple formats exist under the same work folder.
- Excluded `kavita.yaml`, `kavita.yml`, `cover.*`, and similar metadata files from media scans.
- Prevented loose `.jpg` files under web-novel style paths from becoming false series/volumes.
- Added guards so GDS scans preserve DB rows and do not attempt source cleanup.
- Kept GDS cover handling inside Kavita config cover storage rather than writing to media paths.
- Improved GDS `FolderPath` and change detection by considering actual DB file parent directories.
- Reduced repeated scan churn and stabilized no-change rescans.
- Rebuilt UI delivery to avoid stale Angular chunks and set static cache policy to no-cache/no-store.
- Restored default series ordering by last modified descending.

### Multi-arch packaging

- Packaged the scanfix build as one OCI archive containing `linux/amd64` and `linux/arm64`.
- Excluded intermediate test images and the later webtoon patch tree from this public package.
- Added a GHCR publishing workflow so users can deploy with `docker pull ghcr.io/suikano1304/kavita-gds:0.9.0.2-5`.

## Caveat

This host is `amd64`, so `arm64` was build/manifest verified, but not fully runtime-tested on native ARM hardware.
