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
        last_log_time = 0

        while time.time() - start_time < timeout:
            elapsed = int(time.time() - start_time)
            history = self.get_history(prompt_id)

            # 每 10 秒打印一次状态
            if elapsed - last_log_time >= 10:
                print(f"[ComfyAPI] 等待中... {elapsed}s")
                last_log_time = elapsed

            if prompt_id in history:
                prompt_data = history[prompt_id]

                # 🔥 检查是否有错误状态
                status = prompt_data.get("status", {})
                if status.get("status_str") == "error":
                    error_msgs = status.get("messages", [])
                    print(f"[ComfyAPI] ❌ 工作流执行出错!")
                    print(f"[ComfyAPI] 错误信息: {error_msgs}")
                    raise RuntimeError(f"ComfyUI workflow error: {error_msgs}")

                outputs = prompt_data.get("outputs", {})

                # 🔥 打印 outputs 状态
                if outputs and elapsed - last_log_time >= 5:
                    print(f"[ComfyAPI] outputs 节点数: {len(outputs)}")

                # 查找所有输出图片
                images = []
                for node_id, node_output in outputs.items():
                    if "images" in node_output:
                        for img in node_output["images"]:
                            img_path = f"/comfyui/output/{img['filename']}"
                            images.append(img_path)

                if images:
                    print(f"[ComfyAPI] ✅ 找到 {len(images)} 张输出图片")
                    return images

            time.sleep(0.5)

        # 🔥 超时时打印最后的 history 状态
        print(f"[ComfyAPI] ⏰ 超时! 最后的 history:")
        try:
            final_history = self.get_history(prompt_id)
            if prompt_id in final_history:
                print(f"[ComfyAPI] status: {final_history[prompt_id].get('status', {})}")
                print(f"[ComfyAPI] outputs keys: {list(final_history[prompt_id].get('outputs', {}).keys())}")
            else:
                print(f"[ComfyAPI] prompt_id 不在 history 中!")
        except Exception as e:
            print(f"[ComfyAPI] 获取最终 history 失败: {e}")

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
