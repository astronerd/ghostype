#!/usr/bin/env python3
"""测试豆包语音识别接口 - 使用麦克风录音"""

import websocket
import json
import gzip
import struct
import sys
import threading
import time

try:
    import pyaudio
except ImportError:
    print("请先安装 pyaudio: pip3 install pyaudio")
    sys.exit(1)

# 凭证 - 新实例
APP_ID = "8920082845"
ACCESS_TOKEN = "QZvY722AgA_PwMmQbWjj6O3q85-G4Rj-"

# 使用 2.0 版本
RESOURCE_ID = "volc.seedasr.sauc.duration"

# 音频参数
SAMPLE_RATE = 16000
CHANNELS = 1
CHUNK_SIZE = 3200  # 100ms of audio at 16kHz, 16bit

def build_header(msg_type, flags, serialization, compression):
    """构建协议头"""
    header = bytearray(4)
    header[0] = 0x11
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
    
    header = build_header(0x01, 0x00, 0x01, 0x01)
    size = struct.pack('>I', len(compressed))
    
    packet = header + size + compressed
    ws.send(packet, opcode=websocket.ABNF.OPCODE_BINARY)
    print("[TX] Full request sent")

def send_audio(ws, audio_data, is_last=False):
    """发送音频数据"""
    compressed = gzip.compress(audio_data)
    
    flags = 0x02 if is_last else 0x00
    header = build_header(0x02, flags, 0x00, 0x01)
    size = struct.pack('>I', len(compressed))
    
    packet = header + size + compressed
    ws.send(packet, opcode=websocket.ABNF.OPCODE_BINARY)

def parse_response(data):
    """解析响应"""
    if len(data) < 4:
        return None
    
    msg_type = (data[1] >> 4) & 0x0F
    flags = data[1] & 0x0F
    compression = data[2] & 0x0F
    
    if msg_type == 0x0F:  # Error
        error_code = struct.unpack('>I', data[4:8])[0]
        msg_size = struct.unpack('>I', data[8:12])[0]
        msg = data[12:12+msg_size].decode('utf-8')
        print(f"[ERROR] Code: {error_code}, Message: {msg}")
        return None
    
    if msg_type == 0x09:  # Full response
        offset = 4
        if flags & 0x01:
            offset += 4
        
        payload_size = struct.unpack('>I', data[offset:offset+4])[0]
        offset += 4
        
        payload = data[offset:offset+payload_size]
        
        if compression == 0x01:
            payload = gzip.decompress(payload)
        
        result = json.loads(payload.decode('utf-8'))
        return result
    
    return None

class MicRecorder:
    def __init__(self):
        self.p = pyaudio.PyAudio()
        self.stream = None
        self.is_recording = False
        self.audio_buffer = []
        
    def start(self):
        self.stream = self.p.open(
            format=pyaudio.paInt16,
            channels=CHANNELS,
            rate=SAMPLE_RATE,
            input=True,
            frames_per_buffer=CHUNK_SIZE
        )
        self.is_recording = True
        self.audio_buffer = []
        
    def read_chunk(self):
        if self.stream and self.is_recording:
            return self.stream.read(CHUNK_SIZE, exception_on_overflow=False)
        return None
        
    def stop(self):
        self.is_recording = False
        if self.stream:
            self.stream.stop_stream()
            self.stream.close()
        self.p.terminate()

def main():
    # 使用优化版双向流式接口
    url = "wss://openspeech.bytedance.com/api/v3/sauc/bigmodel_async"
    
    headers = {
        "X-Api-App-Key": APP_ID,
        "X-Api-Access-Key": ACCESS_TOKEN,
        "X-Api-Resource-Id": RESOURCE_ID,
        "X-Api-Connect-Id": "test-mic-123"
    }
    
    print("=" * 50)
    print("豆包语音识别测试 - 麦克风录音")
    print("=" * 50)
    print(f"Resource ID: {RESOURCE_ID}")
    print()
    
    try:
        print("连接服务器...")
        ws = websocket.create_connection(url, header=headers)
        print("已连接!")
        
        # 发送初始化请求
        send_full_request(ws)
        
        # 接收初始响应
        response = ws.recv()
        parse_response(response)
        
        # 初始化麦克风
        recorder = MicRecorder()
        
        print()
        print("按 Enter 开始录音，再按 Enter 停止...")
        input()
        
        print("🎤 开始录音... (按 Enter 停止)")
        recorder.start()
        
        # 启动接收线程
        stop_event = threading.Event()
        last_text = ""
        
        def receive_thread():
            nonlocal last_text
            while not stop_event.is_set():
                try:
                    ws.settimeout(0.1)
                    response = ws.recv()
                    result = parse_response(response)
                    if result and 'result' in result:
                        text = result['result'].get('text', '')
                        if text and text != last_text:
                            print(f"\r识别: {text}          ", end='', flush=True)
                            last_text = text
                except websocket.WebSocketTimeoutException:
                    continue
                except Exception as e:
                    if not stop_event.is_set():
                        print(f"\n接收错误: {e}")
                    break
        
        recv_thread = threading.Thread(target=receive_thread)
        recv_thread.start()
        
        # 录音并发送
        def record_thread():
            while not stop_event.is_set():
                chunk = recorder.read_chunk()
                if chunk:
                    try:
                        send_audio(ws, chunk, is_last=False)
                    except Exception as e:
                        print(f"\n发送错误: {e}")
                        break
                time.sleep(0.05)
        
        rec_thread = threading.Thread(target=record_thread)
        rec_thread.start()
        
        # 等待用户按 Enter 停止
        input()
        
        print("\n停止录音...")
        stop_event.set()
        recorder.stop()
        
        # 发送最后一包
        send_audio(ws, b'\x00\x00' * 100, is_last=True)
        
        # 等待最后的响应
        time.sleep(1)
        
        rec_thread.join(timeout=1)
        recv_thread.join(timeout=1)
        
        ws.close()
        
        print()
        print("=" * 50)
        print(f"最终识别结果: {last_text}")
        print("=" * 50)
        
    except Exception as e:
        print(f"错误: {e}")
        import traceback
        traceback.print_exc()

if __name__ == "__main__":
    main()
