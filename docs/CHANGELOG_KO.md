# 변경 내역

기준 버전: `kavita-gds-0.9.0.2-scan-20260528`

현재 배포 후보: `kavita-gds-0.9.0.2-3`

## 2026-05-31: startup FK 진단 및 duplicate cleanup

아래 변경은 `0.9.0.2-3` 배포 후보에 포함했습니다.

- 일부 기존 DB에서 startup migration 실패 뒤 BaseUrl 저장 단계가 `SQLite Error 19: FOREIGN KEY constraint failed`로 보이는 문제를 분석했습니다.
- BaseUrl 저장은 별도 EF scope에서 수행하도록 분리해, migration 단계의 실패한 tracked change가 startup 후속 저장에 섞이지 않도록 했습니다.
- startup migration에서 예외가 발생하면 더 이상 삼키고 계속 진행하지 않고, 원래 migration 예외를 그대로 드러내도록 했습니다.
- BaseUrl 저장에서 `DbUpdateException`이 발생하면 `PRAGMA foreign_key_check` 결과 일부를 로그에 남기도록 했습니다.
- 같은 volume 안에서 같은 파일 경로가 여러 chapter에 남은 경우, 이번 스캔에서 선택된 chapter만 보존하도록 cleanup을 보강했습니다.
- 읽기 전용 진단 스크립트가 `PRAGMA foreign_key_check`와 duplicate file path cleanup 후보 분류를 출력하도록 확장했습니다.
- C# backend build, UI production build, multi-arch OCI build, `linux/amd64` startup smoke test를 통과했습니다.
- `linux/arm64` 이미지는 QEMU 환경에서 entrypoint smoke test를 완료했습니다. Native ARM 서버에서는 기존 DB 상태 확인을 함께 권장합니다.

## 2026-05-31: GDS TXT fallback cover 및 scan debt 회복

아래 변경은 source branch와 `0.9.0.2-2` 배포 후보에 포함했습니다.

- GDS 라이브러리 타입이 UI entity title 계산에서 빠져 일부 화면의 볼륨/회차명이 빈 문자열로 표시될 수 있던 문제를 보정했습니다.
- GDS 원본 `cover.*`가 없을 때 기존 Kavita config cover cache 파일을 삭제하지 않도록 보정했습니다.
- GDS TXT에서 `cover: TEXT`를 이미지 base64로 오인하지 않도록 보정했습니다.
- 원본 커버와 YAML 이미지가 모두 없는 GDS TXT 시리즈는 제목 기반 cover를 Kavita config `covers` 디렉터리에 자동 생성하도록 했습니다.
- 제목 기반 cover는 외부 API나 외부 이미지 다운로드를 사용하지 않습니다.
- 제목 기반 cover의 한글 렌더링을 위해 Docker image에 Nanum Gothic 폰트를 포함했습니다.
- GDS 시리즈에 `Pages=0` 파일이 남아 있으면 폴더 변경 없음 최적화를 건너뛰고 실제 파일 목록을 다시 파싱하도록 했습니다.
- C# backend build, UI production build, `linux/amd64` runtime smoke test, `linux/amd64`/`linux/arm64` OCI manifest 검증을 완료했습니다.

## 2026-05-31: GDS 증분 스캔 안정화 추가

- GDS 라이브러리에서 포맷 하위 폴더가 실제 시리즈 폴더 바로 아래에 있을 때, DB 경로맵에 현재 폴더가 없더라도 부모 시리즈의 변경 상태를 안전하게 재사용하도록 했습니다.
- 변경 없음으로 판단된 폴더를 파싱할 때 현재 폴더 키만 직접 조회하지 않고, 기존 시리즈 경로 또는 GDS 폴더명 fallback으로 안전하게 매칭합니다.
- 같은 시리즈가 정규화명은 같지만 물리 폴더명이 조금 다른 형제 폴더로 나뉜 경우, 폴더명 정규화값을 기존 시리즈명과 비교해 반복 재처리를 줄였습니다.
- 테스트 컨테이너 검증 기준, 문제 라이브러리의 반복 일반 재스캔이 `5 Series / 108 files / 약 7-10초`에서 `0 Series / 0 files / 약 0.8초`로 안정화됐습니다.
- EPUB 단어 수 계산 단계에서 손상되었거나 EPUB 구조가 아닌 파일은 기존처럼 오류로 기록되지만, 스캔 자체는 정상 완료됩니다.

## 2026-05-31: production-library-d 혼합 폴더/읽기 불가 보정

- GDS 라이브러리의 `chapter-info` 처리에서 `LibraryType.GDS`가 누락되어 일부 PDF/EPUB 라우팅이 예외로 이어질 수 있던 문제를 보정했습니다.
- GDS 빠른 스캔에서 EPUB/PDF/TXT의 페이지 수 계산을 생략하더라도 최소 `Pages=1`을 유지해 “읽을 수 없음”처럼 보이지 않도록 했습니다.
- 같은 작품이 `작품명/`과 `작품명 -/`처럼 두 폴더로 나뉜 경우, 증분 스캔 입력에 한쪽 폴더만 들어와도 실제 파일이 존재하는 기존 GDS 볼륨은 제거하지 않도록 했습니다.
- `force=true` GDS 스캔은 누락 파일 복구를 위해 실제 파일시스템을 다시 읽도록 했습니다. 이 모드는 느리지만, 증분 스캔에서 누락된 EPUB/PDF/TXT 복구에 필요합니다.
- 운영 검증 기준 분리 폴더 production-library-d 샘플은 ZIP 3개와 EPUB 5개, 총 8개 파일이 유지되고 EPUB 1권이 정상 열리는 것을 확인했습니다.
- 이후 일반 production-library-d 재스캔은 `171 files / 297 series`를 약 12초에 완료했고, EPUB 5개가 다시 제거되지 않는 것을 확인했습니다.

## 2026-05-31: GDS 재스캔 속도 개선

- GDS 강제 스캔에서 변경 없는 파일의 page count와 KOReader hash를 다시 계산하지 않도록 조정했습니다.
- 일반 GDS/rclone 재스캔에서 변경 없는 파일의 불필요한 재계산을 줄였습니다.
- `[Cover].jpg`처럼 대괄호가 붙은 커버 파일이 GDS 이미지 미디어로 오인식되어 스캔 오류와 지연을 만드는 문제를 막았습니다.
- 폴더 커버가 이미 Kavita config cover 디렉터리에 있고 색상 정보도 있는 경우, 반복 스캔에서 커버 복사/색상 분석을 건너뜁니다.
- 실제 운영 검증 기준 `production-library-a` 강제 스캔은 3분 이상 진행되던 상태에서 `11 files / 187 series`를 약 2.8초에 완료했습니다.
- `production-library-e` 강제 스캔도 `2 files / 2061 series`를 약 4.5초에 완료했습니다.
- loose image 폴더를 쓰지 않는 기존 GDS 라이브러리는 `Images` 파일 그룹을 꺼서 불필요한 커버 이미지 열거를 줄였습니다. `production-library-d`처럼 실제 이미지 파일이 등록된 라이브러리는 유지했습니다.

## 2026-05-31: 운영 검증 및 YAML metadata fix

- 운영 Kavita config를 일반 경로(`/mnt/data/docker/kavita/config`)로 정리하고 compose mount를 확인했습니다.
- 남아 있던 config/test config의 cover 파일을 운영 config로 회수하고, 스캔을 통해 cover cache가 다시 생성되는 것을 확인했습니다.
- GDS 라이브러리에서 `kavita.yaml`/`kavita.yml` sidecar metadata를 읽도록 보강했습니다.
- `Summary`, 장르, 태그, 언어, 웹 링크, 작가/번역자/출판사/작화가, 발매일, 연령등급 등 안전한 YAML 필드를 반영합니다.
- YAML `meta.Name`이 시리즈명 또는 회차 제목을 덮어써 회차 정보가 사라지는 문제를 막았습니다.
- GDS 회차 제목은 파일명에서 만들고 `#138`, `[1440px]`, `[직스샷]`, trailing `(리디)` 같은 배포/품질 태그를 제거합니다.
- 출판사/분류 접두가 붙은 폴더에서도 중복 시리즈가 새로 생기지 않는 것을 확인했습니다.
- 상세 운영 기록은 `docs/OPERATIONS_20260531_KO.md`에 남겼습니다.

## 2026-05-30: universal packaging

- `linux/amd64`, `linux/arm64`를 하나의 OCI archive로 패키징했습니다.
- x86 서버와 Oracle Cloud A1 같은 arm64 서버에서 같은 release asset을 사용할 수 있습니다.
- 중간 테스트 이미지와 webtoon patch tree는 제외하고 scanfix 기준으로만 배포했습니다.
- GitHub Release asset을 GHCR 이미지로 publish하는 workflow를 추가해 `docker pull` 기반 배포가 가능하도록 했습니다.

## 2026-05-30: GDS scanfix

- `LibraryType.GDS` reader/runtime 오류를 수정했습니다.
- GDS 스캔 시 같은 작품 폴더 안의 서로 다른 포맷이 별도 시리즈로 갈라지는 문제를 줄였습니다.
- `kavita.yaml`, `kavita.yml`, `cover.*` 같은 메타데이터 파일이 미디어 파일로 등록되지 않도록 했습니다.
- `웹소설` 경로의 loose `.jpg` 이미지가 권/시리즈로 잘못 등록되는 문제를 방지했습니다.
- GDS 스캔 중 누락 파일 정리 로직이 원본 파일 삭제/정리로 이어지지 않도록 DB 보존 방어를 추가했습니다.
- GDS 폴더/sidecar 커버는 Kavita config cover 디렉터리로만 복사하고 원본 media 경로에는 쓰지 않도록 했습니다.
- GDS 시리즈 `FolderPath`가 가능한 경우 실제 작품 폴더를 가리키도록 조정했습니다.
- GDS 변경 감지가 대표 `FolderPath` 하나에만 의존하지 않고 실제 DB 파일 parent directory도 보도록 했습니다.
- 반복 스캔 시 불필요한 신규/삭제 변화가 줄도록 안정화했습니다.
- 이미지 빌드 시 기존 `/kavita/wwwroot`를 제거한 뒤 새 UI를 복사해 stale Angular chunk 문제를 방지했습니다.
- 정적 파일 캐시 정책을 `no-cache/no-store`로 바꿔 UI 갱신 후 오래된 chunk 참조를 줄였습니다.
- 기본 시리즈 정렬을 마지막 수정 내림차순으로 복구했습니다.

## 2026-05-29: fix build

- EPUB OPF manifest에 `Section0001.xhtml` 같은 중복 ID가 있을 때 자동 복구 후 다시 열도록 했습니다.
- TXT 변환 도구로 생성된 일부 EPUB에서 발생하던 파싱 오류를 완화했습니다.
- 손상된 PDF의 `/Prev` 순환 참조로 인한 XRef 무한 재귀를 막기 위해 최대 깊이 제한을 추가했습니다.
- rclone FUSE 대형 라이브러리에서 디렉터리 재귀 열거가 hang 되는 문제를 줄이기 위해 stack 기반 반복 열거로 바꿨습니다.

## 2026-05-28: scan build 기준 기능

이 버전은 기존 배포 기준입니다. 주요 기능은 다음과 같습니다.

- `LibraryType.GDS = 6`
- `MangaFormat.Text = 5`
- `FileTypeGroup.Text = 5`
- TXT 확장자/parser/reader/controller 지원
- GDS scanner의 folder-based TXT series 지원
- `cover.*`를 series, volume, chapter에 반영
- TXT/ZIP 혼합 GDS 시리즈가 같은 정규화 제목이면 갈라지지 않도록 그룹핑
- mixed GDS series에서 `chapter-info`가 실제 chapter format을 반환
