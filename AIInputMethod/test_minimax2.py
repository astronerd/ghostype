#!/usr/bin/env python3
"""测试 MiniMax API"""
import subprocess
import base64

# 解码 API Key
encoded = "c2stYXBpLUdPT3E5emMzMEZpZ0lYX1BlbmJvaWo5bF9VQWtIT0lYV1dLTjRmN3JrWW82WDlTYk1UeDVEampWWV9lZTRBRUJHRDFkTDQxVU9vSEV2a0Y0amcweTAySW1XT2hENlBuMHkwRmZLZVk3X283NFUwY1I3TTJxMW8="
api_key = base64.b64decode(encoded).decode('utf-8')
print(f"API Key: {api_key}")

# 用 curl 测试
import os
os.system(f'''curl -s -X POST "https://api.minimax.io/v1/text/chatcompletion_v2" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer {api_key}" \
  -d '{{"model": "MiniMax-M2.1", "messages": [{{"role": "user", "content": "你好"}}]}}'
''')
