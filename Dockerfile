# =============================================================================
# 🦊 NSFW Inpaint Worker - RunPod Serverless
# Made with ♥ by 月儿 for 灵大人
#
# 优化原则：
# ✅ Bake: ComfyUI + 节点 + 依赖 + Handler（需要安装/编译的）
# ❌ Volume: 所有模型文件（大文件，方便更新）
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
# PyTorch 2.8 with CUDA 12.8
# =============================================================================
RUN pip install torch torchvision torchaudio --index-url https://download.pytorch.org/whl/cu128

# =============================================================================
# 安装 ComfyUI
# =============================================================================
RUN git clone https://github.com/comfyanonymous/ComfyUI.git ${COMFYUI_PATH} && \
    cd ${COMFYUI_PATH} && \
    pip install -r requirements.txt

# =============================================================================
# 安装自定义节点（这些需要 pip install，所以 bake 进来）
# =============================================================================
RUN cd ${COMFYUI_PATH}/custom_nodes && \
    # ComfyUI Manager
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git && \
    # ComfyUI-RMBG (SAM3 + 衣服分割)
    git clone https://github.com/1038lab/ComfyUI-RMBG.git && \
    # Inpaint CropAndStitch (4K 图裁剪处理)
    git clone https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git && \
    # ControlNet Aux (DWPose 等预处理器)
    git clone https://github.com/Fannovel16/comfyui_controlnet_aux.git && \
    # Impact Pack (常用工具节点)
    git clone https://github.com/ltdrdata/ComfyUI-Impact-Pack.git

# 安装节点依赖
RUN cd ${COMFYUI_PATH}/custom_nodes/ComfyUI-RMBG && pip install -r requirements.txt
RUN cd ${COMFYUI_PATH}/custom_nodes/comfyui_controlnet_aux && pip install -r requirements.txt
RUN cd ${COMFYUI_PATH}/custom_nodes/ComfyUI-Impact-Pack && \
    pip install -r requirements.txt && \
    python install.py
RUN pip install GitPython toml rich

# =============================================================================
# 🔥 模型目录：全部软链接到 Network Volume
# =============================================================================
# 删除 ComfyUI 默认的模型目录，创建软链接
RUN rm -rf ${COMFYUI_PATH}/models/checkpoints && \
    rm -rf ${COMFYUI_PATH}/models/vae && \
    rm -rf ${COMFYUI_PATH}/models/loras && \
    rm -rf ${COMFYUI_PATH}/models/controlnet && \
    rm -rf ${COMFYUI_PATH}/models/clip && \
    rm -rf ${COMFYUI_PATH}/models/unet && \
    rm -rf ${COMFYUI_PATH}/models/sam3 && \
    mkdir -p /runpod-volume/models/checkpoints && \
    mkdir -p /runpod-volume/models/vae && \
    mkdir -p /runpod-volume/models/loras && \
    mkdir -p /runpod-volume/models/controlnet && \
    mkdir -p /runpod-volume/models/clip && \
    mkdir -p /runpod-volume/models/unet && \
    mkdir -p /runpod-volume/models/sam3 && \
    ln -sf /runpod-volume/models/checkpoints ${COMFYUI_PATH}/models/checkpoints && \
    ln -sf /runpod-volume/models/vae ${COMFYUI_PATH}/models/vae && \
    ln -sf /runpod-volume/models/loras ${COMFYUI_PATH}/models/loras && \
    ln -sf /runpod-volume/models/controlnet ${COMFYUI_PATH}/models/controlnet && \
    ln -sf /runpod-volume/models/clip ${COMFYUI_PATH}/models/clip && \
    ln -sf /runpod-volume/models/unet ${COMFYUI_PATH}/models/unet && \
    ln -sf /runpod-volume/models/sam3 ${COMFYUI_PATH}/models/sam3

# ControlNet Aux 的模型目录（DWPose ONNX 等）
RUN rm -rf ${COMFYUI_PATH}/custom_nodes/comfyui_controlnet_aux/ckpts && \
    mkdir -p /runpod-volume/models/controlnet_aux && \
    ln -sf /runpod-volume/models/controlnet_aux ${COMFYUI_PATH}/custom_nodes/comfyui_controlnet_aux/ckpts

# Impact Pack 的模型目录
RUN mkdir -p /runpod-volume/models/ultralytics && \
    mkdir -p /runpod-volume/models/sams && \
    ln -sf /runpod-volume/models/ultralytics ${COMFYUI_PATH}/models/ultralytics && \
    ln -sf /runpod-volume/models/sams ${COMFYUI_PATH}/models/sams

# =============================================================================
# 复制 Handler 代码和工作流
# =============================================================================
COPY requirements.txt /requirements.txt
RUN pip install -r /requirements.txt

COPY src/handler.py /handler.py
COPY src/comfy_api.py /comfy_api.py
COPY workflows/ /workflows/

# =============================================================================
# 启动
# =============================================================================
WORKDIR /

EXPOSE 8188

CMD ["python", "/handler.py"]
