# macOS 版 7-Zip

这是一个使用 Swift Package Manager 和 AppKit 构建的原生 macOS 7-Zip 图形界面。应用通过命令行后端完成压缩/解压工作：

- 官方 macOS 版 7-Zip (`7zz`)，从相邻的 `../7zip` 源码构建并打包进应用。
- 已安装的 p7zip 工具作为备用后端：`/usr/local/bin/7z`、`/usr/local/bin/7za`、`/usr/local/bin/7zr`。

## 构建

```bash
make build-backend
make build
```

`make build-backend` 会编译官方 7-Zip 的 `Alone2` 目标，并把生成的 `7zz` 复制到 `Resources/7zz`。该二进制文件不会被 git 跟踪，`make build` 会把它打包进应用。

## 运行

```bash
make run
```

应用输出位置：

```text
dist/7-Zip.app
```

## 当前功能

- 打开压缩包并通过 `7z l -slt` 列出内容。
- 在压缩包内浏览文件夹。
- 将文件/文件夹添加到新压缩包。
- 解压选中的条目或整个压缩包。
- 测试压缩包完整性。
- 在后端支持时删除选中的压缩包条目。
- 为列表、解压、测试和创建加密压缩包提供密码输入。
- 后端设置支持保存自定义可执行文件路径、重置为自动检测，并显示候选后端检测结果。

## 说明

这是原生 macOS 移植的初始版本，不是 Win32 UI 兼容层。界面遵循 7-Zip File Manager 的核心工作流，同时使用 macOS 控件和官方 7-Zip/p7zip 命令行后端抽象。
