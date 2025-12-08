"""
NSFW Inpaint Worker - RunPod Serverless Handler
接收图片 + mask目标 → SAM3分割 → FLUX Fill Inpaint → 返回NSFW图
"""

import runpod
import os
import json
import time
import base64
import subprocess
import threading
from comfy_api import ComfyAPI

# ComfyUI 进程
comfy_process = None
comfy_api = None

def start_comfyui():
    """启动 ComfyUI 服务"""
    global comfy_process, comfy_api

    comfy_path = os.environ.get("COMFYUI_PATH", "/comfyui")

    comfy_process = subprocess.Popen(
        ["python", "main.py", "--listen", "127.0.0.1", "--port", "8188", "--disable-auto-launch"],
        cwd=comfy_path,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE
    )

    # 等待 ComfyUI 启动
    comfy_api = ComfyAPI("http://127.0.0.1:8188")

    max_retries = 60
    for i in range(max_retries):
        if comfy_api.is_ready():
            print(f"ComfyUI started in {i+1} seconds")
            return True
        time.sleep(1)

    raise RuntimeError("ComfyUI failed to start within 60 seconds")


def load_workflow(workflow_name: str) -> dict:
    """加载预设工作流"""
    workflow_path = f"/workflows/{workflow_name}.json"
    if os.path.exists(workflow_path):
        with open(workflow_path, "r") as f:
            return json.load(f)
    raise FileNotFoundError(f"Workflow not found: {workflow_name}")


def handler(job):
    """
    RunPod Handler

    Input:
    {
        "input": {
            "image": "base64编码的图片",
            "mask_targets": ["skirt", "shirt", "bra"],  # SAM3 分割目标
            "prompt": "nude, naked, ...",  # Inpaint 提示词
            "negative_prompt": "...",
            "workflow": "nsfw_inpaint"  # 可选，默认使用预设工作流
        }
    }

    Output:
    {
        "image": "base64编码的结果图片",
        "masks": [...],  # 可选，返回生成的masks
        "time_taken": 12.5
    }
    """
    global comfy_api

    job_input = job["input"]
    start_time = time.time()

    try:
        # 确保 ComfyUI 已启动
        if comfy_api is None or not comfy_api.is_ready():
            start_comfyui()

        # 解析输入
        image_b64 = job_input.get("image")
        mask_targets = job_input.get("mask_targets", ["clothing"])
        prompt = job_input.get("prompt", "nude, naked, bare skin, natural body")
        negative_prompt = job_input.get("negative_prompt", "clothing, fabric, covered")

        if not image_b64:
            return {"error": "No image provided"}

        # 保存输入图片
        image_data = base64.b64decode(image_b64)
        input_path = "/tmp/input.png"
        with open(input_path, "wb") as f:
            f.write(image_data)

        # 构建工作流
        workflow = build_workflow(
            input_path=input_path,
            mask_targets=mask_targets,
            prompt=prompt,
            negative_prompt=negative_prompt
        )

        # 执行工作流
        result = comfy_api.queue_prompt(workflow)

        # 等待完成并获取结果
        output_images = comfy_api.wait_for_completion(result["prompt_id"])

        if not output_images:
            return {"error": "No output generated"}

        # 读取输出图片
        output_path = output_images[0]
        with open(output_path, "rb") as f:
            output_b64 = base64.b64encode(f.read()).decode("utf-8")

        return {
            "image": output_b64,
            "time_taken": time.time() - start_time
        }

    except Exception as e:
        return {"error": str(e)}


def build_workflow(input_path: str, mask_targets: list, prompt: str, negative_prompt: str) -> dict:
    """
    构建 SAM3 + FLUX Fill Inpaint 工作流
    """
    # TODO: 这里需要根据实际的 ComfyUI 节点结构来构建
    # 现在返回一个占位符，实际工作流需要在 ComfyUI 中设计后导出

    workflow = {
        # 这里是工作流的 JSON 结构
        # 需要包含：
        # 1. LoadImage 节点
        # 2. SAM3 分割节点
        # 3. CropAndStitch 节点
        # 4. FLUX Fill Inpaint 节点
        # 5. SaveImage 节点
    }

    return workflow


# 启动时预热
print("Initializing NSFW Inpaint Worker...")
start_comfyui()

# 启动 RunPod Serverless
runpod.serverless.start({"handler": handler})
