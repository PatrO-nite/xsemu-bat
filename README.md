# XSEmu.bat

A self-contained Windows batch launcher for [zortos293/XSEmu](https://github.com/zortos293/XSEmu),
the experimental Xbox Series X|S (GDK) title runner. Drop the script in an empty folder, run it, and
it fetches XSEmu, installs the build tools it is missing, builds the runtime and the Qt launcher,
and opens the launcher. Later runs go straight to it.

The script only drives other people's tools — XSEmu's own build and `XSEmu run` command, winget,
aqtinstall and CMake. It contains none of XSEmu's code. XSEmu is GPL-2.0-only and belongs to its
authors.

## Install

Put `XSEmu.bat` in a folder of its own — an empty one is fine — and run it.

There are no nested directories: the first run fetches XSEmu into that same folder, so `Cargo.toml`,
`crates\` and `.git` land next to the script. Anything the build needs that the machine lacks is
offered for install:

| Missing | Installed with | Size |
|---|---|---|
| git (fetch), Rust toolchain, Visual Studio C++ build tools, CMake, Python | `winget` | a few hundred MB to several GB |
| Qt 6.8.3 for MSVC 2022 (the launcher) | `aqtinstall` into `%LOCALAPPDATA%\Qt` | about 1.1 GB |

Then `cargo` builds `target\release\XSEmu.exe` and CMake builds
`target\launcher-dist\bin\XSEmuLauncher.exe`, which is what the script starts. Answer `n` to any
offer and the step it belongs to is skipped with an explanation rather than a half-built install.

The folder has to be safe to turn into a checkout, so the script refuses to run where it would
destroy something: a folder that already holds a different Rust project (`Cargo.toml` without
`crates\xcl`), a folder belonging to another git repository, and a whole drive root.

## Usage

| Command | What it does |
|---|---|
| `XSEmu.bat` | Fetches, checks requirements, builds the runtime and the launcher, and opens the launcher. |
| `XSEmu.bat <folder \| game.exe>` | Runs that title directly with `XSEmu.exe run`. Later arguments are passed to the title after `--`. |
| `XSEmu.bat run <folder \| exe>` | The same, spelled out. |
| `XSEmu.bat warm-up --full` | Any other XSEmu CLI command goes straight through: `run`, `inspect`, `disasm`, `shaders`, `rpf`, `warm-up`, `help`, `--help`, `-h`, `--version`. |
| `XSEmu.bat build` | Builds `target\release\XSEmu.exe` even if it already exists. |
| `XSEmu.bat launcher` | Checks requirements, builds the launcher and opens it. |
| `XSEmu.bat update` | Pulls the newest XSEmu sources and rebuilds the runtime, plus the launcher if it was built before. |

Dragging a game folder or a title `.exe` onto `XSEmu.bat` in Explorer also works.

Set `XSEMU_INSTALL=no` to answer every install offer with no — useful for a machine you do not want
touched — or `XSEMU_INSTALL=yes` to accept them all without prompting.

```bat
XSEmu.bat
XSEmu.bat "D:\Games\Some Title"
XSEmu.bat "D:\Games\Some Title" -windowed -novsync
XSEmu.bat shaders "D:\Games\Some Title\Content\package.rpf" --precompile
XSEmu.bat build
XSEmu.bat launcher
XSEmu.bat update
```

## Requirements

The script checks these and offers to install the first five:

- Windows 10 or 11, x64, with a D3D12 GPU that supports Shader Model 6.6 and mesh shaders.
- **git** for the fetch, though the first run falls back to downloading a source archive without it.
- **Rust** MSVC toolchain (`stable-x86_64-pc-windows-msvc`) and the **Visual Studio C++ build
  tools** (the `VC.Tools.x86.x64` component, found through `vswhere`) for the runtime.
- **CMake** 3.21 or later, **Qt 6.4+** for MSVC 2022 x64, and **Python** (only to install Qt) for the
  launcher.
- **DXC** 1.8 or newer (`dxcompiler.dll`, `dxil.dll`) for shader translation. This one is not
  installed for you: it comes with the Windows SDK's "Desktop C++ x64 Apps". XSEmu looks in the SDK,
  next to `XSEmu.exe`, and in `XCL_DXC_DIR`; the script warns when it finds none, for the commands
  that compile shaders (`run`, `warm-up`, `shaders`) and not for `--version`, `--help` or `inspect`.
  Without it, `XCL_SHADER_BACKEND=dxil` uses the built-in backend instead.

## Layout it creates

```
<the folder holding the script>\
  XSEmu.bat
  Cargo.toml, crates\, launcher\, tests\        fetched on the first run
  .git\                                         the checkout, so update can pull
  target\release\XSEmu.exe                      the emulator
  target\launcher-build\                        launcher build tree
  target\launcher-dist\bin\XSEmuLauncher.exe    the launcher, XSEmu.exe beside it
```

`%LOCALAPPDATA%\Qt\6.8.3\msvc2022_64` holds the Qt kit when the script installed it, and CMake and
Visual Studio install where their own installers put them. Everything the build generates stays
under `target\`, which XSEmu's own `.gitignore` covers, so `git status` in that folder lists only
`XSEmu.bat` as untracked. Per-title data goes wherever XSEmu puts it:
`%LOCALAPPDATA%\XCL\<title>\` unless `XCL_DATA_ROOT` says otherwise.

## Behaviour details

- The runtime build runs `cargo build --release --locked --workspace`, the command the upstream
  README and CI use. The launcher is configured with the Visual Studio 17 2022 generator so it works
  from a plain `cmd` window without a Developer prompt, and `XSEmu.exe` is copied next to
  `XSEmuLauncher.exe` because the launcher starts it as its own process.
- The checkout is made with `git init`, a depth-1 fetch of `main` and a checkout into it, because
  `git clone` refuses a folder that already holds `XSEmu.bat`. Fetching replaces the folder's own
  `README.md` with XSEmu's, which is why these wrapper docs are published as `README-XSEmu-bat.md`.
- Installs run with `winget --silent --accept-package-agreements --accept-source-agreements`, and
  `aqtinstall` puts Qt in `%LOCALAPPDATA%\Qt` so nothing needs administrator rights. A tool installed
  this way is usable in the same run, because the script adds its folder to `PATH`.
- A prompt with no answer — no console attached, or `XSEMU_INSTALL=no` — counts as no, so an
  unattended run never starts an install.
- Started from Explorer or by drag-and-drop, the window stays open at the end; from an open console
  it returns the exit code of what it ran.
- Missing tools, a failed fetch, a failed pull, a failed configure and a failed build each print a
  short message with the fix instead of shell noise.
- A folder holding an `XSEmu\` subfolder from version 1.0.0 of this script is still used as is.
