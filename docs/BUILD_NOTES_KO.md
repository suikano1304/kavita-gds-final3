# 빌드 노트

## 목적

Kavita official `0.9.0.6` 기반 GDS scanfix 빌드 `9.0.6-2`를 Docker/GHCR 배포용으로 패키징했습니다.

이 배포는 기존 `0.9.0.2-8`까지의 GDS/rclone 수정, 2026-06-01 테스트 컨테이너/운영 검증에서 확인한 EPUB/TXT/커버 수정, 2026-06-02 scan/page-count 안정화 수정을 포함합니다. 상세 변경 내역은 [CHANGELOG_KO.md](CHANGELOG_KO.md)를 참고하세요.

## 포함 플랫폼

- `linux/amd64`
- `linux/arm64` (GHCR multi-arch manifest)

## 산출물

Release asset:

```text
kavita-gds.tar.gz
```

내부 Docker archive:

```text
docker-image/kavita-gds.docker.tar
```

권장 이미지 태그:

```text
ghcr.io/suikano1304/kavita-gds:9.0.6-2
```

현재 GHCR 기준:

```text
ghcr.io/suikano1304/kavita-gds:9.0.6-2
ghcr.io/suikano1304/kavita-gds:latest
multiarch digest=sha256:980226a70418c5d20f70fc853e154d242a4eb15909c75df8b3a61386b937b386
linux/amd64=sha256:dc7f117d3f6701ffee182d1d80a91f7dc516056e44cbfeb420c42a0c982c9f97
linux/arm64=sha256:019ed329577d1fdad5ed11e1b006fd9c42b7663bf99b0807602d0a0224e882f3
```

GHCR publish workflow:

```text
.github/workflows/publish-ghcr.yml
```

이 workflow는 GitHub Release asset을 다운로드한 뒤 내부 Docker archive를 GHCR에 `version tag`와 `latest` tag로 publish합니다.

## 검증 내용

- official `0.9.0.6` source에 `0.9.0.2-8`까지의 GDS hotfix와 2026-06-01 EPUB/TXT/커버 hotfix를 포팅했습니다.
- duplicate manifest EPUB, EPUB `1/1` navigation, TXT fallback cover font, GDS archive per-volume cover regeneration을 포함했습니다.
- GDS EPUB/PDF/TXT scanner shortcut page-count 문제, malformed YAML fallback, single-spine EPUB virtual page regression을 포함했습니다.
- 대형 GDS 강제 스캔의 OOM 완화를 위해 GDS 라이브러리 post-scan 작업을 시리즈 단위 저메모리 직렬 경로로 처리합니다.
- Angular `dist`와 image의 `/kavita/wwwroot`를 정리한 뒤 production UI만 포함했습니다.
- Docker Buildx로 `linux/amd64` 이미지를 생성했습니다.
- `linux/amd64` 이미지는 `kavita-test`와 운영 `kavita` 컨테이너로 기동 검증했습니다.
- `linux/arm64` 이미지는 같은 소스와 prebuilt production UI로 빌드해 GHCR multi-arch manifest에 포함했고, qemu smoke test에서 `/api/health` 200을 확인했습니다.
- `/kavita/wwwroot` 전체에서 `localhost:5000`, `:5000/api`, Angular development mode 문자열이 없는 것을 확인했습니다.
- 제목 기반 TXT fallback cover 생성을 위해 Docker image에 Nanum Gothic Regular/Bold 폰트를 포함했습니다.
- 중간 테스트 이미지와 webtoon patch tree는 배포 패키지에 넣지 않았습니다.
- 큰 binary 파일은 Git repo에 직접 commit하지 않고 GitHub Release asset으로만 배포합니다.

## 제한

- 이 빌드는 공식 Kavita 이미지가 아닙니다.
- `linux/arm64`는 build/manifest 검증 기준이며, native ARM 실서비스 검증은 별도로 수행해야 합니다.
- 기존 Kavita 데이터베이스에 적용하기 전에는 백업을 권장합니다.
