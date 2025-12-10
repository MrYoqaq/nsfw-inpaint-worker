#!/bin/bash
# =============================================================================
# Pod 一键部署脚本 - FLUX 版本
# 在新 Pod 里运行这个脚本即可启动 ComfyUI
# =============================================================================

set -e

echo "🦊 月儿开始部署 ComfyUI (FLUX 版本)..."

# =============================================================================
# 1. 安装 ComfyUI 到 Container Disk
# =============================================================================
echo "📦 安装 ComfyUI..."
cd /root
if [ ! -d "ComfyUI" ]; then
    git clone https://github.com/comfyanonymous/ComfyUI.git
    cd ComfyUI
    pip install -r requirements.txt --break-system-packages -q
else
    echo "ComfyUI 已存在，跳过克隆"
    cd ComfyUI
fi

# =============================================================================
# 2. 创建模型软链接到 Volume（FLUX 结构）
# =============================================================================
echo "🔗 创建模型软链接..."
cd /root/ComfyUI/models

# FLUX 模型结构
rm -rf unet 2>/dev/null || true
ln -sf /workspace/models/unet unet

rm -rf loras 2>/dev/null || true
ln -sf /workspace/models/loras loras

rm -rf clip 2>/dev/null || true
ln -sf /workspace/models/clip clip

rm -rf vae 2>/dev/null || true
ln -sf /workspace/models/vae vae

# SAM3 模型软链接（RMBG 期望在 models/sam3/ 目录）
rm -rf sam3 2>/dev/null || true
mkdir -p sam3
ln -sf /workspace/models/sam/sam3.pt sam3/sam3.pt

# =============================================================================
# 3. 安装自定义节点
# =============================================================================
echo "🧩 安装自定义节点..."
cd /root/ComfyUI/custom_nodes

# ComfyUI-Manager
if [ ! -d "ComfyUI-Manager" ]; then
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git
fi

# ComfyUI-RMBG (SAM3 + 衣服分割，包含33个节点)
if [ ! -d "ComfyUI-RMBG" ]; then
    git clone https://github.com/1038lab/ComfyUI-RMBG.git
    cd ComfyUI-RMBG && pip install -r requirements.txt --break-system-packages -q && cd ..
fi

# ComfyUI-Inpaint-CropAndStitch (4K图必须裁剪处理)
if [ ! -d "ComfyUI-Inpaint-CropAndStitch" ]; then
    git clone https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git
fi

# =============================================================================
# 4. 安装额外依赖
# =============================================================================
echo "📚 安装额外依赖..."
pip install GitPython toml rich --break-system-packages -q

# =============================================================================
# 5. 启动 ComfyUI
# =============================================================================
echo "🚀 启动 ComfyUI..."
cd /root/ComfyUI
nohup python main.py --listen 0.0.0.0 --port 8188 > /tmp/comfyui.log 2>&1 &

sleep 10

echo ""
echo "============================================="
echo "✅ 部署完成！(FLUX 版本)"
echo "============================================="
echo ""
echo "📍 ComfyUI 地址: http://localhost:8188"
echo "   (通过 SSH 端口转发访问)"
echo ""
echo "📂 模型位置 (Volume - FLUX 结构):"
echo "   /workspace/models/unet/              (FLUX Fill Dev)"
echo "   /workspace/models/loras/             (NSFW LoRA)"
echo "   /workspace/models/clip/              (CLIP + T5XXL)"
echo "   /workspace/models/vae/               (FLUX VAE)"
echo "   /workspace/models/sam/sam3.pt        (3.5GB, SAM3)"
echo ""
echo "📋 查看日志: tail -f /tmp/comfyui.log"
echo "============================================="
