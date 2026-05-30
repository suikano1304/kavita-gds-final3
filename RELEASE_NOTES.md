# Kavita GDS

This release provides the GDS scanfix build as a multi-platform OCI image archive.

## Included Platforms

- `linux/amd64`
- `linux/arm64`

## Asset

`kavita-gds.tar.gz`

SHA256:

```text
894b1b88cc1c63f886bc9413e6eda773fbf278fa5abb666fda4e632246d2177b
```

## Verification

- Built from the scanfix source snapshot.
- OCI index verified to contain both `linux/amd64` and `linux/arm64`.
- The package does not include the intermediate `folderpath` image.
- The package does not include the later webtoon patch tree.

## Changes Since `kavita-gds-0.9.0.2-scan-20260528`

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
- Verified that `[production-library-b] ...` duplicate series were not created during validation.

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
- Added a GHCR publishing workflow so users can deploy with `docker pull ghcr.io/suikano1304/kavita-gds:0.9.0.2-1`.

## Caveat

This host is `amd64`, so `arm64` was build/manifest verified but not runtime-tested on ARM hardware.
