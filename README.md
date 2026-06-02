# Kavita GDS

Kavita official `0.9.0.6` source에 GDS/rclone 환경용 scanfix를 포팅한 비공식 Docker 빌드입니다.

현재 공개 릴리즈는 `9.0.6-2`입니다. GHCR의 `9.0.6-2`와 `latest` 태그는 `linux/amd64`, `linux/arm64`, `linux/arm/v7`를 포함하는 multi-arch manifest입니다.

## 이 빌드가 필요한 경우

이 저장소는 일반 Kavita 배포판이 아니라, 다음 환경을 위해 만든 운영용 hotfix 패키지입니다.

- Google Drive/rclone/FUSE 같은 원격 media mount를 Kavita에 읽기 전용으로 연결한다.
- GDS 라이브러리에서 ZIP/CBZ/EPUB/PDF/TXT가 섞여 있다.
- 대형 라이브러리 스캔 중 hang, OOM, 반복 재스캔, `Pages=0` 또는 `1/1` reader 문제가 있었다.
- GDS sidecar metadata인 `kavita.yaml`/`kavita.yml`과 folder cover를 사용한다.
- 원본 media 경로에는 쓰지 않고 Kavita config/cache 안에서만 cover와 scan state를 관리하고 싶다.

일반 로컬 디스크 기반 Kavita만 쓰는 경우에는 official Kavita 이미지를 먼저 사용하는 편이 낫습니다.

## 빠른 설치

```bash
docker pull ghcr.io/suikano1304/kavita-gds:9.0.6-2
```

Compose 예시:

```yaml
services:
  kavita:
    image: ghcr.io/suikano1304/kavita-gds:9.0.6-2
    container_name: kavita
    restart: always
    ports:
      - "5657:5000"
    volumes:
      - /your/kavita/config:/kavita/config
      - type: bind
        source: /your/gds/mount
        target: /mnt/gds
        read_only: true
        bind:
          propagation: rslave
    environment:
      TZ: Asia/Seoul
      WAIT_ANCHOR_DIRS: <redacted-media-path>
```

`/your/kavita/config`와 `/your/gds/mount`는 본인 환경에 맞게 바꾸세요. GDS/rclone 원본 mount는 읽기 전용을 권장합니다.

전체 예시는 [compose/docker-compose.production.yml](compose/docker-compose.production.yml)에 있습니다.

## 태그

권장 태그:

```text
ghcr.io/suikano1304/kavita-gds:9.0.6-2
```

`latest`도 같은 릴리즈를 가리키지만, 운영에서는 고정 버전 태그를 권장합니다.

현재 GHCR digest:

```text
ghcr.io/suikano1304/kavita-gds:9.0.6-2
ghcr.io/suikano1304/kavita-gds:latest
multiarch digest=sha256:fae093d93e2b56cd1debf23256f45f87f59d3b37934a317cabc1a418c45f3fb0

linux/amd64=sha256:dc7f117d3f6701ffee182d1d80a91f7dc516056e44cbfeb420c42a0c982c9f97
linux/arm64=sha256:019ed329577d1fdad5ed11e1b006fd9c42b7663bf99b0807602d0a0224e882f3
linux/arm/v7=sha256:d6d8a01e684a47c2091219906de6accc0976bf07ce3898c4f76da6a4834b9ca0
```

## 수동 다운로드

Docker pull을 쓸 수 없는 환경에서는 GitHub Release asset을 사용할 수 있습니다.

- Release: <https://github.com/suikano1304/Kavita-GDS/releases/tag/v9.0.6-2>
- Asset: `kavita-gds.tar.gz` - amd64 Docker archive
- Asset: `kavita-gds-oci.tar.gz` - amd64/arm64/armv7 OCI archive
- Checksum: [SHA256SUMS](SHA256SUMS)

압축 안에는 `docker-image/kavita-gds.docker.tar`가 들어 있습니다. 이 archive는 `linux/amd64` 이미지입니다.

```bash
tar -xzf kavita-gds.tar.gz
docker load -i docker-image/kavita-gds.docker.tar
docker tag ghcr.io/suikano1304/kavita-gds:9.0.6-2-amd64 local/kavita-gds:9.0.6-2
```

ARM 서버에서는 GHCR multi-arch image를 pull하는 방식을 권장합니다.

오프라인 환경에서 amd64/arm64/armv7가 모두 들어 있는 archive가 필요하면 `kavita-gds-oci.tar.gz`를 사용하세요. Docker daemon 또는 private registry로 import할 때는 `skopeo` 사용을 권장합니다.

```bash
tar -xzf kavita-gds-oci.tar.gz
skopeo copy --all \
  oci-archive:docker-image/kavita-gds.oci.tar \
  docker://YOUR_REGISTRY/YOUR_NAMESPACE/kavita-gds:9.0.6-2
```

## 주요 수정

`9.0.6-2`에는 다음 안정화가 포함되어 있습니다.

- GDS EPUB/PDF/TXT 신규 또는 재빌드 파일이 scanner shortcut 때문에 `Pages=1`로 저장되는 문제 수정
- 단일 XHTML 안에 여러 TOC anchor가 있는 EPUB을 backend 가상 페이지로 분리
- malformed `kavita.yaml`이 media import 전체를 막지 않도록 fallback metadata 적용
- folder cover가 이후 series cover 재선정에 바로 덮어써지지 않도록 보정
- `Finished library scan` 뒤 post-scan cleanup이 남아 있는 혼선을 줄이기 위한 최종 scan-job completion log 추가
- GDS archive 시리즈에서 2권 이후 cover가 1권 cover로 고정되는 문제 수정
- TXT fallback cover 한글 렌더링을 위해 Nanum Gothic 포함
- GDS 대형 라이브러리 스캔의 OOM 위험을 줄이기 위해 DB update/cover generation 경로를 저메모리 직렬 처리
- EPUB duplicate manifest id/href 복구, resource 상대경로 보정, `1/1` page-count 보정
- Web UI production bundle 적용으로 외부 접속 시 `localhost:5000/api`로 요청이 빠지는 문제 수정
- runtime image에 `sqlite3` 포함, 읽기 전용 진단 스크립트 제공

전체 변경 내역은 [docs/CHANGELOG_KO.md](docs/CHANGELOG_KO.md)와 [RELEASE_NOTES.md](RELEASE_NOTES.md)를 보세요.

## 검증 기록

`9.0.6-2` 배포 전 다음 검증을 수행했습니다.

- `kavita-test`에서 LOCAL-FIXTURES 155개 media 항목을 3회 반복 검증
- CBZ/ZIP/EPUB/TXT reader info, TOC/nav, page API, cover reference 실패 0건
- synthetic single-spine EPUB regression에서 DB pages `3/3`, `book-info=3`, TOC `3`, page 0/1/2 distinct content 확인
- 운영 `kavita`에 `linux/amd64` 적용 후 health `200` 및 Docker health `healthy`
- 운영 `reported duplicate-manifest EPUB sample` duplicate manifest EPUB chapter `sample-chapter-redacted-sample-chapter-redacted`가 `12/12`, `12/12`, `12/12`, `13/13`로 보정되는 것 확인
- `linux/arm64` image를 qemu에서 기동해 `/api/health` 200 확인
- `linux/arm/v7` image를 qemu에서 기동해 host `/api/health` 200 및 Docker health `healthy` 확인

세부 기록은 [docs/SCAN_DELAY_CODE_REVIEW_PASS2_20260602_KO.md](docs/SCAN_DELAY_CODE_REVIEW_PASS2_20260602_KO.md)에 있습니다.

## 문서

- [docs/USAGE_KO.md](docs/USAGE_KO.md): 설치와 운영 사용법
- [docs/CHANGELOG_KO.md](docs/CHANGELOG_KO.md): 변경 내역
- [docs/BUILD_NOTES_KO.md](docs/BUILD_NOTES_KO.md): 빌드/배포 노트
- [docs/SCAN_DELAY_CODE_REVIEW_20260602_KO.md](docs/SCAN_DELAY_CODE_REVIEW_20260602_KO.md): scan delay 1차 코드리뷰
- [docs/SCAN_DELAY_CODE_REVIEW_PASS2_20260602_KO.md](docs/SCAN_DELAY_CODE_REVIEW_PASS2_20260602_KO.md): 9.0.6-2 2차 코드리뷰와 검증 기록
- [docs/TEST_CONTAINER_VALIDATION_20260601_KO.md](docs/TEST_CONTAINER_VALIDATION_20260601_KO.md): 테스트 컨테이너 검증 기록
- [docs/SCAN_COVER_AUDIT_20260601.md](docs/SCAN_COVER_AUDIT_20260601.md): cover/scan 운영 감사 기록
- [scripts/diagnose_kavita_gds.py](scripts/diagnose_kavita_gds.py): 읽기 전용 DB/스캔/startup migration 진단
- [scripts/collect_gds_preflight.sh](scripts/collect_gds_preflight.sh): 운영 적용 전후 preflight/postflight 수집

## 주의

이 이미지는 공식 Kavita 이미지가 아닙니다. 기존 Kavita DB를 연결하기 전에는 config와 DB를 백업하세요.

이 빌드는 GDS/rclone 원본 media mount를 읽기 전용으로 유지하는 구성을 전제로 합니다. cover 생성, 진단, cache, DB 변경은 Kavita config 경로에서만 일어나야 합니다.

`linux/arm64`와 `linux/arm/v7`는 같은 소스와 production UI bundle로 빌드했고 qemu smoke test를 통과했지만, native ARM 실서비스 검증은 별도 환경에서 다시 확인하는 것이 좋습니다.
