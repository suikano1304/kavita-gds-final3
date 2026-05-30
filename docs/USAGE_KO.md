# Kavita GDS final3 universal 사용 설명서

## 개요

이 배포본은 Kavita `0.9.0.2` 기반 비공식 GDS scanfix 빌드입니다.

하나의 OCI archive에 `linux/amd64`와 `linux/arm64` 이미지를 같이 넣었습니다. x86 서버와 Oracle Cloud A1 같은 arm64 서버에서 같은 release asset을 공유하기 위한 형태입니다.

기존 `kavita-gds-0.9.0.2-scan-20260528` 이후의 변경 내역은 [CHANGELOG_KO.md](CHANGELOG_KO.md)에 정리되어 있습니다.

## 다운로드

Release 페이지에서 아래 파일을 다운로드합니다.

```text
kavita-gds-0.9.0.2-scanfix-final3-universal.tar.gz
```

직접 다운로드 예시:

```bash
curl -L -o kavita-gds-0.9.0.2-scanfix-final3-universal.tar.gz \
  https://github.com/suikano1304/kavita-gds-final3/releases/download/v0.9.0.2-gds-scanfix-final3-universal/kavita-gds-0.9.0.2-scanfix-final3-universal.tar.gz
```

체크섬 확인:

```bash
sha256sum kavita-gds-0.9.0.2-scanfix-final3-universal.tar.gz
```

기대값:

```text
a1cc0a3fca45f952b713845a73d3fa725f97bcc173f85b06b8cf64fb01ac26e1
```

## 압축 해제

```bash
tar -xzf kavita-gds-0.9.0.2-scanfix-final3-universal.tar.gz
cd kavita-gds-0.9.0.2-scanfix-final3-universal
```

주요 파일:

```text
docker-image/kavita-gds-0.9.0.2-gds-scanfix-final3-20260530-universal.oci.tar
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
  oci-archive:docker-image/kavita-gds-0.9.0.2-gds-scanfix-final3-20260530-universal.oci.tar \
  docker-daemon:local/kavita-gds:0.9.0.2-gds-scanfix-final3-20260530-universal
```

registry로 밀어 넣기:

```bash
skopeo copy \
  oci-archive:docker-image/kavita-gds-0.9.0.2-gds-scanfix-final3-20260530-universal.oci.tar \
  docker://YOUR_REGISTRY/YOUR_NAMESPACE/kavita-gds:0.9.0.2-gds-scanfix-final3-20260530-universal
```

registry에 올린 뒤 compose의 `image:` 값을 해당 registry 주소로 바꾸면 됩니다.

### containerd/nerdctl 사용

환경에 따라 다음 방식으로 import가 가능합니다.

```bash
nerdctl load -i docker-image/kavita-gds-0.9.0.2-gds-scanfix-final3-20260530-universal.oci.tar
```

런타임마다 OCI archive 지원 방식이 다르므로, 일반 `docker load`가 실패하면 `skopeo`를 쓰는 방식을 권장합니다.

## Compose 설정

예시 파일:

```text
compose/docker-compose.production.yml
```

기본 이미지 태그:

```text
local/kavita-gds:0.9.0.2-gds-scanfix-final3-20260530-universal
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

## 어떤 경우에 쓰는가

이 빌드는 GDS/rclone 마운트 기반 라이브러리에서 Kavita 스캔 동작을 안정화하기 위해 만든 final3 패키지입니다.

주요 목적:

- GDS 원본 경로를 읽기 전용으로 유지
- Kavita scanfix final3 변경사항 배포
- x86 서버와 arm64 서버에서 같은 release asset 사용

## 주의사항

- 공식 Kavita 이미지가 아닙니다.
- 기존 Kavita DB를 연결하기 전에는 백업을 권장합니다.
- `arm64` 이미지는 빌드/manifest 검증까지 완료됐지만, 실제 ARM 장비에서 런타임 테스트는 별도로 필요합니다.
- 이 repo에는 큰 binary 파일을 직접 commit하지 않습니다. 큰 파일은 Release asset으로만 배포합니다.
