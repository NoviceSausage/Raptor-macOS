# Changelog

All notable changes to this packaging project are documented here.

This project packages a third-party application. Entries describe changes to the
macOS packaging only — never changes to RAPTOR itself, which is redistributed
unmodified. See [`THIRD-PARTY-NOTICES.md`](THIRD-PARTY-NOTICES.md).

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The version in [`VERSION`](VERSION) tracks the packaging, not RAPTOR. Each entry
records which upstream build it wraps.

---

## [Unreleased]

### Added

- `tools/package-macos.sh` — builds `RAPTOR.app` from an upstream publish folder.
- `tools/launcher.c` — compiled arm64 launcher for `Contents/MacOS/RAPTOR`.
- `tools/icon-gen.swift` — draws `RAPTOR.icns` at 16–1024 px.
- `tools/extract-credits.sh` — prints the author credits embedded in `raptor.dll`.
- `docs/RELEASING.md`, `UPSTREAM`, `THIRD-PARTY-NOTICES.md`.
- GitHub Actions workflows to verify and release.
- `--dmg` builds a distributable disk image alongside the app: the bundle plus an
  `Applications` shortcut to drag onto and a `READ ME FIRST.txt` covering the
  runtime requirements and the Gatekeeper step. The Finder icon layout is applied
  when a GUI session is available and skipped without failing the build
  otherwise. The image is verified with `hdiutil verify` before the build
  reports success.
- `.dmg` and `.zip` both omit `Contents/cache` (the fontconfig runtime cache),
  which is regenerated on first launch.

### Changed

- `tools/package-macos.sh` now accepts `--dmg`.
- The README documents the official upstream download URL, which was previously
  missing, so a fresh clone can actually complete step 2 of the build.

## [1.0.0] — 2025-10-02

First packaged release. Wraps the official upstream build of 2025-07-10
(`raptor_avalonia.zip`, SHA-256
`91c005fdb63a7e321d9ca9bb8d772fa8817ecb929f5fd481f604f9856adadee4`).

### Added

- macOS application bundle: `Info.plist`, bundle icon, `Contents/Resources`
  payload layout.
- Launcher that locates the .NET 8 runtime on its own (checking
  `/usr/local/share/dotnet`, `/opt/homebrew/share/dotnet`, `~/.dotnet`, then
  `PATH`) and shows a native dialog explaining how to install it when missing.
- `DYLD_LIBRARY_PATH` wiring for `libgdiplus` and the SkiaSharp /
  HarfBuzzSharp / Avalonia native libraries.
- Fontconfig and .NET caches redirected into `Contents/cache`, which removes the
  `Fontconfig error: No writable cache directories` warning and keeps the user's
  home directory clean.
- Packaging trims the Windows and Linux runtime folders plus `.pdb` symbols,
  cutting the download from ~122 MB to ~48 MB; `--no-trim` keeps them.
  `runtimes/unix` is deliberately retained — it holds the Unix build of
  `System.Drawing.Common.dll`, and removing it breaks startup.
- Bundle registered with LaunchServices after packaging so the icon appears
  immediately.
- The launcher validates the bundle layout before doing anything else, so an
  incomplete or mispackaged bundle fails with an actionable message instead of
  a confusing ".NET not found" error.

### Attribution

- Confirmed RAPTOR's licence as **public domain** (US Air Force policy) from the
  official project homepage, and recorded the full author/contributor list as
  credited by the application's own About dialog.
- Confirmed the GPL-licensed NClass/UML designer component is **not** present in
  this Avalonia Edition payload, so no GPL obligation attaches to the bundle.

### Known issues

- The application name shown by Avalonia is `Avalonia Application`, a hardcoded
  default in `Avalonia.Controls.dll` that `Info.plist` cannot override. The Dock
  and Finder show **RAPTOR**.
- The bundle is unsigned and not notarized, so the first launch from a download
  requires clearing the quarantine attribute. See the README.
- Apple Silicon only in published release assets.
- The upstream archive ships no licence file of its own; the public-domain
  status is documented from the official homepage rather than the distribution.

[Unreleased]: https://github.com/NoviceSausage/RAPTOR-macos/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/NoviceSausage/RAPTOR-macos/releases/tag/v1.0.0
