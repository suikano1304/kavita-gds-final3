# Kavita GDS 사용 설명서

## 개요

이 배포본은 Kavita `0.9.0.2` 기반 비공식 GDS scanfix 빌드입니다.

하나의 OCI archive에 `linux/amd64`와 `linux/arm64` 이미지를 같이 넣었습니다. x86 서버와 Oracle Cloud A1 같은 arm64 서버에서 같은 이미지를 사용할 수 있습니다.

기존 `kavita-gds-0.9.0.2-scan-20260528` 이후의 변경 내역은 [CHANGELOG_KO.md](CHANGELOG_KO.md)에 정리되어 있습니다.

운영 서버에서 수행한 커버 복구, `kavita.yaml` 적용 검증, GitHub 배포 절차 기록은 [OPERATIONS_20260531_KO.md](OPERATIONS_20260531_KO.md)에 따로 정리했습니다.

## 다운로드

GHCR publish가 완료된 뒤에는 tarball을 직접 다운로드하지 않고 Docker/Compose에서 바로 pull할 수 있습니다.

```bash
docker pull ghcr.io/suikano1304/kavita-gds:0.9.0.2-7
```

Compose에서는 아래 이미지를 사용하면 됩니다.

```text
ghcr.io/suikano1304/kavita-gds:0.9.0.2-7
```

아래 수동 다운로드 방식은 GHCR을 쓰지 않는 환경을 위한 대체 방법입니다.

Release 페이지에서 아래 파일을 다운로드합니다.

```text
kavita-gds.tar.gz
```

직접 다운로드 예시:

```bash
curl -L -o kavita-gds.tar.gz \
  https://github.com/suikano1304/Kavita-GDS/releases/download/v0.9.0.2-7/kavita-gds.tar.gz
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
  docker-daemon:local/kavita-gds:0.9.0.2-7
```

registry로 밀어 넣기:

```bash
skopeo copy \
  oci-archive:docker-image/kavita-gds.oci.tar \
  docker://YOUR_REGISTRY/YOUR_NAMESPACE/kavita-gds:0.9.0.2-7
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
ghcr.io/suikano1304/kavita-gds:0.9.0.2-7
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

운영 DB를 수정하지 않고 GDS 스캔 상태를 집계하려면 `scripts/diagnose_kavita_gds.py`를 사용할 수 있습니다. 이 도구는 FK/integrity, 라이브러리별 `Pages=0`, 중복 파일 경로, MediaError뿐 아니라 startup 문제 분석에 필요한 EF migration history, manual migration history, 핵심 server setting, 주요 테이블 row count도 함께 출력합니다.

운영 컨테이너가 켜진 live DB에서는 아래 직접 실행보다, 뒤의 `collect_gds_preflight.sh --snapshot-db` 방식을 우선 사용하세요.

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

`--check-covers`는 Kavita DB와 config cover reference만 확인하는 빠른 검사입니다. GDS/rclone 원본 폴더에서 `cover.*` 파일이나 `kavita.yaml` cover hint까지 직접 확인하려면 `--check-cover-source-files`를 같이 넣습니다. 이 원본 probe는 대형 rclone mount에서 오래 걸릴 수 있으므로, 일반 preflight/postflight에는 기본으로 넣지 않는 것을 권장합니다.

재스캔 전후 비교용 JSON baseline을 남기려면 `--json-output`을 추가합니다.

```bash
python3 scripts/diagnose_kavita_gds.py \
  --db /mnt/data/docker/kavita/config/kavita.db \
  --container-root /mnt/gds \
  --host-root /mnt/data/rclone/gds \
  --json-output /tmp/kavita-gds-before.json
```

운영 적용 전 필요한 파일을 한 번에 모으려면 preflight 스크립트를 사용할 수 있습니다. live DB는 `--snapshot-db`로 먼저 사본을 만든 뒤 분석하는 것을 권장합니다.

```bash
scripts/collect_gds_preflight.sh \
  --db /mnt/data/docker/kavita/config/kavita.db \
  --container-root /mnt/gds \
  --host-root /mnt/data/rclone/gds \
  --compose-file compose/docker-compose.production.yml \
  --scan-log /mnt/data/docker/kavita/config/logs/kavita20260531.log \
  --output-dir /tmp/kavita-gds-preflight \
  --label before \
  --snapshot-db \
  --check-archives \
  --check-covers
```

생성되는 파일:

- `before-diagnostics.txt`: 사람이 읽는 진단 출력
- `before-diagnostics.json`: 재스캔 전후 비교용 JSON baseline
- `before-manifest.txt`: DB 경로, 크기, mtime, 생성 시각
- `before-kavita.db`: `--snapshot-db`를 지정한 경우 분석에 사용한 DB 사본
- `before-docker-compose.yml`: 지정한 compose 파일 사본
- `before-scan-log-summary.txt/json`: `--scan-log`를 지정한 경우 scan timing 요약
- `before-request-log-summary.json`: `--scan-log`를 지정한 경우 slow reader request 요약
- `before-reader-latency-summary.txt/json`: `--scan-log`를 지정한 경우 slow reader request와 DB/cache 상태 상관분석

`--snapshot-db`는 같은 label을 재사용해도 이전 DB 사본과 SQLite sidecar 파일을 정리한 뒤 새 임시 파일에 백업하고, 성공한 경우에만 최종 snapshot으로 교체합니다. 기본 snapshot timeout은 120초입니다. 매우 느린 스토리지에서는 `KAVITA_PREFLIGHT_SNAPSHOT_TIMEOUT_SECONDS=300`처럼 늘릴 수 있습니다.

재스캔 후에는 같은 DB를 현재값으로 읽고 이전 JSON과 비교합니다.

```bash
scripts/collect_gds_preflight.sh \
  --db /mnt/data/docker/kavita/config/kavita.db \
  --container-root /mnt/gds \
  --host-root /mnt/data/rclone/gds \
  --scan-log /mnt/data/docker/kavita/config/logs/kavita20260531.log \
  --output-dir /tmp/kavita-gds-preflight \
  --label after \
  --snapshot-db \
  --check-archives \
  --check-covers \
  --compare-json /tmp/kavita-gds-preflight/before-diagnostics.json \
  --compare-scan-json /tmp/kavita-gds-preflight/before-scan-log-summary.json \
  --postflight-gates
```

`--postflight-gates`는 전후 비교 결과를 `PASS`, `WARN`, `FAIL`로 요약합니다. `--check-archives`를 before/after 양쪽에 넣으면 직접 이미지가 있는 복구 가능 `Pages=0` archive와 nested archive를 분리해서 판정합니다. `--check-covers`를 양쪽에 넣으면 GDS config cover reference와 TXT config cover 감소 여부를 판정합니다. TXT의 원본 cover/YAML hint까지 포함한 missing-cover debt를 판정하려면 before/after 양쪽에 `--check-covers --check-cover-source-files`를 넣어 별도 실행합니다. `--compare-scan-json`을 함께 넣으면 비강제 재스캔에서 처리된 series 수와 churn scan 수가 증가했는지도 별도로 판정합니다. CI나 자동화에서 실패 코드를 받고 싶으면 `--fail-on-gate-failure`를 추가합니다.

확인하는 항목:

- 라이브러리별 series/file/Page=0 수
- duplicate file path 구조
- MediaError 분포
- MediaError 원인 분류
- 로그 기준 library scan 시간, file discovery 시간, 처리된 series/file 수
- 로그 기준 slow reader request 수와 endpoint 분포
- 느린 reader request의 file size, format, page count, cache 존재 여부
- `Pages=0` ZIP/CBZ의 내부 이미지 또는 nested archive 여부
- Kavita config cover reference와 TXT config cover 상태
- `--check-cover-source-files` 사용 시 원본 `cover.*`와 `kavita.yaml` cover hint 상태
- SQLite foreign key 위반 여부
- duplicate file path cleanup 후보 분류
- JSON baseline 출력 시 `Pages=0`, duplicate, FK 상태를 재스캔 전후로 기계적으로 비교 가능
- postflight gate 출력 시 SQLite integrity/FK, `Pages=0`, 복구 가능 `Pages=0` archive, same-series duplicate, cross-series duplicate, MediaError, cover cache, TXT config cover 감소 여부를 명시적으로 판정
- baseline 비교 출력에는 MediaError 원인 분류별 증감도 포함됩니다.

스캔 로그만 따로 분석하려면 다음처럼 실행합니다. 기본 출력은 library/series 이름을 노출하지 않고 `library_key`, `series_key` 해시만 보여줍니다. reader request도 endpoint와 해시 기준으로만 요약합니다.

```bash
python3 scripts/summarize_kavita_scan_logs.py \
  /mnt/data/docker/kavita/config/logs/kavita20260531.log
```

로컬에서 이름까지 확인해야 할 때만 `--show-library-names` 또는 `--show-series-names`를 추가합니다.
느린 reader request 기준값은 기본 `1000ms`입니다. 기준을 바꾸려면 `--slow-request-ms 3000`처럼 지정합니다. raw chapter id가 필요할 때만 `--show-request-ids`를 붙입니다.

느린 reader request가 실제 파일 크기나 cache miss와 연결되는지 확인하려면 DB와 cache 경로를 같이 지정합니다. 기본 출력은 title/path/raw id를 숨깁니다.

```bash
python3 scripts/analyze_kavita_reader_latency.py \
  /mnt/data/docker/kavita/config/logs/kavita20260531.log \
  --db /mnt/data/docker/kavita/config/kavita.db \
  --cache-dir /mnt/data/docker/kavita/config/cache \
  --slow-request-ms 3000
```

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
- `arm64` 이미지는 빌드/manifest 검증까지 완료했습니다. 현재 startup FK 제보는 일반 x86 환경의 공통 재현 문제로 보지 않고, Oracle A1 같은 native ARM 서버에서만 발생한 환경별 사례로 분리해 보고 있습니다. 같은 이미지가 x86/NAS 환경에서 정상 기동되는데 Oracle A1에서만 오류가 나면 이미지 아키텍처보다 해당 서버의 DB/migration 상태, 기존 컨테이너 종료 상태, compose volume 연결을 먼저 확인하세요.
- 이 repo에는 큰 binary 파일을 직접 commit하지 않습니다. 큰 파일은 Release asset으로만 배포합니다.

## 로그인 화면에서 localhost:5000으로 요청하는 경우

브라우저 콘솔에 `localhost:5000/api/... ERR_CONNECTION_REFUSED`가 보이거나, 로그인 화면에서 `Something unexpected went wrong`, `You are not authorized to view this page`, `errors.generic`이 같이 뜨면 compose 들여쓰기보다 이미지 버전을 먼저 확인하세요.

`0.9.0.2-4` 이미지는 Web UI가 개발 번들로 들어가 외부 브라우저에서 API를 `localhost:5000`으로 호출할 수 있습니다. 이 문제는 `0.9.0.2-5`에서 production UI 번들로 수정했습니다.

```bash
docker pull ghcr.io/suikano1304/kavita-gds:0.9.0.2-7
docker compose up -d
```

컨테이너 안의 `appsettings.json`에서 `Port: 5000`은 정상입니다. Docker compose의 `ports`에서 `5657:5000`처럼 외부 포트만 매핑하면 됩니다.

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

`0.9.0.2-5` 이후 이미지는 BaseUrl 저장 단계에서 FK 오류가 발생하면 `PRAGMA foreign_key_check` 결과 일부를 로그에 남깁니다. x86에서는 정상이고 Oracle 쪽에서만 실패한다면, 우선 새/이전 컨테이너가 같은 DB를 동시에 잡지 않았는지, compose의 `/kavita/config` volume이 의도한 DB를 가리키는지, 이전 이미지에서 일부 migration만 반영된 DB인지 확인하는 것이 좋습니다.

`diagnose_kavita_gds.py` 출력의 `startup/migration state` 섹션에서 다음 값을 비교하세요.

- `ef_migration_summary.latest`: EF schema migration이 어디까지 적용되었는지
- `manual_migration_summary.latest_rows`: startup manual migration이 어디서 멈췄는지
- `server_settings`의 `InstallVersion`, `FirstInstallVersion`, `BaseUrl`: 이전 이미지와 현재 이미지 전환 상태
- `core_table_counts`: 같은 DB를 보고 있는지 확인할 수 있는 핵심 테이블 row count
