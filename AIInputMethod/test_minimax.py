#!/usr/bin/env python3
"""测试 MiniMax API - 使用 OpenAI 兼容格式"""

import requests
import base64
import json

# 解码 API Key
encoded = "c2stYXBpLUdPT3E5emMzMEZpZ0lYX1BlbmJvaWo5bF9VQWtIT0lYV1dLTjRmN3JrWW82WDlTYk1UeDVEampWWV9lZTRBRUJHRDFkTDQxVU9vSEV2a0Y0amcweTAySW1XT2hENlBuMHkwRmZLZVk3X283NFUwY1I3TTJxMW8="
api_key = base64.b64decode(encoded).decode('utf-8')
print(f"API Key: {api_key[:20]}...")

# MiniMax OpenAI 兼容 API
base_url = "https://api.minimax.io/v1/text/chatcompletion_v2"
model = "MiniMax-M2.1"

# 测试润色
test_text = "那个我今天呢就是去了一趟超市然后买了一些东西嗯就是这样"

payload = {
    "model": model,
    "max_tokens": 2000,
    "messages": [
        {
            "role": "system",
            "content": "你是一个专业的速记员。请将用户的语音转录文本进行润色。去除口语赘词，修正标点，保持原意。只输出润色后的文本。"
        },
        {
            "role": "user",
            "content": test_text
        }
    ]
}

headers = {
    "Content-Type": "application/json",
    "Authorization": f"Bearer {api_key}"
}

print(f"\n测试文本: {test_text}")
print(f"请求 URL: {base_url}")
print(f"模型: {model}")
print("\n发送请求...")

try:
    response = requests.post(base_url, json=payload, headers=headers, timeout=30)
    print(f"状态码: {response.status_code}")
    
    result = response.json()
    print(f"\n响应:\n{json.dumps(result, indent=2, ensure_ascii=False)}")
    
    # 提取文本 (OpenAI 格式)
    if "choices" in result and len(result["choices"]) > 0:
        content = result["choices"][0].get("message", {}).get("content", "")
        if content:
            print(f"\n✅ 润色结果: {content}")
    elif "error" in result:
        print(f"\n❌ 错误: {result['error']}")
    elif "base_resp" in result:
        print(f"\n❌ 错误: {result['base_resp']}")
        
except Exception as e:
    print(f"\n❌ 请求失败: {e}")
