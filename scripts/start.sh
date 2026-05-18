#!/usr/bin/env bash
set -Eeuo pipefail

if [[ -z "${COMFYUI_DIR:-}" ]]; then
  for candidate in \
    /opt/ComfyUI \
    /workspace/ComfyUI \
    /workspace/comfyui \
    /comfyui \
    /ComfyUI \
    /app/ComfyUI; do
    if [[ -f "${candidate}/main.py" ]]; then
      COMFYUI_DIR="${candidate}"
      break
    fi
  done
fi

if [[ -z "${COMFYUI_DIR:-}" ]]; then
  found_main="$(find /opt /workspace /app /comfyui /ComfyUI -maxdepth 4 -type f -name main.py 2>/dev/null | head -n 1 || true)"
  if [[ -n "${found_main}" ]]; then
    COMFYUI_DIR="$(dirname "${found_main}")"
  fi
fi

if [[ -z "${COMFYUI_DIR:-}" || ! -f "${COMFYUI_DIR}/main.py" ]]; then
  echo "ERROR: could not find ComfyUI main.py. Set COMFYUI_DIR explicitly." >&2
  exit 2
fi

WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace/comfyui}"
MODEL_ROOT="${MODEL_ROOT:-${WORKSPACE_DIR}}"
CONFIG_DIR="${CONFIG_DIR:-/workspace/config}"
MODEL_MANIFEST="${MODEL_MANIFEST:-${CONFIG_DIR}/models.json}"
PORT="${PORT:-8188}"
LISTEN="${LISTEN:-0.0.0.0}"

mkdir -p "${WORKSPACE_DIR}/input" \
         "${WORKSPACE_DIR}/output" \
         "${MODEL_ROOT}/models/checkpoints" \
         "${MODEL_ROOT}/models/loras" \
         "${MODEL_ROOT}/models/vae" \
         "${MODEL_ROOT}/models/clip" \
         "${MODEL_ROOT}/models/unet" \
         "${MODEL_ROOT}/models/controlnet" \
         "${CONFIG_DIR}"

write_extra_model_paths() {
  local target="$1"
  cat > "${target}" <<YAML
workspace:
  base_path: ${MODEL_ROOT}
  checkpoints: models/checkpoints/
  clip: models/clip/
  clip_vision: models/clip_vision/
  configs: models/configs/
  controlnet: models/controlnet/
  diffusion_models: models/diffusion_models/
  embeddings: models/embeddings/
  loras: models/loras/
  style_models: models/style_models/
  unet: models/unet/
  upscale_models: models/upscale_models/
  vae: models/vae/
  vae_approx: models/vae_approx/
YAML
}

write_extra_model_paths "${COMFYUI_DIR}/extra_model_paths.yaml"
write_extra_model_paths "${COMFYUI_DIR}/extra_model_paths.yml"

if [[ -n "${MODEL_MANIFEST_JSON:-}" ]]; then
  printf '%s' "${MODEL_MANIFEST_JSON}" > "${MODEL_MANIFEST}"
elif [[ -n "${MODEL_MANIFEST_URL:-}" ]]; then
  python - "${MODEL_MANIFEST_URL}" "${MODEL_MANIFEST}" <<'PY'
import pathlib
import sys
import urllib.request

url, output = sys.argv[1], pathlib.Path(sys.argv[2])
output.parent.mkdir(parents=True, exist_ok=True)
request = urllib.request.Request(url, headers={"User-Agent": "runpod-comfyui-template"})
with urllib.request.urlopen(request, timeout=60) as response:
    output.write_bytes(response.read())
PY
fi

if [[ -f "${MODEL_MANIFEST}" ]]; then
  python /opt/runpod-comfy/scripts/download_models.py \
    --manifest "${MODEL_MANIFEST}" \
    --root "${MODEL_ROOT}"
else
  echo "No model manifest found at ${MODEL_MANIFEST}; starting without model downloads."
fi

if [[ "${RUN_DEP_CHECK:-0}" == "1" ]]; then
  python /opt/runpod-comfy/scripts/check_env.py --comfyui-dir "${COMFYUI_DIR}"
fi

cd "${COMFYUI_DIR}"
exec python main.py \
  --listen "${LISTEN}" \
  --port "${PORT}" \
  --enable-cors-header "${COMFYUI_CORS_ORIGIN:-*}" \
  --input-directory "${WORKSPACE_DIR}/input" \
  --output-directory "${WORKSPACE_DIR}/output" \
  ${COMFYUI_ARGS:-}
