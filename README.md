# Kavita GDS final3 universal

Kavita `0.9.0.2` 기반의 비공식 GDS scanfix 빌드입니다.

이 릴리스는 하나의 OCI archive 안에 다음 두 아키텍처를 포함합니다.

- `linux/amd64`
- `linux/arm64`

자세한 한국어 설치/검증 방법은 [docs/USAGE_KO.md](docs/USAGE_KO.md)를 보세요.

## Download

GitHub Releases에서 아래 파일을 받으면 됩니다.

```text
kavita-gds-0.9.0.2-scanfix-final3-universal.tar.gz
```

Release:

```text
https://github.com/suikano1304/kavita-gds-final3/releases/tag/v0.9.0.2-gds-scanfix-final3-universal
```

SHA256:

```text
a1cc0a3fca45f952b713845a73d3fa725f97bcc173f85b06b8cf64fb01ac26e1
```

## Image

권장 이미지 태그:

```text
local/kavita-gds:0.9.0.2-gds-scanfix-final3-20260530-universal
```

배포 tarball 안의 실제 이미지 파일:

```text
docker-image/kavita-gds-0.9.0.2-gds-scanfix-final3-20260530-universal.oci.tar
```

## Included In This Repository

- [Dockerfile.universal](Dockerfile.universal): universal 이미지 빌드에 사용한 Dockerfile
- [compose/docker-compose.production.yml](compose/docker-compose.production.yml): 배포용 compose 예시
- [SHA256SUMS](SHA256SUMS): 배포 패키지 내부 파일 체크섬
- [docs/USAGE_KO.md](docs/USAGE_KO.md): 한국어 사용 설명서
- [docs/BUILD_NOTES_KO.md](docs/BUILD_NOTES_KO.md): 공개용 빌드 노트

큰 binary 파일은 Git repo에 직접 넣지 않고 GitHub Release asset으로만 배포합니다.

## Notes

이 이미지는 공식 Kavita 이미지가 아닙니다. 개인 GDS/rclone 읽기 전용 마운트 환경에서 스캔 안정성을 확인하기 위해 만든 비공식 빌드입니다.

`arm64` 이미지는 빌드 및 OCI manifest 검증까지 완료했지만, 실제 ARM 장비에서 런타임 테스트는 하지 않았습니다.
