# XSEmu.bat

Batch launcher for [zortos293/XSEmu](https://github.com/zortos293/XSEmu), the experimental Xbox
Series X|S (GDK) title runner. It fetches and builds XSEmu, installs missing build tools, and tells
you where the launcher is. It contains no XSEmu code: XSEmu is GPL-2.0-only and belongs to its
authors. The script itself is MIT licensed, so use it, fork it, and change it freely.

## Use

Put `XSEmu.bat` in an empty folder and run it. The first run fetches XSEmu into that folder, offers
to install whatever the build needs, and builds everything. It starts nothing: when it finishes, it
prints the path of the launcher and you open it yourself.

**The launcher is always this file**, in the folder you put the script in:

```
XSEmu\target\launcher-dist\bin\XSEmuLauncher.exe
```

Run that (or make a shortcut to it) whenever you want to play. You only run `XSEmu.bat` again when
you want to update or rebuild.

| Command | What it does |
|---|---|
| `XSEmu.bat` | Fetch, install what is missing, build everything, print the launcher path. |
| `XSEmu.bat <folder \| game.exe> [args]` | Run a title directly; `args` reach the title after `--`. |
| `XSEmu.bat build` | Rebuild `target\release\XSEmu.exe`. |
| `XSEmu.bat launcher` | Rebuild the launcher and print its path. |
| `XSEmu.bat update` | Pull the newest sources and rebuild. |
| `XSEmu.bat inspect\|shaders\|rpf\|warm-up\|--version ...` | Passed to `XSEmu.exe`. |

Dragging a game folder or a title `.exe` onto the script works too. Double-clicked, the window stays
open at the end; from a console it returns the exit code.

## What it needs

- Windows 10/11, x64.
- A D3D12 GPU with Shader Model 6.6 and mesh shaders.
- git - the fetch falls back to a source archive without it.
- The Rust MSVC toolchain.
- The Visual Studio C++ build tools.
- CMake.
- Python - only to download Qt.
- Qt 6.8 for MSVC 2022 - about 1.1 GB, into `%LOCALAPPDATA%\Qt`.
- DXC 1.8+ from the Windows SDK - not installed for you; without it, set `XCL_SHADER_BACKEND=dxil`.

Everything except Windows, the GPU and DXC is installed for you when you say yes: git, Rust, the C++
build tools, CMake and Python through winget, Qt through aqtinstall.

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
`XSEmu run`, and is itself published under the [MIT licence](LICENSE). XSEmu is not affiliated with
or endorsed by Microsoft or AMD, and Xbox is a trademark of Microsoft.
