# XSEmu.bat

Batch launcher for [zortos293/XSEmu](https://github.com/zortos293/XSEmu), the experimental Xbox
Series X|S (GDK) title runner. It fetches and builds XSEmu, installs missing build tools, and opens
the launcher. It contains no XSEmu code: XSEmu is GPL-2.0-only and belongs to its authors.

## Use

Put `XSEmu.bat` in an empty folder and run it. The first run fetches XSEmu into that folder, offers
to install whatever the build needs, builds everything, and opens the launcher. Later runs go
straight to it.

| Command | What it does |
|---|---|
| `XSEmu.bat` | Build what is missing, open the launcher. |
| `XSEmu.bat <folder \| game.exe> [args]` | Run a title directly; `args` reach the title after `--`. |
| `XSEmu.bat build` | Rebuild `target\release\XSEmu.exe`. |
| `XSEmu.bat launcher` | Rebuild the launcher and open it. |
| `XSEmu.bat update` | Pull the newest sources and rebuild. |
| `XSEmu.bat inspect\|shaders\|rpf\|warm-up\|--version ...` | Passed to `XSEmu.exe`. |

Dragging a game folder or a title `.exe` onto the script works too. Double-clicked, the window stays
open at the end; from a console it returns the exit code.

## What it needs

Windows 10/11 x64 with a D3D12 GPU supporting Shader Model 6.6 and mesh shaders. git, the Rust MSVC
toolchain, the VS C++ build tools, CMake and Python are installed with winget when you say yes; Qt
6.8 for MSVC 2022 is installed with aqtinstall into `%LOCALAPPDATA%\Qt` (about 1.1 GB). DXC from the
Windows SDK is reported but not installed: without it, set `XCL_SHADER_BACKEND=dxil`.

`XSEMU_INSTALL=no` declines every offer, `XSEMU_INSTALL=yes` accepts them all.

## Where things go

```
<folder with the script>\
  XSEmu.bat
  Cargo.toml, crates\, .git, target\           the checkout and its builds
  target\release\XSEmu.exe                     the emulator
  target\launcher-dist\bin\XSEmuLauncher.exe   the launcher
```

The folder becomes the checkout, so the script refuses one that already holds another Rust project
or another git repository, and a drive root.

## Legal

This repository holds a batch script and nothing else. It ships no game files, console firmware, SDK
headers or binaries, keys, or dumps, and it neither decrypts packages nor bypasses DRM. It does not
condone piracy: XSEmu runs a title's own code on Windows, so use it only with titles you own and have
unpacked yourself, and only where that is lawful where you live.

XSEmu is GPL-2.0-only and belongs to its authors; XSEmu.bat is only a wrapper around its build and
`XSEmu run`. XSEmu is not affiliated with or endorsed by Microsoft or AMD, and Xbox is a trademark of
Microsoft.
