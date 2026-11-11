@echo off
if exist "%~dp0GenEffects.exe" (
    start "" "%~dp0GenEffects.exe" %*
) else (
    call "%~dp0Iniciar_GenEffects.bat" %*
)
