# Kavita GDS final3 universal

Kavita `0.9.0.2` 기반 비공식 GDS scanfix 빌드입니다.

기존 `kavita-gds-0.9.0.2-scan-20260528` 이후의 EPUB/PDF/rclone hang 수정, GDS scanfix final3 수정, 그리고 `linux/amd64`/`linux/arm64` universal 배포를 포함합니다.

## 빠른 시작

Docker에서 바로 받을 수 있습니다.

```bash
docker pull ghcr.io/suikano1304/kavita-gds-final3:0.9.0.2-gds-scanfix-final3-20260530-universal
```

Compose에서는 아래 이미지를 사용하세요.

```yaml
services:
  kavita:
    image: ghcr.io/suikano1304/kavita-gds-final3:0.9.0.2-gds-scanfix-final3-20260530-universal
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

전체 compose 예시는 [compose/docker-compose.production.yml](compose/docker-compose.production.yml)에 있습니다.

## 지원 아키텍처

GHCR 이미지는 multi-platform manifest입니다.

- `linux/amd64`
- `linux/arm64`

Oracle Cloud A1 같은 arm64 환경에서도 같은 태그를 사용할 수 있습니다.

## 이미지 태그

고정 버전:

```text
ghcr.io/suikano1304/kavita-gds-final3:0.9.0.2-gds-scanfix-final3-20260530-universal
```

최신 태그:

```text
ghcr.io/suikano1304/kavita-gds-final3:latest
```

운영 배포에는 고정 버전 태그를 권장합니다.

## 수동 다운로드

Docker pull 대신 release asset을 직접 받을 수도 있습니다.

Release:

```text
https://github.com/suikano1304/kavita-gds-final3/releases/tag/v0.9.0.2-gds-scanfix-final3-universal
```

파일:

```text
kavita-gds-0.9.0.2-scanfix-final3-universal.tar.gz
```

SHA256:

```text
a1cc0a3fca45f952b713845a73d3fa725f97bcc173f85b06b8cf64fb01ac26e1
```

tarball 안에는 multi-platform OCI archive가 들어 있습니다.

```text
docker-image/kavita-gds-0.9.0.2-gds-scanfix-final3-20260530-universal.oci.tar
```

## 주요 변경

`kavita-gds-0.9.0.2-scan-20260528` 이후 주요 변경입니다.

- EPUB manifest 중복 ID 자동 복구
- 손상 PDF의 XRef 무한 재귀 방지
- rclone/FUSE 대형 라이브러리 디렉터리 스캔 hang 완화
- GDS reader/runtime 오류 수정
- 혼합 포맷 GDS 시리즈 분리 완화
- `kavita.yaml`, `kavita.yml`, `cover.*` 등 메타데이터 파일의 미디어 오인식 방지
- GDS 스캔 중 원본 media 경로에 쓰지 않도록 커버/정리 동작 방어
- 반복 스캔 churn 감소
- stale Angular chunk 방지를 위한 UI/정적 캐시 정책 조정
- `linux/amd64`, `linux/arm64` universal GHCR 배포

자세한 변경 내역은 [docs/CHANGELOG_KO.md](docs/CHANGELOG_KO.md)를 보세요.

## 문서

- [docs/USAGE_KO.md](docs/USAGE_KO.md): 한국어 사용 설명서
- [docs/CHANGELOG_KO.md](docs/CHANGELOG_KO.md): 변경 내역
- [docs/BUILD_NOTES_KO.md](docs/BUILD_NOTES_KO.md): 빌드 노트
- [RELEASE_NOTES.md](RELEASE_NOTES.md): 릴리스 노트

## 저장소 구성

- [compose/docker-compose.production.yml](compose/docker-compose.production.yml): 배포용 compose 예시
- [Dockerfile.universal](Dockerfile.universal): universal 이미지 빌드에 사용한 Dockerfile
- [SHA256SUMS](SHA256SUMS): release asset 및 주요 산출물 체크섬
- [.github/workflows/publish-ghcr.yml](.github/workflows/publish-ghcr.yml): Release asset을 GHCR 이미지로 publish하는 workflow

큰 binary 파일은 Git repo에 직접 넣지 않고 GitHub Release asset과 GHCR image로 배포합니다.

## 주의

이 이미지는 공식 Kavita 이미지가 아닙니다. 개인 GDS/rclone 읽기 전용 마운트 환경에서 스캔 안정성을 확인하기 위해 만든 비공식 빌드입니다.

`arm64` 이미지는 build/manifest 검증을 완료했지만, 실제 ARM 장비에서의 런타임 테스트는 별도로 필요합니다.
