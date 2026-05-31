# Kavita-GDS 검증 매트릭스

작성일: 2026-05-31

이 문서는 “스캐너와 Kavita 문제를 근본적으로 분석했다”고 판단하기 위한 증거 기준을 정리한다. 원인 설명만으로는 완료가 아니며, 운영 DB와 운영 이미지에서 재현/개선 여부가 확인되어야 한다.

## 현재 판정

현재 상태는 `분석 진행 중`이다.

- 원인 후보는 대부분 분리됐다.
- 진단 도구와 postflight gate는 준비됐다.
- `0.9.0.2-4` 후보는 `0.9.0.2-3` 이후 GDS 타입 처리 보강 커밋까지 포함해 빌드됐다.
- `0.9.0.2-4` 후보의 `linux/amd64` startup smoke test와 `linux/arm64` manifest 확인은 완료됐다.
- 운영 컨테이너는 아직 `local/kavita-gds:0.9.0.2-1`이므로, 운영 DB에서 최신 release/source의 회복/cleanup 효과는 아직 검증되지 않았다.

## 완료 조건

| Requirement | 완료 증거 | 현재 증거 | 판정 |
| --- | --- | --- | --- |
| 스캔 변경 감지 과전파 원인 규명 | 변경 후보가 없는 라이브러리 일반 재스캔에서 `Processing series`가 대량 발생하지 않음 | 테스트 재스캔에서 `0 Series / 0 files / 770 ms` 확인. 운영은 아직 `0.9.0.2-1` | 부분 완료 |
| archive `Pages=0` 회복 | 직접 이미지가 있는 `Pages=0` ZIP이 운영 재스캔 후 감소 | 현재 39개 ZIP은 내부 이미지 13,301개가 있어 복구 가능 debt로 분류됨 | 미검증 |
| nested archive 한계 분리 | nested archive CBZ를 자동 회복 대상에서 제외하고 자료 구조 문제로 분류 | 10개 CBZ가 내부 ZIP 84개 구조로 분류됨 | 완료 |
| `kavita.yaml` 우선 메타데이터 | `EnableMetadata=false`에서도 YAML 안전 필드가 반영되고 `meta.Name`이 회차명을 덮지 않음 | 표본 검증과 source 보정 완료 | 부분 완료 |
| GDS reader/title routing | GDS mixed-format에서 chapter-info/title rendering 예외가 사라짐 | `0.9.0.2-4` 후보에 이어보기/볼륨 표시와 오래된 file type migration 보강 포함. 운영 적용 전 | 부분 완료 |
| cover cache 보존 | source `cover.*`가 없어도 기존 config cover cache가 불필요하게 삭제되지 않음 | cover risk 분류와 postflight cover gate 준비, 보정 포함 | 미검증 |
| TXT fallback cover | 원본 cover 없는 TXT가 오류가 아니라 config cover fallback으로 처리됨 | TXT cover state JSON/gate 준비, fallback 보정 포함 | 미검증 |
| duplicate cleanup | same-series/same-volume duplicate group이 운영 재스캔 후 감소 | 현재 same-series/same-volume group이 남아 있음. cleanup patch는 `0.9.0.2-4` 포함 | 미검증 |
| cross-series duplicate 정책 | 자동 삭제하지 않고 수동 판단 대상으로 분리 | cross-series group 153개가 자동 cleanup 제외 대상으로 문서화됨 | 완료 |
| startup FK 제보 분리 | x86/NAS 정상, Oracle A1 사례는 DB/migration/volume 상태 확인 대상으로 분리 | `0.9.0.2-4` 빈 config startup 통과. 제보는 Oracle A1 환경별 DB/migration/volume 비교 대상으로 분리 | 부분 완료 |
| scan timing 병목 분리 | file discovery, series update, total time을 별도 지표로 수집 | scan log summary 도구와 실제 로그 분석 완료 | 완료 |
| reader latency 분리 | scanner 병목과 reader cache/rclone 지연을 별도 지표로 수집 | slow reader request 8개 중 7개 ZIP, cache/file size 상관분석 완료 | 완료 |
| MediaError 원인 분류 | scanner bug, EPUB 구조 문제, PDF 문제, archive 문제를 분리 | MediaError classification 도구와 운영 DB 분류 완료 | 완료 |
| source/release/운영 일치 | 운영 이미지가 공개 release와 같은 source 기준으로 실행됨 | `0.9.0.2-4` 후보 빌드 완료. 운영은 아직 `0.9.0.2-1` | 미검증 |

## Postflight 기준

운영에 최신 source가 반영된 release를 적용한 뒤 아래가 확인되어야 최종 완료로 볼 수 있다. 현재 운영 검증 대상은 `0.9.0.2-4` 후보이다.

1. `PRAGMA integrity_check`가 `ok`다.
2. `PRAGMA foreign_key_check` 결과가 비어 있다.
3. `Pages=0` 총량이 증가하지 않는다.
4. 직접 이미지가 있는 복구 가능 `Pages=0` archive가 감소한다.
5. same-series/same-volume duplicate group이 감소하거나 최소한 증가하지 않는다.
6. cross-series duplicate는 자동 삭제되지 않는다.
7. MediaError 총량과 원인 분류별 count가 증가하지 않는다.
8. scan log에서 변경 후보가 없는 일반 재스캔이 대량 `Processing series`를 만들지 않는다.
9. reader latency 지표는 scanner timing과 별도 파일로 남는다.
10. cover cache 수가 불필요하게 감소하지 않는다.
11. TXT fallback cover는 Kavita config 경로에만 생성되고 GDS/rclone 원본에는 쓰지 않는다.

## 권장 실행 순서

운영 적용 전 baseline:

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

운영 적용 후 postflight:

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

postflight 결과에 `FAIL`이 없어야 한다. `WARN`은 남은 debt가 줄지 않았다는 뜻이므로, 목표 완료가 아니라 추가 분석 대상으로 남긴다.

`--check-covers`를 before/after 양쪽에 넣으면 cover 관련 gate도 함께 출력된다. `GDS config cover references decreased`는 실패로 보고, `TXT missing-cover debt unchanged`는 fallback cover가 아직 운영 DB에서 검증되지 않았다는 뜻으로 남긴다.
