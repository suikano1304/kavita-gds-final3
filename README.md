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

## 9.0.7-6에서 달라진 점

이번 릴리즈는 WebUI와 기존 GDS 안정화 패치를 묶은 hotfix입니다.

- smart filter 이름 없이 정렬/필터를 저장해도 현재 화면의 기본 필터로 저장되도록 수정했습니다.
- 같은 chapter에 깨진 EPUB row와 정상 EPUB row가 함께 있을 때, reader/cache가 읽을 수 있는 파일을 우선 선택합니다.
- GDS 스캔이 불필요하게 넓은 상위 폴더까지 확장되지 않도록 보정했습니다.
- 대형 GDS 라이브러리 스캔에서 메모리 사용량을 줄이도록 DB update와 cover generation 경로를 조정했습니다.
- EPUB/TXT/PDF/ZIP 계열에서 페이지 수, cover fallback, manifest 경로 복구 관련 기존 GDS 안정화 패치를 유지합니다.
- WebUI production bundle, Nanum Gothic font, `sqlite3` 진단 도구를 runtime image에 포함합니다.

OPDS 실험 패치는 이번 릴리즈에서 제외했습니다. 기존 OPDS 기능은 제거하지 않았고, 새 OPDS 호환성 변경만 원복했습니다.

자세한 변경 내역은 [docs/CHANGELOG_KO.md](docs/CHANGELOG_KO.md)를 보세요.

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
