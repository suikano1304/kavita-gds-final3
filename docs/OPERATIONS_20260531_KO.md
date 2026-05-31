# 2026-05-31 운영 기록

이 문서는 운영 서버에서 수행한 Kavita config 정리, 커버 복구, `kavita.yaml` 메타데이터 적용 검증, GitHub 배포 상태를 남긴 기록입니다.

## 기준 환경

- PVE host에서 LXC `101` (`lxc1-media`)의 Docker Kavita를 운영합니다.
- 운영 compose: `/opt/compose/kavita/docker-compose.yml`
- 운영 config: `/mnt/data/docker/kavita/config`
- 운영 컨테이너: `kavita`
- 운영 이미지: `local/kavita-gds:0.9.0.2-1`
- GDS 원본은 LXC에서 `/mnt/gds2`, 컨테이너에서 `/mnt/gds`로 읽기 전용 마운트합니다.

## 커버 복구

기존 active config 정리 과정에서 cover cache 일부가 사라졌고, 남아 있던 config/test config 쪽 cover 파일을 운영 config로 다시 모았습니다.

처리 방향:

- DB만 복구하지 않고, 남아 있는 cover 파일을 `/mnt/data/docker/kavita/config/covers`로 최대한 회수했습니다.
- ZFS snapshot이나 PVE backup에 `/mnt/data/docker` bind mount가 포함되어 있지 않아 사라진 일부 old cover cache는 원본 그대로 복구할 수 없었습니다.
- 이후 Kavita 스캔/메타데이터 작업으로 cover cache가 다시 생성되도록 운영을 유지했습니다.

확인 명령:

```bash
pct exec 101 -- docker ps --filter name=kavita --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
pct exec 101 -- python3 - <<'PY'
import os
print(sum(1 for _ in os.scandir('/mnt/data/docker/kavita/config/covers')))
PY
```

확인 결과:

- `kavita` 컨테이너는 healthy 상태였습니다.
- 2026-05-31 기준 cover 파일은 약 `5,800+`개까지 회복/재생성되었습니다.

## `kavita.yaml` 메타데이터 적용

기존 GDS 스캔은 `kavita.yaml`의 rich metadata를 제대로 반영하지 못했습니다. 특히 `Summary`, 작가, 출판사, 번역자, 날짜 같은 값이 DB에 들어가지 않거나, 반대로 `meta.Name`이 회차 제목을 덮어써서 회차 정보가 사라지는 문제가 있었습니다.

수정한 동작:

- GDS 라이브러리는 `EnableMetadata=false`여도 같은 폴더의 `kavita.yaml`/`kavita.yml`을 보조 메타데이터로 읽습니다.
- `Summary`, `Genres`, `Tags`, `Language`, `Web Links`, 작가/번역자/출판사/작화가, 발매일, 연령등급 등 안전한 필드를 `ComicInfo`에 반영합니다.
- `meta.Name`은 시리즈명이나 회차 제목을 덮어쓰는 데 사용하지 않습니다.
- 회차 제목은 파일명에서 생성합니다.
- 파일명 제목 생성 시 `#138`, `[1440px]`, `[직스샷]`, trailing `(리디)` 같은 배포/품질 태그를 제거합니다.

관련 소스 위치:

```text
Kavita.Services/Helpers/GdsMetadataParser.cs
Kavita.Services/Reading/ReadingItemService.cs
```

검증한 대표 케이스:

```text
<redacted-media-path> 포함 시리즈>/<시리즈명> Vol. 1 - <부제> (완결) [1440px] [직스샷] (리디)#138.zip
```

확인 내용:

- 시리즈명은 접두/분류명이 아니라 실제 시리즈명으로 유지됩니다.
- YAML `Summary`가 DB chapter summary에 들어왔습니다.
- 접두가 붙은 중복 시리즈는 생성되지 않았습니다.
- 다른 재스캔 표본에서 회차 제목이 파일명 기반으로 정리되어 들어오는 것을 확인했습니다.

예시:

```text
파일: [분류] <시리즈명> Vol. 6 (완결) (리디)#186.zip
회차 제목: <시리즈명> Vol. 6 (완결)
```

검증 명령:

```bash
pct exec 101 -- python3 - <<'PY'
import sqlite3
con=sqlite3.connect('/mnt/data/docker/kavita/config/kavita.db')
print('prefix_dups', con.execute("select count(*) from Series where Name like '[%] %'").fetchone()[0])
for row in con.execute("""
select s.Name,c.TitleName,c.Range
from Chapter c join Volume v on c.VolumeId=v.Id join Series s on v.SeriesId=s.Id
where s.LibraryId=5 and c.TitleName not like '[%] %' and c.TitleName != ''
order by c.Id desc limit 10
"""):
    print(row)
PY
```

주의:

- 이미 스캔된 시리즈는 해당 시리즈가 다시 처리되어야 DB의 `TitleName`이 갱신됩니다.
- 전체 라이브러리 강제 스캔은 ZIP을 다시 열기 때문에 rclone/GDS 환경에서는 오래 걸릴 수 있습니다.
- 빠른 확인이 필요하면 전체 스캔을 기다리지 말고 대상 시리즈만 재스캔하는 편이 낫습니다.

## 배포 상태

공개 GitHub repo:

```text
https://github.com/suikano1304/Kavita-GDS
```

현재 repo의 공개 배포 기준:

- 이미지 이름: `ghcr.io/suikano1304/kavita-gds`
- 권장 태그: `0.9.0.2-2`
- latest 태그도 publish workflow에서 같이 갱신합니다.
- release asset 이름은 `kavita-gds.tar.gz`로 정리했습니다.

현재 문서와 배포 후보는 `0.9.0.2-2` 기준입니다. 운영 컨테이너 적용 여부는 compose의 `image:`와 실행 중인 컨테이너 이미지를 별도로 확인해야 합니다.

배포 확인:

- Release asset: `kavita-gds.tar.gz`
- Release asset SHA256: 저장소 루트 `SHA256SUMS` 기준
- GHCR package visibility: `public`
- GHCR image index는 `linux/amd64`, `linux/arm64`를 포함합니다.

이후 새 버전을 공개 이미지로 올릴 때는 다음 순서로 진행합니다.

1. amd64/arm64 산출물을 새로 build/publish합니다.
2. release asset `kavita-gds.tar.gz`와 `SHA256SUMS`를 갱신합니다.
3. `.github/workflows/publish-ghcr.yml`의 `RELEASE_ASSET_SHA256` 값을 갱신합니다.
4. GitHub Release asset을 올립니다.
5. GitHub Actions `Publish GHCR image` workflow를 실행해 GHCR의 새 버전 태그와 `latest`를 갱신합니다.

## 운영 체크리스트

재배포 전:

```bash
pct exec 101 -- docker ps --filter name=kavita --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
pct exec 101 -- python3 - <<'PY'
import sqlite3
con = sqlite3.connect('file:/mnt/data/docker/kavita/config/kavita.db?mode=ro', uri=True)
print(con.execute('pragma integrity_check').fetchone()[0])
PY
```

재스캔 전:

```bash
pct exec 101 -- cp /mnt/data/docker/kavita/config/kavita.db /mnt/data/docker/kavita/config/kavita.db.pre-scanfix-$(date +%Y%m%d)
```

검증:

- 컨테이너가 healthy인지 확인합니다.
- 접두가 붙은 중복 시리즈가 새로 생기지 않는지 확인합니다.
- `kavita.yaml`의 `Summary`가 DB에 들어왔는지 표본 검사합니다.
- 회차 제목이 `meta.Name`이 아니라 파일명 기반으로 표시되는지 표본 검사합니다.
- rclone/GDS 원본 경로에 업로드/삭제/rename이 없는지 host rclone log/RC 기준으로 확인합니다.
