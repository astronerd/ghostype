# Speech 模块

## 概述

Speech 模块负责语音识别功能，使用豆包语音识别服务。

## 文件结构

```
Features/Speech/
├── README.md                 # 本文档
├── DoubaoSpeechService.swift # 豆包语音识别服务
└── SpeechService.swift       # 语音服务协议（如果存在）
```

## 文件说明

### DoubaoSpeechService.swift
豆包语音识别服务，使用二进制 WebSocket 协议。

**职责**：
- 音频采集（AVAudioEngine）
- WebSocket 连接管理
- 音频数据发送
- 识别结果解析

**关键属性**：
- `transcript` - 当前识别文本（@Published）
- `isRecording` - 录音状态（@Published）
- `onFinalResult` - 最终结果回调
- `onPartialResult` - 流式结果回调

**关键方法**：
- `startRecording()` - 开始录音
- `stopRecording()` - 停止录音
- `hasCredentials()` - 检查凭证是否存在

**音频参数**：
- 采样率：16000 Hz
- 位深：16 bit
- 声道：单声道
- 发送间隔：200ms

**协议细节**：
- 使用 gzip 压缩
- 二进制协议头：4 字节
- 消息类型：0x01（初始化）、0x02（音频）、0x09（响应）、0x0F（错误）

**⚠️ 问题**：
1. API 凭证使用 XOR 混淆存储（伪安全）
2. 魔法数字散落（发送间隔 0.2、采样率 16000）

## 数据流

```
用户按住快捷键
    ↓
startRecording()
    ↓
AVAudioEngine 采集音频
    ↓
音频转换（设备采样率 → 16kHz）
    ↓
gzip 压缩
    ↓
WebSocket 发送
    ↓
接收识别结果
    ↓
onPartialResult / onFinalResult 回调
```

## 音频处理流程

```
麦克风输入（设备原生格式）
    ↓
AVAudioConverter（重采样到 16kHz）
    ↓
Float32 → Int16 转换
    ↓
缓冲到 audioBuffer
    ↓
定时器每 200ms 发送一次
```

## WebSocket 协议

### 请求头
```
X-Api-App-Key: {appId}
X-Api-Access-Key: {accessToken}
X-Api-Resource-Id: volc.seedasr.sauc.duration
X-Api-Request-Id: {UUID}
```

### 初始化请求（消息类型 0x01）
```json
{
  "user": {"uid": "ai_input_method"},
  "audio": {"format": "pcm", "rate": 16000, "bits": 16, "channel": 1},
  "request": {
    "model_name": "bigmodel",
    "enable_itn": true,
    "enable_punc": true,
    "enable_ddc": true,
    "show_utterances": true,
    "enable_nonstream": true
  }
}
```

### 音频数据（消息类型 0x02）
- flags: 0x00（普通）或 0x02（最后一包）
- 数据：gzip 压缩的 PCM 音频

### 响应（消息类型 0x09）
```json
{
  "result": {
    "text": "识别结果"
  }
}
```

## 待重构项

1. **API 凭证安全存储**：移到 Keychain 或环境变量
2. **集中魔法数字**：发送间隔、采样率等移到 Constants
3. **错误处理优化**：统一错误类型
