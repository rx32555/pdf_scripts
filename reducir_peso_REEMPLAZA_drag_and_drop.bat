@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

call "%~dp0locales\compiled_lang.bat"

if "%~1"=="" (
    echo !L_DRAG_DROP!
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
    echo !L_NO_GS!
    pause
    exit /b 1
)

for %%F in (%*) do (
    if /i "%%~xF"==".pdf" (
        set "entrada=%%~fF"
        set "salida=%%~dpnF_temp.pdf"

        echo !L_PROCESSING! "%%~nxF"...

        "!GS!" -sDEVICE=pdfwrite -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH -sOutputFile="!salida!" "!entrada!"

        if exist "!salida!" (
            set "FILE_BACKUP=%%~dpnF_original%%~xF"
            copy /Y "!entrada!" "!FILE_BACKUP!" >nul
            powershell -NoProfile -Command "Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($env:FILE_BACKUP, 'OnlyErrorDialogs', 'SendToRecycleBin')"
            copy /Y "!salida!" "!entrada!" >nul
            del "!salida!"
            echo !entrada!>>"!listfile!"
            echo !L_OK! %%~nxF
        ) else (
            echo !L_ERR_PROCESS! %%~nxF
        )
    ) else (
        echo !L_SKIP_NOPDF!: "%%~nxF"
    )
)

echo.
if exist "!listfile!" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore_selection.ps1" "!listfile!"
)

echo !L_DONE!
timeout /nobreak /t 3 >nul
exit /b
