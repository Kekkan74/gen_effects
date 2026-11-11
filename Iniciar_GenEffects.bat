@echo off
setlocal enabledelayedexpansion
title GenEffects - OmniVFX Studio

set "SCRIPT_DIR=%~dp0"
set "BIN_DIR=%SCRIPT_DIR%bin"
set "GODOT_EXE="

:: 1. Comprobar si ya existe un ejecutable de Godot en bin/
if exist "%BIN_DIR%\Godot_v4.3-stable_win64.exe" (
    set "GODOT_EXE=%BIN_DIR%\Godot_v4.3-stable_win64.exe"
) else if exist "%BIN_DIR%\godot.exe" (
    set "GODOT_EXE=%BIN_DIR%\godot.exe"
) else if exist "%BIN_DIR%\Godot_v4.3-stable_win64_console.exe" (
    set "GODOT_EXE=%BIN_DIR%\Godot_v4.3-stable_win64_console.exe"
)

:: 2. Si no existe, descargar e instalar runtime portable en segundos
if not defined GODOT_EXE (
    echo ===================================================================
    echo           ⚡ GenEffects Studio - Instalacion Rapida ⚡
    echo ===================================================================
    echo Detectada primera ejecucion tras 'git clone'.
    echo Descargando motor portable Godot 4.3 (aprox. 55 MB, solo la 1a vez)...
    echo ===================================================================
    
    if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
    
    set "ZIP_PATH=%BIN_DIR%\godot_runtime.zip"
    set "DOWNLOAD_URL=https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_win64.exe.zip"
    
    curl.exe -L --progress-bar -o "!ZIP_PATH!" "!DOWNLOAD_URL!"
    if errorlevel 1 (
        echo [ERROR] No se pudo descargar automaticamente con curl.
        echo Por favor, coloca godot.exe (Godot 4.3) en la carpeta bin\
        pause
        exit /b 1
    )
    
    echo Extrayendo binario portable...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path '!ZIP_PATH!' -DestinationPath '%BIN_DIR%' -Force"
    if exist "!ZIP_PATH!" del "!ZIP_PATH!"
    
    if exist "%BIN_DIR%\Godot_v4.3-stable_win64.exe" (
        set "GODOT_EXE=%BIN_DIR%\Godot_v4.3-stable_win64.exe"
    ) else (
        for %%F in ("%BIN_DIR%\*.exe") do set "GODOT_EXE=%%F"
    )
    echo Instalacion completada con exito.
)

:: 3. Lanzar GenEffects Studio
echo Iniciando GenEffects Studio...
start "" "!GODOT_EXE!" --path "%SCRIPT_DIR%"
exit /b 0
