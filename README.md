# Kavita GDS

Kavita `0.9.0.2` 기반 비공식 GDS 빌드입니다.

`kavita-gds-0.9.0.2-scan-20260528` 이후의 EPUB/PDF/rclone hang 수정과 GDS scanfix를 포함하며, `linux/amd64`와 `linux/arm64`를 지원합니다.

2026-05-31 운영 서버에는 `kavita.yaml` 메타데이터 반영과 회차 제목 보정 패치를 추가 검증했습니다. 해당 운영 기록은 [docs/OPERATIONS_20260531_KO.md](docs/OPERATIONS_20260531_KO.md)에 정리했습니다.

추가로 GDS/rclone 재스캔 병목, 혼합 폴더 스캔 문제, TXT 커버 부재 문제를 확인했습니다. 일반 재스캔은 빠르게 유지하고, 누락 복구가 필요한 경우만 실제 파일 목록을 다시 읽도록 정리했습니다. 커버가 없는 GDS TXT 시리즈는 외부 API 없이 제목 기반 커버를 Kavita config에 생성합니다.

## Docker Pull

```bash
docker pull ghcr.io/suikano1304/kavita-gds:0.9.0.2-3
```

최신 태그도 제공합니다.

```bash
docker pull ghcr.io/suikano1304/kavita-gds:latest
```

운영에는 `latest`보다 고정 버전 태그 `0.9.0.2-3` 사용을 권장합니다.

## Compose 예시

```yaml
services:
  kavita:
    image: ghcr.io/suikano1304/kavita-gds:0.9.0.2-3
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
    environment:
      TZ: Asia/Seoul
```

`/your/kavita/config`와 `/your/gds/mount`는 본인 환경에 맞게 바꾸세요. GDS/rclone 원본 마운트는 읽기 전용으로 두는 것을 권장합니다.

전체 예시는 [compose/docker-compose.production.yml](compose/docker-compose.production.yml)에 있습니다.

## 수동 다운로드

Docker pull 대신 GitHub Release에서 tarball을 받을 수 있습니다.

- Release: <https://github.com/suikano1304/Kavita-GDS/releases/tag/v0.9.0.2-3>
- File: `kavita-gds.tar.gz`
- SHA256: GitHub Release의 `SHA256SUMS` 또는 저장소 루트 [SHA256SUMS](SHA256SUMS)를 확인하세요.

압축 안에는 `docker-image/kavita-gds.oci.tar`가 들어 있습니다.

## 주요 변경

- EPUB manifest 중복 ID 자동 복구
- 손상 PDF의 XRef 무한 재귀 방지
- rclone/FUSE 대형 라이브러리 디렉터리 스캔 hang 완화
- GDS reader/runtime 오류 수정
- 혼합 포맷 GDS 시리즈 분리 완화
- `kavita.yaml`, `kavita.yml`, `cover.*` 등 메타데이터 파일의 미디어 오인식 방지
- GDS `kavita.yaml`의 요약/인물/출판사/날짜 등 sidecar metadata 반영
- YAML `meta.Name`이 회차 제목을 덮어쓰지 않도록 하고 파일명 기반 회차 제목 사용
- GDS/rclone 반복 스캔에서 변경 없는 파일의 page/hash 재계산과 커버 재분석을 줄여 속도 개선
- GDS EPUB/PDF/TXT가 `Pages=0`으로 남아 읽기 불가처럼 보이는 문제 완화
- `Pages=0`으로 남은 기존 GDS 파일이 있으면 변경 없음 최적화를 건너뛰고 다시 파싱해 scan debt를 회복
- 같은 작품이 `작품명/`과 `작품명 -/`처럼 나뉜 production-library-d 폴더에서도 기존 GDS 볼륨을 보존
- GDS 증분 스캔에서 포맷 하위 폴더와 정규화명이 같은 형제 폴더를 기존 시리즈로 매칭해 반복 재처리 감소
- GDS 스캔 중 원본 media 경로에 쓰지 않도록 커버/정리 동작 방어
- 원본 커버가 없는 GDS TXT 시리즈에 제목 기반 fallback cover 생성
- startup migration/BaseUrl 저장 단계의 SQLite FK 오류 진단 로그 보강
- same-volume duplicate file path cleanup 보강
- 읽기 전용 GDS 진단 스크립트 추가
- 반복 스캔 churn 감소
- stale Angular chunk 방지를 위한 UI/정적 캐시 정책 조정
- `linux/amd64`, `linux/arm64` multi-arch 배포

자세한 내용은 [docs/CHANGELOG_KO.md](docs/CHANGELOG_KO.md)를 보세요.

## 문서

- [docs/USAGE_KO.md](docs/USAGE_KO.md): 한국어 사용 설명서
- [docs/CHANGELOG_KO.md](docs/CHANGELOG_KO.md): 변경 내역
- [docs/BUILD_NOTES_KO.md](docs/BUILD_NOTES_KO.md): 빌드 노트
- [docs/OPERATIONS_20260531_KO.md](docs/OPERATIONS_20260531_KO.md): 커버 복구와 YAML 적용 검증 운영 기록
- [docs/SCANNER_ROOT_CAUSE_KO.md](docs/SCANNER_ROOT_CAUSE_KO.md): GDS 스캐너 병목/오동작 근본 원인 분석
- [scripts/diagnose_kavita_gds.py](scripts/diagnose_kavita_gds.py): 읽기 전용 DB/스캔 상태 진단 도구
- [scripts/summarize_kavita_scan_logs.py](scripts/summarize_kavita_scan_logs.py): 읽기 전용 scan log 및 slow reader request timing 요약 도구
- [RELEASE_NOTES.md](RELEASE_NOTES.md): 릴리스 노트

## 주의

이 이미지는 공식 Kavita 이미지가 아닙니다. 개인 GDS/rclone 읽기 전용 마운트 환경에서 스캔 안정성을 확인하기 위해 만든 비공식 빌드입니다.

`arm64` 이미지는 build/manifest 검증과 QEMU 기반 entrypoint smoke test를 완료했습니다. 현재 startup SQLite FK 제보는 일반 x86 환경의 공통 재현 문제로 보지 않고, Oracle A1 같은 arm64 서버에서만 발생한 환경별 사례로 분리해 보고 있습니다. 같은 DB 또는 같은 이미지가 x86/NAS 환경에서 정상 기동되는데 Oracle A1에서만 오류가 난다면, 이미지 아키텍처보다 해당 서버의 기존 DB 상태, 이전 컨테이너 종료 상태, compose volume 연결, migration history를 먼저 확인하세요. 이 확인을 돕기 위해 `0.9.0.2-3`은 startup FK 진단 로그와 읽기 전용 진단 스크립트를 포함합니다.
