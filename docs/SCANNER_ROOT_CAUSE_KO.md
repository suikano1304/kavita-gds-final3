# Kavita-GDS 스캐너 근본 원인 분석

작성일: 2026-05-31

## 현재 결론

Kavita-GDS의 문제는 단일 버그라기보다, 기존 Kavita 스캐너가 전제하던 모델과 GDS 자료 구조가 맞지 않으면서 생긴 구조적 문제다.

- Kavita 기본 스캐너는 대체로 `시리즈 = 하나의 폴더`, `시리즈 = 하나의 주 포맷`, `파일 변경 = 폴더 mtime 변경`을 전제로 한다.
- GDS 자료는 같은 시리즈 안에 `zip/cbz/pdf/epub/txt/image`가 섞일 수 있고, 파일이 포맷별 하위 폴더에 있거나, `kavita.yaml` 같은 폴더 메타데이터가 별도로 존재한다.
- 이 차이 때문에 스캔 변경 감지, 시리즈 병합, 볼륨/챕터 갱신, 페이지 수 계산, 커버/메타데이터 반영이 서로 다른 방향으로 어긋난다.

## 확인한 운영 증거

운영 컨테이너:

- 컨테이너: `kavita`
- 이미지: `local/kavita-gds:0.9.0.2-1`
- `/mnt/gds` 마운트: 읽기 전용

최근 production-library-d 스캔 로그:

- 강제 스캔: `3004 files / 297 series / 593313 ms`
- 직후 일반 스캔: `171 files / 297 series / 11950 ms`
- DB의 폴더 mtime 비교 기준으로는 production-library-d 297개 시리즈 모두 변경 후보 `0`

즉, 일반 스캔에서 처리된 7개 시리즈는 실제 소스 폴더 변경 때문이 아니라 스캐너 내부 변경 전파 로직 때문에 다시 처리된 것으로 보는 것이 맞다.

전체 DB 정합성 샘플:

| LibraryId | Series | Files | mtime newer | missing folder | duplicate file paths | Pages=0 |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| 1 | 4240 | 40347 | 0 | 0 | 0 | 0 |
| 2 | 1888 | 14061 | 0 | 0 | 0 | 0 |
| 3 | 1144 | 9637 | 0 | 0 | 0 | 0 |
| 4 | 187 | 2261 | 0 | 0 | 10 | 10 |
| 5 | 68 | 162 | 0 | 0 | 13 | 0 |
| 6 | 80 | 564 | 0 | 0 | 0 | 0 |
| 7 | 2061 | 2805 | 0 | 0 | 0 | 0 |
| 8 | 13891 | 63588 | 0 | 0 | 153 | 0 |
| 9 | 297 | 3002 | 0 | 0 | 3 | 39 |

`Pages=0` 중 일부 ZIP 파일은 실제 archive 내부 이미지가 수백 장 존재했다. 따라서 파일 자체가 비어 있거나 깨진 것이 아니라, GDS 최적화 코드가 archive 페이지 수를 계산하지 않아 DB에 0으로 남긴 경우가 있다.

## 원인 1: 변경 상태가 시리즈 단위로 보존되지 않음

파일:

- `Kavita.Services/Scanner/ParseScannedFiles.cs`

현재 문제 코드:

- `CheckSurfaceFiles()`가 전달받은 `hasChanged`를 무시하고 항상 `CreateScanResult(..., true, files)`로 넣는다.
- `CreateFinalSeriesResults()`가 각 시리즈의 변경 여부를 계산할 때 `scanResults.Any(sr => sr.HasChanged)`를 사용한다.

영향:

- 한 폴더나 surface file 하나만 changed로 잡혀도 같은 scan batch 안의 다른 시리즈까지 changed로 전파된다.
- DB mtime상 변경이 없어도 일반 재스캔에서 일부 시리즈가 계속 처리된다.
- 대형 GDS 라이브러리에서는 이 작은 과다 처리도 rclone directory listing, 메타데이터 갱신, 커버 갱신과 겹쳐 체감 속도를 크게 늦춘다.

개선 방향:

- `CheckSurfaceFiles()`는 `hasChanged` 값을 그대로 사용해야 한다.
- `ScannedSeriesResult.HasChanged`는 전체 `scanResults.Any()`가 아니라 해당 시리즈의 `ParserInfo`를 포함한 `ScanResult`들만 대상으로 계산해야 한다.
- 더 안정적으로는 `ParsedSeries` 또는 `SeriesModified`에 `SeriesId`를 포함해 폴더명 충돌 없이 시리즈별 changed state를 전달해야 한다.

## 원인 2: GDS 최적화가 archive 페이지 수까지 0으로 생략함

파일:

- `Kavita.Services/Scanner/ProcessSeries.cs`

현재 동작:

- GDS에서는 hash/page 계산 비용을 줄이기 위해 `skipExpensiveFileStats`를 사용한다.
- `GetFastGdsPageCount()`는 기존 페이지가 있으면 보존하고, `epub/pdf/txt`는 1을 넣지만, archive는 0을 반환한다.

영향:

- 기존 archive 행은 문제가 덜하다. 이미 페이지 수가 있으면 보존된다.
- 새로 생긴 archive 행, 이동된 archive 행, 기존 페이지 수가 0인 행은 계속 `Pages=0`으로 남을 수 있다.
- Image reader는 페이지 수가 0이면 커버/읽기/진행률 계산에서 실패하거나 비정상 동작할 수 있다.

개선 방향:

- GDS에서도 archive는 `readingItemService.GetNumberOfPages()`를 호출해야 한다.
- 다만 `KoreaderHash` 계산은 계속 생략해도 된다. 병목은 전체 파일 hash가 훨씬 크고, ZIP 중앙 디렉터리 기반 페이지 카운트는 상대적으로 비용이 낮다.
- 기존 `Pages=0` archive 행은 재스캔으로 회복되도록, `existingPages <= 0 && format == Archive`일 때도 페이지 수를 다시 계산해야 한다.

## 원인 3: GDS 메타데이터 소스가 운영 소스와 git 소스에 다르게 반영됨

운영 빌드 소스에는 다음 변경이 존재한다.

- `GdsMetadataParser`
- GDS에서 `kavita.yaml`을 `EnableMetadata=false`와 무관하게 보조 메타데이터로 읽는 흐름
- GDS 포맷 하위 폴더명 보정

하지만 `/root/kavita-gds-lab/port-0902-min` git 작업트리에는 이 변경 일부가 아직 없다.

영향:

- 운영 이미지와 git 소스가 완전히 일치하지 않는다.
- 앞으로 GHCR/Release를 다시 만들 때 어느 소스를 기준으로 빌드했는지 흐려질 수 있다.
- 분석/패치가 git에만 들어가면 운영에서 재현되지 않고, 운영 소스에만 들어가면 공유 배포본에서 누락될 수 있다.

개선 방향:

- 운영 빌드 소스와 git 작업트리를 먼저 단일 기준으로 합쳐야 한다.
- 이후 패치는 이 기준 소스에서 만들고, 같은 소스로 운영 이미지와 GHCR 이미지를 빌드해야 한다.

## 원인 4: Kavita의 기본 모델이 GDS를 1급 타입으로 가정하지 않음

이미 일부는 고쳤지만, 구조적 위험은 남아 있다.

- `LibraryType.GDS`는 기존 Kavita에 없던 타입이다.
- reader, 제목 포맷터, 라이브러리 타입 switch, UI pipe, 파일 타입 그룹, 외부 메타데이터 매칭 등 여러 곳에서 명시 처리하지 않으면 런타임 예외가 난다.
- 포맷별 reader는 `MangaFormat`을 기준으로 갈라지지만, 라이브러리 화면/시리즈/챕터 포맷은 `LibraryType`과 섞여 판단된다.

개선 방향:

- GDS를 단순히 Manga/Book 중 하나로 흉내내지 말고, `LibraryType.GDS + MangaFormat.*` 조합을 공식 지원 매트릭스로 정리해야 한다.
- switch/default 예외 지점은 테스트로 막아야 한다.
- GDS mixed-format 시리즈는 series format 하나만 믿지 말고 chapter/file format을 우선해야 한다.

## 우선순위

1. 운영 소스와 git 소스를 동기화한다.
2. `ParseScannedFiles`의 changed propagation을 시리즈 단위로 고친다.
3. GDS archive 페이지 수가 0으로 남지 않게 고친다.
4. 기존 DB의 `Pages=0`, 중복 file path, unknown image row를 읽기 전용 검증 쿼리로 분류한다.
5. 작은 라이브러리에서 일반 재스캔이 `0 files changed` 또는 최소 변경만 남는지 검증한다.
6. production-library-d/웹소설처럼 mixed-format이 많은 라이브러리에서 강제 스캔 후 일반 스캔을 연속 실행해 처리 파일 수가 안정적으로 떨어지는지 확인한다.

## 다음 검증 기준

패치 후에는 최소한 다음이 성립해야 한다.

- 폴더 mtime상 변경 후보가 0인 라이브러리에서 일반 재스캔이 대량의 `Processing series`를 만들지 않는다.
- GDS archive 파일의 신규/이동 DB 행이 `Pages=0`으로 남지 않는다.
- 기존 `Pages=0` archive 행은 force scan 또는 targeted repair로 실제 페이지 수를 회복한다.
- `kavita.yaml`이 있는 폴더는 `EnableMetadata=false` 상태에서도 안전한 로컬 메타데이터를 반영한다.
- 운영 이미지, Release source, git 작업트리의 핵심 scanner 파일이 서로 달라지지 않는다.
