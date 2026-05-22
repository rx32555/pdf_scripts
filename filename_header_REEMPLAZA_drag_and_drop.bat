@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Arrastra y suelta archivos PDF en este script.
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

        "%CPDF%" -topright 17 -font Courier-Bold -font-size 14 -color "1.0 0.0 0.2" -add-text "!nombre!" "!entrada!" -o "!salida!"

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
