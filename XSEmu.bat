@echo off
rem ---------------------------------------------------------------------------
rem XSEmu.bat - fetch XSEmu, build it, then run a title.
rem
rem   XSEmu.bat                        fetch, build, then open XSEmu's own menu
rem   XSEmu.bat <folder | game.exe>    run that title; later args go to the title
rem   XSEmu.bat run|inspect|disasm|shaders|rpf|warm-up|help|--help|--version ...
rem                                    passed straight to XSEmu.exe
rem   XSEmu.bat build                  build target\release\XSEmu.exe
rem   XSEmu.bat launcher               build the Qt launcher (CMake + Qt 6) and start it
rem   XSEmu.bat update                 pull the newest sources and rebuild
rem
rem Put this file in a folder of its own and run it. The first run turns that
rem folder into an XSEmu checkout: it fetches the sources here, so Cargo.toml and
rem crates\ land next to this script, then it builds. Without git it unpacks a
rem source archive instead. A folder that already has Cargo.toml is used as is,
rem and an XSEmu\ subfolder from version 1.0.0 of this script is still honoured.
rem You can also drop a game folder or a title .exe onto the script.
rem ---------------------------------------------------------------------------
setlocal EnableExtensions
title XSEmu

set "HERE=%~dp0"
if "%HERE:~-1%"=="\" set "HERE=%HERE:~0,-1%"
set "SELF=%~nx0"
set "REPO_URL=https://github.com/zortos293/XSEmu"
set "ARCHIVE=%REPO_URL%/archive/refs/heads/main.zip"
set "SRC="
set "TARGET="
set "EXE="
set "RC=0"

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

if not defined FIRST goto launch_menu
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
call :check_dxc
if defined GAMEARGS goto run_game_args
echo [XSEmu] run "%GAME%"
"%EXE%" run "%GAME%"
set "RC=%ERRORLEVEL%"
goto done

:run_game_args
echo [XSEmu] run "%GAME%" --%GAMEARGS%
"%EXE%" run "%GAME%" -- %GAMEARGS%
set "RC=%ERRORLEVEL%"
goto done

:pass_through
call :ensure_exe
if errorlevel 1 goto failed
if /i "%FIRST%"=="run" call :check_dxc
if /i "%FIRST%"=="shaders" call :check_dxc
if /i "%FIRST%"=="warm-up" call :check_dxc
"%EXE%" %*
set "RC=%ERRORLEVEL%"
goto done

:launch_menu
call :ensure_exe
if errorlevel 1 goto failed
call :check_dxc
echo [XSEmu] Starting XSEmu.exe. Its menu asks for a game folder, a game .exe
echo          or a MicrosoftGame.config.
"%EXE%"
set "RC=%ERRORLEVEL%"
goto done

:only_build
call :build
if errorlevel 1 goto failed
goto done

:launcher_target
call :ensure_exe
if errorlevel 1 goto failed
call :build_launcher
if errorlevel 1 goto failed
echo [XSEmu] Starting the launcher.
"%SRC%\target\launcher-dist\bin\XSEmuLauncher.exe"
set "RC=%ERRORLEVEL%"
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
where git >nul 2>nul
if errorlevel 1 (
  echo [XSEmu] ERROR: git is not on PATH, so this checkout cannot be updated.
  exit /b 1
)
echo [XSEmu] Pulling the newest XSEmu sources into "%SRC%".
git -C "%SRC%" pull --ff-only
if errorlevel 1 (
  echo [XSEmu] ERROR: git pull failed, so the checkout is unchanged. Local edits
  echo          or upstream history rewrites block a fast-forward: reset it with
  echo            git -C "%SRC%" fetch --depth 1 origin main ^&^& git -C "%SRC%" reset --hard FETCH_HEAD
  exit /b 1
)
exit /b 0

:ensure_exe
if exist "%EXE%" exit /b 0
call :build
exit /b %ERRORLEVEL%

:build
where cargo >nul 2>nul
if errorlevel 1 (
  echo [XSEmu] ERROR: cargo is not on PATH.
  echo          Install the Rust MSVC toolchain, then run this script again:
  echo            winget install Rustlang.Rustup
  echo            rustup default stable-x86_64-pc-windows-msvc
  echo          Building also needs the Visual Studio C++ build tools,
  echo          the "Desktop development with C++" workload.
  exit /b 1
)
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

:build_launcher
where cmake >nul 2>nul
if errorlevel 1 (
  echo [XSEmu] ERROR: cmake is not on PATH. The launcher is a CMake project:
  echo            winget install Kitware.CMake
  exit /b 1
)
set "QT_DIR="
if defined CMAKE_PREFIX_PATH set "QT_DIR=%CMAKE_PREFIX_PATH%"
if defined QT_DIR goto build_launcher_qt
if exist "C:\Qt" for /f "delims=" %%V in ('dir /b /ad /o-n "C:\Qt" 2^>nul') do call :try_qt "C:\Qt\%%V"
if defined QT_DIR goto build_launcher_qt
echo [XSEmu] ERROR: Qt 6 was not found.
echo          The launcher needs Qt 6.4 or later built for MSVC 2022 x64. Install
echo          it with the Qt online installer ^(the "MSVC 2022 64-bit" component;
echo          CI uses 6.8^), or point CMAKE_PREFIX_PATH at your kit folder, for
echo          example C:\Qt\6.8.3\msvc2022_64.
exit /b 1

:build_launcher_qt
echo [XSEmu] Building the launcher with Qt at "%QT_DIR%". This takes a few minutes.
cmake -S "%SRC%\launcher" -B "%SRC%\target\launcher-build" -G "Visual Studio 17 2022" -A x64 -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="%QT_DIR%"
if errorlevel 1 (
  echo [XSEmu] ERROR: cmake could not configure the launcher.
  echo          It needs Visual Studio 2022 with the C++ build tools.
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

:try_qt
if defined QT_DIR exit /b 0
if exist "%~1\msvc2022_64\lib\cmake\Qt6\Qt6Config.cmake" set "QT_DIR=%~1\msvc2022_64"
if not defined QT_DIR if exist "%~1\msvc2019_64\lib\cmake\Qt6\Qt6Config.cmake" set "QT_DIR=%~1\msvc2019_64"
exit /b 0

:check_dxc
rem Shaders are translated to HLSL and compiled with DXC. Warn once if it looks
rem unfindable; it is only fatal to shader work, not to starting XSEmu.
if exist "%SRC%\target\release\dxcompiler.dll" exit /b 0
if exist "%SRC%\dxcompiler.dll" exit /b 0
if defined XCL_DXC_DIR exit /b 0
if exist "%ProgramFiles(x86)%\Windows Kits\10\bin\*\x64\dxcompiler.dll" exit /b 0
echo [XSEmu] Note: no dxcompiler.dll found next to XSEmu.exe, in XCL_DXC_DIR
echo          or in the Windows SDK. Shader translation needs DXC 1.8 or newer:
echo          install "Windows SDK for Desktop C++ x64 Apps", or set XCL_DXC_DIR
echo          to a folder holding dxcompiler.dll and dxil.dll. Without it, set
echo          XCL_SHADER_BACKEND=dxil to use the built-in DXIL backend.
exit /b 0

:failed
set "RC=1"

:done
if not "%RC%"=="0" (
  echo.
  echo [XSEmu] XSEmu exited with code %RC%.
)
if defined PAUSE_AT_END (
  echo.
  pause
)
endlocal & exit /b %RC%
