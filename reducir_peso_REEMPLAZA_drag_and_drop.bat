@echo off
setlocal enabledelayedexpansion

if "%~1"=="" (
    echo Arrastra y suelta archivos PDF en este script.
    pause
    exit /b
)

set "GS=gswin64c.exe"

where "%GS%" >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Ghostscript no encontrado en el sistema.
    echo         Ejecuta setup.bat para instalarlo.
    pause
    exit /b 1
)

for %%F in (%*) do (
    if /i "%%~xF"==".pdf" (
        set "entrada=%%~fF"
        set "salida=%%~dpnF_temp.pdf"

        echo Procesando: "%%~nxF"...

        "!GS!" -sDEVICE=pdfwrite -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH -sOutputFile="!salida!" "!entrada!"

        if exist "!salida!" (
            copy /Y "!salida!" "!entrada!" >nul
            del "!salida!"
            echo [OK] %%~nxF
        ) else (
            echo [ERROR] Fallo al procesar: %%~nxF
        )
    ) else (
        echo Omitido ^(no es PDF^): "%%~nxF"
    )
)

echo.
echo Proceso completado. Cerrando en 3 segundos...
timeout /nobreak /t 3 >nul
exit /b
