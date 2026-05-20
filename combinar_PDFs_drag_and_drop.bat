@echo off
if "%~1"=="" (
    echo Arrastra y suelta archivos PDF en este script.
    pause
    exit /b
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0combinar_PDFs_gui.ps1" %*
