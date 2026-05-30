# Kavita GDS final3 universal

Unofficial Kavita GDS scanfix build packaged as a multi-platform OCI archive.

## Platforms

- `linux/amd64`
- `linux/arm64`

## Release Asset

Download from GitHub Releases:

```text
kavita-gds-0.9.0.2-scanfix-final3-universal.tar.gz
```

SHA256:

```text
a1cc0a3fca45f952b713845a73d3fa725f97bcc173f85b06b8cf64fb01ac26e1
```

The package contains:

- `docker-image/kavita-gds-0.9.0.2-gds-scanfix-final3-20260530-universal.oci.tar`
- `compose/docker-compose.production.yml`
- final3 source snapshot
- build notes and checksums

## Image Tag

```text
local/kavita-gds:0.9.0.2-gds-scanfix-final3-20260530-universal
```

## Notes

This is an OCI multi-platform archive, not a classic single-platform `docker save` tar. Import it into a registry or a runtime that supports OCI archives and manifest lists.

The arm64 image was built and inspected from the OCI manifest, but runtime testing was not performed on ARM hardware.

