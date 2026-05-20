@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Arrastra y suelta archivos PDF en este script.
    pause
    exit /b
)

set "GS=gswin64c.exe"

for %%F in (%*) do (
    if /i "%%~xF"==".pdf" (
        set "entrada=%%~fF"
        set "salida=%%~dpnF_temp.pdf"

        "!GS!" -sDEVICE=pdfwrite -sColorConversionStrategy=Gray -dProcessColorModel=/DeviceGray -dNOPAUSE -dQUIET -dBATCH -sOutputFile="!salida!" "!entrada!"

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
