# XSEmu.bat

A Windows batch wrapper around [XSEmu](https://github.com/zortos293/XSEmu), the experimental
Xbox Series X|S (GDK) title runner. It builds XSEmu from source when it has to, then runs a title,
passes CLI commands straight through, and can build the Qt launcher.

The script only drives XSEmu's own build and its `XSEmu run` command; it contains none of XSEmu's
code. XSEmu is GPL-2.0-only and belongs to its authors — see the upstream repository.

## Install

Copy `XSEmu.bat` into the XSEmu repository root, the folder that holds `Cargo.toml`, `crates\` and
`launcher\`. The script refuses to run anywhere else.

## Usage

| Command | What it does |
|---|---|
| `XSEmu.bat` | Builds `target\release\XSEmu.exe` if it is missing, then opens XSEmu's own menu, which asks for a game folder, a title `.exe` or a `MicrosoftGame.config`. |
| `XSEmu.bat <folder \| game.exe>` | Runs that title. Later arguments are passed to the title after `--`. |
| `XSEmu.bat run <folder \| exe>` | The same, spelled out. |
| `XSEmu.bat warm-up --full` | Any other XSEmu CLI command goes straight through: `run`, `inspect`, `disasm`, `shaders`, `rpf`, `warm-up`, `--help`, `--version`. |
| `XSEmu.bat build` | Builds `target\release\XSEmu.exe` even if it already exists. |
| `XSEmu.bat launcher` | Builds the Qt launcher and starts it. |

Dragging a game folder or a title `.exe` onto `XSEmu.bat` in Explorer also works.

Examples:

```bat
XSEmu.bat "D:\Games\Some Title"
XSEmu.bat "D:\Games\Some Title" -windowed -novsync
XSEmu.bat shaders "D:\Games\Some Title\Content\package.rpf" --precompile
XSEmu.bat launcher
```

## Requirements

- Windows 10 or 11, x64, with a D3D12 GPU that supports Shader Model 6.6 and mesh shaders.
- **Rust** MSVC toolchain (`stable-x86_64-pc-windows-msvc`) and the **Visual Studio C++ build
  tools** for the runtime.
- **DXC** 1.8 or newer (`dxcompiler.dll`, `dxil.dll`) for shader translation. XSEmu looks in the
  Windows SDK, next to `XSEmu.exe`, and in `XCL_DXC_DIR`; the script warns when it finds none.
  Without DXC, `XCL_SHADER_BACKEND=dxil` uses the built-in backend instead.
- For `launcher` only: **CMake** 3.21 or later, **Visual Studio 2022**, and **Qt 6.4+** built for
  MSVC 2022 x64. The script finds Qt through `CMAKE_PREFIX_PATH` or by scanning
  `C:\Qt\<version>\msvc2022_64`.

## What it writes

- `target\release\XSEmu.exe` from the Rust build, and `target\launcher-build` /
  `target\launcher-dist` from the launcher build. All three sit under `target\`, which the upstream
  `.gitignore` already covers, so the repository stays clean.
- Per-title data goes wherever XSEmu puts it: `%LOCALAPPDATA%\XCL\<title>\` unless `XCL_DATA_ROOT`
  says otherwise.

## Behaviour details

- The build runs `cargo build --release --locked --workspace`, the command the upstream README and
  CI use.
- The launcher is configured with the Visual Studio 17 2022 generator so it works from a plain
  `cmd` window without a Developer prompt, installed to `target\launcher-dist`, and
  `XSEmu.exe` is copied next to `XSEmuLauncher.exe` because the launcher starts it as a separate
  process and looks for it beside itself.
- Started from Explorer or by drag-and-drop, the window stays open at the end; from an open console
  it simply returns XSEmu's exit code.
- Missing `cargo`, a failed build, a failed configure, and missing Qt each produce a short message
  with the fix rather than a stack of shell errors.
