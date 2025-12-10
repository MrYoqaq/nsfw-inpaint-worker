#!/bin/bash
# =============================================================================
# Volume 初始化脚本 - 下载所有需要的模型 (FLUX 版本)
# 在 RunPod Pod 中运行一次来初始化 Network Volume
# =============================================================================

set -e

VOLUME_PATH="/workspace"
MODELS_PATH="${VOLUME_PATH}/models"

echo "🦊 开始初始化 Volume (FLUX 版本)..."

# 创建目录结构 (FLUX 专用)
mkdir -p ${MODELS_PATH}/{unet,loras,clip,vae,sam}

cd ${MODELS_PATH}

# =============================================================================
# FLUX.1 Fill Dev (Inpaint 模型) - 24GB
# =============================================================================
echo "📥 下载 FLUX.1-Fill-dev (24GB，需要较长时间)..."
if [ ! -f "unet/flux1-fill-dev.safetensors" ]; then
    wget -O unet/flux1-fill-dev.safetensors \
        "https://huggingface.co/black-forest-labs/FLUX.1-Fill-dev/resolve/main/flux1-fill-dev.safetensors"
fi

# =============================================================================
# FLUX CLIP 编码器
# =============================================================================
echo "📥 下载 FLUX CLIP..."
if [ ! -f "clip/clip_l.safetensors" ]; then
    wget -O clip/clip_l.safetensors \
        "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"
fi

echo "📥 下载 T5XXL (10GB)..."
if [ ! -f "clip/t5xxl_fp16.safetensors" ]; then
    wget -O clip/t5xxl_fp16.safetensors \
        "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors"
fi

# =============================================================================
# FLUX VAE
# =============================================================================
echo "📥 下载 FLUX VAE..."
if [ ! -f "vae/ae.safetensors" ]; then
    wget -O vae/ae.safetensors \
        "https://huggingface.co/black-forest-labs/FLUX.1-dev/resolve/main/ae.safetensors"
fi

# =============================================================================
# NSFW LoRA
# =============================================================================
echo "📥 下载 NSFW LoRA..."
if [ ! -f "loras/flux-uncensored-v2.safetensors" ]; then
    wget -O loras/flux-uncensored-v2.safetensors \
        "https://huggingface.co/enhanceaiteam/Flux-Uncensored-V2/resolve/main/flux-uncensored-v2.safetensors"
fi

# =============================================================================
# SAM3 模型 (3.5GB)
# 注意：RMBG 插件期望的文件名是 sam3.pt，在 models/sam3/ 目录
# 这里下载到 sam/ 目录，pod_setup.sh 会创建软链接
# =============================================================================
echo "📥 下载 SAM3 (3.5GB)..."
if [ ! -f "sam/sam3.pt" ]; then
    wget -O sam/sam3.pt \
        "https://huggingface.co/1038lab/sam3/resolve/main/sam3.pt"
fi

# =============================================================================
# 完成
# =============================================================================
echo ""
echo "✅ Volume 初始化完成！"
echo ""
echo "模型列表："
find ${MODELS_PATH} -type f \( -name "*.safetensors" -o -name "*.pt" \) | while read f; do
    size=$(du -h "$f" | cut -f1)
    echo "  $size  $f"
done

echo ""
echo "总大小："
du -sh ${MODELS_PATH}
echo ""
echo "============================================="
echo "📂 Volume 结构 (FLUX):"
echo "   ${MODELS_PATH}/unet/flux1-fill-dev.safetensors"
echo "   ${MODELS_PATH}/loras/flux-uncensored-v2.safetensors"
echo "   ${MODELS_PATH}/clip/clip_l.safetensors"
echo "   ${MODELS_PATH}/clip/t5xxl_fp16.safetensors"
echo "   ${MODELS_PATH}/vae/ae.safetensors"
echo "   ${MODELS_PATH}/sam/sam3.pt"
echo "============================================="
