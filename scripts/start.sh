#!/usr/bin/env bash
set -Eeuo pipefail

COMFYUI_DIR="${COMFYUI_DIR:-/opt/ComfyUI}"
WORKSPACE_DIR="${WORKSPACE_DIR:-/workspace/ComfyUI}"
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

cat > "${COMFYUI_DIR}/extra_model_paths.yaml" <<YAML
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

if [[ -n "${MODEL_MANIFEST_JSON:-}" ]]; then
  printf '%s' "${MODEL_MANIFEST_JSON}" > "${MODEL_MANIFEST}"
elif [[ -n "${MODEL_MANIFEST_URL:-}" ]]; then
  curl -fsSL "${MODEL_MANIFEST_URL}" -o "${MODEL_MANIFEST}"
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
