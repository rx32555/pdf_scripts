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

        set "PAGES=0"
        for /f "usebackq delims=" %%P in (`""!CPDF!" -pages "!entrada!" 2^>nul"`) do (
            set "PAGES=%%P"
        )

        if "!PAGES!"=="1" (
            echo Omitido ^(solo 1 pagina^): "%%~nxF"
        ) else if "!PAGES!"=="0" (
            echo [ERROR] No se pudo leer o archivo invalido: "%%~nxF"
        ) else (
            "!CPDF!" -split "!entrada!" -o "!basepath!_p%%d.pdf" >nul 2>&1
            echo Procesado ^(!PAGES! paginas^): "%%~nxF"
        )
    ) else (
        echo Omitido ^(no es PDF^): "%%~nxF"
    )
)

echo Proceso completado. Cerrando en 3 segundos...
timeout /nobreak /t 3 >nul
exit /b
