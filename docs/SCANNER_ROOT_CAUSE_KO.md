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
- 이미지 ID: `sha256:7244e110e4f8ab66a1dbd4e85631d51609cc2a09d10c7a2cffa5c2864486ce7d`
- `/mnt/gds` 마운트: 읽기 전용

최근 production-library-d 스캔 로그:

- 강제 스캔: `3004 files / 297 series / 593313 ms`
- 직후 일반 스캔: `171 files / 297 series / 11950 ms`
- DB의 폴더 mtime 비교 기준으로는 production-library-d 297개 시리즈 모두 변경 후보 `0`
- 추가 패치 전 테스트 재스캔: `5 Series / 108 files / 약 7-10초`
- 추가 패치 후 테스트 재스캔: `0 Series / 0 files / 770 ms`

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

2026-05-31 재확인 결과:

- 현재 운영 DB의 `Pages=0` archive는 총 49개다.
- 39개 ZIP은 실제 파일이 존재하고, archive를 열 수 있으며, 내부 이미지가 총 13,301개 있었다. 즉 파일 자체 문제라기보다 기존 DB 행이 아직 회복되지 않은 상태다.
- 10개 CBZ는 실제 파일이 존재하고 archive 자체는 열리지만, 내부가 이미지가 아니라 ZIP 84개로 구성되어 있었다. Kavita의 일반 CBZ 페이지 카운터가 직접 이미지 파일만 페이지로 세는 구조와 맞지 않는다.
- duplicate file path는 179개 path group, 387개 row reference가 남아 있다. 이 중 일부는 같은 파일이 여러 chapter에 매핑된 경우이고, 일부는 같은 파일이 여러 series에 중복 매핑된 경우다.
- cover cache 위험군은 source `cover.*`는 없지만 `_s{id}.jpg/png/webp` cache 이름을 쓰는 GDS series 4,315개로 집계됐다. 이 값은 원본 손상이 아니라, cover 재생성 로직이 config cache를 다시 만들거나 지울 수 있는 범위를 뜻한다.
- duplicate path와 `Pages=0` 잔여 행에는 현재 progress/bookmark/reading list/toc/rating 참조가 붙어 있지 않다. 다만 cross-series duplicate가 많아 일괄 삭제는 아직 위험하다.

핵심 scanner 파일의 현재 git source와 release source tarball SHA256도 일치했다.

| File | SHA256 |
| --- | --- |
| `Kavita.Services/Scanner/ParseScannedFiles.cs` | `4c3510143f0bb1eea8de5d965e556bc44e6110ecb952ae901f487c85fb507c62` |
| `Kavita.Services/Scanner/ProcessSeries.cs` | `55f39bdced66bde06774d2a5a9f83610fe2d67a7b7f274873fd91a0b1ae27d` |
| `Kavita.Services/Helpers/GdsMetadataParser.cs` | `ece6dc3db07778ff980fa10acb5dfb54a70403100f65e9f39b0da3ae17e28db5` |
| `Kavita.Services/Reading/ReadingItemService.cs` | `24228b4e06aec3d18ac93ea8a12cb7d57695f460905531ff89b237f4e648922f` |

읽기 전용 재현 도구:

```bash
python3 scripts/diagnose_kavita_gds.py \
  --db /mnt/data/docker/kavita/config/kavita.db \
  --container-root /mnt/gds \
  --host-root /mnt/data/rclone/gds \
  --check-archives \
  --check-covers
```

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

적용한 추가 보정:

- surface file 처리 시 전달받은 `hasChanged`를 유지한다.
- 최종 `ScannedSeriesResult.HasChanged`는 전체 scan batch가 아니라 해당 시리즈의 `ParserInfo`가 들어 있는 scan result만 보고 계산한다.
- GDS 포맷 하위 폴더와 정규화명이 같은 형제 폴더는 기존 시리즈 경로맵으로 안전하게 매칭한다.
- 변경 없음으로 처리된 폴더의 fake `ParserInfo` 생성도 직접 dictionary index 대신 fallback lookup을 사용한다.

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

적용한 보정:

- `GetGdsPageCount()`는 기존 페이지 수가 1 이상이면 보존한다.
- GDS archive에서 기존 페이지 수가 0이면 `readingItemService.GetNumberOfPages()`를 호출한다.
- EPUB/PDF/TXT는 기존처럼 빠른 스캔에서 1로 처리한다.

남은 제약:

- 변경 감지가 완전히 skip한 series는 `AddOrUpdateFileForChapter()`까지 들어오지 않으므로 기존 `Pages=0` DB 행은 일반 스캔만으로 회복되지 않을 수 있다.
- 내부에 이미지가 아니라 nested ZIP만 들어 있는 CBZ는 archive reader가 지원하지 않는 구조다. 이 경우는 scanner bug가 아니라 자료 구조 변환 또는 nested archive 지원이 필요한 영역이다.

## 원인 3: GDS 메타데이터 소스가 운영 소스와 git 소스에 다르게 반영됨

초기에는 운영 빌드 소스와 git 작업트리가 어긋날 위험이 있었다. 현재 기준으로는 다음 변경이 git source와 release source tarball에 모두 들어 있다.

- `GdsMetadataParser`
- GDS에서 `kavita.yaml`을 `EnableMetadata=false`와 무관하게 보조 메타데이터로 읽는 흐름
- GDS 포맷 하위 폴더명 보정
- GDS archive `Pages=0` 회복 로직
- GDS scan changed propagation 보정

현재 상태:

- 운영 이미지: `local/kavita-gds:0.9.0.2-1`
- source branch: `codex/gds-light-novel-scan-fixes`
- release candidate: `0.9.0.2-3`
- public GHCR: `ghcr.io/suikano1304/kavita-gds:0.9.0.2-3`, `latest`

남은 운영 원칙:

- 이후 패치는 반드시 같은 source branch에서 만들고, 같은 source tarball로 운영 이미지와 GHCR 이미지를 빌드해야 한다.
- 운영 hotfix만 따로 만들 경우 release source와 실제 운영 image가 다시 갈라지므로 금지한다.

## 원인 4: Kavita의 기본 모델이 GDS를 1급 타입으로 가정하지 않음

이미 일부는 고쳤지만, 구조적 위험은 남아 있다.

- `LibraryType.GDS`는 기존 Kavita에 없던 타입이다.
- reader, 제목 포맷터, 라이브러리 타입 switch, UI pipe, 파일 타입 그룹, 외부 메타데이터 매칭 등 여러 곳에서 명시 처리하지 않으면 런타임 예외가 난다.
- 포맷별 reader는 `MangaFormat`을 기준으로 갈라지지만, 라이브러리 화면/시리즈/챕터 포맷은 `LibraryType`과 섞여 판단된다.
- 실제로 `UI/Web/src/app/_services/entity-title.service.ts`는 `LibraryType.GDS` case가 빠져 있어 `app-entity-title` 기반 화면에서 GDS 볼륨/회차명이 빈 문자열로 표시될 수 있었다.

개선 방향:

- GDS를 단순히 Manga/Book 중 하나로 흉내내지 말고, `LibraryType.GDS + MangaFormat.*` 조합을 공식 지원 매트릭스로 정리해야 한다.
- switch/default 예외 지점은 테스트로 막아야 한다.
- GDS mixed-format 시리즈는 series format 하나만 믿지 말고 chapter/file format을 우선해야 한다.

적용한 보정:

- source branch에서 `LibraryType.GDS`를 Manga 제목 렌더링 경로로 태우도록 패치했다.
- source commit: `7e0279e fix: render GDS entity titles`
- 이 패치는 `0.9.0.2-2` 배포 후보 이미지와 source tarball에 포함했다.

## 원인 5: 회차 제목과 파일명 제목이 Kavita 내부에서 다른 필드로 분리됨

파일:

- `Kavita.Services/Scanner/GdsParser.cs`
- `Kavita.Services/Extensions/ChapterExtensions.cs`
- `Kavita.Services/Scanner/ProcessSeries.cs`

현재 구조:

- `GdsParser`는 파일명 기반 제목을 `ParserInfo.Title`에 넣는다.
- `ChapterExtensions.UpdateFrom()`은 일반 chapter에서는 `chapter.Title`을 `chapter.Range` 기반 숫자/범위로 되돌린다.
- `UpdateChapterFromComicInfo()`는 `ComicInfo.Title`을 `chapter.TitleName`에 넣는다.

영향:

- 사용자가 UI에서 보는 “회차명”이 어느 컴포넌트에서 `Title`, `TitleName`, `Range` 중 무엇을 쓰는지에 따라 다르게 보인다.
- 파일명 기반 부제는 `TitleName`에는 들어갈 수 있지만, `Title`이 숫자/범위로 다시 정리되면 기대한 표시와 다를 수 있다.
- `meta.Name`을 그대로 쓰면 시리즈명 또는 회차명이 덮여 회차 정보가 사라질 수 있어서, 현재 GDS YAML parser는 `meta.Name`을 의도적으로 반영하지 않는다.

개선 방향:

- GDS에서는 파일명 기반 표시명을 `TitleName`에 안정적으로 넣는 현재 방향이 맞다.
- UI/DTO에서는 GDS를 Manga 계열 제목 계산에 포함해 `TitleName`을 우선 표시해야 한다.
- 특정 파일명 정규화 규칙은 parser가 아니라 GDS sidecar metadata/parser 보정 계층에 묶어야 한다.

## 원인 5-1: duplicate file path는 기존 중복 chapter/series를 자동 청소하지 못함

파일:

- `Kavita.Services/Extensions/ChapterListExtensions.cs`
- `Kavita.Services/Scanner/ProcessSeries.cs`

현재 구조:

- `GetChapterByRange()`는 먼저 chapter `Range`로 기존 chapter를 찾는다.
- 같은 파일 경로가 다른 chapter에 이미 있는지 확인하는 fallback은 `chapter == null`일 때만 실행된다.
- 기존 DB에 같은 `Range`를 가진 중복 chapter가 이미 있으면 첫 번째 chapter만 갱신되고, 나머지 중복 chapter는 파일이 존재하는 한 cleanup 대상에서 빠질 수 있다.

운영 DB 구조:

| Pattern | Groups |
| --- | ---: |
| same series / same volume / 3 chapters / 1 range / same pages | 17 |
| same series / same volume / 4 chapters / 1 range / same pages | 6 |
| two series / two volumes / two chapters / 1 range / same pages | 94 |
| two series / two volumes / two chapters / 1 range / different pages | 1 |
| two series / two volumes / two chapters / 2 ranges / same pages | 2 |
| two series / two volumes / two chapters / 2 ranges / different pages | 56 |
| same series / same volume / 2 chapters / 1 range / different pages | 3 |

사용자 데이터 참조:

- duplicate path group 중 progress/bookmark/reading list/toc/rating이 붙은 group은 0개였다.
- same series / same volume / same range / 사용자 데이터 없음 조건을 만족하는 group은 26개다.
- cross-series duplicate는 153개 group이다. 사용자 데이터 참조는 없지만, 자동 삭제하면 series 분류 자체가 바뀔 수 있다.

영향:

- scanner가 새 중복을 만들지 않더라도, 이미 DB에 생긴 duplicate rows는 자동으로 사라지지 않는다.
- 같은 파일이 여러 series에 걸친 경우는 단순 dedupe로 지우면 사용자가 의도한 분류를 깨뜨릴 수 있다.
- 같은 series/volume/range 안의 duplicate는 DB repair 후보지만, reading progress와 chapter metadata 연결을 확인해야 한다.

개선 방향:

- 자동 삭제보다 read-only report를 먼저 기준으로 삼는다.
- same series/same volume/same range duplicate만 별도 repair 대상으로 분리한다.
- cross-series duplicate는 parser/폴더 구조 문제인지, 실제로 같은 파일을 여러 라이브러리/시리즈에서 공유하는 의도된 구조인지 구분해야 한다.

## 원인 6: cover cache는 원본 메타데이터와 Kavita config cache 사이에 있음

파일:

- `Kavita.Services/MetadataService.cs`

현재 구조:

- GDS 원본의 `cover.jpg`, `cover.png`, `cover.webp` 또는 `kavita.yaml` base64 cover를 읽는다.
- 실제 UI cover는 Kavita config의 `covers` 디렉터리에 복사/생성된 cache 파일을 본다.
- GDS 원본은 읽기 전용이어도 config cache는 쓰기 대상이다.

영향:

- 운영 config 폴더를 정리하거나 이름을 바꾸면 DB는 살아 있어도 cover cache 파일이 사라질 수 있다.
- 원본 cover가 없고 기존 `_s{id}.jpg/png/webp` cache만 남은 경우, GDS folder cover 경로는 stale cache를 삭제할 수 있다.
- 따라서 “GDS가 읽기 전용이라 안전하다”와 “Kavita config cache가 안전하다”는 별개다.

개선 방향:

- config/covers는 DB와 같이 백업해야 한다.
- folder cover가 없는 경우 기존 cache 삭제가 필요한지, fallback cover 생성을 방해하지 않는지 추가 검토가 필요하다. 현재 운영 DB 기준 위험군은 4,315개 series다.
- cover 재생성은 원본 파일을 수정하지 않지만 config에는 대량 쓰기를 만들 수 있으므로 스캔과 분리해서 실행하는 편이 안전하다.

적용한 보정:

- source branch에서 source `cover.*`가 없을 때 기존 config cache 파일을 삭제하지 않도록 패치했다.
- source commit: `77fa01f fix: preserve GDS cover cache fallback`
- C# build 검증: `dotnet build Kavita.Server/Kavita.Server.csproj` 성공, 480 warnings, 0 errors.
- 이 패치는 `0.9.0.2-2` 배포 후보 이미지와 source tarball에 포함했다.

## 원인 6-1: TXT 파일은 자체 cover extraction 대상이 아님

파일:

- `Kavita.Services/Reading/ReadingItemService.cs`
- `Kavita.Services/MetadataService.cs`
- `Kavita.Services/Helpers/GdsMetadataParser.cs`

현재 구조:

- TXT는 페이지 수 계산은 `BookService.GetNumberOfPagesText()`를 타지만, cover 추출은 `ReadingItemService.GetCoverImage()`의 switch에서 처리되지 않는다.
- EPUB/PDF는 `BookService.GetCoverImage()`로 표지 이미지를 추출할 수 있지만, TXT는 파일 내부에서 추출할 표지가 없으므로 빈 cover가 정상 결과다.
- GDS에서는 TXT 자체보다 폴더 `cover.jpg/png/webp` 또는 `kavita.yaml`의 base64 cover가 권위 있는 커버 소스다.
- `cover: TEXT`는 이미지가 아니라 텍스트 자료 표식이므로 cover 후보로 취급하면 안 된다.

운영 DB 기준 TXT 커버 상태:

| LibraryId | Library | TXT series | TXT files | config cover series | yaml base64 | yaml TEXT marker | source cover file | no usable cover hint |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| <redacted> | production-library-a | 1 | 1 | 1 | 0 | 1 | 0 | 0 |
| <redacted> | production-library-b | 80 | 84 | 80 | 1 | 79 | 79 | 0 |
| <redacted> | production-library-e | 2061 | 2805 | 0 | 0 | 2061 | 0 | 2061 |
| <redacted> | production-library-c | 3548 | 3548 | 3544 | 3540 | 0 | 1 | 4 |
| <redacted> | production-library-d | 25 | 125 | 25 | 24 | 1 | 0 | 0 |

해석:

- TXT에 cover가 없다는 것은 파일 오류가 아니다.
- production-library-e의 `kavita.yaml`은 `cover: TEXT`라서 이미지 커버가 아니다.
- 진짜로 사용 가능한 원본 cover 후보가 없는 TXT series는 production-library-e 기준 2,061개다.

개선 방향:

- 우선순위는 기존 config cover cache, folder `cover.*`, `kavita.yaml` base64 cover 순으로 유지한다.
- 위 세 가지가 모두 없으면 스캔 오류를 만들지 않고 GDS/TXT 전용 deterministic title-cover를 Kavita config `covers` 디렉터리에 생성한다.
- title-cover를 만들더라도 GDS 원본에는 쓰지 않고, 외부 이미지 다운로드도 하지 않는다.
- title-cover 생성은 source cover가 나중에 생기면 source cover가 다시 이기도록 fallback으로만 동작해야 한다.
- 진단 스크립트의 `--check-covers` 출력에서 `txt cover state`를 보고, `series_without_any_cover_hint`만 수동 큐레이션 또는 fallback 생성 대상으로 삼는다.
- 한글 제목 렌더링을 위해 Docker image에 Nanum Gothic TTF를 포함해야 한다.

적용한 보정:

- `cover: TEXT`와 URL 값을 base64 cover로 오인하지 않도록 source branch에서 `GdsMetadataParser`를 보정했다.
- GDS/TXT에서 folder cover와 YAML base64 cover가 없을 때 제목 기반 cover를 생성하도록 source branch에서 fallback을 추가했다.
- 생성 cover는 Kavita config `covers`에만 저장되고 GDS 원본에는 쓰지 않는다.
- Dockerfile에 Nanum Gothic 폰트를 포함해 한글 제목이 네모 박스로 렌더링되지 않도록 했다.
- C# build 검증: `dotnet build Kavita.Server/Kavita.Server.csproj` 성공, 481 warnings, 0 errors.
- 런타임 스모크 검증: 제목 기반 PNG 생성 성공, Nanum Gothic 사용 시 한글 제목 렌더링 확인.
- 이 패치는 `0.9.0.2-2` 배포 후보 이미지와 source tarball에 포함했다.

## 원인 7: `Pages=0` 잔여 행은 일반 스캔에서 복구되지 않을 수 있음

파일:

- `Kavita.Services/Scanner/ParseScannedFiles.cs`
- `Kavita.Services/Scanner/ProcessSeries.cs`
- `Kavita.Database/Repositories/SeriesRepository.cs`

현재 구조:

- GDS 일반 library scan은 폴더 mtime이 기존 `LastScanned`보다 오래되면 실제 파일 목록을 다시 읽지 않고, 기존 series 정보를 기반으로 fake `ParserInfo`만 만든다.
- 이 최적화는 정상 상태에서는 빠른 재스캔에 필요하지만, DB에 이미 `Pages=0` 같은 scan debt가 남아 있으면 해당 파일을 다시 열 기회도 같이 사라진다.
- 운영 DB 기준 `Pages=0` archive는 두 라이브러리에만 남아 있다.

운영 DB 기준:

| LibraryId | Library | Ext | Pages=0 files | Archive readable | Direct images | Nested archives |
| --- | --- | --- | ---: | ---: | ---: | ---: |
| <redacted> | production-library-a | cbz | 10 | 10 | 0 | 84 |
| <redacted> | production-library-d | zip | 39 | 39 | 13,301 | 0 |

해석:

- Library 4의 잔여 CBZ는 직접 이미지가 아니라 nested archive 중심이라 Kavita의 archive page counter 기준으로 `Pages=0`이 자연스러운 케이스다.
- Library 9의 잔여 ZIP은 archive 자체가 읽히고 직접 이미지도 있으므로 파일 손상보다는 기존 DB row가 최적화 때문에 재분석되지 않은 상태로 보는 것이 맞다.
- 전체 `Pages=0` 중 duplicate path와 직접 겹치는 것은 3 row뿐이라, 모든 `Pages=0`을 중복 row 문제로 단정하면 안 된다.

적용한 보정:

- source branch에서 `SeriesModified`에 `HasZeroPageFiles`를 추가했다.
- GDS series에 `Pages=0` 파일이 하나라도 있으면 `HasSeriesFolderNotChangedSinceLastScan()`이 변경 없음으로 처리하지 않고 실제 scan path를 타도록 했다.
- C# build 검증: `dotnet build Kavita.Server/Kavita.Server.csproj` 성공, 481 warnings, 0 errors.
- 이 패치는 `0.9.0.2-2` 배포 후보 이미지와 source tarball에 포함했다.

## 원인 8: startup migration 실패가 BaseUrl 저장 FK 오류처럼 보일 수 있음

제보 증상:

```text
Microsoft.Data.Sqlite.SqliteException: SQLite Error 19: 'FOREIGN KEY constraint failed'
Kavita.Server.Startup.Configure(...) Startup.cs:line 289
```

해석:

- 해당 line은 운영 설정의 BaseUrl을 `ServerSetting`에 저장하는 코드였다.
- BaseUrl 저장 자체가 외래키를 직접 건드리지는 않는다.
- 더 가능성이 높은 경로는 startup manual migration 중 FK 오류가 먼저 발생했지만, 기존 코드가 migration 예외를 catch 후 계속 진행하면서 같은 EF context 또는 pooled context에 실패한 변경 상태가 남고, 이후 BaseUrl `SaveChanges()`에서 다시 표면화되는 경우다.
- x86 NAS에서는 같은 이미지가 정상 기동되고 Oracle 쪽에서만 발생했다면, CPU 아키텍처 자체보다는 Oracle 서버의 기존 DB 상태, 기존 컨테이너와 새 컨테이너의 동시 접근, 또는 이전 이미지에서 생성된 특정 migration 상태 차이를 먼저 의심해야 한다.
- 실제 DB 자체에 영구 FK 위반이 있는지는 `PRAGMA foreign_key_check;`로 확인해야 한다.

적용한 보정:

- startup migration은 별도 DI scope에서 실행하고, BaseUrl 저장도 별도 DI scope에서 실행하도록 분리했다.
- migration 예외를 더 이상 삼키지 않고 rethrow해 실제 실패 지점이 로그에 남도록 했다.
- BaseUrl 저장에서 `DbUpdateException`이 발생하면 `PRAGMA foreign_key_check` 일부 결과를 로그에 남기도록 했다.
- source commit: `6fa0173 fix: stabilize GDS startup and cleanup`
- C# build 검증: `dotnet build Kavita.Server/Kavita.Server.csproj` 성공, 481 warnings, 0 errors.
- 이 패치는 `0.9.0.2-3` 배포 후보 이미지와 source tarball에 포함했다.

운영자 진단 명령:

```bash
sqlite3 /path/to/kavita.db 'PRAGMA integrity_check;'
sqlite3 /path/to/kavita.db 'PRAGMA foreign_key_check;'
```

## 원인 9: same-volume duplicate file path는 스캔 cleanup에서 살아남을 수 있음

현재 구조:

- 같은 volume 안에서 같은 파일 경로가 여러 chapter에 붙어 있어도, 기존 cleanup은 “현재 스캔 결과에 존재하는 파일 경로”이면 각 chapter의 파일을 계속 보존할 수 있었다.
- 운영 DB 기준 same-series/same-volume duplicate group은 일부 라이브러리에 남아 있으며, 같은 range와 같은 page 값이면 사용자가 보기에는 중복 chapter로 보일 수 있다.

적용한 보정:

- 같은 volume cleanup 중 이번 스캔에서 선택된 chapter만 해당 normalized file path를 보존하도록 했다.
- cross-series duplicate는 자료 구조 의도일 수 있어 자동 정리하지 않는다.
- source commit: `6fa0173 fix: stabilize GDS startup and cleanup`
- source commit: `40ec52d fix: prefer scanned GDS duplicate target`
- C# build 검증: `dotnet build Kavita.Server/Kavita.Server.csproj` 성공, 481 warnings, 0 errors.
- 이 패치는 `0.9.0.2-3` 배포 후보 이미지와 source tarball에 포함했다.

## 우선순위

1. `ParseScannedFiles`의 changed propagation을 시리즈 단위로 고친다. 완료 및 운영 반영.
2. GDS archive 페이지 수가 0으로 남지 않게 고친다. 신규/변경 파일 보정 완료, 기존 DB scan debt 재분석 트리거는 `0.9.0.2-2` 이후 배포 후보에 포함.
3. 운영 source, release source, GitHub 배포 source를 같은 기준으로 맞춘다. 완료.
4. 기존 DB의 `Pages=0`, duplicate file path, media error를 읽기 전용 검증 쿼리로 분류한다. 1차 완료.
5. GDS UI 제목 표시 누락과 cover cache 삭제 방어를 `0.9.0.2-2` 배포 후보에 포함한다. 완료.
6. TXT no-cover는 오류로 처리하지 않고, YAML/base64 cover 반영 누락과 실제 no-cover fallback을 분리한다. 완료.
7. same series/same volume/same range duplicate group은 cleanup patch를 `0.9.0.2-3`에 포함했고, 운영 재스캔 후 감소 여부를 확인한다.
8. cross-series duplicate 153개 group과 nested archive는 자동 수정하지 말고 자료 구조/분류 의도를 먼저 확인한다.

## 다음 검증 기준

패치 후에는 최소한 다음이 성립해야 한다.

- 폴더 mtime상 변경 후보가 0인 라이브러리에서 일반 재스캔이 대량의 `Processing series`를 만들지 않는다.
- GDS archive 파일의 신규/이동 DB 행이 `Pages=0`으로 남지 않는다.
- 기존 `Pages=0` archive 행은 force scan 또는 targeted repair로 실제 페이지 수를 회복한다. nested archive는 별도 처리한다.
- `kavita.yaml`이 있는 폴더는 `EnableMetadata=false` 상태에서도 안전한 로컬 메타데이터를 반영한다.
- 운영 이미지, Release source, git 작업트리의 핵심 scanner 파일이 서로 달라지지 않는다.
- duplicate path group이 추가 스캔 후 늘어나지 않는다.
- cover cache 재생성은 원본 GDS 경로가 아니라 Kavita config 경로에만 쓰기를 만든다.
- source `cover.*`가 없는 series라도 기존 config cover cache를 삭제하지 않는다.
- TXT series는 source cover가 없어도 스캔 오류로 남기지 않고, YAML/base64 또는 fallback cover 정책으로 일관되게 표시한다.
