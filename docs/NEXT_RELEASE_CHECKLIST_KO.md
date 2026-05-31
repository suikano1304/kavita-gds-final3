# 다음 릴리즈 체크리스트

작성일: 2026-05-31

현재 빌드 후보는 `0.9.0.2-5`이다. `0.9.0.2-4` 배포 이미지의 Web UI dev build 문제를 production UI hotfix로 보정한 multi-arch OCI archive를 다시 만들었다.

## 목적

- source branch, release source archive, GHCR image, 운영 compose image tag를 같은 기준으로 맞춘다.
- 운영 적용 전후 `collect_gds_preflight.sh` 결과를 비교해 scanner/Kavita 문제가 실제로 개선됐는지 판정한다.
- 운영 DB와 GDS/rclone 원본에는 검증 전 쓰기 작업을 하지 않는다.

## 포함해야 할 source 변경

- GDS 이어보기/볼륨 표시 분기에서 `LibraryType.GDS`를 chapter 계열로 처리
- 오래된 DB가 file type migration을 다시 탈 때 GDS 기본 file group에 `Archive`, `EPub`, `Pdf`, `Images`, `Text`를 모두 포함
- Web UI가 `localhost:5000/api`를 호출하지 않도록 production 환경 번들만 포함

## 권장 버전

현재 후보는 `0.9.0.2-5`로 둔다.

## 빌드 산출물

- Release package: `/tmp/kavita-gds-0.9.0.2-5.tar.gz`
- OCI archive: `/tmp/kavita-gds-0.9.0.2-5.oci.tar`

## 산출물 SHA256

```text
64d6de0d1f384e80fa5c0fc97e00c231d990f1d54cb6c26c300e076b7445c714  kavita-gds-0.9.0.2-5.tar.gz
55ecf03127480de13e795da426833fa6924d164c2049b15796532c02f9f1a40d  kavita-gds-0.9.0.2-5.oci.tar
```

## 완료한 검증

- `linux/amd64` startup smoke test: `Ok`
- OCI index 내부 manifest list: `linux/amd64`, `linux/arm64` 확인
- `/kavita/wwwroot` 전체에서 `localhost:5000`, `:5000/api`, Angular development mode 문자열 없음
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
  --scan-log /mnt/data/docker/kavita/config/logs/kavita20260531.log \
  --output-dir /tmp/kavita-gds-preflight \
  --label after \
  --snapshot-db \
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
