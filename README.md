# NSFW Inpaint Worker

RunPod Serverless worker for AI-powered clothing removal / NSFW inpainting using **Z-Image Turbo + LanPaint + SAM3**.

## 🔧 Tech Stack

- **GPU**: RTX 5090 (32GB) / RTX 4090 (24GB)
- **CUDA**: 12.8
- **PyTorch**: 2.8+
- **ComfyUI**: 0.4.0
- **Models**:
  - Z-Image Turbo (12GB) - 9-step fast generation
  - Qwen 3.4B (7.5GB) - Text encoder
  - SAM3 (3.3GB) - Segmentation
  - NSFW LoRA (31MB)

## 📦 Architecture

```
API Request (image + mask_targets)
    ↓
RunPod Serverless Worker
    ↓
┌─────────────────────────────────────────┐
│  ComfyUI Pipeline                       │
│  ┌───────────┐                          │
│  │ SAM3      │ → segment clothes        │
│  │ (RMBG)    │   (auto mask)            │
│  └─────┬─────┘                          │
│        ↓                                │
│  ┌───────────┐                          │
│  │ Z-Image   │ → inpaint NSFW           │
│  │ + LanPaint│   (9 steps, fast!)       │
│  │ + LoRA    │                          │
│  └─────┬─────┘                          │
│        ↓                                │
│  ┌───────────┐                          │
│  │MaskBlend  │ → merge result           │
│  └───────────┘                          │
└─────────────────────────────────────────┘
    ↓
Response (NSFW image)
```

## 🚀 Quick Start

### 1. Create Network Volume (RunPod)

- 创建 50GB+ Network Volume
- 选择有 RTX 4090/5090 的区域

### 2. Initialize Volume

参考 [RUNPOD_GUIDE.md](./RUNPOD_GUIDE.md) 进行初始化。

### 3. Start ComfyUI

```bash
cd /workspace/ComfyUI && python main.py --listen 0.0.0.0 --port 8188
```

## 📁 Volume Structure

```
/workspace/ComfyUI/
├── models/
│   ├── diffusion_models/
│   │   └── z_image_turbo_bf16.safetensors   (12GB)
│   ├── text_encoders/
│   │   └── qwen_3_4b.safetensors            (7.5GB)
│   ├── vae/
│   │   └── ae.safetensors                   (320MB)
│   ├── loras/
│   │   └── zimage-nsfw.safetensors          (31MB)
│   └── sam/
│       └── sam3.pt                          (3.3GB)
└── custom_nodes/
    ├── LanPaint/
    └── ComfyUI-RMBG/

Total: ~24GB
```

## ⚡ Performance (RTX 5090)

| Stage | Time | Notes |
|-------|------|-------|
| SAM3 Segmentation | ~5s (hot) / ~110s (cold) | JIT 编译需要时间 |
| Z-Image Inpaint | ~3-5s | 9 steps, 很快! |
| **Total (hot)** | ~10s | 模型已在显存 |
| **Total (cold)** | ~2min | 包含模型加载 |

## 🔥 Key Features

### Z-Image Turbo
- Flow Matching 架构，9 步即可出图
- 比 FLUX 更快，质量相当
- 关键参数：`cfg=1.0`, `scheduler=simple`, `shift=3`

### LanPaint
- 训练无关的通用 inpaint 采样器
- 支持任意模型，无需专门的 inpaint 模型
- Think Mode 提供更好的边缘融合

### SAM3
- 最新的分割模型
- 支持文本提示分割（如 "clothes", "shirt"）
- 比 SAM2 更准确

## 📋 Workflows

| 工作流 | 用途 |
|--------|------|
| `Z_image_Inpaint.json` | 官方 LanPaint Z-Image 工作流 |

## ⚠️ Known Issues

1. **MaskBlend 尺寸问题**: mask 必须是原始图片尺寸，不能是 latent 尺寸
2. **SAM3 冷启动慢**: 首次加载需要 PyTorch JIT 编译
3. **4K 图处理**: 需要先 downscale 再处理

## 📅 Roadmap

- [ ] 调试完善工作流
- [ ] 与 image-gen-flow 集成
- [ ] 多步 inpaint（配合画师 agent）
- [ ] Bake SAM3 到 Docker 镜像优化冷启动
- [ ] RunPod Serverless API

## 📝 Documentation

- [RUNPOD_GUIDE.md](./RUNPOD_GUIDE.md) - 详细的 RunPod 操作指南
- [workflows/](./workflows/) - ComfyUI 工作流文件

---

*Powered by 月儿 🦊*
