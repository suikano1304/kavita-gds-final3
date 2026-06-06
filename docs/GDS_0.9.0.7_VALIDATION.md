# Kavita-GDS 0.9.0.7 검증 기록

검증일: 2026-06-06

이 문서는 official Kavita `0.9.0.7` nightly 병합 후보에 대해 로컬 Kavita-GDS 검증을 수행한 결과를 기록한다. 검증은 별도 테스트 컨테이너와 테스트 DB 사본으로 진행했으며, 운영 컨테이너는 업그레이드하거나 재시작하지 않았다.

## 범위

- official Kavita `0.9.0.7` nightly 기반 병합 후보 확인.
- GDS 전용 reader 동작과 기존 GDS 회귀 수정 유지 여부 확인.
- Kavita+를 사용하지 않는 운영 가정에서 GDS 외 일반 Book 라이브러리 eligibility가 유지되는지 코드 리뷰.
- 테스트 컨테이너 startup, health, version API, DB integrity, reader API, image API, cover API, post-test log 확인.
- 테스트 컨테이너의 GDS source mount가 read-only인지 확인.
- ARM 계열도 같은 source patch set에서 공식 RID/platform 매핑으로 빌드되어야 한다는 릴리스 조건 확인.

## 결과

확장 검증을 통과했다.

- health endpoint가 HTTP 200을 반환했다.
- plugin version endpoint가 `0.9.0.7`을 반환했다.
- reader/API 검증 전후 SQLite integrity check가 `ok`를 반환했다.
- 최종 검증 실행 중 새 MediaError가 생성되지 않았다.
- 최종 검증 실행 중 새 404, 500, Fatal, SQLite, database-lock, disk I/O error 로그가 발생하지 않았다.

## Reader 검증 범위

대표 GDS 샘플과 로컬 fixture 샘플을 이용해 다음 경로를 확인했다.

- TXT book reader: 긴 텍스트 pagination과 TXT 회귀 fixture.
- ZIP/CBZ 계열 archive image reader: chapter-info, file dimensions, image, thumbnail, negative-page clamp.
- EPUB book reader: 정상 EPUB, 문제 재현 EPUB, navigation 누락 fallback, synthetic single-spine TOC fixture.
- PDF reader: raw PDF serving, PDF extraction metadata, extracted page image rendering.
- TXT, archive, EPUB, PDF에 대한 반복 chapter-info cache 호출.
- cover가 존재하는 대표 샘플의 series cover retrieval.

## 특이사항

- synthetic single-spine EPUB fixture는 실제 콘텐츠가 아니라 TOC page mapping 회귀 검증용 파일이다. cover가 없고 HTML page가 매우 작으므로 cover 생성이나 page size 검증 대상이 아니다.
- navigation 누락 EPUB fixture는 매우 작은 generated wrapper page를 반환할 수 있다. 기대 동작은 book-info, TOC, page API가 정상 응답하는 것이다.
- 테스트 DB 사본의 기존 duplicate path 및 loose image counter는 baseline 데이터로 취급했으며, `0.9.0.7` 병합으로 새로 생긴 항목이 아니다.
- 운영 컨테이너는 검증 중 기존 이미지에 그대로 유지했다.

## ARM 적용 조건

`0.9.0.7`을 릴리스로 승격할 때는 amd64 전용 결과로 마감하지 않는다.

- `linux/amd64`는 .NET RID `linux-x64` publish output을 사용한다.
- `linux/arm64`는 같은 source patch set에서 .NET RID `linux-arm64` publish output을 사용한다.
- `linux/arm/v7`을 포함하는 경우 같은 source patch set에서 .NET RID `linux-arm` publish output을 사용한다.
- Docker build는 official Kavita 방식처럼 `TARGETPLATFORM`에 따라 RID별 runtime output을 선택해야 한다.
- GHCR에는 버전 태그와 `latest`를 multi-arch manifest로 publish한다.
- `linux/arm64`는 qemu 또는 native ARM smoke test에서 `/api/health` 200을 확인한 뒤 manifest에 포함한다.
- `linux/arm/v7`은 qemu 또는 native ARMv7 smoke test에서 `/api/health` 200과 Docker health를 확인한 뒤 manifest에 포함한다.
