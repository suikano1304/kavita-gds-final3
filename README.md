# Kavita GDS

Kavita `0.9.0.2` 기반 비공식 GDS 빌드입니다.

`kavita-gds-0.9.0.2-scan-20260528` 이후의 EPUB/PDF/rclone hang 수정과 GDS scanfix를 포함하며, `linux/amd64`와 `linux/arm64`를 지원합니다.

2026-05-31 운영 서버에는 `kavita.yaml` 메타데이터 반영과 회차 제목 보정 패치를 추가 검증했습니다. 해당 운영 기록은 [docs/OPERATIONS_20260531_KO.md](docs/OPERATIONS_20260531_KO.md)에 정리했습니다.

## Docker Pull

```bash
docker pull ghcr.io/suikano1304/kavita-gds:0.9.0.2
```

최신 태그도 제공합니다.

```bash
docker pull ghcr.io/suikano1304/kavita-gds:latest
```

운영에는 `latest`보다 고정 버전 태그 `0.9.0.2`를 권장합니다.

## Compose 예시

```yaml
services:
  kavita:
    image: ghcr.io/suikano1304/kavita-gds:0.9.0.2
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

- Release: <https://github.com/suikano1304/Kavita-GDS/releases/tag/v0.9.0.2>
- File: `kavita-gds.tar.gz`
- SHA256: `894b1b88cc1c63f886bc9413e6eda773fbf278fa5abb666fda4e632246d2177b`

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
- GDS 스캔 중 원본 media 경로에 쓰지 않도록 커버/정리 동작 방어
- 반복 스캔 churn 감소
- stale Angular chunk 방지를 위한 UI/정적 캐시 정책 조정
- `linux/amd64`, `linux/arm64` multi-arch 배포

자세한 내용은 [docs/CHANGELOG_KO.md](docs/CHANGELOG_KO.md)를 보세요.

## 문서

- [docs/USAGE_KO.md](docs/USAGE_KO.md): 한국어 사용 설명서
- [docs/CHANGELOG_KO.md](docs/CHANGELOG_KO.md): 변경 내역
- [docs/BUILD_NOTES_KO.md](docs/BUILD_NOTES_KO.md): 빌드 노트
- [docs/OPERATIONS_20260531_KO.md](docs/OPERATIONS_20260531_KO.md): 커버 복구와 YAML 적용 검증 운영 기록
- [RELEASE_NOTES.md](RELEASE_NOTES.md): 릴리스 노트

## 주의

이 이미지는 공식 Kavita 이미지가 아닙니다. 개인 GDS/rclone 읽기 전용 마운트 환경에서 스캔 안정성을 확인하기 위해 만든 비공식 빌드입니다.

`arm64` 이미지는 build/manifest 검증을 완료했지만, 실제 ARM 장비에서의 런타임 테스트는 별도로 필요합니다.
