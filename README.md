# RAPTOR for macOS

Packages the official **Mac RAPTOR Avalonia** build into a proper macOS
application bundle, so RAPTOR launches by double-clicking instead of by typing
`dotnet raptor.dll` in a terminal.

[中文说明](#中文说明) · [Download](#install) · [Build](#build-from-source) · [Attribution](#attribution)

> **Unofficial.** This is a community repackaging. It is not affiliated with,
> endorsed by, or supported by the RAPTOR authors or the Avalonia project.

**What RAPTOR is:** a flowchart-based programming environment for learning
algorithmic reasoning, originally developed by and for the **US Air Force
Academy** and maintained by Martin C. Carlisle. It is **public domain** under US
Air Force policy, so packaging and redistribution need no permission. Note this
is *not* the unrelated old freeware .NET *decompiler* that shares the name.

Full credits: [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).

---

## What this gives you

The upstream distribution is a bare Windows-style folder of .NET assemblies.
This project adds a macOS wrapper around those untouched files:

| Added | Purpose |
| --- | --- |
| `Contents/MacOS/RAPTOR` | Compiled arm64 launcher that finds .NET and starts `raptor.dll` |
| `Contents/Info.plist` | Bundle identity so Finder, Dock and Spotlight recognise the app |
| `Contents/Resources/RAPTOR.icns` | Icon, drawn from scratch (upstream ships only a 32 px bitmap) |
| `Contents/cache` | Keeps the fontconfig cache inside the bundle instead of `$HOME` |
| — | Removes Windows/Linux runtime folders and `.pdb` symbols (~50 % smaller) |

The launcher also fixes a real problem with the naive approach: a shell-script
launcher renames the process to `dotnet`, so the Dock shows a generic icon and
the bundle's identity is lost. Compiling a real Mach-O executable at
`Contents/MacOS/RAPTOR` keeps the bundle identity intact.

Nothing inside `raptor.dll` or any other upstream assembly is modified.

---

## Requirements

| | |
| --- | --- |
| macOS | 11 Big Sur or later |
| Architecture | Apple Silicon (arm64). See [Intel Macs](#intel-macs) |
| .NET Runtime | **8.0** — [download from Microsoft](https://dotnet.microsoft.com/download/dotnet/8.0). Choose **macOS → Arm64 → Runtime** |
| libgdiplus | Required for image handling. `brew install mono-libgdiplus` |

Install the two dependencies:

```bash
# .NET 8 runtime (if you do not have it)
brew install --cask dotnet-runtime

# libgdiplus, used by System.Drawing for image operations
brew install mono-libgdiplus
```

---

## Install

### Option A — download a release (recommended)

**`.dmg` (easiest).** Download `RAPTOR-<version>-macos-arm64.dmg`, open it, and
drag `RAPTOR.app` onto the `Applications` shortcut in the window. The disk image
also contains a `READ ME FIRST.txt` with the requirements and the Gatekeeper
step below.

**`.zip`.** Download `RAPTOR-<version>-macos-arm64.zip`, unzip it, and drag
`RAPTOR.app` into `/Applications`.

Then double-click the app. The first launch may be blocked by Gatekeeper with
*"Apple could not verify RAPTOR.app"*. The release is unsigned, so clear the
quarantine flag once:

```bash
xattr -dr com.apple.quarantine /Applications/RAPTOR.app
```

Then open it again. Alternatively use **System Settings → Privacy & Security →
Open Anyway**, or right-click the app and choose **Open**. Note that the app is
installed by copying it; opening it straight from the mounted image also works
but will ask for the flag each time.

### Option B — build it yourself

See [Build from source](#build-from-source). This avoids the Gatekeeper prompt
entirely, since the bundle is created locally and never quarantined.

---

## Build from source

You need the official RAPTOR archive plus Xcode command line tools
(`xcode-select --install`).

```bash
# 1. Get the repository
git clone https://github.com/NoviceSausage/RAPTOR-macos.git
cd RAPTOR-macos

# 2. Get the official RAPTOR Avalonia build and unzip it
#    Official download: https://raptor.martincarlisle.com/raptor_avalonia.zip
#    (the archive extracts to a folder called "publish")
curl -LO https://raptor.martincarlisle.com/raptor_avalonia.zip
unzip raptor_avalonia.zip -d upstream

# 3. Package it (--zip and --dmg are both optional)
./tools/package-macos.sh upstream/publish --zip --dmg
```

The result lands in `build/`:

```
build/RAPTOR.app
build/RAPTOR-1.0.0-macos-arm64.zip
build/RAPTOR-1.0.0-macos-arm64.dmg
```

Verify it starts:

```bash
open build/RAPTOR.app
```

### Script options

```
./tools/package-macos.sh <publish-folder> [options]

  -o, --out DIR    Where to write RAPTOR.app       (default: ./build)
  -z, --zip        Also produce a Release-ready .zip
  -d, --dmg        Also produce a distributable .dmg
  --no-trim        Keep Windows/Linux runtimes and .pdb symbols
  -h, --help       Show help
```

### What each artifact is for

| Artifact | Use |
| --- | --- |
| `RAPTOR.app` | The application itself. The real output of this project. |
| `...-macos-arm64.dmg` | **Give this to people.** A disk image with the app, an `Applications` shortcut to drag onto, and a `READ ME FIRST.txt`. |
| `...-macos-arm64.zip` | The same bundle, zipped. Smaller to host and works on any filesystem; no drag-to-install affordance. |

Both archives are attached to each release. Building the `.dmg` needs
`hdiutil`, which requires an unsandboxed shell; the Finder icon layout step is
applied opportunistically and skipped without failing the build when no GUI
session is available (for example on CI).

---

## Repository layout

```
.
├── tools/
│   ├── package-macos.sh    # builds RAPTOR.app (+ .zip/.dmg) from an upstream folder
│   ├── launcher.c          # the Contents/MacOS/RAPTOR executable
│   ├── icon-gen.swift      # draws RAPTOR.icns
│   └── extract-credits.sh  # prints RAPTOR's own author credits
├── docs/
│   └── RELEASING.md        # how to cut a release
├── .github/workflows/
│   ├── verify.yml          # verifies packaging on every push
│   └── release.yml         # builds and attaches assets on a version tag
├── VERSION                 # marketing version, drives CFBundleVersion
├── UPSTREAM                # provenance of the packaged upstream build
├── THIRD-PARTY-NOTICES.md  # attribution and licences  ← read before releasing
└── LICENSE                 # MIT — covers the packaging scripts ONLY
```

Binaries are never committed. Releases are built by CI from the tagged source
and attached as release assets.

---

## Troubleshooting

**"The .NET 8.0 Runtime was not found" dialog on launch**
Install the runtime, then reopen. Verify with:

```bash
dotnet --list-runtimes | grep NETCore
```

You should see `Microsoft.NETCore.App 8.0.x`. If `dotnet` is missing entirely,
install from [dotnet.microsoft.com](https://dotnet.microsoft.com/download/dotnet/8.0).

**Image-related features fail, or a `libgdiplus` error appears**
Install it: `brew install mono-libgdiplus`. The launcher already puts the
bundled copy in `Contents/Resources` on the library search path, but
`System.Drawing` may still look for the Homebrew one.

**Runtime error mentioning `System.Drawing.Common`**
You removed `runtimes/unix/` while trimming. That folder holds the Unix build of
`System.Drawing.Common.dll`, which is what .NET resolves on macOS; the copy at
the payload root is not enough. Rebuild without hand-trimming, or use the
script's default trim mode, which keeps it.

**The app bounces once and exits**
Run the launcher in a terminal to see the real error:

```bash
/Applications/RAPTOR.app/Contents/MacOS/RAPTOR
```

**The menu bar says "Avalonia Application" instead of "RAPTOR"**
Known and cosmetic. The name is a hardcoded default inside
`Avalonia.Controls.dll`; it is not read from `Info.plist`, so the launcher
cannot override it without patching the upstream assembly, which this project
deliberately does not do. The Dock and Finder show **RAPTOR**.

**Spotlight/Dock shows a generic icon right after building**
Re-register the bundle:

```bash
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f build/RAPTOR.app
```

### Intel Macs

The launcher is compiled arm64. On an Intel Mac, build from source on that
machine — `package-macos.sh` compiles for whatever architecture it runs on. The
upstream native libraries are universal binaries, so x86_64 works. Note that
the official installer referenced in upstream docs is titled *ARM Mac*, and
release assets here are built for arm64 only.

---

## Attribution

- **RAPTOR** — the flowchart interpreter. **Public domain** (US Air Force
  policy), originally developed by and for the US Air Force Academy. Avalonia
  Edition by Martin C. Carlisle, Aidan M. Heffron, Santiago Fonesca and
  Siddharth Mangalpally (Avalonia port); Windows Edition by Terry A. Wilson,
  Martin C. Carlisle, Jeffrey W. Humphries and Jason A. Moore. Redistributed
  unmodified. See [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).
- **Avalonia**, **SkiaSharp**, **HarfBuzzSharp**, **ReactiveUI**, **Roslyn**,
  **libgdiplus**, **Noto Sans CJK** and the **.NET runtime** — copyright their
  respective owners, MIT or as noted in
  [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).

The packaging work in this repository (scripts, launcher, icon generator,
workflows, docs) is MIT licensed — see [`LICENSE`](LICENSE). That licence does
**not** extend to RAPTOR, which is public domain and carries no conditions, nor
to the bundled third-party libraries, which have their own licences.

Official homepage: <https://raptor.martincarlisle.com/> · the statement of
public-domain status is in its *Acknowledgements* section.

---

## 中文说明

把官方 **Mac RAPTOR Avalonia** 版打包成标准的 macOS 应用（`.app`），双击即可运行，
不需要每次开终端敲 `dotnet raptor.dll`。

> **非官方打包。** 与 RAPTOR 作者及 Avalonia 项目无隶属关系，未获其背书或支持。

**RAPTOR 是什么：** 一个用流程图学习算法思维的教学编程环境，最初由**美国空军学院**
为教学目的开发，现由 Martin C. Carlisle 维护。按美国空军政策，RAPTOR 属于
**公有领域（public domain）**，打包和再分发无需授权。注意：它与同名的那个老式
.NET **反编译器**是两个完全不同的软件。

完整署名见 [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md)，官网
<https://raptor.martincarlisle.com/>。

### 环境要求

| | |
| --- | --- |
| 系统 | macOS 11 Big Sur 及以上 |
| 架构 | Apple 芯片（arm64） |
| .NET 运行时 | **8.0**，[从微软下载](https://dotnet.microsoft.com/download/dotnet/8.0) 选 macOS → Arm64 → Runtime |
| libgdiplus | 处理图片时需要，`brew install mono-libgdiplus` |

```bash
brew install --cask dotnet-runtime
brew install mono-libgdiplus
```

### 安装

**推荐用 `.dmg`：** 从 [Releases](../../releases/latest) 下载
`RAPTOR-<版本>-macos-arm64.dmg`，双击打开，把 `RAPTOR.app` 拖到窗口里的
`Applications` 快捷方式上即可。镜像里还放了一份 `READ ME FIRST.txt`，写着运行
依赖和下面的 Gatekeeper 处理办法。

**也可以下 `.zip`：** 解压后把 `RAPTOR.app` 拖进 `/Applications`。

首次打开若提示 *"Apple 无法验证 RAPTOR.app"*（因为未做代码签名），执行一次：

```bash
xattr -dr com.apple.quarantine /Applications/RAPTOR.app
```

### 自行打包

```bash
git clone https://github.com/NoviceSausage/RAPTOR-macos.git
cd RAPTOR-macos
unzip raptor_avalonia.zip -d upstream
./tools/package-macos.sh upstream/publish --zip --dmg
```

产物在 `build/` 下：`RAPTOR.app`、可直接上传 Release 的 `.zip`，以及带
"拖进 Applications" 界面的 `.dmg`（加 `--dmg` 参数生成）。

### 注意事项

- 原版发行包只有 32×32 的 Windows 图标，放大没法用，所以图标是重新绘制的。
- 打包会删掉 Windows / Linux 的运行时目录和 `.pdb` 调试符号，体积从约 122 MB 降到约 48 MB；
  需要完整内容时加 `--no-trim`。注意 `runtimes/unix` 必须保留 —— 里面是 macOS 用的
  `System.Drawing.Common.dll`，删掉会导致启动直接报 `Could not load file or assembly`。
- 菜单栏应用名可能显示为 "Avalonia Application"：这是 `Avalonia.Controls.dll`
  里写死的默认值，不读取 `Info.plist`，除非改动上游程序本体否则无法覆盖。
  Dock 和访达里显示的仍是 RAPTOR。
- 本仓库的脚本部分采用 MIT 许可；RAPTOR 本体为公有领域，不属于本仓库；
  其依赖库（Avalonia、SkiaSharp、libgdiplus 等）各自保留原有许可。

---

## Takedown

If you hold rights to any redistributed component and object to its presence
here, open an issue and the affected release will be withdrawn.
