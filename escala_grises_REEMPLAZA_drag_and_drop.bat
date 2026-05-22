@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Arrastra y suelta archivos PDF en este script.
    pause
    exit /b
)

set "GS=gswin64c.exe"
set "GS_FOUND=0"
set "listfile=%temp%\pdf_scripts_sel_%RANDOM%.txt"
where "%GS%" >nul 2>&1
if %errorlevel% equ 0 set "GS_FOUND=1"

if "!GS_FOUND!"=="0" (
    for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\GPL Ghostscript" /s /v "GS_DLL" 2^>nul ^| find /i "GS_DLL"') do (
        set "GS_DLL=%%B"
    )
    if defined GS_DLL (
        for %%I in ("!GS_DLL!") do set "GS_BIN=%%~dpIgswin64c.exe"
        if exist "!GS_BIN!" (
            set "GS=!GS_BIN!"
            set "GS_FOUND=1"
        )
    )
)

if "!GS_FOUND!"=="0" (
    echo [ERROR] Ghostscript no encontrado en el sistema.
    echo         Ejecuta setup.bat para instalarlo.
    pause
    exit /b 1
)

for %%F in (%*) do (
    if /i "%%~xF"==".pdf" (
        set "entrada=%%~fF"
        set "salida=%%~dpnF_temp.pdf"

        "!GS!" -sDEVICE=pdfwrite -sColorConversionStrategy=Gray -dProcessColorModel=/DeviceGray -dNOPAUSE -dQUIET -dBATCH -sOutputFile="!salida!" "!entrada!"

        if exist "!salida!" (
            set "FILE_BACKUP=%%~dpnF_original%%~xF"
            copy /Y "!entrada!" "!FILE_BACKUP!" >nul
            powershell -NoProfile -Command "Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($env:FILE_BACKUP, 'OnlyErrorDialogs', 'SendToRecycleBin')"
            copy /Y "!salida!" "!entrada!" >nul
            del "!salida!"
            echo !entrada!>>"!listfile!"
            echo Procesado: "%%~nxF"
        ) else (
            echo [ERROR] Fallo al procesar: %%~nxF
        )
    ) else (
        echo Omitido ^(no es PDF^): "%%~nxF"
    )
)

if exist "!listfile!" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore_selection.ps1" "!listfile!"
)

echo Proceso completado. Cerrando en 3 segundos...
timeout /nobreak /t 3 >nul
exit /b
