# Teeworlds 0.6.5 for Windows RT / Surface RT

[![Platform](https://img.shields.io/badge/Platform-Windows%20RT%20%7C%20ARM32%20(ARMv7)-blue.svg)]()
[![Graphics](https://img.shields.io/badge/Graphics-Direct3D%209%20%2F%20GLDirect-brightgreen.svg)]()
[![Language](https://img.shields.io/badge/Language-C%2B%2B-orange.svg)]()

A native port of **Teeworlds v0.6.5** for Microsoft Surface RT and Windows RT 8.1 ARM32 devices, featuring OpenGL rendering over Direct3D 9 via SciTech GLDirect 5.0, client and dedicated server builds, custom RCON commands, and tailored rendering fixes for Tegra 3.

---

## Repository Structure

```
.
├── src/               # Teeworlds 0.6.5 source code (base, engine, game)
├── data/              # Game assets (maps, skins, fonts, audio, languages)
├── libs/              # Static libraries, include headers, and runtime DLLs
│   ├── arm32/         # Precompiled static libraries (libSDL.a, libfreetype.a)
│   ├── include/       # Headers (SDL, FreeType, winrt_compat.h)
│   └── runtime/       # Windows RT DLLs (opengl32.dll, SDL.dll, d3dx9d.dll, GLU32.dll, D3DCompiler_Test.dll)
├── build.sh           # Linux cross-compilation script (using llvm-mingw)
├── build.bat          # Windows build script for ARM32
├── LICENSE.txt        # License file
└── README.md
```

---

## Building from Source

### Prerequisites

You need the **LLVM-MinGW** cross-compiler toolchain supporting `armv7-w64-mingw32` (for ARM32 / Windows RT).

- Download LLVM-MinGW: [github.com/mstorsjo/llvm-mingw](https://github.com/mstorsjo/llvm-mingw/releases)

### Building on Linux (Cross-compile)

1. Make sure `LLVM_MINGW_ROOT` points to your toolchain directory:
   ```bash
   export LLVM_MINGW_ROOT=/path/to/llvm-mingw
   ```
2. Run the build script:
   ```bash
   chmod +x build.sh
   ./build.sh all
   ```
   *To build client or server individually:*
   ```bash
   ./build.sh client
   ./build.sh server
   ```

The compiled binary and assets will be output to the `dist/` directory.

### Building on Windows

1. Set `MINGW` environment variable to your LLVM-MinGW folder:
   ```cmd
   set MINGW=C:\llvm-mingw
   ```
2. Run:
   ```cmd
   build.bat
   ```

---

## Running on Windows RT

1. Ensure has **Windows RT Jailbreak** to run desktop applications.
2. Copy the entire `dist/` folder containing:
   - `teeworlds.exe`
   - `teeworlds_server.exe`
   - Runtime DLLs (`opengl32.dll`, `SDL.dll`, `d3dx9d.dll`, `GLU32.dll`, `D3DCompiler_Test.dll`)
   - `data/` folder and config files (`storage.cfg`, `gldirect.ini`, `autoexec.cfg`)
3. Sign the `teeworlds.exe` and `teeworlds_server.exe` files (use SignTool) for Windows RT
4. Launch `teeworlds.exe`.

---

## License & Credits

- Original Teeworlds by **Magnus Auvinen** and contributors.
- Windows RT / ARM32 GLDirect 5.0 port and fixes by project contributors.
- This project is intended for historical preservation and educational purposes.
