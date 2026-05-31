# 다음 릴리즈 체크리스트

작성일: 2026-05-31

현재 빌드 후보는 `0.9.0.2-4`이다. `0.9.0.2-3` 이후 source branch에 있던 GDS 타입 처리 보강 커밋까지 포함해 source snapshot, runtime tarball, multi-arch OCI archive를 다시 만들었다.

## 목적

- source branch, release source archive, GHCR image, 운영 compose image tag를 같은 기준으로 맞춘다.
- 운영 적용 전후 `collect_gds_preflight.sh` 결과를 비교해 scanner/Kavita 문제가 실제로 개선됐는지 판정한다.
- 운영 DB와 GDS/rclone 원본에는 검증 전 쓰기 작업을 하지 않는다.

## 포함해야 할 source 변경

- GDS 이어보기/볼륨 표시 분기에서 `LibraryType.GDS`를 chapter 계열로 처리
- 오래된 DB가 file type migration을 다시 탈 때 GDS 기본 file group에 `Archive`, `EPub`, `Pdf`, `Images`, `Text`를 모두 포함

## 권장 버전

현재 후보는 `0.9.0.2-4`로 둔다.

## 빌드 산출물

- Source snapshot: `/tmp/kavita-gds-0.9.0.2-4-source.tar.gz`
- OCI archive: `/tmp/kavita-gds-0.9.0.2-4.oci.tar`
- Runtime tarball x64: `/tmp/kavita-linux-x64-0.9.0.2-4.tar.gz`
- Runtime tarball arm64: `/tmp/kavita-linux-arm64-0.9.0.2-4.tar.gz`

## 산출물 SHA256

```text
03f7e14899683d6ca632f88f8f83d52494ae9e2f62ba8c2f81ee61ce2761814e  kavita-gds-0.9.0.2-4.oci.tar
a8812cbd7e992d7dd37c89768dce964651f7e99cae05a5127c5ed0e35689ede1  kavita-gds-0.9.0.2-4-source.tar.gz
83b80653e203bbf7daf63febed647206b500d4eaab6fd85a3b7e048c218bad69  kavita-linux-x64-0.9.0.2-4.tar.gz
6a07c72e6399ba82aad35798b0458c27a130b21e255d4f0e6d0f80821c677370  kavita-linux-arm64-0.9.0.2-4.tar.gz
```

## 완료한 검증

- `linux/amd64` startup smoke test: `Ok`
- OCI index 내부 manifest list: `linux/amd64`, `linux/arm64` 확인
- 운영 컨테이너는 변경하지 않음

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
6. 운영 DB 사본 또는 Oracle A1 제보 DB로 startup smoke test 통과
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
