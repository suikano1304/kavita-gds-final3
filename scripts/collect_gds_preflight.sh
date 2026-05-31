#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: collect_gds_preflight.sh --db PATH --output-dir DIR [options]

Read-only preflight collector for Kavita-GDS operations.

Required:
  --db PATH             Path to kavita.db
  --output-dir DIR      Directory where reports will be written

Options:
  --container-root DIR  Media root stored in Kavita DB paths (default: /mnt/gds)
  --host-root DIR       Media root readable from this shell (default: /mnt/gds2)
  --compose-file PATH   Copy a docker-compose.yml into the report directory
  --label TEXT          Prefix output filenames with this label (default: before)
  --scan-log PATH       Include a Kavita log file in scan timing summary. Repeatable
  --check-archives      Ask diagnose_kavita_gds.py to inspect Pages=0 ZIP/CBZ files
  --check-covers        Ask diagnose_kavita_gds.py to inspect cover state
  --compare-json PATH   Compare this run with a previous diagnostics JSON
  --postflight-gates    Print PASS/WARN/FAIL gates for a --compare-json run
  --fail-on-gate-failure
                        Exit non-zero if any postflight gate fails
  --hash-db             Record a SHA256 hash of the DB file
  -h, --help            Show this help

The script does not modify the Kavita DB, compose file, or media folders.
EOF
}

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
db=""
output_dir=""
container_root="/mnt/gds"
host_root="/mnt/gds2"
compose_file=""
scan_logs=()
label="before"
check_archives=false
check_covers=false
compare_json=""
postflight_gates=false
fail_on_gate_failure=false
hash_db=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --db)
      db="${2:-}"
      shift 2
      ;;
    --output-dir)
      output_dir="${2:-}"
      shift 2
      ;;
    --container-root)
      container_root="${2:-}"
      shift 2
      ;;
    --host-root)
      host_root="${2:-}"
      shift 2
      ;;
    --compose-file)
      compose_file="${2:-}"
      shift 2
      ;;
    --scan-log)
      scan_logs+=("${2:-}")
      shift 2
      ;;
    --label)
      label="${2:-}"
      shift 2
      ;;
    --check-archives)
      check_archives=true
      shift
      ;;
    --check-covers)
      check_covers=true
      shift
      ;;
    --compare-json)
      compare_json="${2:-}"
      shift 2
      ;;
    --postflight-gates)
      postflight_gates=true
      shift
      ;;
    --fail-on-gate-failure)
      fail_on_gate_failure=true
      shift
      ;;
    --hash-db)
      hash_db=true
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [[ -z "$db" || -z "$output_dir" ]]; then
  usage >&2
  exit 2
fi

if [[ ! -f "$db" ]]; then
  echo "DB not found: $db" >&2
  exit 1
fi

if [[ -n "$compare_json" && ! -f "$compare_json" ]]; then
  echo "Compare JSON not found: $compare_json" >&2
  exit 1
fi
if [[ "$postflight_gates" == true && -z "$compare_json" ]]; then
  echo "--postflight-gates requires --compare-json" >&2
  exit 2
fi
if [[ "$fail_on_gate_failure" == true && "$postflight_gates" != true ]]; then
  echo "--fail-on-gate-failure requires --postflight-gates" >&2
  exit 2
fi
for scan_log in "${scan_logs[@]}"; do
  if [[ ! -f "$scan_log" ]]; then
    echo "Scan log not found: $scan_log" >&2
    exit 1
  fi
done

mkdir -p "$output_dir"

json_file="$output_dir/${label}-diagnostics.json"
text_file="$output_dir/${label}-diagnostics.txt"
manifest_file="$output_dir/${label}-manifest.txt"
scan_log_text_file="$output_dir/${label}-scan-log-summary.txt"
scan_log_json_file="$output_dir/${label}-scan-log-summary.json"

diagnose_args=(
  --db "$db"
  --container-root "$container_root"
  --host-root "$host_root"
  --json-output "$json_file"
)

if [[ "$check_archives" == true ]]; then
  diagnose_args+=(--check-archives)
fi
if [[ "$check_covers" == true ]]; then
  diagnose_args+=(--check-covers)
fi
if [[ -n "$compare_json" ]]; then
  diagnose_args+=(--compare-json "$compare_json")
fi
if [[ "$postflight_gates" == true ]]; then
  diagnose_args+=(--postflight-gates)
fi
if [[ "$fail_on_gate_failure" == true ]]; then
  diagnose_args+=(--fail-on-gate-failure)
fi

python3 -B "$script_dir/diagnose_kavita_gds.py" "${diagnose_args[@]}" | tee "$text_file"

{
  echo "created_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "db=$db"
  echo "container_root=$container_root"
  echo "host_root=$host_root"
  echo "json=$json_file"
  echo "text=$text_file"
  if [[ ${#scan_logs[@]} -gt 0 ]]; then
    echo "scan_log_json=$scan_log_json_file"
    echo "scan_log_text=$scan_log_text_file"
  fi
  echo "host_uname=$(uname -a)"
  echo "host_arch=$(uname -m)"
  if command -v docker >/dev/null 2>&1; then
    docker version --format 'docker_client_version={{.Client.Version}}' 2>/dev/null || true
    docker version --format 'docker_server_version={{.Server.Version}}' 2>/dev/null || true
    docker info --format 'docker_ostype={{.OSType}}' 2>/dev/null || true
    docker info --format 'docker_architecture={{.Architecture}}' 2>/dev/null || true
  fi
  if docker compose version >/dev/null 2>&1; then
    docker compose version 2>/dev/null | sed 's/^/docker_compose=/'
  fi
  if [[ -n "$compare_json" ]]; then
    echo "compare_json=$compare_json"
  fi
  echo "postflight_gates=$postflight_gates"
  echo "fail_on_gate_failure=$fail_on_gate_failure"
  if command -v stat >/dev/null 2>&1; then
    stat -c 'db_size_bytes=%s' "$db"
    stat -c 'db_mtime=%y' "$db"
  fi
  if [[ "$hash_db" == true ]]; then
    sha256sum "$db" | sed 's/^/db_sha256=/' || true
  fi
} > "$manifest_file"

if [[ -n "$compose_file" ]]; then
  if [[ ! -f "$compose_file" ]]; then
    echo "Compose file not found: $compose_file" >&2
    exit 1
  fi
  cp "$compose_file" "$output_dir/${label}-docker-compose.yml"
  echo "compose_copy=$output_dir/${label}-docker-compose.yml" >> "$manifest_file"
fi

if [[ ${#scan_logs[@]} -gt 0 ]]; then
  python3 -B "$script_dir/summarize_kavita_scan_logs.py" \
    "${scan_logs[@]}" \
    --json-output "$scan_log_json_file" \
    > "$scan_log_text_file"
  echo "scan_logs=${scan_logs[*]}" >> "$manifest_file"
fi

echo
echo "Wrote preflight report:"
echo "$output_dir"
