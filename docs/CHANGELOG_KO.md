# 변경 내역

기준 버전: `kavita-gds-0.9.0.2-scan-20260528`

현재 배포: `kavita-gds-0.9.0.2-gds-scanfix-20260530-universal`

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
