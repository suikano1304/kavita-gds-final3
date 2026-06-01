# 2026-06-01 scan cover audit

## Scope

- Target libraries:
  - `production-library-a` (`LibraryId=1`)
  - `연재중` (`LibraryId=2`)
- Observed scan finish: `2026-06-01 02:24:02 KST`
- Kavita log summary: `1146 files`, `4395 series`
- Scan duration: `8631763 ms` for the library scan
- Audit window used for detailed cover verification:
  - `2026-05-31 16:45:00` to `2026-05-31 17:25:00` UTC
  - This corresponds to the final user-observed scan segment around `65%`, including the last 50 processed series in the log.
- Additional completed scan:
  - `연재중` finished at `2026-06-01 03:17:45 KST`
  - Kavita log summary: `307 files`, `1933 series`
  - Scan duration: `3221926 ms` for the library scan
  - Audit window: `2026-05-31 17:45:00` to `2026-05-31 18:18:30` UTC

No database rows, cover files, source files, media files, or container settings were changed for this audit.

## Findings

The final scan segment completed, but 2nd-and-later volume/chapter covers did not populate correctly for newly processed multi-file series.

Aggregate DB check:

`production-library-a` final observed segment:

- Multi-chapter series checked: `48`
- Chapters after the first chapter: `340`
- Missing `Chapter.CoverImage` after first chapter: `340`
- Missing `Volume.CoverImage` after first chapter: `337`

`연재중` completed scan:

- Multi-chapter series checked: `40`
- Chapters after the first chapter: `249`
- Missing `Chapter.CoverImage` after first chapter: `249`
- Missing `Volume.CoverImage` after first chapter: `249`

This means every checked chapter after the first one is missing a chapter cover in both audited scan windows.

During the `연재중` scan, a burst of `VIPS-WARNING iCCP profile ... ICC profile tag start not a multiple of 4` messages appeared while processing image covers. The scan continued afterward, so this warning is noted separately from the missing 2nd-and-later chapter cover issue.

## Evidence

Example pattern from DB:

```text
1st file:
  Volume.CoverImage  = v..._c....png
  Chapter.CoverImage = v..._c....png

2nd and later files:
  Volume.CoverImage  = empty
  Chapter.CoverImage = empty
```

The cover job logs are also suspiciously short for multi-volume archive series:

```text
Updated covers ... in 43-124 milliseconds
```

For series with 10-32 ZIP files, that duration is too short to indicate that every archive was opened and a thumbnail was extracted. It is consistent with only first-cover propagation or most chapter cover extraction being skipped.

## Likely Cause

The likely issue is in cover generation/update flow, not in rclone or the original media files.

Relevant code path:

- `Kavita.Services/MetadataService.cs`
- `ProcessSeriesCoverGen`
- `UpdateChapterCoverImage`
- `UpdateVolumeCoverImage`

The GDS library does enter normal cover generation unless a folder-level `cover.jpg/png/webp` is found. The observed state suggests:

1. First chapter cover is generated or applied.
2. Later chapters keep empty `CoverImage`.
3. Volume cover then copies the corresponding chapter cover, so later volumes also remain empty.

The `CacheHelper.ShouldUpdateCoverImage(...)` decision path should be reviewed for the empty-cover case. A false skip when `CoverImage` is empty would explain the observed pattern.

## Related Separate Issue

The EPUB reader error seen for another library item is separate from this cover issue.

That EPUB contains a duplicated manifest item ID in `OEBPS/content.opf`:

```text
duplicate id: Section0001.xhtml
```

Kavita fails because `VersOne.Epub` rejects the invalid EPUB manifest. This is an EPUB packaging problem, not the GDS manga cover issue.

## Suggested Next Investigation

Do not change production DB directly. For a fix branch or test container:

1. Reproduce with a small GDS series containing 2-3 ZIP files and no folder-level cover file.
2. Add debug logging around `UpdateChapterCoverImage`:
   - chapter id
   - current `CoverImage`
   - first file path
   - result of `ShouldUpdateCoverImage`
   - result of `readingItemService.GetCoverImage`
3. Verify that every chapter after the first actually calls archive cover extraction.
4. If fixed, rescan or regenerate covers for a small sample before applying to the full library.

## 2026-06-01 Test Fix Prepared

Prepared in source tree:

- `/root/kavita-gds-lab/port-0906-gds/Kavita.Services/MetadataService.cs`
- `/root/kavita-gds-lab/port-0906-gds/Kavita.Services/ArchiveService.cs`
- `/root/kavita-gds-lab/port-0906-gds/Kavita.Services/Helpers/GdsMetadataParser.cs`
- `/root/kavita-gds-lab/Dockerfile.0906-gds-test`

Build image:

- official baseline: `ghcr.io/kareadita/kavita:nightly-0.9.0.6`
- official revision: `c7e9555061d970b50cedc695e60124bf8c47084a`
- test image: `local/kavita-gds:9.0.6-1-test`
- Image ID: `4aa4a776f1ce1e1f74edde66de9804bddf947cb335a610b87abc0d2e68ad7ce9`

Root cause found while preparing the test build:

- The GDS-specific cover generation path returned after applying the YAML or first-cover path.
- That left later chapters and volumes in multi-file GDS series without `Chapter.CoverImage` and `Volume.CoverImage`.

Code changes prepared for test validation:

- `ProcessGdsSeriesCoverGen` now processes all non-text GDS volumes and chapters instead of returning after the first cover path.
- Text series still use the existing GDS text title-cover path.
- Archive cover extraction now returns an empty cover result instead of throwing when an archive has no candidate cover entry.

Production has not been changed. The test image is staged for `kavita-test` validation only.

## 2026-06-01 06:08 KST Test Validation

The cover issue was reproduced in `LOCAL-FIXTURES`: generated cover filenames were distinct, but 2nd-and-later CBZ/ZIP files initially had identical image hashes to volume 1. The source `kavita.yaml` file-level `cover` values were distinct, so the bug was in GDS cover selection/fallback rather than the fixture source.

Additional root cause:

- The earlier `kavita.yaml` parser could fall back to archive extraction when it did not resolve the target file's YAML cover.
- Archive extraction then selected the same embedded `cover`/first image pattern for multiple files.
- Forced metadata refresh is required to overwrite already-generated cover files; a scan alone may leave unchanged cached covers in place.

Validated fix in `kavita-test`:

```text
cbz-sample-a 01  <redacted-cover-file>  5c6c7c6e7d67e0524cc08831091fbf40150d5c4380399501f3f9af3b0b443fad
cbz-sample-a 02  <redacted-cover-file>  6313241d31770d4268e6368972039b06ca0c00b0603696aaab33e6d8b2ee29bf
cbz-sample-a 03  <redacted-cover-file>  505f6f8061bc4c258e1c79986b6d9456a5b01ac985d4e93bfeea47b4eb49a9c3
cbz-sample-b 01  <redacted-cover-file>  3e621ebceeedc677b6ae071e427553262b42bb1bc11df4ff1e30f9b7a202fcde
cbz-sample-b 02  <redacted-cover-file>  5f57cc1fb14a4e5f35394fd0e95b3dde3ecc9818b4bd8afe1df63d3299cf4462
zip-sample-a 01  <redacted-cover-file>  4a695f7c157b455e032d1fc696797276cafabba35a5a544847fb85e91d136604
zip-sample-a 02  <redacted-cover-file>  6a5ec72d8da594f846b8f1b8c14a5227526bcdf3eef6f76260dbc620182c5455
```

TXT cover rendering issue:

- Test image initially lacked Korean fonts from the official runtime path.
- Added `fontconfig` and NanumGothic TTFs to the test runtime image.
- Kept SVG `font-family` unquoted so fontconfig/Pango resolves `NanumGothic`.
- Verified `series24530.png` renders Korean text normally instead of square-box tofu glyphs.

EPUB duplicate manifest follow-up:

- Added a test-only tolerant reader path for exact duplicate OPF manifest items.
- The original EPUB is not modified; Kavita creates a temporary repaired EPUB copy and removes exact duplicate `manifest/item` entries where `id`, `href`, and `media-type` all match.
- Validated `book-info` for all three `epub-problem` chapters returned HTTP 200.
- Validated forced cover refresh and `series/analyze` completed for `epub-problem`; word counts were written:

```text
24535|epub-problem|589835|sample-chapter-redacted|180283
24535|epub-problem|589835|sample-chapter-redacted|207839
24535|epub-problem|589835|sample-chapter-redacted|201713
```

The duplicate manifest repair path now logs the recovery message without an exception stack when repair succeeds.

## 2026-06-01 06:55 KST Additional Cover Regression Check

User reported a second possible cover symptom: covers after volume/chapter 1 may all be generated as the same image as volume/chapter 1.

The latest test image was rebuilt and redeployed:

- test image: `local/kavita-gds:9.0.6-1-test`
- Image ID: `c5368ead72cbdc7bc8caa71662aeb0782d2ed114d99349c5097d740923a0b2ba`
- `kavita-test` container image hash matched the image tag hash.

After a forced `LOCAL-FIXTURES` scan, the DB and cover image hashes were checked across EPUB, CBZ, and ZIP multi-file samples.

Result:

- EPUB/CBZ/ZIP chapter cover filenames are distinct per chapter.
- EPUB/CBZ/ZIP cover file hashes are distinct per chapter.
- TXT rows share generated series title covers by design and are not treated as a cover-extraction regression.

Representative hash evidence:

```text
epub-problem sample-chapter-redacted <redacted-cover-file> ad08ac5aa8b35b4b09a960cd8420ff995f58bf1afd7f903138333120efedef1d
epub-problem sample-chapter-redacted <redacted-cover-file> da320b51520ee91f2af3c0e0690a2b4b6f2cf966fbb96442d6923d660bcc162b
epub-problem sample-chapter-redacted <redacted-cover-file> e81eb169298cc46e90ce9bc41a2caca84b12a626fe531e9ebdaf500ddbc15275
epub-sample-a sample-chapter-redacted <redacted-cover-file> a498bd2e231dbd4307cd5a248f411ec949202d9796659c6523986194de34fb4e
epub-sample-a sample-chapter-redacted <redacted-cover-file> 75dd57eef22cbb186bd4080400ba0fbf3e7c2cac1459e1054113c787a245bd9f
epub-sample-a sample-chapter-redacted <redacted-cover-file> 119e17f803886334cf3b1ce5608541c3a11720fd4bab8bd800588a31b305e5b1
zip-sample-a sample-chapter-redacted <redacted-cover-file> 4a695f7c157b455e032d1fc696797276cafabba35a5a544847fb85e91d136604
zip-sample-a sample-chapter-redacted <redacted-cover-file> 6a5ec72d8da594f846b8f1b8c14a5227526bcdf3eef6f76260dbc620182c5455
cbz-sample-a sample-chapter-redacted <redacted-cover-file> 5c6c7c6e7d67e0524cc08831091fbf40150d5c4380399501f3f9af3b0b443fad
cbz-sample-a sample-chapter-redacted <redacted-cover-file> 6313241d31770d4268e6368972039b06ca0c00b0603696aaab33e6d8b2ee29bf
```

The "2nd-and-later cover equals 1st cover" symptom is not present in the current test image after forced refresh.

## 2026-06-01 07:26 KST Expanded Fixture Validation

The final `9.0.6-1-test` image was rebuilt and redeployed:

- test image: `local/kavita-gds:9.0.6-1-test`
- Image ID: `4aa4a776f1ce1e1f74edde66de9804bddf947cb335a610b87abc0d2e68ad7ce9`
- `kavita-test`: healthy

`LOCAL-FIXTURES` was expanded to `117` media files across `26` series:

```text
Archive: 65 files, 12 series, zero pages 0, missing covers 0
EPUB:    30 files, 7 series,  zero pages 0, missing covers 0
TXT:     22 files, 7 series,  zero pages 0, missing covers 0
```

Full reader/API validation over all `117` chapters was repeated 3 times:

```text
pass=1 total=117 info_fail=0 nav_fail=0 page_fail=0 zero_bytes=0
pass=2 total=117 info_fail=0 nav_fail=0 page_fail=0 zero_bytes=0
pass=3 total=117 info_fail=0 nav_fail=0 page_fail=0 zero_bytes=0
```

The validation checked `chapter-info`, next/previous chapter APIs, and first/middle/last page fetches for every item. No `[Error]`, exception, failed Hangfire job, or `DirectoryNotFound` log appeared during the final validation or the follow-up force scan.

Final force scan:

```text
Finished library scan of 117 files and 26 series in 11037 milliseconds for LOCAL-FIXTURES
DB summary: 117 chapters, 26 series, zero pages 0, missing chapter covers 0
```

## 2026-06-01 EPUB Page Count Follow-up

A separate reader issue was found while checking problem EPUBs in the Web UI:

- The files opened.
- The reader showed `1/1`.
- Choosing an item from the content table worked, but next/previous page navigation did not behave correctly.

## 2026-06-01 Production Cover Regeneration

After deploying final image `sha256:b62e5cc99c342b5584b93c43385d5474cb6bf3b29bf7cfe4f6c17f25d5176163`, production cover references for 2nd-and-later chapters/volumes were cleaned only where they were missing or had the same hash as the first item in the series.

Backups/manifests:

- DB backup: `/mnt/data/docker/kavita/config/kavita.db.coverfix-20260601-093202.bak`
- cleanup manifest: `/root/kavita-cover-repair-20260601-093312.tsv`
- final cleanup summary: `/root/kavita-cover-repair-final-20260601-094926.json`

Final cleanup before regeneration:

```text
series_count 12695
chapter_rows_nulled 109841
volume_rows_nulled 104278
deleted_cover_files 0
```

Forced metadata refresh was queued for production libraries `1..9` with `force=true&forceColorscape=true`.

Status at `2026-06-01 10:50 KST`:

```text
production-library-a: 1300 / 4366 series complete (29.8%)
cover files: 36239
Chapter null: 100957
Volume null: 96034
production Web UI root: HTTP 200
```

The refresh is still running. The final duplicate/missing cover audit and forced production `scan-all` are intentionally deferred until metadata refresh completes.

Root cause:

- The GDS scan optimization returned `1` page for EPUB/PDF/TXT without reading the file.
- This was meant for the remote `/mnt/gds` mount but also affected local `/fixtures` files.

Fix prepared and validated:

- Keep the shortcut for `/mnt/gds`.
- For local fixture paths, run normal Kavita page-count logic.
- Recompute local fixture page count on force scan even if the previous DB value was already `1`.

Validation:

```text
sample-chapter-redacted Chapter.Pages=34 MangaFile.Pages=34
sample-chapter-redacted Chapter.Pages=49 MangaFile.Pages=49
sample-chapter-redacted Chapter.Pages=42 MangaFile.Pages=42
book-page middle/last pages HTTP 200
first EPUB font resources HTTP 200
```

## 2026-06-01 Production Apply

Production was updated after test validation and explicit user approval to interrupt the running production scan.

Backups:

- `/root/kavita-prod-backups/20260601-075551/docker-compose.yml.pre-0906-1`
- `/root/kavita-prod-backups/20260601-075551/kavita.db.pre-0906-1.backup`
- `/root/kavita-prod-backups/20260601-075551/appsettings.json.pre-0906-1`

Image:

- previous: `ghcr.io/suikano1304/kavita-gds:0.9.0.2-8`
- current: `local/kavita-gds:9.0.6-1`
- Image ID: `4aa4a776f1ce1e1f74edde66de9804bddf947cb335a610b87abc0d2e68ad7ce9`

Verification:

- production `kavita`: healthy
- `/api/health`: `Ok`
- `/mnt/gds2 -> /mnt/gds`: `RW=false`
- startup migration completed from `0.9.0.2` to `0.9.0.6`
- full force scan requested with `POST /api/library/scan-all?force=true`, HTTP `200`
- scan log shows `Starting Scan of All Libraries, Forced: true`
- rclone RC after deploy: `errors=0`, `deletes=0`, `renames=0`, `serverSideCopies=0`, `serverSideMoves=0`

Follow-up:

- The first force-scan run was followed by repeated SQLite `disk I/O error` 500s from production API requests.
- Storage and DB checks were clean: `zpool status -x` healthy, config write test OK, `PRAGMA integrity_check = ok`.
- Restarted production `kavita`; API recovered and `/api/library/libraries` returned `200`.
- Re-requested `POST /api/library/scan-all?force=true`; HTTP `200`.
- Retry scan started on `production-library-a`.
- No further SQLite `disk I/O` logs observed after restart; remaining errors were external publisher image fetch failures.

## 2026-06-01 08:31 KST Production EPUB Reader Repair

After production apply, Web UI checks found that test and production behaved differently for some EPUBs:

- `reported page-count EPUB sample` opened in test but production still showed `1/1`.
- `reported duplicate-manifest EPUB sample` produced `Incorrect EPUB manifest: item with href = "image-0001.jpg" is not unique.`

Root cause:

- The fixture library uses local `/fixtures` paths and was rescanned with real EPUB page counts.
- Production `/mnt/gds` paths still use the GDS scan shortcut, so scanner-side EPUB page counts remained `1`.
- Running real page counting during production scan was rejected because it blocked the Web UI against remote GDS reads.

Applied fix:

- Kept `/mnt/gds` scanner shortcut to avoid blocking scans.
- Added on-read EPUB page-count repair from `book-info`, updating `Chapter`, `MangaFile`, `Volume`, and `Series` page totals when an EPUB is opened and the real reading order is greater than the DB value.
- Applied duplicate manifest repair across `BookService` EPUB open paths so reader page rendering and TOC generation use the same temporary repaired EPUB copy.

Production image:

```text
local/kavita-gds:9.0.6-1
sha256:b62e5cc99c342b5584b93c43385d5474cb6bf3b29bf7cfe4f6c17f25d5176163
```

Production verification:

```text
kavita health: healthy
internal Web UI: HTTP 200
external kavita.suikano.net via NPM: HTTP 200

reported page-count EPUB sample 1권 chapter sample-chapter-redacted: pages 1 -> 15, book-page page=2 HTTP 200
reported page-count EPUB sample 2권 chapter sample-chapter-redacted: pages 1 -> 12
reported duplicate-manifest EPUB sample 1권 chapter sample-chapter-redacted: pages 1 -> 13, book-page page=2 HTTP 200, chapters HTTP 200
reported duplicate-manifest EPUB sample 2권 chapter sample-chapter-redacted: pages 1 -> 12, book-page page=2 HTTP 200, chapters HTTP 200
```

rclone safety check:

```text
errors=0
deletes=0
renames=0
serverSideCopies=0
serverSideMoves=0
```

Final forced production scan:

```text
2026-06-01 10:53 KST: not started yet.
```

The user requested GitHub push first while the production cover metadata refresh continues. The forced `scan-all?force=true` step remains a follow-up after cover regeneration completes.

Release package prepared:

```text
kavita-gds.tar.gz sha256=facbf3165d4a3b81ebe14d4d9958f8d63f85d26a2b66dbf8c0d988770a8db367
docker-image/kavita-gds.docker.tar sha256=35ca299130c45ea16b391abb0d32e2a6422713d350130ffb86392e59c3aea16a
```

GitHub release and GHCR publish:

```text
release=https://github.com/suikano1304/Kavita-GDS/releases/tag/v9.0.6-1
workflow_result=success
ghcr.io/suikano1304/kavita-gds:9.0.6-1 digest=sha256:8cbc948df4cc80a06692ded9232e9fa5e56bf50192d3b7c404808f673cd31ea0
ghcr.io/suikano1304/kavita-gds:latest digest=sha256:8cbc948df4cc80a06692ded9232e9fa5e56bf50192d3b7c404808f673cd31ea0
```

## 2026-06-01 09:12 KST Missing EPUB3 NAV follow-up

User Web UI testing found another EPUB reader failure:

```text
EPUB parsing error: NAV item not found in EPUB manifest.
```

Affected production item:

```text
chapter=131366
series=<redacted> reported cover-only EPUB sample
file=<redacted-media-path> reported cover-only EPUB sample/001-440 完[txt].epub
```

Implemented follow-up:

- temporary EPUB repair now also synthesizes a minimal EPUB3 nav document when OPF has no `properties="nav"` item;
- EPUB repair fallback catches `EpubReaderException`, not only `EpubPackageException`;
- applied to `BookService`, `BookController`, and `WordCountAnalyzerService`;
- copied the reported file into test fixtures at `<redacted-fixture-path> reported cover-only EPUB sample/001-440 完[txt].epub`.

Verification:

```text
test image local/kavita-gds:9.0.6-1-test intermediate sha256:be556ae5a720674f967468d9ca521d50593251e3297372e5877c471a26f7969b
LOCAL-FIXTURES scan: 118 files, 27 series, zero pages 0, missing covers 0
test fixture chapter sample-chapter-redacted: book-info 200, book-page?page=0 200, chapters 200
production image local/kavita-gds:9.0.6-1 final sha256:b62e5cc99c342b5584b93c43385d5474cb6bf3b29bf7cfe4f6c17f25d5176163
production chapter <redacted>: book-info 200, book-page?page=0 200, chapters 200
production Web UI internal/external: HTTP 200
rclone: errors=0 deletes=0 renames=0 serverSideCopies=0 serverSideMoves=0
```

Important limitation:

- The reported EPUB contains only `cover.jpg`, `cover.xhtml`, `toc.ncx`, and `content.opf`.
- OPF manifest has only one XHTML item, `cover.xhtml`; spine has only one `itemref`.
- The repair prevents reader failure, but the item remains a legitimate 1-page cover-only EPUB until the source file is replaced with a copy that contains the actual body chapters.
