# Kavita-GDS 9.0.6-2 second code review - 2026-06-02

## Scope

This is the second review before implementing `9.0.6-2`.
It re-checks the code paths identified in the first review and narrows them to the changes that should be made before the test build.

Reviewed source:

- `/root/kavita-gds-lab/port-0906-gds`
- HEAD before changes: `17253b38908b56f3aaa1479fdd75c63c3ec07bb8`
- Official comparison base from image label: `c7e9555061d970b50cedc695e60124bf8c47084a`

## Review results

### Must fix in 9.0.6-2

1. `ProcessSeries.GetGdsPageCount()`

   Current behavior stores `1` for new GDS EPUB/PDF/TXT files on `/mnt/gds`.
   This is not just a performance shortcut; it persists incorrect chapter page counts and can reproduce the `1/1` reader symptom.

   Required change:

   - Preserve existing non-zero counts.
   - For EPUB/PDF/TXT, compute the real page count when the existing count is missing or less than or equal to 1.
   - If real counting fails, keep a conservative fallback but log it clearly.

2. `GdsMetadataParser.GetComicInfo()`

   Current behavior lets malformed `kavita.yaml` throw through `ReadingItemService.ParseFile()`, causing the entire media file to be skipped.

   Required change:

   - Catch `YamlException`, `IOException`, and other parse-time exceptions inside the GDS metadata parser.
   - Return `baseInfo` or a minimal `ComicInfo` derived from filename.
   - Leave cover fallback parsing untouched because `TryGetCoverBase64()` already has line-based fallback logic.

3. `ScannerService.ScanLibrary()` logging

   Current `Finished library scan` log is emitted before post-scan cleanup and metadata cleanup complete.
   The scheduler can still see the job as running after that line.

   Required change:

   - Add a final scan-job completion log after all awaited post-scan work.
   - Keep existing log for compatibility, but make the new final line explicit.

4. `MetadataService.ProcessSeriesCoverGen()`

   Current folder-cover application ignores the return value and can be overwritten by later series cover selection.

   Required change:

   - Make folder cover precedence explicit.
   - If a folder cover is applied, preserve it as series cover while still allowing per-volume/per-chapter generation.

### Defer unless verification still fails

1. Moving GDS cover generation out of the scan job

   This likely reduces scan-lock time, but it changes job ordering and failure behavior.
   For `9.0.6-2`, keep cover generation in-line and add final logging first.
   If scan-lock delay remains after page-count/YAML fixes, make this the next change.

2. Optimizing bottom-up directory descendant checks

   The `O(n^2)` path check is a scalability risk, but current evidence does not prove it is the immediate post-finish delay.
   Defer until profiling or timing logs show it dominates scan time.

## Verification focus

The test build must verify:

- A new/rebuilt GDS EPUB no longer stores `Pages = 1` unless the actual reading order is 1.
- A new/rebuilt GDS TXT stores a page count based on line count, not unconditional `1`.
- Malformed GDS `kavita.yaml` does not skip the media file.
- A scan log contains a final job completion line after post-scan cleanup.
- Folder-level series cover is not overwritten by first chapter/volume cover.

No implementation was performed before this review document was written.

## Implementation and verification record

Implemented as `local/kavita-gds:9.0.6-2` after this review.

Changed source files:

- `Kavita.Services/Scanner/ProcessSeries.cs`
- `Kavita.Services/Helpers/GdsMetadataParser.cs`
- `Kavita.Services/Scanner/ScannerService.cs`
- `Kavita.Services/MetadataService.cs`
- `Kavita.Services/BookService.cs`
- `Kavita.Server/Controllers/BookController.cs`

Additional finding during production verification:

- `reported cover-only EPUB sample` remained `1/1` after a focused production series scan.
- ZIP inspection of the fixture EPUB showed only `cover.xhtml`, `cover.jpg`, `toc.ncx`, and `content.opf`; no body content XHTML exists.
- This case is source-file corruption, not a recoverable Kavita page-count failure.
- A separate single-spine EPUB with real body XHTML and multiple TOC anchors was covered with a synthetic regression fixture.

Verification results:

- `linux/amd64` build completed with existing upstream warnings only.
- `kavita-test` ran `local/kavita-gds:9.0.6-2-test` image id `sha256:6ed1d2933392333c9baf609a25802e5e8ff065cf41f92e49414f4bcc2a323ead`.
- LOCAL-FIXTURES validation passed 3 times: `total=155`, `info_fail=0`, `nav_fail=0`, `page_fail=0`, `zero_bytes=0`, `zero_pages=0`, `missing_covers=0`.
- Synthetic single-spine EPUB regression passed: DB pages `3/3`, `book-info` pages `3`, TOC `3`, `book-page` 0/1/2 returned distinct content.
- Production ran `local/kavita-gds:9.0.6-2` image id `sha256:6ed1d2933392333c9baf609a25802e5e8ff065cf41f92e49414f4bcc2a323ead`.
- Production health returned `200` and Docker health became `healthy`.
- Production `reported duplicate-manifest EPUB sample` chapters `sample-chapter-redacted-sample-chapter-redacted` repaired duplicate manifest EPUBs and updated DB pages to `12/12`, `12/12`, `12/12`, `13/13`.
- `linux/arm64` image built as `local/kavita-gds:9.0.6-2-arm64`, architecture `arm64`, and qemu smoke test returned `/api/health` 200.
- `linux/arm/v7` image built with .NET RID `linux-arm`, CoreCLR write-xor-execute disabled for qemu ARM32 startup, and qemu smoke test returned host `/api/health` 200 with Docker health `healthy`.
- GHCR pushed:
  - multi-arch `ghcr.io/suikano1304/kavita-gds:9.0.6-2`, digest `sha256:fae093d93e2b56cd1debf23256f45f87f59d3b37934a317cabc1a418c45f3fb0`
  - `linux/amd64` digest `sha256:dc7f117d3f6701ffee182d1d80a91f7dc516056e44cbfeb420c42a0c982c9f97`
  - `linux/arm64` digest `sha256:019ed329577d1fdad5ed11e1b006fd9c42b7663bf99b0807602d0a0224e882f3`
  - `linux/arm/v7` digest `sha256:d6d8a01e684a47c2091219906de6accc0976bf07ce3898c4f76da6a4834b9ca0`
