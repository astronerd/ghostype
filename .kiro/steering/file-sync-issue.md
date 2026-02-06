# 文件同步问题

## 问题描述

`strReplace` 和 `readFile` 工具操作的是编辑器内存缓存，不是磁盘上的实际文件。

当使用 `swift build` 或其他外部编译命令时，编译器读取的是磁盘文件，不是缓存。

## 症状

- `strReplace` 显示替换成功
- `readFile` 显示新内容
- 但 `grep` 或 `cat` 显示旧内容
- 编译后运行的还是旧代码

## 解决方案

修改文件后，使用 `executeBash` 运行 `cat` 或 `grep` 验证磁盘文件是否真的更新了。

如果没更新，用 `fsWrite` 直接覆盖整个文件，而不是用 `strReplace`。
