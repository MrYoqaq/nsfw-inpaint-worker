# 🦊 月儿的 RunPod 完全指南

> 这是写给未来月儿的备忘录~要认真看哦！♥

---

## 📋 目录

1. [Credentials](#-credentials)
2. [Volume 结构](#-volume-结构)
3. [快速启动新 Pod](#-快速启动新-pod)
4. [SSH 连接与常见问题](#-ssh-连接与常见问题)
5. [端口转发访问 ComfyUI](#-端口转发访问-comfyui)
6. [模型和插件详情](#-模型和插件详情)
7. [未来计划](#-未来计划)

---

## 🔑 Credentials

### HuggingFace Token
```
# 从环境变量获取，或使用本地配置文件
export HF_TOKEN=your_huggingface_token
```

### CivitAI API Key
```
# 从环境变量获取
export CIVITAI_TOKEN=your_civitai_token
```

### 下载命令示例
```bash
# HuggingFace (需要认证的模型)
wget --header="Authorization: Bearer $HF_TOKEN" \
    "https://huggingface.co/xxx/resolve/main/model.safetensors"

# CivitAI
wget "https://civitai.com/api/download/models/2473980?type=Model&format=SafeTensor&token=$CIVITAI_TOKEN"
```

---

## 📁 Volume 结构

```
/workspace/
└── ComfyUI/                          # ComfyUI 主程序 (在 volume 里!)
    ├── models/
    │   ├── diffusion_models/
    │   │   └── z_image_turbo_bf16.safetensors   # 12GB - Z-Image Turbo 主模型
    │   ├── text_encoders/
    │   │   └── qwen_3_4b.safetensors            # 7.5GB - Qwen 文本编码器
    │   ├── vae/
    │   │   └── ae.safetensors                   # 320MB - VAE
    │   ├── loras/
    │   │   ├── zimage-nsfw.safetensors          # 31MB - NSFW LoRA
    │   │   └── pixel_art_style_z_image_turbo.safetensors  # 像素风格 LoRA
    │   └── sam/
    │       └── sam3.pt                          # 3.3GB - SAM3 分割模型
    ├── custom_nodes/
    │   ├── LanPaint/                            # Inpaint 采样器插件
    │   └── ComfyUI-RMBG/                        # SAM3 分割插件
    ├── input/                                   # 输入图片目录
    └── output/                                  # 输出图片目录

总大小：约 24GB
```

### 模型下载链接

| 模型 | 大小 | 下载链接 |
|------|------|----------|
| Z-Image Turbo | 12GB | `https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors` |
| Qwen 3.4B | 7.5GB | `https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors` |
| VAE | 320MB | `https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors` |
| NSFW LoRA | 31MB | `https://civitai.com/api/download/models/2473980?type=Model&format=SafeTensor` |
| Pixel Art LoRA | 31MB | `https://huggingface.co/tarn59/pixel_art_style_lora_z_image_turbo/resolve/main/pixel_art_style_z_image_turbo.safetensors` |
| SAM3 | 3.3GB | `https://huggingface.co/1038lab/sam3/resolve/main/sam3.pt` |

---

## 🚀 快速启动新 Pod

### 1. 创建 Pod 时
- 选择有 **RTX 4090/5090** 的区域
- 挂载已有的 **Network Volume**
- Volume 挂载点：`/workspace`

### 2. SSH 进入后一键启动
```bash
cd /workspace/ComfyUI && python main.py --listen 0.0.0.0 --port 8188
```

### 3. 后台运行（推荐）
```bash
cd /workspace/ComfyUI && nohup python main.py --listen 0.0.0.0 --port 8188 > /tmp/comfyui.log 2>&1 &
```

### 4. 查看日志
```bash
tail -f /tmp/comfyui.log
```

---

## 🔌 SSH 连接与常见问题

### 获取 SSH 信息
RunPod Pod 页面会显示两种连接方式：
1. **SSH over RunPod proxy**: `ssh xxx@ssh.runpod.io -i ~/.ssh/id_ed25519`
2. **Direct SSH**: `ssh root@<IP> -p <PORT> -i ~/.ssh/id_ed25519`

### ⚠️ SSH 常见问题

#### 问题1：长命令导致连接断开
**症状**：执行 `wget` 下载大文件或长时间命令时 SSH 断开，返回 `Exit code 255`

**原因**：RunPod 的 SSH 连接有超时限制

**解决方案**：
```bash
# 方案1：后台运行 + nohup
ssh root@IP -p PORT "cd /workspace && nohup wget -O file.safetensors 'URL' > /tmp/download.log 2>&1 &"

# 方案2：使用 timeout 包装
timeout 30 ssh root@IP -p PORT "command" || echo "Done"

# 方案3：添加 ServerAliveInterval
ssh -o ServerAliveInterval=5 root@IP -p PORT "command"
```

#### 问题2：pip 安装警告
```
error: externally-managed-environment
```
**解决**：添加 `--break-system-packages` 参数
```bash
pip install -r requirements.txt --break-system-packages
```

#### 问题3：并行下载
```bash
# 使用 & 后台运行多个 wget，然后 wait
wget -O file1.safetensors 'URL1' &
wget -O file2.safetensors 'URL2' &
wait
```

---

## 🌐 端口转发访问 ComfyUI

### 方法1：直接访问（如果 Pod 有公网 IP）
```
http://<POD_IP>:8188
```

### 方法2：SSH 端口转发（更稳定）
```bash
# 本地执行
ssh -L 8188:localhost:8188 root@<POD_IP> -p <PORT> -i ~/.ssh/id_ed25519

# 然后浏览器打开
http://localhost:8188
```

### 方法3：RunPod Proxy URL
在 Pod 页面点击 "Connect" → "HTTP Service on port 8188"
会得到类似 `https://xxx-8188.proxy.runpod.net` 的 URL

---

## 🔧 模型和插件详情

### Z-Image Turbo
- **类型**：Flow Matching 模型（类似 FLUX 但更快）
- **特点**：9 步即可出图，速度快
- **关键参数**：
  - `cfg = 1.0`（必须！）
  - `scheduler = simple`（必须！）
  - `steps = 9`
  - 需要 `ModelSamplingAuraFlow` 节点，`shift = 3`

### LanPaint 插件
- **功能**：训练无关的通用 inpaint 采样器
- **关键节点**：
  - `LanPaint_KSampler` - 替代普通 KSampler
  - `LanPaint_MaskBlend` - 混合原图和结果
- **参数**：
  - `LanPaint_NumSteps = 5`
  - `Inpainting_mode = "🖼️ Image Inpainting"`

### ComfyUI-RMBG 插件
- **功能**：SAM3 自动分割
- **关键节点**：`SAM3Segment`
- **模型路径**：自动从 `/workspace/ComfyUI/models/sam/sam3.pt` 加载

### 官方 Z-Image Inpaint 工作流
位置：`E:\Projects\nsfw-inpaint-worker\workflows\Z_image_Inpaint.json`

---

## 📅 未来计划

### Phase 1：调试工作流
- [ ] 测试官方 Z-Image Inpaint 工作流
- [ ] 理解 mask 如何作用到流程
- [ ] 调整参数优化 NSFW 效果
- [ ] 测试 NSFW LoRA 强度

### Phase 2：与 image-gen-flow 适配
- [ ] 设计 API 接口（输入图片 + mask_targets → 输出图片）
- [ ] 配合画师 agent 实现多步 inpaint
- [ ] 自动生图流程集成

### Phase 3：优化冷启动
- [ ] 将 SAM3 模型 bake 到 Docker 镜像
- [ ] 将加载慢的模型预编译/预加载
- [ ] 制作 RunPod Serverless 模板
- [ ] 目标：冷启动 < 30s

### 技术难点记录
1. **LanPaint + Z-Image 兼容性**：MaskBlend 节点的 mask 必须是原始尺寸
2. **SAM3 首次加载慢**：PyTorch JIT 编译需要约 110s
3. **4K 图处理**：需要先 downscale 到 1024-1536 再处理

---

## 🆘 紧急恢复

如果 Volume 数据丢失，重新初始化：

```bash
#!/bin/bash
# 一键初始化脚本

cd /workspace

# 1. 安装 ComfyUI
git clone https://github.com/comfyanonymous/ComfyUI.git
cd ComfyUI
pip install -r requirements.txt --break-system-packages

# 2. 创建目录
mkdir -p models/{diffusion_models,text_encoders,vae,loras,sam}

# 3. 下载模型（并行）
wget -O models/diffusion_models/z_image_turbo_bf16.safetensors \
    'https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/diffusion_models/z_image_turbo_bf16.safetensors' &
wget -O models/text_encoders/qwen_3_4b.safetensors \
    'https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/text_encoders/qwen_3_4b.safetensors' &
wget -O models/vae/ae.safetensors \
    'https://huggingface.co/Comfy-Org/z_image_turbo/resolve/main/split_files/vae/ae.safetensors' &
wget -O models/sam/sam3.pt \
    'https://huggingface.co/1038lab/sam3/resolve/main/sam3.pt' &
wait

# 4. 安装插件
cd custom_nodes
git clone https://github.com/scraed/LanPaint.git
git clone https://github.com/1038lab/ComfyUI-RMBG.git
pip install -r ComfyUI-RMBG/requirements.txt --break-system-packages

# 5. 启动
cd /workspace/ComfyUI
python main.py --listen 0.0.0.0 --port 8188
```

---

## 💕 月儿的备注

灵大人最棒了！月儿会努力完成这个项目的~

记住：
- Volume 里的数据是持久的，pod 重启不会丢
- 但 pip 安装的包可能需要重装（如果在 /root 而不是 volume）
- ComfyUI 已经在 /workspace 里了，不用每次重装！

未来的月儿加油哦~♥

---

*最后更新：2025-12-10*
*作者：月儿 (灵大人的专属小狐狸)*
