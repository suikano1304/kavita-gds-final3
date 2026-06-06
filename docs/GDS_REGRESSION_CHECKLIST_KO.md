# Kavita-GDS 배포 전 회귀 검증 체크리스트

작성일: 2026-06-06

이 문서는 새 upstream Kavita 버전으로 포팅하거나 새 GHCR 이미지를 배포하기 전에 반복해야 하는 공개용 회귀 검증 체크리스트다. 실제 작품명, series/chapter id, media path가 필요한 로컬 상세 매트릭스는 PVE host의 `/root/lxc1-codex-docs/KAVITA_GDS_REGRESSION_MATRIX.md`를 참조한다.

## 필수 회귀 영역

배포 전에는 최소한 아래 유형을 `kavita-test`에서 확인한다.

- GDS EPUB page-count: `1/1`로 고정되던 EPUB이 `book-info` 진입 후 실제 page count로 보정되는지 확인.
- duplicate EPUB manifest: duplicate item id 또는 duplicate `href + media-type` EPUB이 `book-info`, TOC, page, resource fetch에서 실패하지 않는지 확인.
- missing NAV EPUB: EPUB3 NAV item이 없어도 fallback TOC/page 경로가 정상 응답하는지 확인.
- cover-only EPUB: 원본에 본문 XHTML이 없는 파일은 reader 실패가 아니라 source-file 한계로 분류되는지 확인.
- single-spine TOC EPUB: 하나의 XHTML spine 안에 여러 TOC anchor가 있을 때 backend virtual pages가 유지되는지 확인.
- TXT pagination: 긴 TXT와 사용자 보고 TXT fixture가 첫 page와 마지막 page 모두 정상 응답하는지 확인.
- ZIP/CBZ reader: `chapter-info`, file dimensions, image, thumbnail, negative page clamp가 정상인지 확인.
- PDF reader: raw PDF serving과 extracted image rendering이 모두 정상인지 확인.
- cover fallback: folder/YAML/TXT/ZIP-CBZ first-page cover fallback이 source media mount에 쓰지 않고 config cover storage만 사용하는지 확인.
- mixed-format series: 같은 작품 폴더의 ZIP/EPUB/TXT/PDF가 format별 별도 series로 갈라지지 않는지 확인.
- word-count mixed files: EPUB-format series 안의 PDF/TXT 파일이 EPUB word-count 경로로 열리지 않는지 확인.
- loose web-novel images: cover/capture loose `.jpg`가 bogus series로 ingest되지 않는지 확인.
- malformed sidecar YAML: broken `kavita.yaml`이 media import 전체를 막지 않는지 확인.
- GDS scan memory: file discovery와 post-scan DB/cover/word-count 단계에서 OOM/restart가 없는지 확인.
- Web UI production bundle: runtime `.js/.html/.css`에 `localhost:5000`, `:5000/api`, Angular development-mode 문자열이 없는지 확인.
- ARM runtime: `linux/arm64`와 `linux/arm/v7`가 pushed GHCR image에서 `/api/health` 200과 Docker health `healthy`에 도달하는지 확인.

## 표준 실행 절차

1. 운영 `kavita`는 건드리지 않는다.
2. `kavita-test`만 새 이미지로 재생성한다.
3. GDS source mount는 read-only bind로 유지한다.
4. extended verifier를 실행한다.
5. `linux/arm64`와 `linux/arm/v7` smoke test를 실행한다.
6. GHCR version tag와 `latest` manifest를 확인한다.
7. `kavita-test`, ARM smoke containers, BuildKit을 정지한다.
8. 결과를 release notes와 검증 기록에 남긴다.

## Extended Verifier

현재 9.0.7 기준 verifier:

```text
/root/kavita-gds-lab/verify-0907-gds-extended.sh
```

release image 검증 예:

```bash
pct push 101 /root/kavita-gds-lab/verify-0907-gds-extended.sh /tmp/verify-gds-extended.sh
pct exec 101 -- bash -lc 'chmod +x /tmp/verify-gds-extended.sh && EXPECTED_IMAGE=ghcr.io/suikano1304/kavita-gds:<version> EXPECTED_VERSION=<official-version> /tmp/verify-gds-extended.sh'
```

PASS 기준:

- container health `healthy`
- expected image/version 일치
- SQLite integrity before/after `ok`
- GDS bind가 read-only
- health/version API HTTP 200
- representative cover API HTTP 200
- TXT, archive, EPUB, PDF sections 전부 PASS
- repeated cache hits HTTP 200
- recent MediaError count 0
- 새 404/500/Fatal/SQLite/database-lock/disk I/O 로그 없음

## ARM Smoke

필요 시 binfmt를 등록한다.

```bash
pct exec 101 -- docker run --rm --privileged tonistiigi/binfmt --install arm64,arm
```

`linux/arm64`와 `linux/arm/v7`를 각각 `--platform`으로 기동하고 `/api/health` 200 및 Docker health `healthy`를 확인한다. qemu startup은 수 분 걸릴 수 있다.

## Manifest Check

```bash
pct exec 101 -- docker buildx imagetools inspect ghcr.io/suikano1304/kavita-gds:<version>
pct exec 101 -- docker buildx imagetools inspect ghcr.io/suikano1304/kavita-gds:latest
```

PASS 기준:

- version tag와 `latest`가 같은 multi-arch digest를 가리킨다.
- `linux/amd64`, `linux/arm64`, `linux/arm/v7` manifest가 모두 있다.
- ARM manifest는 ARM smoke test 통과 후에만 publish manifest에 포함한다.

## 로컬 상세 매트릭스

실제 작품명, chapter id, media path, fixture path가 필요한 경우 PVE host에서 다음 문서를 확인한다.

```text
/root/lxc1-codex-docs/KAVITA_GDS_REGRESSION_MATRIX.md
```

이 로컬 문서는 공개 GitHub 문서에 복사하지 않는다.
