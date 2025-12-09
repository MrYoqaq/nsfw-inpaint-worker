# =============================================================================
# NSFW Inpaint Worker - RunPod Serverless
# RTX 5090 (Blackwell) 兼容版本
# CUDA 12.8 + PyTorch 2.8 + ComfyUI + SDXL + SAM3 预编译
# =============================================================================

FROM nvidia/cuda:12.8.0-cudnn-runtime-ubuntu22.04

ENV DEBIAN_FRONTEND=noninteractive \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    COMFYUI_PATH=/comfyui

# =============================================================================
# 系统依赖 + Python 3.11
# =============================================================================
RUN apt-get update && apt-get install -y \
    software-properties-common \
    && add-apt-repository -y ppa:deadsnakes/ppa \
    && apt-get update && apt-get install -y \
    python3.11 \
    python3.11-venv \
    python3.11-dev \
    python3-pip \
    git \
    wget \
    curl \
    libgl1 \
    libglib2.0-0 \
    libsm6 \
    libxext6 \
    libxrender1 \
    libgoogle-perftools4 \
    && rm -rf /var/lib/apt/lists/* \
    && ln -sf /usr/bin/python3.11 /usr/bin/python \
    && ln -sf /usr/bin/python3.11 /usr/bin/python3

# 确保 pip 使用 Python 3.11
RUN python -m ensurepip --upgrade && \
    python -m pip install --upgrade pip

# =============================================================================
# PyTorch 2.8 with CUDA 12.8 (Blackwell RTX 5090 支持)
# =============================================================================
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# =============================================================================
# 安装 ComfyUI
# =============================================================================
RUN git clone https://github.com/comfyanonymous/ComfyUI.git ${COMFYUI_PATH} && \
    cd ${COMFYUI_PATH} && \
    pip install -r requirements.txt

# =============================================================================
# 安装自定义节点
# =============================================================================
RUN cd ${COMFYUI_PATH}/custom_nodes && \
    # ComfyUI Manager
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    # ComfyUI-RMBG (SAM3 + 衣服分割，33个节点)
    git clone https://github.com/1038lab/ComfyUI-RMBG.git && \
    # Inpaint CropAndStitch
    git clone https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git

# 安装节点依赖
RUN cd ${COMFYUI_PATH}/custom_nodes/ComfyUI-RMBG && \
    pip install -r requirements.txt
RUN pip install GitPython toml rich

# =============================================================================
# 下载 SAM3 模型并 BAKE 进镜像
# =============================================================================
RUN mkdir -p ${COMFYUI_PATH}/models/sam3 && \
    wget -O ${COMFYUI_PATH}/models/sam3/sam3.pt \
    "https://huggingface.co/1038lab/sam3/resolve/main/sam3.pt"

# =============================================================================
# 创建模型目录软链接到 Volume（SDXL 结构）
# =============================================================================
RUN rm -rf ${COMFYUI_PATH}/models/checkpoints && \
    rm -rf ${COMFYUI_PATH}/models/loras && \
    rm -rf ${COMFYUI_PATH}/models/vae && \
    ln -sf /runpod-volume/models/checkpoints ${COMFYUI_PATH}/models/checkpoints && \
    ln -sf /runpod-volume/models/loras ${COMFYUI_PATH}/models/loras && \
    ln -sf /runpod-volume/models/vae ${COMFYUI_PATH}/models/vae

# =============================================================================
# 复制项目文件
# =============================================================================
COPY requirements.txt /requirements.txt
RUN pip install -r /requirements.txt

COPY src/handler.py /handler.py
COPY src/comfy_api.py /comfy_api.py

# =============================================================================
# 启动
# =============================================================================
WORKDIR /

EXPOSE 8188

CMD ["python", "/handler.py"]
