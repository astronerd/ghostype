#!/usr/bin/env python3
"""测试豆包语音识别接口"""

import websocket
import json
import gzip
import struct
import sys
import wave
import io
import math

# 凭证 - 新实例
APP_ID = "8920082845"
ACCESS_TOKEN = "QZvY722AgA_PwMmQbWjj6O3q85-G4Rj-"

# 使用 2.0 版本
RESOURCE_ID = "volc.seedasr.sauc.duration"

def build_header(msg_type, flags, serialization, compression):
    """构建协议头"""
    header = bytearray(4)
    header[0] = 0x11  # version 1, header size 1
    header[1] = (msg_type << 4) | flags
    header[2] = (serialization << 4) | compression
    header[3] = 0x00
    return bytes(header)

def send_full_request(ws):
    """发送初始化请求"""
    payload = {
        "user": {"uid": "test"},
        "audio": {
            "format": "pcm",
            "rate": 16000,
            "bits": 16,
            "channel": 1
        },
        "request": {
            "model_name": "bigmodel",
            "enable_itn": True,
            "enable_punc": True,
            "show_utterances": True
        }
    }
    
    json_data = json.dumps(payload).encode('utf-8')
    compressed = gzip.compress(json_data)
    
    # Header: msg_type=1 (full request), flags=0, serialization=1 (JSON), compression=1 (gzip)
    header = build_header(0x01, 0x00, 0x01, 0x01)
    size = struct.pack('>I', len(compressed))
    
    packet = header + size + compressed
    ws.send(packet, opcode=websocket.ABNF.OPCODE_BINARY)
    print(f"[TX] Full request sent, payload size: {len(compressed)}")

def send_audio(ws, audio_data, is_last=False):
    """发送音频数据"""
    compressed = gzip.compress(audio_data)
    
    flags = 0x02 if is_last else 0x00
    header = build_header(0x02, flags, 0x00, 0x01)
    size = struct.pack('>I', len(compressed))
    
    packet = header + size + compressed
    ws.send(packet, opcode=websocket.ABNF.OPCODE_BINARY)
    print(f"[TX] Audio sent, size: {len(audio_data)}, compressed: {len(compressed)}, is_last: {is_last}")

def parse_response(data):
    """解析响应"""
    if len(data) < 4:
        return None
    
    msg_type = (data[1] >> 4) & 0x0F
    flags = data[1] & 0x0F
    compression = data[2] & 0x0F
    
    print(f"[RX] msg_type={msg_type}, flags={flags}, compression={compression}")
    
    if msg_type == 0x0F:  # Error
        error_code = struct.unpack('>I', data[4:8])[0]
        msg_size = struct.unpack('>I', data[8:12])[0]
        msg = data[12:12+msg_size].decode('utf-8')
        print(f"[ERROR] Code: {error_code}, Message: {msg}")
        return None
    
    if msg_type == 0x09:  # Full response
        offset = 4
        if flags & 0x01:
            offset += 4  # sequence number
        
        payload_size = struct.unpack('>I', data[offset:offset+4])[0]
        offset += 4
        
        payload = data[offset:offset+payload_size]
        
        if compression == 0x01:
            payload = gzip.decompress(payload)
        
        result = json.loads(payload.decode('utf-8'))
        print(f"[RX] Result: {json.dumps(result, ensure_ascii=False, indent=2)}")
        return result
    
    return None

def generate_tone_audio(frequency=440, duration_ms=1000):
    """生成正弦波测试音频（模拟说话）"""
    sample_rate = 16000
    samples = int(sample_rate * duration_ms / 1000)
    audio = bytearray()
    
    for i in range(samples):
        # 生成正弦波
        t = i / sample_rate
        value = int(32767 * 0.5 * math.sin(2 * math.pi * frequency * t))
        # 添加一些变化模拟语音
        if i % 1600 < 800:  # 每100ms变化一次
            value = int(value * 0.8)
        audio.extend(struct.pack('<h', value))
    
    return bytes(audio)

def generate_test_audio():
    """生成测试音频（静音）"""
    # 16kHz, 16bit, mono, 1秒
    samples = 16000
    return b'\x00\x00' * samples

def main():
    # 使用优化版双向流式接口
    url = "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async"
    
    headers = {
        "X-Api-App-Key": APP_ID,
        "X-Api-Access-Key": ACCESS_TOKEN,
        "X-Api-Resource-Id": RESOURCE_ID,
        "X-Api-Connect-Id": "test-123"
    }
    
    print(f"Connecting to {url}...")
    print(f"Headers: {headers}")
    
    try:
        ws = websocket.create_connection(url, header=headers)
        print("Connected!")
        
        # 发送初始化请求
        send_full_request(ws)
        
        # 接收响应
        response = ws.recv()
        parse_response(response)
        
        # 生成测试音频 - 使用正弦波而不是静音
        print("\n--- Sending tone audio (simulating speech) ---")
        audio = generate_tone_audio(440, 2000)  # 2秒 440Hz 音频
        
        # 分包发送，每包 200ms (6400 bytes = 3200 samples * 2 bytes)
        chunk_size = 6400
        chunks = [audio[i:i+chunk_size] for i in range(0, len(audio), chunk_size)]
        
        for i, chunk in enumerate(chunks):
            is_last = (i == len(chunks) - 1)
            send_audio(ws, chunk, is_last=is_last)
            
            response = ws.recv()
            result = parse_response(response)
            if result and 'result' in result:
                text = result['result'].get('text', '')
                if text:
                    print(f"\n>>> 识别结果: {text}\n")
        
        ws.close()
        print("Done!")
        
    except Exception as e:
        print(f"Error: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
