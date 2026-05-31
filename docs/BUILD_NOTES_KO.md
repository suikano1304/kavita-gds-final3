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
kavita-gds.tar.gz
```

내부 OCI archive:

```text
docker-image/kavita-gds.oci.tar
```

권장 이미지 태그:

```text
ghcr.io/suikano1304/kavita-gds:0.9.0.2-7
```

GHCR publish workflow:

```text
.github/workflows/publish-ghcr.yml
```

이 workflow는 GitHub Release asset을 다운로드한 뒤 내부 OCI archive를 GHCR에 `version tag`와 `latest` tag로 publish합니다.

## 검증 내용

- `0.9.0.2-7` source에서 `linux/amd64`, `linux/arm64` self-contained publish를 수행했습니다.
- 혼합 포맷 시리즈의 EPUB word-count hotfix와 GDS archive cover fallback hotfix를 포함했습니다.
- Angular `dist`와 image의 `/kavita/wwwroot`를 정리한 뒤 production UI만 포함했습니다.
- Docker Buildx로 `linux/amd64`, `linux/arm64` OCI image index를 생성했습니다.
- OCI index에 두 플랫폼이 모두 포함된 것을 확인했습니다.
- `linux/amd64` 이미지는 `0.9.0.2-7` 임시 컨테이너로 기동 검증했습니다.
- `linux/arm64` 이미지는 OCI manifest 포함과 QEMU 기반 image build 경로를 검증했습니다.
- `/kavita/wwwroot` 전체에서 `localhost:5000`, `:5000/api`, Angular development mode 문자열이 없는 것을 확인했습니다.
- 제목 기반 TXT fallback cover 생성을 위해 Docker image에 Nanum Gothic 폰트를 포함했습니다.
- 중간 테스트 이미지와 webtoon patch tree는 배포 패키지에 넣지 않았습니다.
- 큰 binary 파일은 Git repo에 직접 commit하지 않고 GitHub Release asset으로만 배포합니다.

## 제한

- 이 빌드는 공식 Kavita 이미지가 아닙니다.
- `arm64` 이미지는 build/manifest 검증까지 완료했지만, 실제 ARM 장비에서 기존 DB를 붙인 전체 runtime 검증은 별도로 필요합니다.
- 기존 Kavita 데이터베이스에 적용하기 전에는 백업을 권장합니다.
