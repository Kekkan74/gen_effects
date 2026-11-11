@echo off
setlocal
cd /d "%~dp0"
title GenEffects - OmniVFX Studio

set "BIN_DIR=%~dp0bin"
set "GODOT_EXE="

if exist "%BIN_DIR%\Godot_v4.3-stable_win64.exe" goto :Encontrado_Godot
if exist "%BIN_DIR%\godot.exe" goto :Encontrado_Godot_Alt
if exist "%BIN_DIR%\Godot_v4.3-stable_win64_console.exe" goto :Encontrado_Godot_Console

:: Si no existe el binario en bin\, descargarlo de GitHub Releases
echo ===================================================================
echo             GenEffects Studio - Instalacion Inicial
echo ===================================================================
echo Detectada primera ejecucion tras clonar el repositorio.
echo Descargando runtime portable de Godot 4.3 - solo tomara unos segundos...
echo ===================================================================

if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"

set "ZIP_PATH=%BIN_DIR%\godot_runtime.zip"
set "DOWNLOAD_URL=https://github.com/godotengine/godot/releases/download/4.3-stable/Godot_v4.3-stable_win64.exe.zip"

curl.exe -L --progress-bar -o "%ZIP_PATH%" "%DOWNLOAD_URL%"
if errorlevel 1 goto :Error_Descarga

echo Extrayendo binario portable...
powershell -NoProfile -ExecutionPolicy Bypass -Command "Expand-Archive -Path '%ZIP_PATH%' -DestinationPath '%BIN_DIR%' -Force"
if exist "%ZIP_PATH%" del /f /q "%ZIP_PATH%"

if exist "%BIN_DIR%\Godot_v4.3-stable_win64.exe" goto :Encontrado_Godot
if exist "%BIN_DIR%\godot.exe" goto :Encontrado_Godot_Alt
goto :Error_No_Exe

:Encontrado_Godot
set "GODOT_EXE=%BIN_DIR%\Godot_v4.3-stable_win64.exe"
goto :Lanzar

:Encontrado_Godot_Alt
set "GODOT_EXE=%BIN_DIR%\godot.exe"
goto :Lanzar

:Encontrado_Godot_Console
set "GODOT_EXE=%BIN_DIR%\Godot_v4.3-stable_win64_console.exe"
goto :Lanzar

:Lanzar
echo Iniciando GenEffects Studio...
start "" "%GODOT_EXE%" --path "%~dp0."
exit /b 0

:Error_Descarga
echo [ERROR] No se pudo descargar automaticamente con curl.
echo Por favor, coloca godot.exe en la carpeta bin
pause
exit /b 1

:Error_No_Exe
echo [ERROR] No se encontro el ejecutable en bin tras la extraccion.
pause
exit /b 1
