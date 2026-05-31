# Kavita GDS 사용 설명서

## 개요

이 배포본은 Kavita `0.9.0.2` 기반 비공식 GDS scanfix 빌드입니다.

하나의 OCI archive에 `linux/amd64`와 `linux/arm64` 이미지를 같이 넣었습니다. x86 서버와 Oracle Cloud A1 같은 arm64 서버에서 같은 이미지를 사용할 수 있습니다.

기존 `kavita-gds-0.9.0.2-scan-20260528` 이후의 변경 내역은 [CHANGELOG_KO.md](CHANGELOG_KO.md)에 정리되어 있습니다.

운영 서버에서 수행한 커버 복구, `kavita.yaml` 적용 검증, GitHub 배포 절차 기록은 [OPERATIONS_20260531_KO.md](OPERATIONS_20260531_KO.md)에 따로 정리했습니다.

## 다운로드

GHCR publish가 완료된 뒤에는 tarball을 직접 다운로드하지 않고 Docker/Compose에서 바로 pull할 수 있습니다.

```bash
docker pull ghcr.io/suikano1304/kavita-gds:0.9.0.2-3
```

Compose에서는 아래 이미지를 사용하면 됩니다.

```text
ghcr.io/suikano1304/kavita-gds:0.9.0.2-3
```

아래 수동 다운로드 방식은 GHCR을 쓰지 않는 환경을 위한 대체 방법입니다.

Release 페이지에서 아래 파일을 다운로드합니다.

```text
kavita-gds.tar.gz
```

직접 다운로드 예시:

```bash
curl -L -o kavita-gds.tar.gz \
  https://github.com/suikano1304/Kavita-GDS/releases/download/v0.9.0.2-3/kavita-gds.tar.gz
```

체크섬 확인:

```bash
sha256sum kavita-gds.tar.gz
```

기대값은 GitHub Release의 `SHA256SUMS` 또는 저장소 루트 `SHA256SUMS`를 기준으로 확인하세요.

## 압축 해제

```bash
tar -xzf kavita-gds.tar.gz
cd kavita-gds
```

주요 파일:

```text
docker-image/kavita-gds.oci.tar
compose/docker-compose.production.yml
Dockerfile.universal
SHA256SUMS
```

## 이미지 가져오기

이 파일은 classic `docker save` 형식이 아니라 multi-platform OCI archive입니다. 환경에 따라 아래 방식 중 하나를 사용하세요.

### skopeo 사용

Docker daemon으로 가져오기:

```bash
skopeo copy \
  oci-archive:docker-image/kavita-gds.oci.tar \
  docker-daemon:local/kavita-gds:0.9.0.2-3
```

registry로 밀어 넣기:

```bash
skopeo copy \
  oci-archive:docker-image/kavita-gds.oci.tar \
  docker://YOUR_REGISTRY/YOUR_NAMESPACE/kavita-gds:0.9.0.2-3
```

registry에 올린 뒤 compose의 `image:` 값을 해당 registry 주소로 바꾸면 됩니다.

### containerd/nerdctl 사용

환경에 따라 다음 방식으로 import가 가능합니다.

```bash
nerdctl load -i docker-image/kavita-gds.oci.tar
```

런타임마다 OCI archive 지원 방식이 다르므로, 일반 `docker load`가 실패하면 `skopeo`를 쓰는 방식을 권장합니다.

## Compose 설정

예시 파일:

```text
compose/docker-compose.production.yml
```

기본 이미지 태그:

```text
ghcr.io/suikano1304/kavita-gds:0.9.0.2-3
```

반드시 자신의 환경에 맞게 아래 경로를 수정하세요.

```yaml
volumes:
  - /your/kavita/config:/kavita/config
  - type: bind
    source: /your/gds/mount
    target: /mnt/gds
    read_only: true
```

GDS/rclone 원본은 읽기 전용 마운트로 사용하는 것을 권장합니다.

실행:

```bash
docker compose -f compose/docker-compose.production.yml up -d
```

로그 확인:

```bash
docker logs -f kavita
```

## 읽기 전용 진단

운영 DB를 수정하지 않고 GDS 스캔 상태를 집계하려면 `scripts/diagnose_kavita_gds.py`를 사용할 수 있습니다.

PVE host에서 실행하는 예:

```bash
python3 scripts/diagnose_kavita_gds.py \
  --db /mnt/data/docker/kavita/config/kavita.db \
  --container-root /mnt/gds \
  --host-root /mnt/data/rclone/gds \
  --check-archives \
  --check-covers
```

LXC 내부에서 실행하는 예:

```bash
python3 scripts/diagnose_kavita_gds.py \
  --db /mnt/data/docker/kavita/config/kavita.db \
  --container-root /mnt/gds \
  --host-root /mnt/gds2 \
  --check-archives \
  --check-covers
```

재스캔 전후 비교용 JSON baseline을 남기려면 `--json-output`을 추가합니다.

```bash
python3 scripts/diagnose_kavita_gds.py \
  --db /mnt/data/docker/kavita/config/kavita.db \
  --container-root /mnt/gds \
  --host-root /mnt/data/rclone/gds \
  --json-output /tmp/kavita-gds-before.json
```

운영 적용 전 필요한 파일을 한 번에 모으려면 preflight 스크립트를 사용할 수 있습니다.

```bash
scripts/collect_gds_preflight.sh \
  --db /mnt/data/docker/kavita/config/kavita.db \
  --container-root /mnt/gds \
  --host-root /mnt/data/rclone/gds \
  --compose-file compose/docker-compose.production.yml \
  --output-dir /tmp/kavita-gds-preflight \
  --label before \
  --check-archives
```

생성되는 파일:

- `before-diagnostics.txt`: 사람이 읽는 진단 출력
- `before-diagnostics.json`: 재스캔 전후 비교용 JSON baseline
- `before-manifest.txt`: DB 경로, 크기, mtime, 생성 시각
- `before-docker-compose.yml`: 지정한 compose 파일 사본

재스캔 후에는 같은 DB를 현재값으로 읽고 이전 JSON과 비교합니다.

```bash
scripts/collect_gds_preflight.sh \
  --db /mnt/data/docker/kavita/config/kavita.db \
  --container-root /mnt/gds \
  --host-root /mnt/data/rclone/gds \
  --output-dir /tmp/kavita-gds-preflight \
  --label after \
  --check-archives \
  --compare-json /tmp/kavita-gds-preflight/before-diagnostics.json \
  --postflight-gates
```

`--postflight-gates`는 전후 비교 결과를 `PASS`, `WARN`, `FAIL`로 요약합니다. `--check-archives`를 before/after 양쪽에 넣으면 직접 이미지가 있는 복구 가능 `Pages=0` archive와 nested archive를 분리해서 판정합니다. CI나 자동화에서 실패 코드를 받고 싶으면 `--fail-on-gate-failure`를 추가합니다.

확인하는 항목:

- 라이브러리별 series/file/Page=0 수
- duplicate file path 구조
- MediaError 분포
- `Pages=0` ZIP/CBZ의 내부 이미지 또는 nested archive 여부
- 원본 `cover.*`와 Kavita config cover cache의 불일치 위험
- SQLite foreign key 위반 여부
- duplicate file path cleanup 후보 분류
- JSON baseline 출력 시 `Pages=0`, duplicate, FK 상태를 재스캔 전후로 기계적으로 비교 가능
- postflight gate 출력 시 SQLite integrity/FK, `Pages=0`, 복구 가능 `Pages=0` archive, same-series duplicate, cross-series duplicate, MediaError 증가 여부를 명시적으로 판정

## TXT 커버 정책

TXT 파일은 파일 내부에서 추출할 표지가 없으므로 원본 `cover.jpg`, `cover.png`, `cover.webp` 또는 `kavita.yaml`의 base64 cover가 우선입니다.

위 커버가 모두 없고 GDS TXT 시리즈로 판정되면, 이 빌드는 외부 API나 외부 이미지 다운로드 없이 제목 기반 fallback cover를 Kavita config `covers` 디렉터리에 생성합니다. GDS/rclone 원본 마운트에는 쓰지 않습니다.

`kavita.yaml`의 `cover: TEXT`는 이미지가 아니라 텍스트 자료 표식으로 취급합니다.

## 어떤 경우에 쓰는가

이 빌드는 GDS/rclone 마운트 기반 라이브러리에서 Kavita 스캔 동작을 안정화하기 위해 만든 scanfix 패키지입니다.

주요 목적:

- GDS 원본 경로를 읽기 전용으로 유지
- Kavita scanfix 변경사항 배포
- `kavita.yaml` sidecar metadata를 GDS 스캔에 반영
- 파일명 기반 회차 제목을 유지해 `meta.Name`으로 회차명이 덮이지 않게 처리
- x86 서버와 arm64 서버에서 같은 release asset 사용

## 주의사항

- 공식 Kavita 이미지가 아닙니다.
- 기존 Kavita DB를 연결하기 전에는 백업을 권장합니다.
- `arm64` 이미지는 빌드/manifest 검증과 QEMU entrypoint smoke test를 완료했습니다. 같은 이미지가 x86/NAS 환경에서 정상 기동되는데 Oracle A1 같은 native ARM 서버에서만 startup FK 오류가 나면 이미지 아키텍처보다 해당 서버의 DB/migration 상태, 기존 컨테이너 종료 상태, compose volume 연결을 먼저 확인하세요.
- 이 repo에는 큰 binary 파일을 직접 commit하지 않습니다. 큰 파일은 Release asset으로만 배포합니다.

## Oracle A1 startup FK 오류 확인

`SQLite Error 19: 'FOREIGN KEY constraint failed'`가 startup 중 발생하는 경우, 먼저 기존 DB를 백업한 뒤 읽기 전용 진단만 실행하세요.

```bash
python3 scripts/diagnose_kavita_gds.py \
  --db /path/to/kavita.db \
  --json-output /tmp/kavita-gds-diagnostics.json
```

간단히 SQLite만 확인할 수도 있습니다.

```bash
sqlite3 /path/to/kavita.db 'PRAGMA integrity_check;'
sqlite3 /path/to/kavita.db 'PRAGMA foreign_key_check;'
```

`0.9.0.2-3` 이후 이미지는 BaseUrl 저장 단계에서 FK 오류가 발생하면 `PRAGMA foreign_key_check` 결과 일부를 로그에 남깁니다. x86에서는 정상이고 Oracle 쪽에서만 실패한다면, 우선 새/이전 컨테이너가 같은 DB를 동시에 잡지 않았는지, compose의 `/kavita/config` volume이 의도한 DB를 가리키는지, 이전 이미지에서 일부 migration만 반영된 DB인지 확인하는 것이 좋습니다.
