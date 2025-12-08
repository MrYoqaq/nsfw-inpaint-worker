#!/bin/bash
# =============================================================================
# Pod 一键部署脚本
# 在新 Pod 里运行这个脚本即可启动 ComfyUI
# =============================================================================

set -e

echo "🦊 月儿开始部署 ComfyUI..."

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
# 2. 创建模型软链接到 Volume
# =============================================================================
echo "🔗 创建模型软链接..."
cd /root/ComfyUI/models
rm -rf checkpoints unet loras clip vae 2>/dev/null || true
ln -sf /workspace/models/unet unet
ln -sf /workspace/models/loras loras
ln -sf /workspace/models/clip clip
ln -sf /workspace/models/vae vae
mkdir -p sam
ln -sf /workspace/models/sam/sam3.safetensors sam/sam3.safetensors

# =============================================================================
# 3. 安装自定义节点
# =============================================================================
echo "🧩 安装自定义节点..."
cd /root/ComfyUI/custom_nodes

# ComfyUI-Manager
if [ ! -d "ComfyUI-Manager" ]; then
    git clone https://github.com/ltdrdata/ComfyUI-Manager.git
fi

# ComfyUI-RMBG (SAM3 + 衣服分割)
if [ ! -d "ComfyUI-RMBG" ]; then
    git clone https://github.com/1038lab/ComfyUI-RMBG.git
    cd ComfyUI-RMBG && pip install -r requirements.txt --break-system-packages -q && cd ..
fi

# comfyui_sam3
if [ ! -d "comfyui_sam3" ]; then
    git clone https://github.com/wouterverweirder/comfyui_sam3.git
    cd comfyui_sam3 && pip install -r requirements.txt --break-system-packages -q 2>/dev/null || true && cd ..
fi

# ComfyUI-Inpaint-CropAndStitch
if [ ! -d "ComfyUI-Inpaint-CropAndStitch" ]; then
    git clone https://github.com/lquesada/ComfyUI-Inpaint-CropAndStitch.git
fi

# =============================================================================
# 4. 安装额外依赖
# =============================================================================
echo "📚 安装额外依赖..."
pip install GitPython toml --break-system-packages -q

# =============================================================================
# 5. 启动 ComfyUI
# =============================================================================
echo "🚀 启动 ComfyUI..."
cd /root/ComfyUI
nohup python main.py --listen 0.0.0.0 --port 8188 > /tmp/comfyui.log 2>&1 &

sleep 10

echo ""
echo "============================================="
echo "✅ 部署完成！"
echo "============================================="
echo ""
echo "📍 ComfyUI 地址: http://localhost:8188"
echo "   (通过 SSH 端口转发访问)"
echo ""
echo "📂 模型位置 (Volume):"
echo "   /workspace/models/unet/flux1-fill-dev.safetensors"
echo "   /workspace/models/loras/flux_uncensored_v2.safetensors"
echo "   /workspace/models/sam/sam3.safetensors"
echo ""
echo "📋 查看日志: tail -f /tmp/comfyui.log"
echo "============================================="
