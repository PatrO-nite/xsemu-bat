@echo off
rem ---------------------------------------------------------------------------
rem XSEmu.bat - fetch XSEmu, install what it needs, build it, then run it.
rem
rem   XSEmu.bat                        fetch, check requirements, build, open the launcher
rem   XSEmu.bat <folder | game.exe>    run that title; later args go to the title
rem   XSEmu.bat run|inspect|disasm|shaders|rpf|warm-up|help|--help|--version ...
rem                                    passed straight to XSEmu.exe
rem   XSEmu.bat build                  build target\release\XSEmu.exe
rem   XSEmu.bat launcher               build the Qt launcher and open it
rem   XSEmu.bat update                 pull the newest sources, rebuild both
rem
rem Put this file in a folder of its own and run it. The first run turns that
rem folder into an XSEmu checkout: it fetches the sources here, so Cargo.toml and
rem crates\ land next to this script. Missing build tools are offered for install
rem through winget and aqtinstall, then the runtime is built with cargo and the
rem Qt launcher with CMake. You can also drop a game folder or a title .exe onto
rem the script.
rem
rem XSEMU_INSTALL=no  never offer to install anything, just report what is missing
rem XSEMU_INSTALL=yes accept every install offer without asking
rem ---------------------------------------------------------------------------
setlocal EnableExtensions
title XSEmu

set "HERE=%~dp0"
if "%HERE:~-1%"=="\" set "HERE=%HERE:~0,-1%"
set "SELF=%~nx0"
set "REPO_URL=https://github.com/zortos293/XSEmu"
set "ARCHIVE=%REPO_URL%/archive/refs/heads/main.zip"
set "QT_VER=6.8.3"
set "QT_KIT=win64_msvc2022_64"
set "QT_ROOT=%LOCALAPPDATA%\Qt"
set "SRC="
set "TARGET="
set "EXE="
set "QT_DIR="
set "PY="
set "ANSWER="
rem Do not name this RC: CMake reads the RC variable as its resource compiler.
set "EXITCODE=0"

rem A double-click or drag-and-drop starts this through cmd /c, which closes the
rem window afterwards; keep it open then, but not when run from an open console.
set "CMDLINE=%cmdcmdline:"=%"
set "PAUSE_AT_END="
if not "%CMDLINE:/c=%"=="%CMDLINE%" set "PAUSE_AT_END=1"

if "%HERE:~1%"==":" (
  echo [XSEmu] ERROR: "%HERE%" is a whole drive. Give this script a folder of its
  echo          own; the first run turns that folder into an XSEmu checkout.
  goto failed
)

set "FIRST=%~1"
if /i "%FIRST%"=="update" goto update_target

call :ensure_source
if errorlevel 1 goto failed
set "EXE=%SRC%\target\release\XSEmu.exe"

if not defined FIRST goto default_target
if /i "%FIRST%"=="build" goto only_build
if /i "%FIRST%"=="launcher" goto launcher_target
if /i "%FIRST%"=="run" goto pass_through
if /i "%FIRST%"=="inspect" goto pass_through
if /i "%FIRST%"=="disasm" goto pass_through
if /i "%FIRST%"=="shaders" goto pass_through
if /i "%FIRST%"=="rpf" goto pass_through
if /i "%FIRST%"=="warm-up" goto pass_through
if /i "%FIRST%"=="help" goto pass_through
if /i "%FIRST%"=="--help" goto pass_through
if /i "%FIRST%"=="-h" goto pass_through
if /i "%FIRST%"=="--version" goto pass_through

rem Anything else is a game folder or a title .exe.
set "GAME=%~1"
set "GAMEARGS="
shift
:collect_args
if "%~1"=="" goto run_game
set "GAMEARGS=%GAMEARGS% "%~1""
shift
goto collect_args

:run_game
call :ensure_exe
if errorlevel 1 goto failed
call :note_dxc
if defined GAMEARGS goto run_game_args
echo [XSEmu] run "%GAME%"
"%EXE%" run "%GAME%"
set "EXITCODE=%ERRORLEVEL%"
goto done

:run_game_args
echo [XSEmu] run "%GAME%" --%GAMEARGS%
"%EXE%" run "%GAME%" -- %GAMEARGS%
set "EXITCODE=%ERRORLEVEL%"
goto done

:pass_through
call :ensure_exe
if errorlevel 1 goto failed
if /i "%FIRST%"=="run" call :note_dxc
if /i "%FIRST%"=="shaders" call :note_dxc
if /i "%FIRST%"=="warm-up" call :note_dxc
"%EXE%" %*
set "EXITCODE=%ERRORLEVEL%"
goto done

:default_target
call :ensure_exe
if errorlevel 1 goto failed
call :ensure_launcher
if errorlevel 1 goto console_menu
echo [XSEmu] Starting the launcher.
"%SRC%\target\launcher-dist\bin\XSEmuLauncher.exe"
set "EXITCODE=%ERRORLEVEL%"
goto done

:console_menu
call :note_dxc
echo [XSEmu] Starting XSEmu.exe. Its menu asks for a game folder, a game .exe
echo          or a MicrosoftGame.config.
"%EXE%"
set "EXITCODE=%ERRORLEVEL%"
goto done

:only_build
call :build
if errorlevel 1 goto failed
goto done

:launcher_target
call :ensure_launcher_forced
if errorlevel 1 goto failed
echo [XSEmu] Starting the launcher.
"%SRC%\target\launcher-dist\bin\XSEmuLauncher.exe"
set "EXITCODE=%ERRORLEVEL%"
goto done

:update_target
call :find_source
if not defined SRC (
  call :ensure_source
  if errorlevel 1 goto failed
) else (
  call :update_source
  if errorlevel 1 goto failed
)
set "EXE=%SRC%\target\release\XSEmu.exe"
call :build
if errorlevel 1 goto failed
if not exist "%SRC%\target\launcher-dist\bin\XSEmuLauncher.exe" goto done
call :have_qt
if errorlevel 1 goto done
call :build_launcher
if errorlevel 1 goto failed
goto done

rem ---------------------------------------------------------------- helpers ---

:find_source
set "SRC="
if exist "%HERE%\Cargo.toml" if exist "%HERE%\crates\xcl\Cargo.toml" set "SRC=%HERE%"
if not defined SRC if exist "%HERE%\XSEmu\Cargo.toml" if exist "%HERE%\XSEmu\crates\xcl\Cargo.toml" set "SRC=%HERE%\XSEmu"
exit /b 0

:ensure_source
call :find_source
if defined SRC exit /b 0
set "TARGET=%HERE%"
call :fetch
if errorlevel 1 exit /b 1
if not exist "%TARGET%\crates\xcl\Cargo.toml" (
  echo [XSEmu] ERROR: the download left "%TARGET%" without the xcl crate.
  exit /b 1
)
set "SRC=%TARGET%"
exit /b 0

:fetch
if exist "%TARGET%\Cargo.toml" (
  echo [XSEmu] ERROR: "%TARGET%" already holds another Rust project, and fetching
  echo          XSEmu here would overwrite it. Use an empty folder instead.
  exit /b 1
)
set "OTHER_REMOTE="
if exist "%TARGET%\.git" for /f "delims=" %%U in ('git -C "%TARGET%" remote get-url origin 2^>nul') do set "OTHER_REMOTE=%%U"
if defined OTHER_REMOTE if /i not "%OTHER_REMOTE%"=="%REPO_URL%" (
  echo [XSEmu] ERROR: "%TARGET%" already belongs to another git repository:
  echo            %OTHER_REMOTE%
  echo          Use an empty folder instead, so nothing of yours is overwritten.
  exit /b 1
)
echo [XSEmu] No XSEmu sources here yet, so fetching them into "%TARGET%".
echo          One download and one build; expect a few minutes.
call :need_git
where git >nul 2>nul
if errorlevel 1 goto fetch_archive
git -C "%TARGET%" init --quiet
if errorlevel 1 goto fetch_archive
git -C "%TARGET%" remote remove origin >nul 2>nul
git -C "%TARGET%" remote add origin "%REPO_URL%"
git -C "%TARGET%" fetch --quiet --depth 1 origin +refs/heads/main:refs/remotes/origin/main
if errorlevel 1 goto fetch_git_failed
git -C "%TARGET%" checkout --quiet --force -B main origin/main
if errorlevel 1 goto fetch_git_failed
echo [XSEmu] Fetched "%REPO_URL%" into "%TARGET%".
echo          Later runs reuse it; "XSEmu.bat update" pulls the newest sources.
exit /b 0

:fetch_git_failed
echo [XSEmu] git could not fetch XSEmu, so trying a source archive instead.
if exist "%TARGET%\.git" rmdir /s /q "%TARGET%\.git"

:fetch_archive
set "ZIP=%TEMP%\xsemu-main.zip"
set "UNPACK=%TEMP%\xsemu-unpack"
if exist "%ZIP%" del /q "%ZIP%"
if exist "%UNPACK%" rmdir /s /q "%UNPACK%"
echo [XSEmu] Downloading "%ARCHIVE%".
where curl >nul 2>nul
if errorlevel 1 goto fetch_archive_ps
curl -L --fail --silent --show-error -o "%ZIP%" "%ARCHIVE%"
if errorlevel 1 goto fetch_failed
goto fetch_unpack

:fetch_archive_ps
powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; [Net.ServicePointManager]::SecurityProtocol=[Net.SecurityProtocolType]::Tls12; Invoke-WebRequest -UseBasicParsing -Uri '%ARCHIVE%' -OutFile '%ZIP%'"
if errorlevel 1 goto fetch_failed

:fetch_unpack
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -LiteralPath '%ZIP%' -DestinationPath '%UNPACK%' -Force"
if errorlevel 1 goto fetch_failed
robocopy "%UNPACK%\XSEmu-main" "%TARGET%" /E /NFL /NDL /NJH /NJS /NP >nul
if errorlevel 8 goto fetch_failed
del /q "%ZIP%" 2>nul
rmdir /s /q "%UNPACK%" 2>nul
echo [XSEmu] Unpacked the sources into "%TARGET%".
echo          That copy has no git history, so "XSEmu.bat update" downloads a
echo          fresh archive instead of pulling.
exit /b 0

:fetch_failed
echo [XSEmu] ERROR: could not download XSEmu.
echo          Check the network, or fetch the sources yourself with:
echo            git clone %REPO_URL% "%TARGET%"
exit /b 1

:update_source
if exist "%SRC%\.git" goto update_git
echo [XSEmu] "%SRC%" came from a source archive, so downloading a fresh copy.
set "TARGET=%SRC%"
goto fetch_archive

:update_git
call :need_git
where git >nul 2>nul
if errorlevel 1 exit /b 1
echo [XSEmu] Pulling the newest XSEmu sources into "%SRC%".
git -C "%SRC%" pull --ff-only
if errorlevel 1 (
  echo [XSEmu] ERROR: git pull failed, so the checkout is unchanged. Local edits
  echo          or upstream history rewrites block a fast-forward: reset it with
  echo            git -C "%SRC%" fetch --depth 1 origin main ^&^& git -C "%SRC%" reset --hard FETCH_HEAD
  exit /b 1
)
exit /b 0

rem ------------------------------------------------------------- the builds ---

:ensure_exe
if exist "%EXE%" exit /b 0
call :build
exit /b %ERRORLEVEL%

:build
call :need_runtime
if errorlevel 1 exit /b 1
echo [XSEmu] Building "%EXE%". The first build takes a while; later ones are quick.
pushd "%SRC%"
cargo build --release --locked --workspace
set "BUILD_RC=%ERRORLEVEL%"
popd
if not "%BUILD_RC%"=="0" (
  echo [XSEmu] ERROR: cargo build failed with exit code %BUILD_RC%.
  echo          The log above says why.
  exit /b 1
)
if not exist "%EXE%" (
  echo [XSEmu] ERROR: cargo reported success, but "%EXE%" is missing.
  exit /b 1
)
echo [XSEmu] Built "%EXE%".
exit /b 0

:ensure_launcher
if exist "%SRC%\target\launcher-dist\bin\XSEmuLauncher.exe" exit /b 0

:ensure_launcher_forced
call :ensure_exe
if errorlevel 1 exit /b 1
call :need_cmake
if errorlevel 1 exit /b 1
call :need_qt
if errorlevel 1 exit /b 1
call :build_launcher
exit /b %ERRORLEVEL%

:build_launcher
call :need_vs
if errorlevel 1 exit /b 1
if not defined QT_DIR call :have_qt
if not defined QT_DIR exit /b 1
echo [XSEmu] Building the launcher with Qt at "%QT_DIR%". This takes a few minutes.
cmake -S "%SRC%\launcher" -B "%SRC%\target\launcher-build" -G "Visual Studio 17 2022" -A x64 -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="%QT_DIR%"
if errorlevel 1 (
  echo [XSEmu] ERROR: cmake could not configure the launcher.
  echo          The log above says why.
  exit /b 1
)
cmake --build "%SRC%\target\launcher-build" --config Release
if errorlevel 1 (
  echo [XSEmu] ERROR: cmake could not build the launcher.
  echo          The log above says why.
  exit /b 1
)
cmake --install "%SRC%\target\launcher-build" --config Release --prefix "%SRC%\target\launcher-dist"
if errorlevel 1 (
  echo [XSEmu] ERROR: cmake could not install the launcher.
  echo          The log above says why.
  exit /b 1
)
if not exist "%SRC%\target\launcher-dist\bin\XSEmuLauncher.exe" (
  echo [XSEmu] ERROR: XSEmuLauncher.exe is missing after the build.
  exit /b 1
)
rem The launcher starts XSEmu.exe as its own process, so keep it beside itself.
copy /y "%EXE%" "%SRC%\target\launcher-dist\bin\XSEmu.exe" >nul
if errorlevel 1 (
  echo [XSEmu] ERROR: could not copy XSEmu.exe next to the launcher.
  exit /b 1
)
echo [XSEmu] Built "%SRC%\target\launcher-dist\bin\XSEmuLauncher.exe".
exit /b 0

rem --------------------------------------------------------- what it needs ----

:ask
rem %1 is the question. Sets ANSWER to y or n; anything but an explicit yes is no.
set "ANSWER=n"
if /i "%XSEMU_INSTALL%"=="no" exit /b 0
if /i "%XSEMU_INSTALL%"=="yes" set "ANSWER=y"
if "%ANSWER%"=="y" exit /b 0
set "REPLY="
set /p "REPLY=%~1 [y/N] "
if /i "%REPLY%"=="y" set "ANSWER=y"
if /i "%REPLY%"=="yes" set "ANSWER=y"
exit /b 0

:need_runtime
call :need_vs
if errorlevel 1 exit /b 1
call :need_cargo
if errorlevel 1 exit /b 1
exit /b 0

:need_git
where git >nul 2>nul
if not errorlevel 1 exit /b 0
if exist "%ProgramFiles%\Git\cmd\git.exe" set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
where git >nul 2>nul
if not errorlevel 1 exit /b 0
where winget >nul 2>nul
if errorlevel 1 goto no_winget
call :ask "git is missing. Install Git with winget now?"
if not "%ANSWER%"=="y" exit /b 1
echo [XSEmu] Installing Git. The installer may ask for permission.
winget install --id Git.Git -e --source winget --silent --accept-source-agreements --accept-package-agreements
if exist "%ProgramFiles%\Git\cmd\git.exe" set "PATH=%ProgramFiles%\Git\cmd;%PATH%"
where git >nul 2>nul
if errorlevel 1 (
  echo [XSEmu] ERROR: Git is still not on PATH. Close this window, open a new one
  echo          and run the script again.
  exit /b 1
)
echo [XSEmu] Git is installed.
exit /b 0

:need_cargo
where cargo >nul 2>nul
if not errorlevel 1 exit /b 0
if exist "%USERPROFILE%\.cargo\bin\cargo.exe" set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"
where cargo >nul 2>nul
if not errorlevel 1 exit /b 0
where winget >nul 2>nul
if errorlevel 1 goto missing_cargo
call :ask "The Rust toolchain is missing. Install it with winget now?"
if not "%ANSWER%"=="y" goto missing_cargo
echo [XSEmu] Installing the Rust MSVC toolchain. This downloads a few hundred MB.
winget install --id Rustlang.Rustup -e --source winget --silent --accept-source-agreements --accept-package-agreements
set "PATH=%USERPROFILE%\.cargo\bin;%PATH%"
where rustup >nul 2>nul
if errorlevel 1 goto missing_cargo
rustup default stable-x86_64-pc-windows-msvc
where cargo >nul 2>nul
if errorlevel 1 goto missing_cargo
echo [XSEmu] Cargo is installed.
exit /b 0

:no_winget
echo [XSEmu] ERROR: winget is not available, so this script cannot install
echo          anything for you. Install the missing tool by hand and run again.
exit /b 1

:missing_python
echo [XSEmu] ERROR: Python is not on PATH, and installing Qt needs it.
echo            winget install Python.Python.3.12
exit /b 1

:missing_cargo
echo [XSEmu] ERROR: cargo is not on PATH, so XSEmu cannot be built.
echo          Install it yourself, then run the script again:
echo            winget install Rustlang.Rustup
echo            rustup default stable-x86_64-pc-windows-msvc
exit /b 1

:need_vs
call :have_vs
if not errorlevel 1 exit /b 0
where winget >nul 2>nul
if errorlevel 1 goto missing_vs
call :ask "The Visual Studio C++ build tools are missing. Install them with winget now (several GB)?"
if not "%ANSWER%"=="y" goto missing_vs
echo [XSEmu] Installing the Visual Studio 2022 build tools with the C++ workload.
echo          This takes a while and may ask for permission.
winget install --id Microsoft.VisualStudio.2022.BuildTools -e --source winget --accept-source-agreements --accept-package-agreements --override "--quiet --wait --add Microsoft.VisualStudio.Workload.VCTools --includeRecommended"
call :have_vs
if errorlevel 1 goto missing_vs
echo [XSEmu] The C++ build tools are installed.
exit /b 0

:missing_vs
echo [XSEmu] ERROR: no Visual Studio C++ build tools were found.
echo          Install "Desktop development with C++" from the Visual Studio
echo          installer, or run: winget install Microsoft.VisualStudio.2022.BuildTools
exit /b 1

:have_vs
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" exit /b 1
set "VS_PATH="
for /f "usebackq delims=" %%P in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath 2^>nul`) do set "VS_PATH=%%P"
if not defined VS_PATH exit /b 1
exit /b 0

:need_cmake
where cmake >nul 2>nul
if not errorlevel 1 exit /b 0
if exist "%ProgramFiles%\CMake\bin\cmake.exe" set "PATH=%ProgramFiles%\CMake\bin;%PATH%"
where cmake >nul 2>nul
if not errorlevel 1 exit /b 0
where winget >nul 2>nul
if errorlevel 1 goto missing_cmake
call :ask "CMake is missing. Install it with winget now?"
if not "%ANSWER%"=="y" goto missing_cmake
echo [XSEmu] Installing CMake.
winget install --id Kitware.CMake -e --source winget --silent --accept-source-agreements --accept-package-agreements
if exist "%ProgramFiles%\CMake\bin\cmake.exe" set "PATH=%ProgramFiles%\CMake\bin;%PATH%"
where cmake >nul 2>nul
if errorlevel 1 goto missing_cmake
echo [XSEmu] CMake is installed.
exit /b 0

:missing_cmake
echo [XSEmu] ERROR: cmake is not on PATH, so the Qt launcher cannot be built.
echo          Install it, then run the script again: winget install Kitware.CMake
exit /b 1

:have_qt
set "QT_DIR="
if defined CMAKE_PREFIX_PATH set "QT_DIR=%CMAKE_PREFIX_PATH%"
if defined QT_DIR exit /b 0
if exist "%QT_ROOT%" for /f "delims=" %%V in ('dir /b /ad /o-n "%QT_ROOT%" 2^>nul') do call :try_qt "%QT_ROOT%\%%V"
if defined QT_DIR exit /b 0
if exist "C:\Qt" for /f "delims=" %%V in ('dir /b /ad /o-n "C:\Qt" 2^>nul') do call :try_qt "C:\Qt\%%V"
if defined QT_DIR exit /b 0
exit /b 1

:try_qt
if defined QT_DIR exit /b 0
if exist "%~1\msvc2022_64\lib\cmake\Qt6\Qt6Config.cmake" set "QT_DIR=%~1\msvc2022_64"
if not defined QT_DIR if exist "%~1\msvc2019_64\lib\cmake\Qt6\Qt6Config.cmake" set "QT_DIR=%~1\msvc2019_64"
exit /b 0

:need_qt
call :have_qt
if not errorlevel 1 exit /b 0
call :ask "Qt 6 is missing. Download it with aqtinstall now (about 1.5 GB)?"
if not "%ANSWER%"=="y" goto missing_qt
call :need_python
if errorlevel 1 goto missing_qt
echo [XSEmu] Installing aqtinstall and Qt %QT_VER% for MSVC 2022 into "%QT_ROOT%".
echo          This downloads about 1.5 GB and takes a few minutes.
%PY% -m pip install --user --quiet --upgrade aqtinstall
if errorlevel 1 goto missing_qt
%PY% -m aqt install-qt windows desktop %QT_VER% %QT_KIT% --outputdir "%QT_ROOT%"
if errorlevel 1 goto missing_qt
call :have_qt
if errorlevel 1 goto missing_qt
echo [XSEmu] Qt is installed at "%QT_DIR%".
exit /b 0

:missing_qt
echo [XSEmu] ERROR: no Qt 6 found, so the launcher cannot be built.
echo          Install Qt 6.4 or later for MSVC 2022 x64 into "%QT_ROOT%":
echo            py -m pip install --user aqtinstall
echo            py -m aqt install-qt windows desktop %QT_VER% %QT_KIT% --outputdir "%QT_ROOT%"
echo          Or install it with the Qt online installer and set CMAKE_PREFIX_PATH.
echo          XSEmu.exe itself still works: "XSEmu.bat <game folder>" runs a title
echo          without the launcher.
exit /b 1

:need_python
if defined PY exit /b 0
py -3 --version >nul 2>nul && set "PY=py -3"
if defined PY exit /b 0
python --version >nul 2>nul && set "PY=python"
if defined PY exit /b 0
where winget >nul 2>nul
if errorlevel 1 goto missing_python
call :ask "Python is missing, and installing Qt needs it. Install Python with winget now?"
if not "%ANSWER%"=="y" exit /b 1
echo [XSEmu] Installing Python.
winget install --id Python.Python.3.12 -e --source winget --silent --accept-source-agreements --accept-package-agreements
set "PATH=%LOCALAPPDATA%\Programs\Python\Python312;%LOCALAPPDATA%\Programs\Python\Python312\Scripts;%PATH%"
py -3 --version >nul 2>nul && set "PY=py -3"
if defined PY exit /b 0
python --version >nul 2>nul && set "PY=python"
if defined PY exit /b 0
echo [XSEmu] ERROR: Python is still not on PATH. Open a new window and run again.
exit /b 1

:note_dxc
rem Shaders are translated to HLSL and compiled with DXC. Warn if it looks
rem unfindable; it is only fatal to shader work, not to starting XSEmu.
if exist "%SRC%\target\release\dxcompiler.dll" exit /b 0
if exist "%SRC%\dxcompiler.dll" exit /b 0
if defined XCL_DXC_DIR exit /b 0
rem if exist stops at the first wildcard, so walk the SDK folders one by one.
for /d %%K in ("%ProgramFiles(x86)%\Windows Kits\10\bin\*") do if exist "%%K\x64\dxcompiler.dll" exit /b 0
echo [XSEmu] Note: no dxcompiler.dll found next to XSEmu.exe, in XCL_DXC_DIR
echo          or in the Windows SDK. Shader translation needs DXC 1.8 or newer:
echo          install "Windows SDK for Desktop C++ x64 Apps", or set XCL_DXC_DIR
echo          to a folder holding dxcompiler.dll and dxil.dll. Without it, set
echo          XCL_SHADER_BACKEND=dxil to use the built-in DXIL backend.
exit /b 0

:failed
set "EXITCODE=1"

:done
if not "%EXITCODE%"=="0" (
  echo.
  echo [XSEmu] XSEmu exited with code %EXITCODE%.
)
if defined PAUSE_AT_END (
  echo.
  pause
)
endlocal & exit /b %EXITCODE%
