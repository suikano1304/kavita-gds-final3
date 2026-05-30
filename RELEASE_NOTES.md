# Kavita GDS universal

This release provides the GDS scanfix build as a universal multi-platform OCI image archive.

## Included Platforms

- `linux/amd64`
- `linux/arm64`

## Asset

`kavita-gds-0.9.0.2-scanfix-universal-20260530.tar.gz`

SHA256:

```text
23b887ab6b35522e2c9730089ed082403ae10ffef3e16dd875833ae85b7b969e
```

## Verification

- Built from the scanfix source snapshot.
- OCI index verified to contain both `linux/amd64` and `linux/arm64`.
- The package does not include the intermediate `folderpath` image.
- The package does not include the later webtoon patch tree.

## Changes Since `kavita-gds-0.9.0.2-scan-20260528`

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

### Universal packaging

- Packaged the scanfix build as one OCI archive containing `linux/amd64` and `linux/arm64`.
- Excluded intermediate test images and the later webtoon patch tree from this public package.
- Added a GHCR publishing workflow so users can deploy with `docker pull ghcr.io/suikano1304/kavita-gds:0.9.0.2-gds-scanfix-20260530-universal`.

## Caveat

This host is `amd64`, so `arm64` was build/manifest verified but not runtime-tested on ARM hardware.
