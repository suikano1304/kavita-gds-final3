# 다음 릴리즈 체크리스트

작성일: 2026-05-31

현재 공개 릴리즈는 `0.9.0.2-3`이다. 이후 source branch에는 GDS 타입 처리 보강 커밋이 추가되어 있으므로, 운영 검증을 계속하려면 새 릴리즈 후보를 같은 source 기준으로 다시 만들어야 한다.

## 목적

- source branch, release source archive, GHCR image, 운영 compose image tag를 같은 기준으로 맞춘다.
- 운영 적용 전후 `collect_gds_preflight.sh` 결과를 비교해 scanner/Kavita 문제가 실제로 개선됐는지 판정한다.
- 운영 DB와 GDS/rclone 원본에는 검증 전 쓰기 작업을 하지 않는다.

## 포함해야 할 source 변경

- GDS 이어보기/볼륨 표시 분기에서 `LibraryType.GDS`를 chapter 계열로 처리
- 오래된 DB가 file type migration을 다시 탈 때 GDS 기본 file group에 `Archive`, `EPub`, `Pdf`, `Images`, `Text`를 모두 포함

## 권장 버전

다음 후보는 `0.9.0.2-4`로 둔다.

## 빌드 전 확인

```bash
git -C /root/kavita-gds-lab/port-0902-min status --short
git -C /root/kavita-gds-lab/port-0902-min log --oneline -5
git -C /root/Kavita-GDS status --short
```

## 필수 검증

1. UI production build 통과
2. backend build 또는 container build 통과
3. `linux/amd64` startup smoke test 통과
4. `linux/arm64` manifest 포함 확인
5. 가능하면 QEMU entrypoint smoke test 통과
6. 운영 DB 사본으로 startup smoke test 통과
7. public release asset과 GHCR image가 같은 source snapshot에서 생성됐는지 확인

## 운영 적용 전 baseline

```bash
scripts/collect_gds_preflight.sh \
  --db /mnt/data/docker/kavita/config/kavita.db \
  --container-root /mnt/gds \
  --host-root /mnt/data/rclone/gds \
  --scan-log /mnt/data/docker/kavita/config/logs/kavita20260531.log \
  --output-dir /tmp/kavita-gds-preflight \
  --label before \
  --check-archives \
  --check-covers
```

## 운영 적용 후 postflight

```bash
scripts/collect_gds_preflight.sh \
  --db /mnt/data/docker/kavita/config/kavita.db \
  --container-root /mnt/gds \
  --host-root /mnt/data/rclone/gds \
  --scan-log /mnt/data/docker/kavita/config/logs/kavita20260531.log \
  --output-dir /tmp/kavita-gds-preflight \
  --label after \
  --check-archives \
  --check-covers \
  --compare-json /tmp/kavita-gds-preflight/before-diagnostics.json \
  --postflight-gates
```

## 완료 판정

- `FAIL`이 없어야 한다.
- `Pages=0`, same-series duplicate, TXT missing-cover debt가 `WARN`으로 남으면 목표 완료가 아니라 추가 분석 대상으로 둔다.
- cross-series duplicate는 자동 삭제 대상이 아니므로 증가하지 않는지만 확인한다.
- cover cache gate가 실패하면 운영 config cover 보존 로직을 다시 봐야 한다.
