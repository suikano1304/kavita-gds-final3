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
  --check-archives      Ask diagnose_kavita_gds.py to inspect Pages=0 ZIP/CBZ files
  --check-covers        Ask diagnose_kavita_gds.py to inspect cover state
  --compare-json PATH   Compare this run with a previous diagnostics JSON
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
label="before"
check_archives=false
check_covers=false
compare_json=""
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

mkdir -p "$output_dir"

json_file="$output_dir/${label}-diagnostics.json"
text_file="$output_dir/${label}-diagnostics.txt"
manifest_file="$output_dir/${label}-manifest.txt"

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

python3 -B "$script_dir/diagnose_kavita_gds.py" "${diagnose_args[@]}" | tee "$text_file"

{
  echo "created_at_utc=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "db=$db"
  echo "container_root=$container_root"
  echo "host_root=$host_root"
  echo "json=$json_file"
  echo "text=$text_file"
  if [[ -n "$compare_json" ]]; then
    echo "compare_json=$compare_json"
  fi
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

echo
echo "Wrote preflight report:"
echo "$output_dir"
