"""
ComfyUI API 客户端
"""

import json
import time
import uuid
import requests
from typing import Optional, List


class ComfyAPI:
    def __init__(self, base_url: str = "http://127.0.0.1:8188"):
        self.base_url = base_url
        self.client_id = str(uuid.uuid4())

    def is_ready(self) -> bool:
        """检查 ComfyUI 是否就绪"""
        try:
            response = requests.get(f"{self.base_url}/system_stats", timeout=2)
            return response.status_code == 200
        except:
            return False

    def queue_prompt(self, workflow: dict) -> dict:
        """提交工作流到队列"""
        payload = {
            "prompt": workflow,
            "client_id": self.client_id
        }
        response = requests.post(
            f"{self.base_url}/prompt",
            json=payload
        )
        return response.json()

    def get_history(self, prompt_id: str) -> dict:
        """获取执行历史"""
        response = requests.get(f"{self.base_url}/history/{prompt_id}")
        return response.json()

    def wait_for_completion(self, prompt_id: str, timeout: int = 300) -> List[str]:
        """等待工作流完成并返回输出图片路径"""
        start_time = time.time()

        while time.time() - start_time < timeout:
            history = self.get_history(prompt_id)

            if prompt_id in history:
                outputs = history[prompt_id].get("outputs", {})

                # 查找所有输出图片
                images = []
                for node_id, node_output in outputs.items():
                    if "images" in node_output:
                        for img in node_output["images"]:
                            img_path = f"/comfyui/output/{img['filename']}"
                            images.append(img_path)

                if images:
                    return images

            time.sleep(0.5)

        raise TimeoutError(f"Workflow did not complete within {timeout} seconds")

    def upload_image(self, image_path: str, filename: str = "input.png") -> dict:
        """上传图片到 ComfyUI"""
        with open(image_path, "rb") as f:
            files = {"image": (filename, f, "image/png")}
            response = requests.post(
                f"{self.base_url}/upload/image",
                files=files
            )
        return response.json()
