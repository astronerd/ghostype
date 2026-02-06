#!/usr/bin/env python3
"""测试 MiniMax API - 尝试不同的 header"""
import base64
import os

# 解码 API Key
encoded = "c2stYXBpLUdPT3E5emMzMEZpZ0lYX1BlbmJvaWo5bF9VQWtIT0lYV1dLTjRmN3JrWW82WDlTYk1UeDVEampWWV9lZTRBRUJHRDFkTDQxVU9vSEV2a0Y0amcweTAySW1XT2hENlBuMHkwRmZLZVk3X283NFUwY1I3TTJxMW8="
api_key = base64.b64decode(encoded).decode('utf-8')
print(f"API Key: {api_key[:30]}...")

# 尝试用 Authorization: Bearer 格式
print("\n========== 测试 Authorization: Bearer ==========")
os.system(f'''curl -s -X POST "https://api.minimax.io/anthropic/v1/messages" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {api_key}" \
  -H "anthropic-version: 2023-06-01" \
  -d '{{"model": "MiniMax-M2.1", "max_tokens": 1000, "messages": [{{"role": "user", "content": "你好"}}]}}'
''')
print()
