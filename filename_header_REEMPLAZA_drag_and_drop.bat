@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Arrastra y suelta archivos PDF en este script.
    pause
    exit /b
)

set "CPDF=%~dp0dependencias\cpdf.exe"

for %%F in (%*) do (
    if /i "%%~xF"==".pdf" (
        set "entrada=%%~fF"
        set "salida=%%~dpnF_temp.pdf"
        set "nombre=%%~nxF"

        "%CPDF%" -topright 17 -font Courier-Bold -font-size 14 -color "1.0 0.0 0.2" -add-text "!nombre!" "!entrada!" -o "!salida!"

        copy /Y "!salida!" "!entrada!" >nul
        del "!salida!"

        echo Procesado: "%%~nxF"
    ) else (
        echo Omitido ^(no es PDF^): "%%~nxF"
    )
)

echo Proceso completado. Cerrando en 3 segundos...
timeout /nobreak /t 3 >nul
exit /b
