#!/usr/bin/env bash
set -euo pipefail

IMAGE="${IMAGE:-ghcr.io/jimmysitu/mineru-deploy:latest}"
CONTAINER_NAME="${CONTAINER_NAME:-mineru-api}"
API_HOST_PORT="${API_HOST_PORT:-8000}"
API_CONTAINER_PORT="${API_CONTAINER_PORT:-8000}"
MODELS_DIR="${MODELS_DIR:-}"
PIPELINE_MODELS_DIR="${PIPELINE_MODELS_DIR:-}"
VLM_MODELS_DIR="${VLM_MODELS_DIR:-}"
# Same default tree as scripts/download_mineru_models.sh: ./mineru-models/pipeline, ./mineru-models/vlm
_DEFAULT_MODELS_ROOT="${PWD}/mineru-models"
DATA_DIR="${DATA_DIR:-$PWD/mineru-data}"
EXTRA_DOCKER_ARGS="${EXTRA_DOCKER_ARGS:-}"
EXTRA_MINERU_API_ARGS="${EXTRA_MINERU_API_ARGS:-}"
RECREATE="${RECREATE:-true}"
PULL_IMAGE="${PULL_IMAGE:-true}"

_is_cpu_image() {
    [[ "${1}" =~ (:|/)mineru-[0-9.]+-cpu$|:cpu-latest$ ]]
}

# Use ${VAR-default} (not :=) so GPU_ARGS="" disables GPU passthrough.
if [[ -z "${GPU_ARGS+x}" ]]; then
    if _is_cpu_image "${IMAGE}"; then
        GPU_ARGS=""
    else
        GPU_ARGS="--gpus all"
    fi
fi

usage() {
    cat <<'EOF'
Deploy the MinerU API runtime image (mineru-api service).

GPU and CPU images share the same volume layout. For CPU tags (*-cpu, cpu-latest),
GPU_ARGS defaults to empty, mineru-api gets --backend pipeline --device cpu,
and VLM weights are optional (pipeline-only download is enough).

GPU image deploy still requires both pipeline/ and vlm/ unless you mount VLM yourself.

Environment variables:
  IMAGE                 Docker image to run. Default: ghcr.io/jimmysitu/mineru-deploy:latest
  CONTAINER_NAME        Container name. Default: mineru-api
  API_HOST_PORT         Host port for mineru-api. Default: 8000
  MODELS_DIR            Parent directory for default pipeline/ and vlm/ (default: ./mineru-models)
  PIPELINE_MODELS_DIR   Pipeline weights dir (default: MODELS_DIR/pipeline if unset)
  VLM_MODELS_DIR        VLM weights dir (default: MODELS_DIR/vlm if unset)
  DATA_DIR              Host data/output directory. Default: ./mineru-data
  GPU_ARGS              Docker GPU args. Default: --gpus all (GPU image), empty (CPU image).
                        Set GPU_ARGS="" explicitly to disable GPUs on any image.
  EXTRA_DOCKER_ARGS     Extra docker run args.
  EXTRA_MINERU_API_ARGS Extra mineru-api args.
  RECREATE              Remove existing container before deploy. Default: true
  PULL_IMAGE            Pull image before deploy. Default: true

Examples:
  ./scripts/download_mineru_models.sh && ./scripts/deploy_mineru_image.sh
  PIPELINE_MODELS_DIR=/mnt/custom/pipeline ./scripts/deploy_mineru_image.sh
  VLM_MODELS_DIR=/mnt/custom/vlm ./scripts/deploy_mineru_image.sh
  MODELS_DIR=/opt/mineru-models IMAGE=ghcr.io/acme/mineru-deploy:mineru-3.1.14 ./scripts/deploy_mineru_image.sh
  ./scripts/download_mineru_models.sh -m pipeline
  IMAGE=ghcr.io/acme/mineru-deploy:cpu-latest ./scripts/deploy_mineru_image.sh
  PIPELINE_MODELS_DIR=/mnt/models/pipeline VLM_MODELS_DIR=/mnt/models/vlm ./scripts/deploy_mineru_image.sh

Client usage:
  mineru -p input.pdf -o output -b pipeline --api-url http://<server>:8000
  mineru -p input.pdf -o output -b vlm-auto-engine --api-url http://<server>:8000
  mineru -p input.pdf -o output -b hybrid-auto-engine --api-url http://<server>:8000
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
    exit 0
fi

MODELS_DIR="${MODELS_DIR:-${_DEFAULT_MODELS_ROOT}}"
PIPELINE_MODELS_DIR="${PIPELINE_MODELS_DIR:-${MODELS_DIR%/}/pipeline}"
VLM_MODELS_DIR="${VLM_MODELS_DIR:-${MODELS_DIR%/}/vlm}"

if [[ ! -d "${PIPELINE_MODELS_DIR}" ]]; then
    echo "ERROR: Pipeline model directory does not exist: ${PIPELINE_MODELS_DIR}" >&2
    exit 1
fi

# docker run args replace image CMD; restore CPU defaults when using a CPU tag.
if _is_cpu_image "${IMAGE}" && [[ -z "${EXTRA_MINERU_API_ARGS}" ]]; then
    EXTRA_MINERU_API_ARGS="--backend pipeline --device cpu"
fi

VLM_VOLUME_ARGS=()
if [[ -d "${VLM_MODELS_DIR}" ]]; then
    VLM_VOLUME_ARGS=(-v "${VLM_MODELS_DIR}:/models/vlm:ro")
elif ! _is_cpu_image "${IMAGE}"; then
    echo "ERROR: VLM model directory does not exist: ${VLM_MODELS_DIR}" >&2
    exit 1
fi

mkdir -p "${DATA_DIR}"

if [[ "${PULL_IMAGE}" == "true" ]]; then
    docker pull "${IMAGE}"
fi

if docker ps -a --format '{{.Names}}' | grep -Fxq "${CONTAINER_NAME}"; then
    if [[ "${RECREATE}" == "true" ]]; then
        docker rm -f "${CONTAINER_NAME}"
    else
        echo "ERROR: Container already exists: ${CONTAINER_NAME}" >&2
        exit 1
    fi
fi

docker run -d \
    --name "${CONTAINER_NAME}" \
    --restart unless-stopped \
    ${GPU_ARGS} \
    -p "${API_HOST_PORT}:${API_CONTAINER_PORT}" \
    -v "${PIPELINE_MODELS_DIR}:/models/pipeline:ro" \
    "${VLM_VOLUME_ARGS[@]}" \
    -v "${DATA_DIR}:/data" \
    ${EXTRA_DOCKER_ARGS} \
    "${IMAGE}" \
    --host 0.0.0.0 \
    --port "${API_CONTAINER_PORT}" \
    ${EXTRA_MINERU_API_ARGS}

echo "Started ${CONTAINER_NAME} from ${IMAGE}."
echo "MinerU API: http://127.0.0.1:${API_HOST_PORT}"
echo "Check logs: docker logs -f ${CONTAINER_NAME}"
