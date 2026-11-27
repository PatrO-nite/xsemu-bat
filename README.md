# XSEmu.bat

A self-contained Windows batch launcher for [XSEmu](https://github.com/zortos293/XSEmu), the
experimental Xbox Series X|S (GDK) title runner. Drop the script in any folder, run it, and it
fetches XSEmu, builds it, and starts it. Later runs reuse the checkout and go straight to the game.

The script only drives XSEmu's own build and `XSEmu run` command; it contains none of XSEmu's code.
XSEmu is GPL-2.0-only and belongs to its authors.

## Install

That's the whole install: put `XSEmu.bat` in a folder — an empty one is fine — and run it.

The first run clones XSEmu into `XSEmu\` beside the script and builds
`XSEmu\target\release\XSEmu.exe`, which takes a few minutes. Later runs reuse that checkout. If the
script sits inside an existing XSEmu checkout (a folder with `Cargo.toml`), it uses that one and
clones nothing. Without git on `PATH`, the first run downloads the source archive instead and
`update` re-downloads it.

## Usage

| Command | What it does |
|---|---|
| `XSEmu.bat` | Fetches, builds if needed, then opens XSEmu's own menu, which asks for a game folder, a title `.exe` or a `MicrosoftGame.config`. |
| `XSEmu.bat <folder \| game.exe>` | Runs that title. Later arguments are passed to the title after `--`. |
| `XSEmu.bat run <folder \| exe>` | The same, spelled out. |
| `XSEmu.bat warm-up --full` | Any other XSEmu CLI command goes straight through: `run`, `inspect`, `disasm`, `shaders`, `rpf`, `warm-up`, `help`, `--help`, `-h`, `--version`. |
| `XSEmu.bat build` | Builds `target\release\XSEmu.exe` even if it already exists. |
| `XSEmu.bat launcher` | Builds the Qt launcher (CMake + Qt 6) and starts it. |
| `XSEmu.bat update` | Pulls the newest XSEmu sources and rebuilds; on a copy that came from a source archive it downloads a fresh one. |

Dragging a game folder or a title `.exe` onto `XSEmu.bat` in Explorer also works.

```bat
XSEmu.bat
XSEmu.bat "D:\Games\Some Title"
XSEmu.bat "D:\Games\Some Title" -windowed -novsync
XSEmu.bat shaders "D:\Games\Some Title\Content\package.rpf" --precompile
XSEmu.bat update
XSEmu.bat launcher
```

## Requirements

- Windows 10 or 11, x64, with a D3D12 GPU that supports Shader Model 6.6 and mesh shaders.
- **git** for the clone, though the script falls back to downloading a source archive.
- **Rust** MSVC toolchain (`stable-x86_64-pc-windows-msvc`) and the **Visual Studio C++ build
  tools** for the runtime.
- **DXC** 1.8 or newer (`dxcompiler.dll`, `dxil.dll`) for shader translation. XSEmu looks in the
  Windows SDK, next to `XSEmu.exe`, and in `XCL_DXC_DIR`. The script warns when it finds none, for
  the commands that compile shaders (`run`, `warm-up`, `shaders`) and not for `--version`,
  `--help` or `inspect`. Without DXC, `XCL_SHADER_BACKEND=dxil` uses the built-in backend instead.
- For `launcher` only: **CMake** 3.21 or later, **Visual Studio 2022**, and **Qt 6.4+** built for
  MSVC 2022 x64. The script finds Qt through `CMAKE_PREFIX_PATH` or by scanning
  `C:\Qt\<version>\msvc2022_64`.

## Layout it creates

```
<wherever the script is>\
  XSEmu.bat
  XSEmu\                        cloned on first run
    Cargo.toml
    target\release\XSEmu.exe    the emulator
    target\launcher-build\      launcher build tree
    target\launcher-dist\bin\   XSEmuLauncher.exe, XSEmu.exe beside it
```

Everything the script generates lives under `target\`, which XSEmu's own `.gitignore` covers, so
`git status` inside the clone stays clean. Per-title data goes wherever XSEmu puts it:
`%LOCALAPPDATA%\XCL\<title>\` unless `XCL_DATA_ROOT` says otherwise.

## Behaviour details

- The runtime build runs `cargo build --release --locked --workspace`, the command the upstream
  README and CI use.
- The launcher is configured with the Visual Studio 17 2022 generator so it works from a plain
  `cmd` window without a Developer prompt, installed into `target\launcher-dist`, and `XSEmu.exe` is
  copied next to `XSEmuLauncher.exe` because the launcher starts it as a separate process and looks
  for it beside itself.
- Started from Explorer or by drag-and-drop, the window stays open at the end; from an open console
  it returns XSEmu's exit code.
- Missing git, missing `cargo`, a failed clone, a failed pull, a failed configure and missing Qt each
  print a short message with the fix instead of shell noise.
