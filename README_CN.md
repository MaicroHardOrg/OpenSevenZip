# OpenSevenZip Explorer

这是一个使用 Swift Package Manager 和 AppKit 构建的原生 macOS 压缩包图形界面。它不是官方 7-Zip File Manager。

应用共享同一套 Swift 源码，并提供两个发行版本：

- Mac App Store/TestFlight 版本：启用沙盒，只使用打包进应用内的官方 `7zz`。
- GitHub 版本：支持打包的 `7zz`、PATH 中发现的宿主机 `7z` 系列工具，以及用户临时导入的可执行文件。

## 构建

```bash
make build-backend-universal
make package-github
make package-appstore
```

`make build-backend-universal` 会分别构建 `x86_64` 和 `arm64` 的官方 7-Zip `Alone2` 后端，并用 `lipo` 合并为通用 `Resources/7zz`。该二进制文件不会被 git 跟踪。

## 测试

```bash
make test
make test-appstore
```

## 运行

```bash
make run
```

应用输出位置：

```text
dist/OpenSevenZip Explorer.app
```

也可以直接打开压缩包：

```bash
open "dist/OpenSevenZip Explorer.app" --args /path/to/archive.7z
```

## 说明

App Store/TestFlight 版本会在编译期禁用任意外部可执行文件支持，只使用已打包并参与审核的 `7zz`。GitHub 版本保留更灵活的后端选择能力。
