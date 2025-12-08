# =============================================================================
# NSFW Inpaint Worker - RunPod Serverless
# RTX 5090 (Blackwell) 兼容版本
# CUDA 12.8 + PyTorch 2.8 + ComfyUI
# =============================================================================

FROM nvidia/cuda:12.8.0-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    COMFYUI_PATH=/comfyui

# 系统依赖
RUN apt-get update && apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3-pip \
    git \
    wget \
    curl \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3

# PyTorch 2.8 with CUDA 12.8 (Blackwell 支持)
RUN pip install --upgrade pip && \
    pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# 克隆 ComfyUI
RUN git clone https://github.com/comfyanonymous/ComfyUI.git ${COMFYUI_PATH} && \
    cd ${COMFYUI_PATH} && \
    pip install -r requirements.txt

# 安装 ComfyUI Manager
RUN cd ${COMFYUI_PATH}/custom_nodes && \
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git

# 安装必要的自定义节点
RUN cd ${COMFYUI_PATH}/custom_nodes && \
    # SAM3 节点
    git clone https://github.com/wouterverweirder/comfyui_sam3.git && \
    # Inpaint CropAndStitch
    git clone https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git && \
    # GGUF 支持 (量化模型)
    git clone https://github.com/city96/ComfyUI-GGUF.git

# 安装节点依赖
RUN cd ${COMFYUI_PATH}/custom_nodes/comfyui_sam3 && \
    pip install -r requirements.txt || true
RUN cd ${COMFYUI_PATH}/custom_nodes/ComfyUI-GGUF && \
    pip install -r requirements.txt || true

# RunPod SDK
RUN pip install runpod requests

# 复制 handler
COPY src/handler.py /handler.py
COPY src/comfy_api.py /comfy_api.py

# 创建模型目录软链接到 Volume
RUN mkdir -p /runpod-volume/models && \
    ln -sf /runpod-volume/models/checkpoints ${COMFYUI_PATH}/models/checkpoints && \
    ln -sf /runpod-volume/models/unet ${COMFYUI_PATH}/models/unet && \
    ln -sf /runpod-volume/models/loras ${COMFYUI_PATH}/models/loras && \
    ln -sf /runpod-volume/models/clip ${COMFYUI_PATH}/models/clip && \
    ln -sf /runpod-volume/models/vae ${COMFYUI_PATH}/models/vae && \
    ln -sf /runpod-volume/models/sam ${COMFYUI_PATH}/models/sam

WORKDIR /

CMD ["python", "/handler.py"]
