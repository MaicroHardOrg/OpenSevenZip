# OpenSevenZip Explorer

> [!CAUTION]
> 本项目仍处于非常早期的开发阶段。预计会有破坏性变更、缺陷和未完成的功能。请勿用于生产环境。

这是一次 vibe coding 尝试，目标是在 macOS 上移植/复刻 Windows 版 [7-Zip](https://7-zip.org/) File Manager 的使用体验。它是使用 Swift Package Manager 和 [AppKit](https://developer.apple.com/documentation/appkit) 构建的原生 macOS 压缩包图形界面，还不是成熟产品。

它不是官方 [7-Zip File Manager](https://7-zip.org/)。

应用共享同一套 Swift 源码，并提供两个发行版本：

- [Mac App Store](https://developer.apple.com/app-store/)/[TestFlight](https://developer.apple.com/testflight/) 版本：启用沙盒，只使用打包进应用内的官方 `7zz`。
- GitHub 版本：支持打包的 `7zz`、PATH 中发现的宿主机 `7z` 系列工具，以及用户临时导入的可执行文件。

## 构建

```bash
make build-backend-universal
make package-github
make package-appstore
```

`make build-backend-universal` 会分别构建 `x86_64` 和 `arm64` 的官方 [7-Zip](https://7-zip.org/) `Alone2` 后端，并用 `lipo` 合并为通用 `Resources/7zz`。该二进制文件不会被 git 跟踪。

打包后的应用会把后端 helper 放在 `Contents/MacOS/7zz`。

## 测试

```bash
make test
make test-appstore
```

## 运行

```bash
make run
```

GitHub 版本输出位置：

```text
dist/OpenSevenZip Explorer-gh.app
```

也可以直接打开压缩包：

```bash
open "dist/OpenSevenZip Explorer-gh.app" --args /path/to/archive.7z
```

App Store/TestFlight 版本输出到 `dist/OpenSevenZip Explorer.app`。

## 当前功能

- 多语言界面，可在 `Tools > Options...` 中选择语言。
- 已打包英文、简体中文、日文、韩文、法文、德文、西班牙文和俄文字符串表。
- 与 7-Zip 原界面重叠的术语尽量对齐官方 7-Zip 语言资源；OpenSevenZip Explorer 新增文案仍需要人工校对。

## 致谢

感谢 Igor Pavlov 和 [7-Zip](https://7-zip.org/) 贡献者开发 7-Zip，也感谢 [p7zip](https://github.com/p7zip-project/p7zip)/7-Zip 命令行工具生态，使本应用能够与这些工具协同工作。本项目开发过程中使用了 [OpenAI Codex](https://openai.com/codex/) 作为 AI 编程助手。OpenSevenZip Explorer 仍是独立项目，并不代表获得 7-Zip、p7zip、OpenAI 或 Codex 的认可或背书。

## 说明

App Store/TestFlight 版本会在编译期禁用任意外部可执行文件支持，只使用已打包并参与审核的 `7zz`。GitHub 版本保留更灵活的后端选择能力。
