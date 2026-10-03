@echo off
setlocal enabledelayedexpansion

REM ==============================================================================
REM  Build Script for Teeworlds 0.6.5 (Surface RT / Windows RT - ARM32)
REM  For Windows with llvm-mingw toolchain
REM ==============================================================================

set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"

if "%MINGW%"=="" (
    if exist "C:\llvm-mingw" set "MINGW=C:\llvm-mingw"
    if exist "%USERPROFILE%\llvm-mingw" set "MINGW=%USERPROFILE%\llvm-mingw"
    if exist "%ROOT%\toolchain" set "MINGW=%ROOT%\toolchain"
)

if "%MINGW%"=="" (
    echo [ERROR] MINGW path not set. Please set MINGW environment variable.
    echo Example: set MINGW=C:\llvm-mingw
    exit /b 1
)

set "SRC=%ROOT%\src"
set "BUILD=%ROOT%\build"
set "OBJ=%BUILD%\obj"
set "LIBS=%ROOT%\libs"
set "LIBSARM=%LIBS%\arm32"
set "INCDIR=%LIBS%\include"
set "RUNTIMEDIR=%LIBS%\runtime"
set "DIST=%ROOT%\dist"

set "CC=%MINGW%\bin\armv7-w64-mingw32-clang.exe"
set "CXX=%MINGW%\bin\armv7-w64-mingw32-clang++.exe"
set "AR=%MINGW%\bin\armv7-w64-mingw32-ar.exe"
set "PATH=%MINGW%\bin;%PATH%"

if not exist "%CXX%" (
    echo [ERROR] Compiler not found: %CXX%
    exit /b 1
)

if not exist "%OBJ%" mkdir "%OBJ%"
if not exist "%DIST%" mkdir "%DIST%"

set "COMMON=-O2 -ffunction-sections -fdata-sections -I"%SRC%" -I"%INCDIR%" -I"%INCDIR%\SDL" -I"%SRC%\engine\external\wavpack" -I"%SRC%\engine\external\zlib" -include "%INCDIR%\winrt_compat.h""
set "CXXFLAGS=!COMMON! -fno-exceptions -fno-rtti -Wno-deprecated-non-prototype -Wno-unknown-warning-option"

echo === 1/4 Compiling external libraries ===
if not exist "%OBJ%\ext\zlib" mkdir "%OBJ%\ext\zlib"
if not exist "%OBJ%\ext\pnglite" mkdir "%OBJ%\ext\pnglite"
if not exist "%OBJ%\ext\md5" mkdir "%OBJ%\ext\md5"
if not exist "%OBJ%\ext\wavpack" mkdir "%OBJ%\ext\wavpack"

for %%f in ("%SRC%\engine\external\zlib\*.c") do %CC% !COMMON! -c "%%f" -o "%OBJ%\ext\zlib\%%~nf.o"
for %%f in ("%SRC%\engine\external\pnglite\*.c") do %CC% !COMMON! -c "%%f" -o "%OBJ%\ext\pnglite\%%~nf.o"
for %%f in ("%SRC%\engine\external\md5\*.c") do %CC% !COMMON! -c "%%f" -o "%OBJ%\ext\md5\%%~nf.o"
for %%f in ("%SRC%\engine\external\wavpack\*.c") do %CC% !COMMON! -c "%%f" -o "%OBJ%\ext\wavpack\%%~nf.o"

%AR% rcs "%BUILD%\lib_ext.a" "%OBJ%\ext\zlib\*.o" "%OBJ%\ext\pnglite\*.o" "%OBJ%\ext\md5\*.o" "%OBJ%\ext\wavpack\*.o"

echo === 2/4 Compiling client sources ===
if not exist "%OBJ%\shared" mkdir "%OBJ%\shared"
if not exist "%OBJ%\game" mkdir "%OBJ%\game"
if not exist "%OBJ%\base" mkdir "%OBJ%\base"
if not exist "%OBJ%\client" mkdir "%OBJ%\client"
if not exist "%OBJ%\gcli" mkdir "%OBJ%\gcli"
if not exist "%OBJ%\editor" mkdir "%OBJ%\editor"

set "CLIENT_OBJS="

for %%f in ("%SRC%\engine\shared\*.cpp") do (
    %CXX% !CXXFLAGS! -c "%%f" -o "%OBJ%\shared\%%~nf.o"
    set "CLIENT_OBJS=!CLIENT_OBJS! "%OBJ%\shared\%%~nf.o""
)

%CXX% !CXXFLAGS! -c "%SRC%\game\generated\protocol.cpp" -o "%OBJ%\game\protocol.o"
set "CLIENT_OBJS=!CLIENT_OBJS! "%OBJ%\game\protocol.o""
%CXX% !CXXFLAGS! -c "%SRC%\game\generated\client_data.cpp" -o "%OBJ%\game\client_data.o"
set "CLIENT_OBJS=!CLIENT_OBJS! "%OBJ%\game\client_data.o""
%CC% !COMMON! -c "%SRC%\base\system.c" -o "%OBJ%\base\system.o"
set "CLIENT_OBJS=!CLIENT_OBJS! "%OBJ%\base\system.o""

for %%f in ("%SRC%\game\*.cpp") do (
    %CXX% !CXXFLAGS! -c "%%f" -o "%OBJ%\game\%%~nf.o"
    set "CLIENT_OBJS=!CLIENT_OBJS! "%OBJ%\game\%%~nf.o""
)

if exist "%SRC%\game\generated\git_revision.cpp" (
    %CXX% !CXXFLAGS! -c "%SRC%\game\generated\git_revision.cpp" -o "%OBJ%\game\git_revision.o"
    set "CLIENT_OBJS=!CLIENT_OBJS! "%OBJ%\game\git_revision.o""
)

for %%f in ("%SRC%\engine\client\*.cpp") do (
    %CXX% !CXXFLAGS! -c "%%f" -o "%OBJ%\client\%%~nf.o"
    set "CLIENT_OBJS=!CLIENT_OBJS! "%OBJ%\client\%%~nf.o""
)

if exist "%SRC%\engine\client\glu_compat.c" (
    %CC% !COMMON! -c "%SRC%\engine\client\glu_compat.c" -o "%OBJ%\client\glu_compat.o"
    set "CLIENT_OBJS=!CLIENT_OBJS! "%OBJ%\client\glu_compat.o""
)

for %%f in ("%SRC%\game\client\components\*.cpp") do (
    %CXX% !CXXFLAGS! -c "%%f" -o "%OBJ%\gcli\%%~nf.o"
    set "CLIENT_OBJS=!CLIENT_OBJS! "%OBJ%\gcli\%%~nf.o""
)

for %%f in ("%SRC%\game\client\*.cpp") do (
    %CXX% !CXXFLAGS! -c "%%f" -o "%OBJ%\gcli\%%~nf.o"
    set "CLIENT_OBJS=!CLIENT_OBJS! "%OBJ%\gcli\%%~nf.o""
)

for %%f in ("%SRC%\game\editor\*.cpp") do (
    %CXX% !CXXFLAGS! -c "%%f" -o "%OBJ%\editor\%%~nf.o"
    set "CLIENT_OBJS=!CLIENT_OBJS! "%OBJ%\editor\%%~nf.o""
)

echo === Linking teeworlds.exe ===
%CXX% -mwindows -o "%DIST%\teeworlds.exe" !CLIENT_OBJS! "%BUILD%\lib_ext.a" "%LIBSARM%\libfreetype.a" "%LIBSARM%\libSDL.a" -Wl,-Bstatic -lc++ -lc++abi -lunwind -Wl,-Bdynamic -lopengl32 -lwinmm -lws2_32 -luser32 -lgdi32 -ladvapi32 -lshell32 -s

echo === 3/4 Compiling server sources ===
if not exist "%OBJ%\sv_shared" mkdir "%OBJ%\sv_shared"
if not exist "%OBJ%\sv_esrv" mkdir "%OBJ%\sv_esrv"
if not exist "%OBJ%\sv_game" mkdir "%OBJ%\sv_game"
if not exist "%OBJ%\sv_gsrv" mkdir "%OBJ%\sv_gsrv"
if not exist "%OBJ%\sv_gen" mkdir "%OBJ%\sv_gen"
if not exist "%OBJ%\sv_base" mkdir "%OBJ%\sv_base"

set "SERVER_OBJS="

for %%f in ("%SRC%\engine\shared\*.cpp") do (
    %CXX% !CXXFLAGS! -c "%%f" -o "%OBJ%\sv_shared\%%~nf.o"
    set "SERVER_OBJS=!SERVER_OBJS! "%OBJ%\sv_shared\%%~nf.o""
)

for %%f in ("%SRC%\engine\server\*.cpp") do (
    %CXX% !CXXFLAGS! -c "%%f" -o "%OBJ%\sv_esrv\%%~nf.o"
    set "SERVER_OBJS=!SERVER_OBJS! "%OBJ%\sv_esrv\%%~nf.o""
)

for %%f in ("%SRC%\game\*.cpp") do (
    %CXX% !CXXFLAGS! -c "%%f" -o "%OBJ%\sv_game\%%~nf.o"
    set "SERVER_OBJS=!SERVER_OBJS! "%OBJ%\sv_game\%%~nf.o""
)

for %%f in ("%SRC%\game\server\*.cpp") do (
    %CXX% !CXXFLAGS! -c "%%f" -o "%OBJ%\sv_gsrv\%%~nf.o"
    set "SERVER_OBJS=!SERVER_OBJS! "%OBJ%\sv_gsrv\%%~nf.o""
)

for %%f in ("%SRC%\game\server\entities\*.cpp") do (
    %CXX% !CXXFLAGS! -c "%%f" -o "%OBJ%\sv_gsrv\%%~nf.o"
    set "SERVER_OBJS=!SERVER_OBJS! "%OBJ%\sv_gsrv\%%~nf.o""
)

for %%f in ("%SRC%\game\server\gamemodes\*.cpp") do (
    %CXX% !CXXFLAGS! -c "%%f" -o "%OBJ%\sv_gsrv\%%~nf.o"
    set "SERVER_OBJS=!SERVER_OBJS! "%OBJ%\sv_gsrv\%%~nf.o""
)

if exist "%SRC%\game\generated\protocol.cpp" (
    %CXX% !CXXFLAGS! -c "%SRC%\game\generated\protocol.cpp" -o "%OBJ%\sv_gen\protocol.o"
    set "SERVER_OBJS=!SERVER_OBJS! "%OBJ%\sv_gen\protocol.o""
)
if exist "%SRC%\game\generated\nethash.cpp" (
    %CXX% !CXXFLAGS! -c "%SRC%\game\generated\nethash.cpp" -o "%OBJ%\sv_gen\nethash.o"
    set "SERVER_OBJS=!SERVER_OBJS! "%OBJ%\sv_gen\nethash.o""
)
if exist "%SRC%\game\generated\server_data.cpp" (
    %CXX% !CXXFLAGS! -c "%SRC%\game\generated\server_data.cpp" -o "%OBJ%\sv_gen\server_data.o"
    set "SERVER_OBJS=!SERVER_OBJS! "%OBJ%\sv_gen\server_data.o""
)

%CC% !COMMON! -c "%SRC%\base\system.c" -o "%OBJ%\sv_base\system.o"
set "SERVER_OBJS=!SERVER_OBJS! "%OBJ%\sv_base\system.o""

echo === Linking teeworlds_server.exe ===
%CXX% -o "%DIST%\teeworlds_server.exe" !SERVER_OBJS! "%BUILD%\lib_ext.a" "%LIBSARM%\libfreetype.a" -Wl,-Bstatic -lc++ -lc++abi -lunwind -Wl,-Bdynamic -lws2_32 -lwinmm -luser32 -lgdi32 -ladvapi32 -lshell32 -s

echo === 4/4 Packaging ===
if exist "%RUNTIMEDIR%" copy /Y "%RUNTIMEDIR%\*" "%DIST%\" >nul
if not exist "%DIST%\data" xcopy /E /I /Y "%ROOT%\data" "%DIST%\data" >nul

echo === Build complete! Output: %DIST%
endlocal
exit /b 0
