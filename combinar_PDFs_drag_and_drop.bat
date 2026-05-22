@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion
call "%~dp0locales\compiled_lang.bat"

if "%~1"=="" (
    echo !L_DRAG_DROP!
    pause
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0combinar_PDFs_gui.ps1" %*
