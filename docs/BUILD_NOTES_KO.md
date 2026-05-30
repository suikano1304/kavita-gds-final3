# 빌드 노트

## 목적

Kavita `0.9.0.2` 기반 GDS scanfix 빌드를 `linux/amd64`와 `linux/arm64`에서 사용할 수 있도록 multi-platform OCI archive로 패키징했습니다.

이 배포는 기존 `kavita-gds-0.9.0.2-scan-20260528` 이후의 EPUB/PDF/rclone hang 수정과 GDS scanfix 변경을 포함합니다. 상세 변경 내역은 [CHANGELOG_KO.md](CHANGELOG_KO.md)를 참고하세요.

## 포함 플랫폼

- `linux/amd64`
- `linux/arm64`

## 산출물

Release asset:

```text
kavita-gds-0.9.0.2-scanfix-universal-20260530.tar.gz
```

내부 OCI archive:

```text
docker-image/kavita-gds-0.9.0.2-gds-scanfix-20260530-universal.oci.tar
```

권장 이미지 태그:

```text
ghcr.io/suikano1304/kavita-gds:0.9.0.2-gds-scanfix-20260530-universal
```

GHCR publish workflow:

```text
.github/workflows/publish-ghcr.yml
```

이 workflow는 GitHub Release asset을 다운로드한 뒤 내부 OCI archive를 GHCR에 `version tag`와 `latest` tag로 publish합니다.

## 검증 내용

- scanfix 소스 스냅샷 기준으로 빌드했습니다.
- `linux-x64`와 `linux-arm64` self-contained runtime publish를 생성했습니다.
- Docker Buildx로 `linux/amd64`, `linux/arm64` OCI image index를 생성했습니다.
- OCI index에 두 플랫폼이 모두 포함된 것을 확인했습니다.
- 중간 테스트 이미지와 webtoon patch tree는 배포 패키지에 넣지 않았습니다.
- 큰 binary 파일은 Git repo에 직접 commit하지 않고 GitHub Release asset으로만 배포합니다.

## 제한

- 이 빌드는 공식 Kavita 이미지가 아닙니다.
- `arm64` 이미지는 build/manifest 검증까지 완료했지만, 실제 ARM 장비에서 런타임 테스트는 별도로 필요합니다.
- 기존 Kavita 데이터베이스에 적용하기 전에는 백업을 권장합니다.
