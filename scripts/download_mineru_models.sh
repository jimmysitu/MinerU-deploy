#!/usr/bin/env bash
# Download MinerU pipeline and/or VLM weights into MODELS_ROOT (default: ./mineru-models).
# Requires: mineru-models-download (pip install "mineru[core]")
# Cache is kept under MODELS_ROOT; stable symlinks MODELS_ROOT/pipeline and MODELS_ROOT/vlm
# point to the downloaded Hub/ModelScope snapshot roots (for docker -v .../pipeline .../vlm).

set -euo pipefail

SOURCE="${SOURCE:-huggingface}"
MODEL_TYPE="${MODEL_TYPE:-all}"
MODELS_ROOT="${MODELS_ROOT:-./mineru-models}"

usage() {
    cat <<'EOF'
Usage:
  ./scripts/download_mineru_models.sh [options]

Options:
  -s, --source huggingface|modelscope   Model hub (default: huggingface, or env SOURCE)
  -m, --model  pipeline|vlm|all         What to download (default: all, or env MODEL_TYPE)
  -d, --dir    PATH                     Output root (default: ./mineru-models, or env MODELS_ROOT)
  -h, --help

Environment:
  MODELS_ROOT   Same as --dir
  SOURCE        Same as --source
  MODEL_TYPE    Same as --model

Hub caches (under MODELS_ROOT):
  HuggingFace:  .hf/
  ModelScope:   .modelscope/

Config written to:
  MODELS_ROOT/mineru.json

After download, use with deploy script:
  MODELS_DIR=/absolute/path/to/mineru-models ./scripts/deploy_mineru_image.sh

Notes:
  - Unset MINERU_MODEL_SOURCE for the download run so weights are fetched from the network.
  - Ensure enough disk space (pipeline + vlm is large).
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -s|--source)
            SOURCE="$2"
            shift 2
            ;;
        -m|--model)
            MODEL_TYPE="$2"
            shift 2
            ;;
        -d|--dir)
            MODELS_ROOT="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

case "$SOURCE" in
    huggingface|modelscope) ;;
    *)
        echo "ERROR: --source must be huggingface or modelscope, got: $SOURCE" >&2
        exit 1
        ;;
esac

case "$MODEL_TYPE" in
    pipeline|vlm|all) ;;
    *)
        echo "ERROR: --model must be pipeline, vlm, or all, got: $MODEL_TYPE" >&2
        exit 1
        ;;
esac

if ! command -v mineru-models-download >/dev/null 2>&1; then
    echo "ERROR: mineru-models-download not found. Install MinerU, e.g.:" >&2
    echo "  pip install -U \"mineru[core]\"" >&2
    exit 1
fi

mkdir -p "$MODELS_ROOT"
MODELS_ROOT="$(cd "$MODELS_ROOT" && pwd)"

export HF_HOME="${MODELS_ROOT}/.hf"
export MODELSCOPE_CACHE="${MODELS_ROOT}/.modelscope"
export MINERU_TOOLS_CONFIG_JSON="${MODELS_ROOT}/mineru.json"

# Allow real download from remote hubs (not local-only mode).
unset MINERU_MODEL_SOURCE || true

echo "MODELS_ROOT=${MODELS_ROOT}"
echo "SOURCE=${SOURCE} MODEL_TYPE=${MODEL_TYPE}"
echo "HF_HOME=${HF_HOME}"
echo "MODELSCOPE_CACHE=${MODELSCOPE_CACHE}"
echo "MINERU_TOOLS_CONFIG_JSON=${MINERU_TOOLS_CONFIG_JSON}"
echo

mineru-models-download -s "$SOURCE" -m "$MODEL_TYPE"

export MODELS_ROOT
python3 <<'PY'
import json
import os
import pathlib
import sys

root = pathlib.Path(os.environ["MODELS_ROOT"])
cfg_path = root / "mineru.json"
if not cfg_path.is_file():
    print(f"ERROR: missing config {cfg_path}", file=sys.stderr)
    sys.exit(1)

data = json.loads(cfg_path.read_text(encoding="utf-8"))
models_dir = data.get("models-dir") or {}
for name in ("pipeline", "vlm"):
    target = models_dir.get(name)
    if not target:
        continue
    src = pathlib.Path(target).resolve()
    if not src.is_dir():
        print(f"WARN: {name} path is not a directory, skip symlink: {src}", file=sys.stderr)
        continue
    link = root / name
    if link.is_symlink() or link.exists():
        if link.is_dir() and not link.is_symlink():
            print(f"ERROR: {link} exists and is a real directory; remove it to create symlink.", file=sys.stderr)
            sys.exit(1)
        link.unlink()
    link.symlink_to(src, target_is_directory=True)
    print(f"Symlink {link} -> {src}")

print(f"Done. Config: {cfg_path}")
PY

echo
echo "For Docker deploy, pass the directory that contains pipeline/ and vlm/ symlinks:"
echo "  MODELS_DIR=${MODELS_ROOT} ./scripts/deploy_mineru_image.sh"
