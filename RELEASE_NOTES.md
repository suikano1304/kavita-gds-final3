# Kavita GDS final3 universal

This release provides the final3 GDS scanfix build as a universal multi-platform OCI image archive.

## Included Platforms

- `linux/amd64`
- `linux/arm64`

## Asset

`kavita-gds-0.9.0.2-scanfix-final3-universal.tar.gz`

SHA256:

```text
a1cc0a3fca45f952b713845a73d3fa725f97bcc173f85b06b8cf64fb01ac26e1
```

## Verification

- Built from the final3 source snapshot.
- OCI index verified to contain both `linux/amd64` and `linux/arm64`.
- The package does not include the intermediate `folderpath` image.
- The package does not include the later webtoon patch tree.

## Caveat

This host is `amd64`, so `arm64` was build/manifest verified but not runtime-tested on ARM hardware.

