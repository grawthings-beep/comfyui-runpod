# syntax=docker/dockerfile:1.7

# Match the standard RunPod ComfyUI Pod template as closely as possible.
# Official docs use:
#   Standard GPUs:  runpod/comfyui:latest
#   Blackwell GPUs: runpod/comfyui:cuda12.8
ARG BASE_IMAGE=runpod/comfyui:latest

FROM ${BASE_IMAGE}

ENV PYTHONUNBUFFERED=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

COPY config/ /opt/runpod-comfy/config/
COPY scripts/ /opt/runpod-comfy/scripts/
RUN chmod +x /opt/runpod-comfy/scripts/*.sh

EXPOSE 8188

ENTRYPOINT []
CMD ["/opt/runpod-comfy/scripts/start.sh"]
