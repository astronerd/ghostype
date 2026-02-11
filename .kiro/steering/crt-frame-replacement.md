---
inclusion: manual
---

# CRT 显示器框架图替换

## 文件

- `AIInputMethod/Sources/Resources/CRTFrame.png`

## 流程

1. 新图裁掉外围 alpha=0 的透明区域（只保留有内容的部分）
2. 用分析脚本对比新旧图的屏幕开口位置（alpha≠255 在不透明外壳内部的区域）
3. 如果缩放到 530×482 后屏幕开口还是 320×240 @ (85,83) → 直接替换，代码不用改
4. 如果不一致 → 更新 `IncubatorPage.swift` 里的 `crtFrameWidth/Height`、`screenWidth/Height`、`screenOffsetX/Y`
5. `swift build -c release` → `bash bundle_app.sh` → `open GHOSTYPE.app`

## 裁图

```python
from PIL import Image
import numpy as np

img = Image.open('new_frame.png').convert('RGBA')
alpha = np.array(img)[:,:,3]
rows, cols = np.any(alpha > 0, axis=1), np.any(alpha > 0, axis=0)
rmin, rmax = np.where(rows)[0][[0, -1]]
cmin, cmax = np.where(cols)[0][[0, -1]]
img.crop((cmin, rmin, cmax+1, rmax+1)).save('Sources/Resources/CRTFrame.png')
```
