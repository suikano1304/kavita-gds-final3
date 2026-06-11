# Kavita GDS

Kavita GDS는 official Kavita `0.9.0.7` nightly를 기반으로, Google Drive/rclone 같은 원격 저장소를 쓰는 대형 라이브러리 환경에서 더 안정적으로 스캔하고 읽을 수 있도록 보정한 비공식 Docker 빌드입니다.

현재 릴리즈는 `9.0.7-6`입니다.

## 누구에게 필요한가요?

다음 환경이면 이 이미지를 쓰는 것이 도움이 됩니다.

- Google Drive, rclone, FUSE mount 같은 원격 media 경로를 Kavita에 연결해 사용합니다.
- ZIP/CBZ, EPUB, PDF, TXT가 한 라이브러리 안에 섞여 있습니다.
- 큰 라이브러리 스캔 중 메모리 부족, 긴 멈춤, 반복 재스캔, 잘못된 페이지 수 문제가 있었습니다.
- `kavita.yaml`/`kavita.yml`, folder cover, TXT/EPUB cover fallback 같은 GDS용 metadata 흐름을 사용합니다.
- 원본 media 폴더는 읽기 전용으로 두고, DB/cache/cover만 Kavita config 경로에 저장하고 싶습니다.

일반 로컬 디스크 기반 Kavita만 쓰는 경우에는 official Kavita 이미지를 먼저 권장합니다.

## 빠른 시작

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

`/your/kavita/config`, `/your/gds/mount`, `WAIT_ANCHOR_DIRS`는 본인 환경에 맞게 바꾸세요. GDS/rclone 원본 mount는 읽기 전용으로 연결하는 것을 권장합니다.

전체 예시는 [compose/docker-compose.production.yml](compose/docker-compose.production.yml)에 있습니다.

## 태그와 플랫폼

운영에서는 고정 버전 태그를 권장합니다.

```text
ghcr.io/suikano1304/kavita-gds:9.0.7-6
```

`latest`도 현재는 같은 릴리즈를 가리킵니다. 지원 플랫폼은 다음과 같습니다.

- `linux/amd64`
- `linux/arm64`
- `linux/arm/v7`

정확한 manifest digest와 검증 기록은 [RELEASE_NOTES.md](RELEASE_NOTES.md)와 [docs/GDS_0.9.0.7_VALIDATION.md](docs/GDS_0.9.0.7_VALIDATION.md)에 기록합니다.

## 주요 수정

이번 릴리즈는 원격 저장소에 있는 큰 만화/책 라이브러리를 더 안정적으로 다루기 위한 수정들을 모은 버전입니다.

- 필터 저장 개선: 스마트 필터 이름을 따로 입력하지 않아도, 현재 화면에서 선택한 정렬과 필터가 기본값으로 저장됩니다.
- 읽기 오류 완화: 같은 항목 안에 깨진 EPUB 정보와 정상 EPUB 정보가 같이 있을 때, 가능한 정상 파일을 우선 사용합니다.
- 스캔 범위 축소: 특정 시리즈만 스캔하려고 했는데 상위 폴더나 큰 라이브러리까지 같이 훑는 상황을 줄였습니다.
- 대형 라이브러리 안정화: 큰 GDS/rclone 라이브러리를 스캔할 때 메모리를 덜 쓰도록 DB 업데이트와 표지 생성 흐름을 조정했습니다.
- 페이지 수와 표지 처리 보정: EPUB, TXT, PDF, ZIP/CBZ 파일에서 페이지 수가 잘못 잡히거나 표지가 엉뚱하게 선택되는 문제를 줄였습니다.
- 한글 표지 fallback 개선: TXT 파일 등에서 표지를 자동 생성할 때 한글이 깨지지 않도록 Nanum Gothic 폰트를 포함했습니다.
- 운영 진단 편의: 컨테이너 안에 `sqlite3`와 읽기 전용 진단 스크립트를 포함해 DB와 스캔 상태를 확인하기 쉽게 했습니다.

OPDS 실험 패치는 이번 릴리즈에서 제외했습니다. 기존 OPDS 기능은 제거하지 않았고, 새 OPDS 호환성 변경만 원복했습니다.

자세한 변경 내역은 [docs/CHANGELOG_KO.md](docs/CHANGELOG_KO.md)를 보세요.

## 검증 기록

`9.0.7-6` 이미지는 배포 전에 다음 항목을 확인했습니다.

- 웹 화면 빌드 확인: 실제 운영에 들어가는 WebUI bundle이 정상 생성되고, 필터 저장 수정이 포함되어 있는지 확인했습니다.
- 기본 실행 확인: `linux/amd64`, `linux/arm64`, `linux/arm/v7` 이미지가 각각 시작되고 `/api/health`에서 `Ok`를 반환하는지 확인했습니다.
- Docker 상태 확인: 테스트 컨테이너들이 Docker health `healthy` 상태까지 도달하는지 확인했습니다.
- 기존 reader/cache 회귀 확인: 깨진 EPUB 정보와 정상 EPUB 정보가 함께 있는 경우에도 읽기 경로가 정상 파일을 선택하는지 테스트했습니다.
- GHCR 배포 확인: `9.0.7-6`와 `latest`가 같은 multi-arch 이미지로 올라갔고, 세 플랫폼을 모두 포함하는지 확인했습니다.
- 운영 적용 확인: 운영 컨테이너를 `9.0.7-6`로 교체한 뒤 `/api/health=Ok`, Docker health `healthy`, restart count `0`을 확인했습니다.

더 자세한 검증 내역과 manifest digest는 [RELEASE_NOTES.md](RELEASE_NOTES.md)와 [docs/GDS_0.9.0.7_VALIDATION.md](docs/GDS_0.9.0.7_VALIDATION.md)에 있습니다.

## 업그레이드 전 확인

기존 Kavita DB를 연결하기 전에는 config 디렉터리와 DB를 백업하세요.

```bash
cp -a /your/kavita/config /your/kavita/config.backup
```

운영 적용 후에는 최소한 다음을 확인하세요.

```bash
curl http://127.0.0.1:5657/api/health
docker ps --filter name=kavita
```

정상 응답은 `/api/health`의 `Ok`와 Docker health `healthy`입니다.

## 문서

- [docs/USAGE_KO.md](docs/USAGE_KO.md): 설치와 운영 사용법
- [docs/CHANGELOG_KO.md](docs/CHANGELOG_KO.md): 변경 내역
- [RELEASE_NOTES.md](RELEASE_NOTES.md): 릴리즈 노트와 manifest digest
- [docs/GDS_REGRESSION_CHECKLIST_KO.md](docs/GDS_REGRESSION_CHECKLIST_KO.md): 배포 전 회귀 검증 체크리스트
- [scripts/diagnose_kavita_gds.py](scripts/diagnose_kavita_gds.py): 읽기 전용 DB/스캔/startup migration 진단
- [scripts/collect_gds_preflight.sh](scripts/collect_gds_preflight.sh): 운영 적용 전후 preflight/postflight 수집

## 주의

이 이미지는 official Kavita 이미지가 아닙니다.

원본 media mount는 읽기 전용으로 연결하는 구성을 전제로 합니다. cover 생성, 진단, cache, DB 변경은 Kavita config 경로에서만 일어나야 합니다.

`linux/arm64`와 `linux/arm/v7` 이미지는 qemu smoke test를 통과했지만, ARM 실서비스 환경에서는 적용 후 별도 확인을 권장합니다.
