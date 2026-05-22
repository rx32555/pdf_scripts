@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

call "%~dp0locales\compiled_lang.bat"

if "%~1"=="" (
    echo !L_DRAG_DROP!
    pause
    exit /b
)

set "CPDF=%~dp0dependencias\cpdf.exe"
set "listfile=%temp%\pdf_scripts_sel_%RANDOM%.txt"

for %%F in (%*) do (
    if /i "%%~xF"==".pdf" (
        set "entrada=%%~fF"
        set "salida=%%~dpnF_temp.pdf"
        set "nombre=%%~nxF"

        echo !L_PROCESSING! "%%~nxF"...

        "%CPDF%" -topright 17 -font Courier-Bold -font-size 14 -color "1.0 0.0 0.2" -add-text "!nombre!" "!entrada!" -o "!salida!"

        if exist "!salida!" (
            set "FILE_BACKUP=%%~dpnF_original%%~xF"
            copy /Y "!entrada!" "!FILE_BACKUP!" >nul
            powershell -NoProfile -Command "Add-Type -AssemblyName Microsoft.VisualBasic; [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($env:FILE_BACKUP, 'OnlyErrorDialogs', 'SendToRecycleBin')"
            copy /Y "!salida!" "!entrada!" >nul
            del "!salida!"
            echo !entrada!>>"!listfile!"
            echo !L_OK! "%%~nxF"
        ) else (
            echo !L_ERR_PROCESS! "%%~nxF"
        )
    ) else (
        echo !L_SKIP_NOPDF!: "%%~nxF"
    )
)

if exist "!listfile!" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0restore_selection.ps1" "!listfile!"
)

echo !L_DONE!
timeout /nobreak /t 3 >nul
exit /b
