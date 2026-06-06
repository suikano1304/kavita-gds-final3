# 다음 릴리즈 체크리스트

작성일: 2026-06-02

현재 공개 릴리즈는 `9.0.7`입니다. 다음 릴리즈는 official Kavita 기준 버전, source patch, GHCR image, Release asset, 운영 compose tag가 서로 어긋나지 않는지 먼저 확인합니다.

## 기본 원칙

- official Kavita source/image 기준 버전을 명시한다.
- 운영 GDS/rclone 원본 mount는 읽기 전용으로 유지한다.
- 운영 DB/config를 변경하기 전 backup 또는 snapshot을 만든다.
- test 컨테이너에서 fixture 검증을 먼저 통과한 뒤 운영에 반영한다.
- 운영 반영 후 health, reader API, scan log, rclone read-only 상태를 확인한다.
- 검증 전에는 GitHub commit, release, package publish를 하지 않는다.

## 버전 결정

다음 값을 릴리즈 문서에 모두 기록한다.

- official Kavita version
- official source revision 또는 image label
- GDS patch version
- local test image tag
- production image tag
- GHCR version tag
- GHCR multi-arch digest
- `linux/amd64` digest
- `linux/arm64` digest
- `linux/arm/v7` digest

## 빌드 전 확인

```bash
git -C /root/kavita-gds-lab/port-0906-gds status --short
git -C /root/kavita-gds-lab/port-0906-gds log --oneline -5
git -C /root/Kavita-GDS status --short
```

패키징 repo에는 큰 binary를 commit하지 않습니다. Docker archive와 tarball은 GitHub Release asset으로만 배포합니다.

## 필수 검증

1. official source 대비 GDS patch diff 리뷰
2. 수정 대상 코드리뷰 2회 기록
3. backend/container build 통과
4. `kavita-test` startup health 통과
5. fixture validation 최소 2회 통과
6. 문제 EPUB/TXT/ZIP/CBZ 샘플 reader API 확인
7. 운영 반영 후 startup health 통과
8. 운영 반영 후 대표 문제 series API 확인
9. rclone log/RC에서 write/delete/rename activity가 없는지 확인
10. `linux/arm64` build와 qemu smoke test 통과
11. GHCR amd64/arm64/armv7 image push
12. multi-arch manifest와 `latest` manifest 확인
13. GitHub Release asset과 `SHA256SUMS` 확인

## 운영 적용 전 baseline

```bash
scripts/collect_gds_preflight.sh \
  --db /mnt/data/docker/kavita/config/kavita.db \
  --container-root /mnt/gds \
  --host-root /mnt/data/rclone/gds \
  --scan-log /mnt/data/docker/kavita/config/logs/kavitaYYYYMMDD.log \
  --output-dir /tmp/kavita-gds-preflight \
  --label before \
  --snapshot-db \
  --check-archives \
  --check-covers
```

## 운영 적용 후 postflight

```bash
scripts/collect_gds_preflight.sh \
  --db /mnt/data/docker/kavita/config/kavita.db \
  --container-root /mnt/gds \
  --host-root /mnt/data/rclone/gds \
  --scan-log /mnt/data/docker/kavita/config/logs/kavitaYYYYMMDD.log \
  --output-dir /tmp/kavita-gds-preflight \
  --label after \
  --snapshot-db \
  --check-archives \
  --check-covers \
  --compare-json /tmp/kavita-gds-preflight/before-diagnostics.json \
  --compare-scan-json /tmp/kavita-gds-preflight/before-scan-log-summary.json \
  --postflight-gates
```

## 완료 판정

- `postflight-gates`에 `FAIL`이 없어야 한다.
- `Pages=0`, missing cover, same-series duplicate가 증가하지 않아야 한다.
- 문제 샘플의 reader API가 정상 page count와 page response를 반환해야 한다.
- Web UI가 production bundle로 동작하고 `localhost:5000/api` 요청이 없어야 한다.
- 운영 compose image tag와 GHCR digest가 문서에 기록된 값과 일치해야 한다.
- release asset checksum이 `SHA256SUMS`와 일치해야 한다.

## 문서 갱신

릴리즈 전에 다음 파일을 갱신한다.

- `README.md`
- `RELEASE_NOTES.md`
- `SHA256SUMS`
- `compose/docker-compose.production.yml`
- `docs/USAGE_KO.md`
- `docs/CHANGELOG_KO.md`
- `docs/BUILD_NOTES_KO.md`
- `docs/SCAN_*` 또는 해당 릴리즈 검증 기록
- `patches/<version>/`
- `.github/workflows/publish-ghcr.yml`을 사용하는 경우 현재 asset/tag/checksum
