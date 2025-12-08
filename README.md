# NSFW Inpaint Worker

RunPod Serverless worker for AI-powered clothing removal / NSFW inpainting.

## 🔧 Tech Stack

- **GPU**: RTX 5090 (Blackwell) compatible
- **CUDA**: 12.8
- **PyTorch**: 2.8+
- **ComfyUI**: Latest
- **Models**:
  - FLUX.1-Fill-dev (Inpainting)
  - SAM3 (Segmentation)
  - Flux-Uncensored-V2 (NSFW LoRA)

## 📦 Architecture

```
API Request (image + mask_targets)
    ↓
RunPod Serverless Worker
    ↓
┌─────────────────────────────────┐
│  ComfyUI Pipeline               │
│  ┌───────────┐                  │
│  │ SAM3      │ → segment clothes│
│  └─────┬─────┘                  │
│        ↓                        │
│  ┌───────────┐                  │
│  │ Crop      │ → extract region │
│  └─────┬─────┘                  │
│        ↓                        │
│  ┌───────────┐                  │
│  │FLUX Fill  │ → inpaint NSFW   │
│  └─────┬─────┘                  │
│        ↓                        │
│  ┌───────────┐                  │
│  │ Stitch    │ → merge back     │
│  └───────────┘                  │
└─────────────────────────────────┘
    ↓
Response (NSFW image)
```

## 🚀 Deployment

### 1. Create Network Volume

```bash
# On RunPod, create a Network Volume (50-100GB)
# Region: Choose one with RTX 5090 availability
```

### 2. Initialize Volume (run once)

```bash
# Start a temporary Pod with the volume attached
# Run the init script:
bash /scripts/init_volume.sh
```

### 3. Build & Push Docker Image

```bash
docker build -t your-registry/nsfw-inpaint-worker:latest .
docker push your-registry/nsfw-inpaint-worker:latest
```

### 4. Create Serverless Endpoint

- Template: Custom
- Image: `your-registry/nsfw-inpaint-worker:latest`
- GPU: RTX 5090
- Network Volume: Attach your volume

## 📡 API Usage

### Request

```json
POST /runsync
{
  "input": {
    "image": "<base64 encoded image>",
    "mask_targets": ["skirt", "shirt", "bra"],
    "prompt": "nude, naked, bare skin, natural body, realistic",
    "negative_prompt": "clothing, fabric, covered, censored"
  }
}
```

### Response

```json
{
  "output": {
    "image": "<base64 encoded result>",
    "time_taken": 25.3
  }
}
```

## 📁 Volume Structure

```
/runpod-volume/
└── models/
    ├── unet/
    │   └── flux1-fill-dev.safetensors (24GB)
    ├── loras/
    │   └── flux-uncensored-v2.safetensors
    ├── clip/
    │   ├── clip_l.safetensors
    │   └── t5xxl_fp16.safetensors
    ├── vae/
    │   └── ae.safetensors
    └── sam/
        └── sam3_hiera_large.pt
```

## ⚡ Performance (RTX 5090)

| Stage | Time |
|-------|------|
| SAM3 Segmentation | ~5s |
| FLUX Fill (per region) | ~5s |
| Total (3 regions) | ~20-25s |

## 📝 TODO

- [ ] Design complete ComfyUI workflow
- [ ] Add batch processing support
- [ ] Add S3 output option
- [ ] Add quality settings (steps, cfg)
