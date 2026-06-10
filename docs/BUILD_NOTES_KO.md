# 빌드 노트

## 목적

Kavita official `0.9.0.7` nightly 기반 GDS scanfix 빌드 `9.0.7-5`를 Docker/GHCR 배포용으로 패키징했습니다.

이 배포는 기존 `0.9.0.2-8`까지의 GDS/rclone 수정, 2026-06-01 테스트 컨테이너/운영 검증에서 확인한 EPUB/TXT/커버 수정, 2026-06-02 scan/page-count 안정화 수정, official Kavita `0.9.0.7` nightly 병합을 포함합니다. 상세 변경 내역은 [CHANGELOG_KO.md](CHANGELOG_KO.md)를 참고하세요.

## 포함 플랫폼

- `linux/amd64`
- `linux/arm64` (GHCR multi-arch manifest)
- `linux/arm/v7` (GHCR multi-arch manifest)

## 산출물

Primary release image:

```text
ghcr.io/suikano1304/kavita-gds:9.0.7-5
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
ghcr.io/suikano1304/kavita-gds:9.0.7-5
```

현재 GHCR 기준:

```text
ghcr.io/suikano1304/kavita-gds:9.0.7-5
ghcr.io/suikano1304/kavita-gds:latest
multiarch digest=sha256:65c7eaed1dc6a21a39c1819f71276c26f748556303e1af904818817be5dfd780
linux/amd64=sha256:7bc92d3c3aaf63c4e7b9acd23c54215ef8ca4641de5b612fa0f327fec5a2e227
linux/arm64=sha256:f9fcf0d95d81325547b380a6ecb1e24b4b369f01d75f7070421dadef2c4f73e4
linux/arm/v7=sha256:6f2bfe3c5ab6069bcd6af7dc1260ebb927d091989031d963825cea8bb63756ba
```

GHCR는 Docker buildx `--push`로 직접 publish했습니다.

## 검증 내용

- official `0.9.0.7` nightly source에 `0.9.0.2-8`까지의 GDS hotfix와 2026-06-01 EPUB/TXT/커버 hotfix를 포팅했습니다.
- `9.0.7-5`에는 duplicate broken/valid EPUB row에서 readable EPUB row를 우선 선택하는 reader/cache hotfix를 포함했습니다.
- `9.0.7-4`의 GDS targeted series scan 후 word-count 분석과 전역 metadata/cache cleanup을 건너뛰는 hotfix를 유지했습니다.
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
- GHCR `9.0.7-5`와 `latest`는 같은 amd64/arm64/armv7 multi-arch manifest를 가리킵니다.
- `/kavita/wwwroot` 전체에서 `localhost:5000`, `:5000/api`, Angular development mode 문자열이 없는 것을 확인했습니다.
- 제목 기반 TXT fallback cover 생성을 위해 Docker image에 Nanum Gothic Regular/Bold 폰트를 포함했습니다.
- 중간 테스트 이미지와 webtoon patch tree는 배포 패키지에 넣지 않았습니다.
- 큰 binary 파일은 Git repo에 직접 commit하지 않습니다.

## 제한

- 이 빌드는 공식 Kavita 이미지가 아닙니다.
- `linux/arm64`와 `linux/arm/v7`는 qemu smoke 검증 기준이며, native ARM 실서비스 검증은 별도로 수행해야 합니다.
- 기존 Kavita 데이터베이스에 적용하기 전에는 백업을 권장합니다.
