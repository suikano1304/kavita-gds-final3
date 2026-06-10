# 빌드 노트

## 목적

Kavita official `0.9.0.7` nightly 기반 GDS scanfix 빌드 `9.0.7-4`를 Docker/GHCR 배포용으로 패키징했습니다.

이 배포는 기존 `0.9.0.2-8`까지의 GDS/rclone 수정, 2026-06-01 테스트 컨테이너/운영 검증에서 확인한 EPUB/TXT/커버 수정, 2026-06-02 scan/page-count 안정화 수정, official Kavita `0.9.0.7` nightly 병합을 포함합니다. 상세 변경 내역은 [CHANGELOG_KO.md](CHANGELOG_KO.md)를 참고하세요.

## 포함 플랫폼

- `linux/amd64`
- `linux/arm64` (GHCR multi-arch manifest)
- `linux/arm/v7` (GHCR multi-arch manifest)

## 산출물

Primary release image:

```text
ghcr.io/suikano1304/kavita-gds:9.0.7-4
ghcr.io/suikano1304/kavita-gds:latest
```

RID package outputs used by Docker buildx:

```text
kavita-linux-x64.tar.gz
kavita-linux-arm64.tar.gz
kavita-linux-arm.tar.gz
```

권장 이미지 태그:

```text
ghcr.io/suikano1304/kavita-gds:9.0.7-4
```

현재 GHCR 기준:

```text
ghcr.io/suikano1304/kavita-gds:9.0.7-4
ghcr.io/suikano1304/kavita-gds:latest
multiarch digest=sha256:789bafd898cd5cc3c01768cf6df57e2513f63a4552ce7b14c35294b3ab263526
linux/amd64=sha256:53dca54bd2f4ff9ea0f2fa433127f71bab2dddbac7b6d5adbd30d010fbbecd9c
linux/arm64=sha256:b4b377b69b4d771129148a34ce12285a4206506ac81cfeaed4b95aaa5634b48e
linux/arm/v7=sha256:8cf0ae274c5c741cec69b7740b97adaa789220eb92a5d5a280758fa109710838
```

GHCR는 Docker buildx `--push`로 직접 publish했습니다.

## 검증 내용

- official `0.9.0.7` nightly source에 `0.9.0.2-8`까지의 GDS hotfix와 2026-06-01 EPUB/TXT/커버 hotfix를 포팅했습니다.
- `9.0.7-4`에는 GDS targeted series scan 후 word-count 분석과 전역 metadata/cache cleanup을 건너뛰는 hotfix를 포함했습니다.
- `9.0.7-3`에는 mixed-root GDS series scan root 축소, mixed-format scan batching, WebUI cover cache-busting을 포함했습니다.
- duplicate manifest EPUB, EPUB `1/1` navigation, TXT fallback cover font, GDS archive per-volume cover regeneration을 포함했습니다.
- GDS EPUB/PDF/TXT scanner shortcut page-count 문제, malformed YAML fallback, single-spine EPUB virtual page regression을 포함했습니다.
- 대형 GDS 강제 스캔의 OOM 완화를 위해 GDS 라이브러리 post-scan 작업을 시리즈 단위 저메모리 직렬 경로로 처리합니다.
- Angular `dist`와 image의 `/kavita/wwwroot`를 정리한 뒤 production UI만 포함했습니다.
- Docker Buildx로 `linux/amd64`, `linux/arm64`, `linux/arm/v7` 이미지를 생성했습니다.
- `linux/amd64` 이미지는 pushed GHCR image를 `kavita-test` 컨테이너로 extended validation했습니다.
- `linux/arm64` 이미지는 같은 소스와 prebuilt production UI로 빌드해 GHCR multi-arch manifest에 포함했고, qemu smoke test에서 `/api/health` 200을 확인했습니다.
- `linux/arm/v7` 이미지는 .NET RID `linux-arm`으로 빌드했고, qemu smoke test에서 host `/api/health` 200을 확인했습니다.
- `linux/arm/v7` qemu startup 안정화를 위해 runtime image에 `DOTNET_EnableWriteXorExecute=0`, `COMPlus_EnableWriteXorExecute=0`을 포함하고 healthcheck start period를 300초로 조정했습니다.
- GHCR `9.0.7-4`와 `latest`는 같은 amd64/arm64/armv7 multi-arch manifest를 가리킵니다.
- `/kavita/wwwroot` 전체에서 `localhost:5000`, `:5000/api`, Angular development mode 문자열이 없는 것을 확인했습니다.
- 제목 기반 TXT fallback cover 생성을 위해 Docker image에 Nanum Gothic Regular/Bold 폰트를 포함했습니다.
- 중간 테스트 이미지와 webtoon patch tree는 배포 패키지에 넣지 않았습니다.
- 큰 binary 파일은 Git repo에 직접 commit하지 않습니다.

## 제한

- 이 빌드는 공식 Kavita 이미지가 아닙니다.
- `linux/arm64`와 `linux/arm/v7`는 qemu smoke 검증 기준이며, native ARM 실서비스 검증은 별도로 수행해야 합니다.
- 기존 Kavita 데이터베이스에 적용하기 전에는 백업을 권장합니다.
