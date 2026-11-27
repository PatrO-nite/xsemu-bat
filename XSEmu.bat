@echo off
rem ---------------------------------------------------------------------------
rem XSEmu.bat - build XSEmu from this repository when needed, then run a title.
rem
rem   XSEmu.bat                        open XSEmu's own menu (it asks for the game)
rem   XSEmu.bat <folder | game.exe>    run that title; later args go to the title
rem   XSEmu.bat run <folder | exe>     the same, spelled out
rem   XSEmu.bat inspect|disasm|shaders|rpf|warm-up|--help|--version ...
rem                                    passed straight to XSEmu.exe
rem   XSEmu.bat build                  build target\release\XSEmu.exe
rem   XSEmu.bat launcher               build the Qt launcher (CMake + Qt 6) and start it
rem
rem Keep this file in the repository root, next to Cargo.toml. You can also drop
rem a game folder or a title .exe onto it in Explorer.
rem ---------------------------------------------------------------------------
setlocal EnableExtensions
title XSEmu

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
set "EXE=%ROOT%\target\release\XSEmu.exe"
set "SELF=%~nx0"
set "RC=0"

rem A double-click or drag-and-drop starts this through cmd /c, which closes the
rem window afterwards; keep it open then, but not when run from an open console.
set "CMDLINE=%cmdcmdline:"=%"
set "PAUSE_AT_END="
if not "%CMDLINE:/c=%"=="%CMDLINE%" set "PAUSE_AT_END=1"

if not exist "%ROOT%\Cargo.toml" (
  echo [XSEmu] ERROR: Cargo.toml is not next to %SELF%.
  echo          Put this script in the XSEmu repository root: the folder that
  echo          holds Cargo.toml, crates\ and launcher\.
  set "RC=1"
  goto done
)

set "FIRST=%~1"
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
if errorlevel 1 (
  set "RC=1"
  goto done
)
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
if errorlevel 1 (
  set "RC=1"
  goto done
)
call :check_dxc
"%EXE%" %*
set "RC=%ERRORLEVEL%"
goto done

:launch_menu
call :ensure_exe
if errorlevel 1 (
  set "RC=1"
  goto done
)
call :check_dxc
echo [XSEmu] Starting XSEmu.exe. Its menu asks for a game folder, a game .exe
echo          or a MicrosoftGame.config.
"%EXE%"
set "RC=%ERRORLEVEL%"
goto done

:only_build
call :build
if errorlevel 1 (
  set "RC=1"
  goto done
)
goto done

:launcher_target
call :ensure_exe
if errorlevel 1 (
  set "RC=1"
  goto done
)
call :build_launcher
if errorlevel 1 (
  set "RC=1"
  goto done
)
echo [XSEmu] Starting the launcher.
"%ROOT%\target\launcher-dist\bin\XSEmuLauncher.exe"
set "RC=%ERRORLEVEL%"
goto done

rem ---------------------------------------------------------------- helpers ---

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
echo [XSEmu] Building target\release\XSEmu.exe. The first build takes a while.
pushd "%ROOT%"
cargo build --release --locked --workspace
set "BUILD_RC=%ERRORLEVEL%"
popd
if not "%BUILD_RC%"=="0" (
  echo [XSEmu] ERROR: cargo build failed with exit code %BUILD_RC%.
  echo          The log above says why.
  exit /b 1
)
if not exist "%EXE%" (
  echo [XSEmu] ERROR: cargo reported success, but %EXE% is missing.
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
cmake -S "%ROOT%\launcher" -B "%ROOT%\target\launcher-build" -G "Visual Studio 17 2022" -A x64 -DCMAKE_BUILD_TYPE=Release -DCMAKE_PREFIX_PATH="%QT_DIR%"
if errorlevel 1 (
  echo [XSEmu] ERROR: cmake could not configure the launcher.
  echo          It needs Visual Studio 2022 with the C++ build tools.
  exit /b 1
)
cmake --build "%ROOT%\target\launcher-build" --config Release
if errorlevel 1 (
  echo [XSEmu] ERROR: cmake could not build the launcher.
  echo          The log above says why.
  exit /b 1
)
cmake --install "%ROOT%\target\launcher-build" --config Release --prefix "%ROOT%\target\launcher-dist"
if errorlevel 1 (
  echo [XSEmu] ERROR: cmake could not install the launcher.
  echo          The log above says why.
  exit /b 1
)
if not exist "%ROOT%\target\launcher-dist\bin\XSEmuLauncher.exe" (
  echo [XSEmu] ERROR: XSEmuLauncher.exe is missing after the build.
  exit /b 1
)
rem The launcher starts XSEmu.exe as its own process, so keep it beside itself.
copy /y "%EXE%" "%ROOT%\target\launcher-dist\bin\XSEmu.exe" >nul
if errorlevel 1 (
  echo [XSEmu] ERROR: could not copy XSEmu.exe next to the launcher.
  exit /b 1
)
echo [XSEmu] Built "%ROOT%\target\launcher-dist\bin\XSEmuLauncher.exe".
exit /b 0

:try_qt
if defined QT_DIR exit /b 0
if exist "%~1\msvc2022_64\lib\cmake\Qt6\Qt6Config.cmake" set "QT_DIR=%~1\msvc2022_64"
if not defined QT_DIR if exist "%~1\msvc2019_64\lib\cmake\Qt6\Qt6Config.cmake" set "QT_DIR=%~1\msvc2019_64"
exit /b 0

:check_dxc
rem Shaders are translated to HLSL and compiled with DXC. Warn once if it looks
rem unfindable; it is only fatal to shader work, not to starting XSEmu.
if exist "%ROOT%\dxcompiler.dll" exit /b 0
if defined XCL_DXC_DIR exit /b 0
if exist "%ProgramFiles(x86)%\Windows Kits\10\bin\*\x64\dxcompiler.dll" exit /b 0
echo [XSEmu] Note: no dxcompiler.dll found next to XSEmu.exe, in XCL_DXC_DIR
echo          or in the Windows SDK. Shader translation needs DXC 1.8 or newer:
echo          install "Windows SDK for Desktop C++ x64 Apps", or set XCL_DXC_DIR
echo          to a folder holding dxcompiler.dll and dxil.dll. Without it, set
echo          XCL_SHADER_BACKEND=dxil to use the built-in DXIL backend.
exit /b 0

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
