# Kavita GDS

Kavita official `0.9.0.7` nightly source에 GDS/rclone 환경용 scanfix를 포팅한 비공식 Docker 빌드입니다.

현재 공개 릴리즈는 `9.0.7-6`입니다. GHCR의 `9.0.7-6`와 `latest` 태그는 `linux/amd64`, `linux/arm64`, `linux/arm/v7`를 포함하는 multi-arch manifest입니다.

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
docker pull ghcr.io/suikano1304/kavita-gds:9.0.7-6
```

Compose 예시:

```yaml
services:
  kavita:
    image: ghcr.io/suikano1304/kavita-gds:9.0.7-6
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
      WAIT_ANCHOR_DIRS: /mnt/gds/READING_ROOT
```

`/your/kavita/config`와 `/your/gds/mount`는 본인 환경에 맞게 바꾸세요. GDS/rclone 원본 mount는 읽기 전용을 권장합니다.

전체 예시는 [compose/docker-compose.production.yml](compose/docker-compose.production.yml)에 있습니다.

## 태그

권장 태그:

```text
ghcr.io/suikano1304/kavita-gds:9.0.7-6
```

`latest`도 같은 릴리즈를 가리키지만, 운영에서는 고정 버전 태그를 권장합니다.

현재 GHCR digest:

```text
ghcr.io/suikano1304/kavita-gds:9.0.7-6
ghcr.io/suikano1304/kavita-gds:latest
multiarch digest=sha256:a8f887897ff78e33e8d8763d9a7f67971cf5e5af3d3402f2ea7041e80443132f

linux/amd64=sha256:faa6536b9fa1889c022b8b9948e0607d9f1346b69d5bab3ce515defc3c841f24
linux/arm64=sha256:eabc568d9faebd5cd5ee1b7ca5e2b174f970b98a53bbb19f9675eb45ea284a29
linux/arm/v7=sha256:517bd042d09ab6f6aa796a82267d4b8abf8473d2d8aaeed3036409235955d4d2
```

## 수동 다운로드

`9.0.7-6`의 기본 배포물은 GHCR multi-arch image입니다. Docker pull이 불가능한 폐쇄망 환경에서는 GHCR image를 별도 registry로 미러링하거나, 필요한 플랫폼의 OCI archive를 따로 생성해 반입하세요. 과거 릴리스의 GitHub tarball은 해당 릴리스 태그 기준 산출물입니다.

## 주요 수정

`9.0.7-6`에는 다음 안정화가 포함되어 있습니다.

- official Kavita `0.9.0.7` nightly 변경 병합
- OPDS multi-file archive acquisition regression 수정: 다중 ZIP/CBZ chapter feed에서 각 entry가 실제 `MangaFile` id, filename, size, page count, file-specific download route를 사용
- OPDS image stream의 `saveProgress=false` 조건이 진행률 저장을 막도록 수정
- WebUI unnamed metadata filter default regression 수정: smart filter 이름 없이 정렬/필터를 저장하면 현재 route의 기본 metadata filter로 저장하고 다음 진입 시 적용
- 같은 chapter에 broken/empty EPUB row와 valid EPUB row가 함께 있을 때 reader/cache/TOC 경로가 readable EPUB row를 우선 선택
- GDS targeted series scan 후 word-count 분석과 전역 metadata/cache cleanup을 건너뛰도록 보정
- mixed-root GDS series scan이 broad category/library root로 확장되지 않도록 실제 file directory만 scan
- WebUI cover cache-busting과 cover endpoint no-cache header 적용
- GDS cover generation refactor: GDS 전용 cover 우선순위를 별도 서비스로 분리해 upstream 재적용 충돌면을 축소
- TXT YAML cover precedence fix: TXT-only import/refresh에서 file-level YAML base64 cover를 title fallback보다 우선 적용
- GDS EPUB cover fallback 안정화와 SQLite startup/WebUI 회귀 hotfix
- GDS reader metadata refresh 안정화 유지
- Kavita+를 쓰지 않는 운영에서 일반 Book 라이브러리 eligibility 유지 확인
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

`9.0.7-6` 배포 전 다음 검증을 수행했습니다.

- OPDS feed/service focused tests 33개 통과
- OPDS controller focused tests 6개 통과
- WebUI production build 통과 및 unnamed metadata filter default storage bundle 포함 확인
- `9.0.7-5` reader/cache baseline용 `CacheServiceTests` 재실행 `DOTNET_EXIT:0` 확인
- backend runtime package `linux-x64`, `linux-arm64`, `linux-arm` 생성
- local release image `linux/amd64` startup `/api/health` 200 확인
- local release image `linux/arm64` qemu startup `/api/health` 200 확인
- local release image `linux/arm/v7` qemu startup `/api/health` 200 확인
- pushed GHCR `9.0.7-6` 이미지의 `linux/amd64` startup `/api/health` 200 확인
- GHCR `9.0.7-6`와 `latest`가 같은 multi-arch digest를 가리키고 `linux/amd64`, `linux/arm64`, `linux/arm/v7` manifest를 포함하는지 확인
- 운영 컨테이너는 이 hotfix publish 중 재기동하지 않았고 기존 `9.0.7-5` 상태로 유지했습니다.

세부 기록은 [docs/GDS_0.9.0.7_VALIDATION.md](docs/GDS_0.9.0.7_VALIDATION.md)에 있습니다.

다음 릴리즈 배포 전에는 [docs/GDS_REGRESSION_CHECKLIST_KO.md](docs/GDS_REGRESSION_CHECKLIST_KO.md)를 따라 기존 문제 샘플 회귀 검증을 먼저 통과시킵니다. 실제 작품명과 경로가 필요한 로컬 상세 매트릭스는 PVE host의 `/root/lxc1-codex-docs/KAVITA_GDS_REGRESSION_MATRIX.md`에만 기록합니다.

## 문서

- [docs/USAGE_KO.md](docs/USAGE_KO.md): 설치와 운영 사용법
- [docs/CHANGELOG_KO.md](docs/CHANGELOG_KO.md): 변경 내역
- [docs/BUILD_NOTES_KO.md](docs/BUILD_NOTES_KO.md): 빌드/배포 노트
- [docs/GDS_REGRESSION_CHECKLIST_KO.md](docs/GDS_REGRESSION_CHECKLIST_KO.md): 배포 전 회귀 검증 체크리스트
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
