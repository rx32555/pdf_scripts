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
        set "basepath=%%~dpnF"

        "!CPDF!" -split "!entrada!" -o "!basepath!_p%%d.pdf"

        echo Procesado: "%%~nxF"
    ) else (
        echo Omitido ^(no es PDF^): "%%~nxF"
    )
)

echo Proceso completado. Cerrando en 3 segundos...
timeout /nobreak /t 3 >nul
exit /b
