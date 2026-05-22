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

for %%F in (%*) do (
    if /i "%%~xF"==".pdf" (
        set "entrada=%%~fF"
        set "basepath=%%~dpnF"

        set "PAGES=0"
        for /f "usebackq delims=" %%P in (`""!CPDF!" -pages "!entrada!" 2^>nul"`) do (
            set "PAGES=%%P"
        )

        if "!PAGES!"=="1" (
            echo !L_SKIP_1PAGE!: "%%~nxF"
        ) else if "!PAGES!"=="0" (
            echo !L_ERR_READ!: "%%~nxF"
        ) else (
            "!CPDF!" -split "!entrada!" -o "!basepath!_p%%d.pdf" >nul 2>&1
            echo !L_PROCESSED! ^(!PAGES! !L_PAGES!^): "%%~nxF"
        )
    ) else (
        echo !L_SKIP_NOPDF!: "%%~nxF"
    )
)

echo !L_DONE!
timeout /nobreak /t 3 >nul
exit /b
