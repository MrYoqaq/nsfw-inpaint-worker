"""
🦊 NSFW Inpaint Worker - RunPod Serverless Handler
Made with ♥ by 月儿 for 灵大人

接收：底图URL + 椭圆参数 + SAM提示词 + Inpaint提示词
输出：NSFW 重绘后的图片
"""

import runpod
import os
import json
import time
import base64
import subprocess
import random
import math
import httpx
from PIL import Image, ImageDraw
from io import BytesIO
from comfy_api import ComfyAPI

# ═══════════════════════════════════════════════════════════════
# 全局变量
# ═══════════════════════════════════════════════════════════════

comfy_process = None
comfy_api = None

COMFYUI_PATH = os.environ.get("COMFYUI_PATH", "/comfyui")
COMFYUI_INPUT = f"{COMFYUI_PATH}/input"
COMFYUI_OUTPUT = f"{COMFYUI_PATH}/output"

# 模型映射
MODEL_MAP = {
    "anime": "WAI-illustrious-SDXL.safetensors",      # 二次元
    "realistic": "WAI-REAL_CN.safetensors"            # 三次元
}


# ═══════════════════════════════════════════════════════════════
# ComfyUI 启动
# ═══════════════════════════════════════════════════════════════

def start_comfyui():
    """启动 ComfyUI 服务"""
    global comfy_process, comfy_api

    # 🔥 用 DEVNULL 丢弃输出，避免 pipe 缓冲区满导致死锁！
    # 之前用 PIPE 但不读取，ComfyUI 输出太多会阻塞整个进程！
    comfy_process = subprocess.Popen(
        ["python", "main.py", "--listen", "127.0.0.1", "--port", "8188", "--disable-auto-launch"],
        cwd=COMFYUI_PATH,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL
    )

    comfy_api = ComfyAPI("http://127.0.0.1:8188")

    max_retries = 120  # 2分钟超时
    for i in range(max_retries):
        if comfy_api.is_ready():
            print(f"[OK] ComfyUI started in {i+1} seconds")
            return True
        time.sleep(1)

    raise RuntimeError("ComfyUI failed to start within 120 seconds")


# ═══════════════════════════════════════════════════════════════
# 工具函数
# ═══════════════════════════════════════════════════════════════

def download_image(url: str, output_dir: str) -> str:
    """下载图片到指定目录，返回文件名"""
    filename = f"input_{int(time.time() * 1000)}.png"
    filepath = os.path.join(output_dir, filename)

    with httpx.Client(timeout=60.0, follow_redirects=True) as client:
        response = client.get(url)
        response.raise_for_status()

        # 用 PIL 打开并保存为 PNG（确保格式正确）
        img = Image.open(BytesIO(response.content))
        img.save(filepath, "PNG")

    print(f"[OK] Downloaded image: {filename} ({img.size[0]}x{img.size[1]})")
    return filename, img.size  # 返回文件名和尺寸


def generate_ellipse_mask(ellipse: dict, image_size: tuple, output_dir: str) -> str:
    """
    生成黑底白椭圆 mask 图像

    ellipse: {"cx": 2048, "cy": 1536, "rx": 200, "ry": 150, "angle": 0}
    image_size: (width, height)
    """
    cx = ellipse["cx"]
    cy = ellipse["cy"]
    rx = ellipse["rx"]
    ry = ellipse["ry"]
    angle = ellipse.get("angle", 0)

    # 创建黑底 RGB 图像
    mask = Image.new("RGB", image_size, (0, 0, 0))
    draw = ImageDraw.Draw(mask)

    if angle == 0:
        # 无旋转，直接画椭圆
        bbox = (cx - rx, cy - ry, cx + rx, cy + ry)
        draw.ellipse(bbox, fill=(255, 255, 255))
    else:
        # 有旋转，用多边形近似
        points = []
        angle_rad = math.radians(angle)
        cos_a = math.cos(angle_rad)
        sin_a = math.sin(angle_rad)

        for i in range(360):
            theta = math.radians(i)
            # 椭圆参数方程
            px = rx * math.cos(theta)
            py = ry * math.sin(theta)
            # 旋转
            x = cx + px * cos_a - py * sin_a
            y = cy + px * sin_a + py * cos_a
            points.append((x, y))

        draw.polygon(points, fill=(255, 255, 255))

    # 保存
    filename = f"ellipse_mask_{int(time.time() * 1000)}.png"
    filepath = os.path.join(output_dir, filename)
    mask.save(filepath, "PNG")

    print(f"[OK] Generated mask: {filename} (ellipse at {cx},{cy} r={rx}x{ry})")
    return filename


def load_workflow(workflow_name: str) -> dict:
    """加载工作流 JSON"""
    workflow_path = f"/workflows/{workflow_name}.json"
    if os.path.exists(workflow_path):
        with open(workflow_path, "r", encoding="utf-8") as f:
            return json.load(f)
    raise FileNotFoundError(f"Workflow not found: {workflow_name}")


def inject_params(workflow: dict, params: dict) -> dict:
    """
    注入参数到工作流

    params:
        - image_filename: 底图文件名
        - mask_filename: 椭圆 mask 文件名
        - sam_prompt: SAM 分割提示词
        - inpaint_prompt: 重绘提示词
        - style: anime / realistic
        - seed: 随机种子（可选）
    """
    # 深拷贝避免修改原始工作流
    import copy
    wf = copy.deepcopy(workflow)

    # 节点 3: LoadImage - 底图
    if "3" in wf:
        wf["3"]["inputs"]["image"] = params["image_filename"]

    # 节点 83: LoadImageMask - 椭圆 mask
    if "83" in wf:
        wf["83"]["inputs"]["image"] = params["mask_filename"]

    # 节点 10: SAM3Segment - SAM 提示词
    if "10" in wf:
        wf["10"]["inputs"]["prompt"] = params["sam_prompt"]

    # 节点 20: CLIPTextEncode - 正面提示词 (inpaint)
    if "20" in wf:
        wf["20"]["inputs"]["text"] = params["inpaint_prompt"]

    # 节点 1: CheckpointLoaderSimple - 模型选择
    if "1" in wf:
        style = params.get("style", "anime")
        model_name = MODEL_MAP.get(style, MODEL_MAP["anime"])
        wf["1"]["inputs"]["ckpt_name"] = model_name

    # 节点 40: KSampler - 随机种子
    if "40" in wf:
        seed = params.get("seed", random.randint(0, 2**32 - 1))
        wf["40"]["inputs"]["seed"] = seed

    return wf


# ═══════════════════════════════════════════════════════════════
# Handler
# ═══════════════════════════════════════════════════════════════

def handler(job):
    """
    RunPod Handler - 单区域 Inpaint

    Input:
    {
        "input": {
            "image_url": "https://xxx/image.png",     # 4K 底图 URL
            "ellipse": {                               # 椭圆参数（4K 尺寸坐标）
                "cx": 2048, "cy": 1536,
                "rx": 200, "ry": 150,
                "angle": 0
            },
            "sam_prompt": "female chest area",        # SAM 分割提示词
            "inpaint_prompt": "bare breasts, pink nipples, soft skin",  # 重绘提示词
            "style": "anime",                          # anime / realistic
            "seed": 12345                              # 可选
        }
    }

    Output:
    {
        "success": true,
        "image_base64": "...",           # 输出图片 base64
        "time_taken": 15.2
    }
    """
    global comfy_api

    job_input = job.get("input", {})
    start_time = time.time()

    try:
        # ═══════════════════════════════════════════════════════════
        # 1. 确保 ComfyUI 已启动
        # ═══════════════════════════════════════════════════════════
        if comfy_api is None or not comfy_api.is_ready():
            print("[INFO] Starting ComfyUI...")
            start_comfyui()

        # ═══════════════════════════════════════════════════════════
        # 2. 解析输入参数
        # ═══════════════════════════════════════════════════════════
        image_url = job_input.get("image_url")
        ellipse = job_input.get("ellipse")
        sam_prompt = job_input.get("sam_prompt", "clothing")
        inpaint_prompt = job_input.get("inpaint_prompt", "nude, naked, bare skin")
        style = job_input.get("style", "anime")
        seed = job_input.get("seed")

        # 也支持直接传 base64
        image_base64 = job_input.get("image_base64")

        if not image_url and not image_base64:
            return {"success": False, "error": "No image provided (need image_url or image_base64)"}

        if not ellipse:
            return {"success": False, "error": "No ellipse provided"}

        # ═══════════════════════════════════════════════════════════
        # 3. 准备图片文件
        # ═══════════════════════════════════════════════════════════

        if image_url:
            # 从 URL 下载
            image_filename, image_size = download_image(image_url, COMFYUI_INPUT)
        else:
            # 从 base64 解码
            image_data = base64.b64decode(image_base64)
            image_filename = f"input_{int(time.time() * 1000)}.png"
            filepath = os.path.join(COMFYUI_INPUT, image_filename)

            img = Image.open(BytesIO(image_data))
            img.save(filepath, "PNG")
            image_size = img.size

        print(f"[INFO] Image: {image_filename}, size: {image_size}")

        # ═══════════════════════════════════════════════════════════
        # 4. 生成椭圆 mask
        # ═══════════════════════════════════════════════════════════
        mask_filename = generate_ellipse_mask(ellipse, image_size, COMFYUI_INPUT)

        # ═══════════════════════════════════════════════════════════
        # 5. 加载并注入工作流
        # ═══════════════════════════════════════════════════════════
        workflow = load_workflow("final2")

        params = {
            "image_filename": image_filename,
            "mask_filename": mask_filename,
            "sam_prompt": sam_prompt,
            "inpaint_prompt": inpaint_prompt,
            "style": style,
        }
        if seed is not None:
            params["seed"] = seed

        workflow = inject_params(workflow, params)

        print(f"[INFO] Workflow injected: sam_prompt={sam_prompt}, style={style}")

        # ═══════════════════════════════════════════════════════════
        # 6. 执行工作流
        # ═══════════════════════════════════════════════════════════
        result = comfy_api.queue_prompt(workflow)
        prompt_id = result.get("prompt_id")

        if not prompt_id:
            return {"success": False, "error": f"Failed to queue prompt: {result}"}

        print(f"[INFO] Queued prompt: {prompt_id}")

        # ═══════════════════════════════════════════════════════════
        # 7. 等待完成
        # ═══════════════════════════════════════════════════════════
        output_images = comfy_api.wait_for_completion(prompt_id, timeout=300)

        if not output_images:
            return {"success": False, "error": "No output generated"}

        output_path = output_images[0]
        print(f"[OK] Output: {output_path}")

        # ═══════════════════════════════════════════════════════════
        # 8. 读取输出并返回
        # ═══════════════════════════════════════════════════════════
        with open(output_path, "rb") as f:
            output_b64 = base64.b64encode(f.read()).decode("utf-8")

        # 清理临时文件（可选）
        try:
            os.remove(os.path.join(COMFYUI_INPUT, image_filename))
            os.remove(os.path.join(COMFYUI_INPUT, mask_filename))
        except:
            pass

        return {
            "success": True,
            "image_base64": output_b64,
            "time_taken": round(time.time() - start_time, 2)
        }

    except Exception as e:
        import traceback
        traceback.print_exc()
        return {
            "success": False,
            "error": str(e),
            "time_taken": round(time.time() - start_time, 2)
        }


# ═══════════════════════════════════════════════════════════════
# 启动
# ═══════════════════════════════════════════════════════════════

print("🦊 NSFW Inpaint Worker initializing...")

# 预热启动 ComfyUI
try:
    start_comfyui()
except Exception as e:
    print(f"[WARN] Failed to pre-start ComfyUI: {e}")

# 启动 RunPod Serverless
runpod.serverless.start({"handler": handler})
