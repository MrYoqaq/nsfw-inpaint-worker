#!/bin/bash
# =============================================================================
# Volume 初始化脚本 - 下载所有需要的模型
# 在 RunPod Pod 中运行一次来初始化 Network Volume
# =============================================================================

set -e

VOLUME_PATH="/runpod-volume"
MODELS_PATH="${VOLUME_PATH}/models"

echo "🦊 开始初始化 Volume..."

# 创建目录结构
mkdir -p ${MODELS_PATH}/{unet,loras,clip,vae,sam}

cd ${MODELS_PATH}

# =============================================================================
# FLUX.1 Fill Dev (Inpaint 模型)
# =============================================================================
echo "📥 下载 FLUX.1-Fill-dev..."
if [ ! -f "unet/flux1-fill-dev.safetensors" ]; then
    wget -O unet/flux1-fill-dev.safetensors \
        "https://huggingface.co/black-forest-labs/FLUX.1-Fill-dev/resolve/main/flux1-fill-dev.safetensors"
fi

# =============================================================================
# FLUX CLIP 和 VAE
# =============================================================================
echo "📥 下载 FLUX CLIP..."
if [ ! -f "clip/clip_l.safetensors" ]; then
    wget -O clip/clip_l.safetensors \
        "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/clip_l.safetensors"
fi

if [ ! -f "clip/t5xxl_fp16.safetensors" ]; then
    wget -O clip/t5xxl_fp16.safetensors \
        "https://huggingface.co/comfyanonymous/flux_text_encoders/resolve/main/t5xxl_fp16.safetensors"
fi

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
# SAM3 模型
# =============================================================================
echo "📥 下载 SAM3..."
if [ ! -f "sam/sam3_hiera_large.pt" ]; then
    wget -O sam/sam3_hiera_large.pt \
        "https://dl.fbaipublicfiles.com/segment_anything_3/sam3_hiera_large.pt"
fi

# =============================================================================
# 完成
# =============================================================================
echo ""
echo "✅ Volume 初始化完成！"
echo ""
echo "模型列表："
find ${MODELS_PATH} -type f -name "*.safetensors" -o -name "*.pt" | while read f; do
    size=$(du -h "$f" | cut -f1)
    echo "  $size  $f"
done

echo ""
echo "总大小："
du -sh ${MODELS_PATH}
