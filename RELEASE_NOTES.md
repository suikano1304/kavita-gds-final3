# Kavita GDS

This release provides the GDS scanfix build as a multi-platform OCI image archive.

## Included Platforms

- `linux/amd64`
- `linux/arm64`

## Asset

`kavita-gds.tar.gz`

Use the repository `SHA256SUMS` file or the release checksum note to verify the downloaded asset.

## Verification

- Built from the GDS scanfix source snapshot.
- OCI index verified to contain both `linux/amd64` and `linux/arm64`.
- `linux/amd64` image startup was smoke-tested locally.
- `linux/arm64` image entrypoint was smoke-tested under QEMU; native ARM validation should still be done on the target server.
- The package does not include intermediate test images.

## Changes Since `kavita-gds-0.9.0.2-scan-20260528`

### 2026-05-31 startup FK diagnostics and duplicate cleanup

- Separated startup migration execution from later BaseUrl setting persistence so a failed migration is not hidden behind a later settings save.
- Startup migration exceptions are now logged and rethrown instead of being swallowed and surfacing as a misleading later `SaveChanges` failure.
- If BaseUrl persistence fails with a database update exception, Kavita logs `PRAGMA foreign_key_check` output to make existing DB damage or migration-state issues visible.
- Same-volume duplicate file path cleanup now preserves the chapter selected by the current scan instead of retaining an arbitrary earlier duplicate.
- The read-only diagnostic script now prints SQLite foreign-key violations and classifies duplicate file path groups into cleanup-safe and cross-series cases.
- The read-only diagnostic script now classifies MediaError rows into EPUB structure, PDF metadata/encryption, archive support, and scanner-unrecognized buckets.
- The preflight collector records host architecture and Docker engine details, which helps separate Oracle A1-only startup reports from generic x86 or image architecture issues.
- Postflight comparison can now print explicit `PASS`, `WARN`, and `FAIL` gates for integrity, foreign keys, `Pages=0`, duplicate file paths, and media errors.
- Archive validation can be written into the JSON baseline, so postflight gates can separate recoverable direct-image `Pages=0` archives from nested archive structures.
- Added a read-only scan-log timing summarizer that reports library scan, file discovery, series update timings, and slow reader HTTP requests without exposing library or series names by default.
- Added a read-only reader latency correlator that maps slow reader requests to DB file size, format, page count, and cache-folder state without exposing titles or paths by default.
- Built and packaged as `0.9.0.2-3` for `linux/amd64` and `linux/arm64`.

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
- Added a GHCR publishing workflow so users can deploy with `docker pull ghcr.io/suikano1304/kavita-gds:0.9.0.2-3`.

## Caveat

This host is `amd64`, so `arm64` was build/manifest verified and entrypoint-tested under QEMU, but not fully runtime-tested on native ARM hardware.
