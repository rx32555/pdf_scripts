@echo off
chcp 65001 >nul
setlocal enabledelayedexpansion

set "ROOT=%~dp0"
set "DEPS=%ROOT%dependencias"
set "CPDF=%DEPS%\cpdf.exe"
set "SZIP=%DEPS%\7za.exe"

:: ---- Inicializacion de Idioma ----
powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%locales\compile_lang.ps1"
call "%ROOT%locales\compiled_lang.bat"

echo.
set /p "L_CHANGE=!L_SETUP_LANG_PROMPT! "
if /i "!L_CHANGE!"=="C" (
    echo [es] Espanol  /  [en] English
    set /p "NEW_LANG=Idioma/Language (es/en): "
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%locales\compile_lang.ps1" -Lang "!NEW_LANG!"
    call "%ROOT%locales\compiled_lang.bat"
) else if /i "!L_CHANGE!"=="S" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%locales\compile_lang.ps1" -Lang "es"
    call "%ROOT%locales\compiled_lang.bat"
) else if /i "!L_CHANGE!"=="Y" (
    powershell -NoProfile -ExecutionPolicy Bypass -File "%ROOT%locales\compile_lang.ps1" -Lang "en"
    call "%ROOT%locales\compiled_lang.bat"
)
:: -----------------------------------

echo.
echo  ==============================================
echo   Setup - Scripts PDF
echo  ==============================================
echo.

if not exist "%DEPS%" mkdir "%DEPS%"

:: ---- cpdf ----
if exist "%CPDF%" (
    echo [OK] cpdf.exe !L_SETUP_ALREADY!
) else (
    echo !L_SETUP_DL_CPDF!
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; $tmp=[System.IO.Path]::GetTempPath(); $zip=Join-Path $tmp 'cpdf_binaries.zip'; Invoke-WebRequest -Uri 'https://github.com/coherentgraphics/cpdf-binaries/archive/refs/heads/master.zip' -OutFile $zip -UseBasicParsing"
    if errorlevel 1 ( echo !L_SETUP_ERR_DL! & pause & exit /b 1 )

    echo !L_SETUP_EXTRACT!
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$tmp=[System.IO.Path]::GetTempPath(); $zip=Join-Path $tmp 'cpdf_binaries.zip'; $ext=Join-Path $tmp 'cpdf_extract'; Expand-Archive -Path $zip -DestinationPath $ext -Force"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$tmp=[System.IO.Path]::GetTempPath(); $ext=Join-Path $tmp 'cpdf_extract'; $f=Get-ChildItem $ext -Recurse -Filter 'cpdf.exe' | Where-Object {$_.DirectoryName -match 'Windows64'} | Select-Object -First 1; if($f){Copy-Item $f.FullName -Destination '%CPDF%'}else{exit 1}"
    if errorlevel 1 ( echo !L_SETUP_ERR_BIN! & pause & exit /b 1 )

    powershell -NoProfile -ExecutionPolicy Bypass -Command "$tmp=[System.IO.Path]::GetTempPath(); Remove-Item (Join-Path $tmp 'cpdf_binaries.zip'),(Join-Path $tmp 'cpdf_extract') -Recurse -Force -ErrorAction SilentlyContinue"
    echo [OK] cpdf.exe !L_SETUP_INSTALLED!
)

echo.

:: ---- 7za (portable) ----
:: Bootstrap: 7zr.exe (standalone ~600KB, solo formato .7z) extrae el paquete
:: extra de 7-zip que contiene 7za.exe (soporta todos los formatos, incluido NSIS)
if exist "%SZIP%" (
    echo [OK] 7za.exe !L_SETUP_ALREADY!
) else (
    echo !L_SETUP_DL_7Z!
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; $deps='%DEPS%'; Invoke-WebRequest -Uri 'https://github.com/ip7z/7zip/releases/download/26.01/7zr.exe' -OutFile (Join-Path $deps '7zr.exe') -UseBasicParsing; Invoke-WebRequest -Uri 'https://github.com/ip7z/7zip/releases/download/26.01/7z2601-extra.7z' -OutFile (Join-Path $deps '7z_extra.7z') -UseBasicParsing"
    if errorlevel 1 ( echo !L_SETUP_ERR_DL! & pause & exit /b 1 )

    echo !L_SETUP_EXTRACT!
    "%DEPS%\7zr.exe" x "%DEPS%\7z_extra.7z" -y -o"%DEPS%\7z_ext" >nul
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$deps='%DEPS%'; $f=Get-ChildItem (Join-Path $deps '7z_ext') -Recurse -Filter '7za.exe' | Select-Object -Last 1; if($f){Copy-Item $f.FullName -Destination '%SZIP%'}else{exit 1}"
    if errorlevel 1 ( echo !L_SETUP_ERR_BIN! & pause & exit /b 1 )

    del "%DEPS%\7zr.exe" "%DEPS%\7z_extra.7z" >nul 2>&1
    rmdir /s /q "%DEPS%\7z_ext" >nul 2>&1
    echo [OK] 7za.exe !L_SETUP_INSTALLED!
)

echo.

:: ---- Ghostscript ----
set "GS_FOUND=0"
where gswin64c.exe >nul 2>&1
if %errorlevel% equ 0 set "GS_FOUND=1"
if "!GS_FOUND!"=="0" (
    for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\GPL Ghostscript" /s /v "GS_DLL" 2^>nul ^| find /i "GS_DLL"') do (
        set "GS_DLL=%%B"
    )
    if defined GS_DLL set "GS_FOUND=1"
)

if "!GS_FOUND!"=="1" (
    echo [OK] !L_SETUP_GS_FOUND!
) else (
    echo !L_SETUP_GS_NOT_FOUND!
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; $deps='%DEPS%'; Invoke-WebRequest -Uri 'https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs10071/gs10071w64.exe' -OutFile (Join-Path $deps 'gs_installer.exe') -UseBasicParsing"
    if errorlevel 1 ( echo !L_SETUP_ERR_DL! & pause & exit /b 1 )

    echo.
    echo  ----------------------------------------------
    echo   !L_SETUP_GS_INST1!
    echo   !L_SETUP_GS_INST2!
    echo   !L_SETUP_GS_INST3!
    echo   !L_SETUP_GS_INST4!
    echo  ----------------------------------------------
    echo.
    pause
    start /wait "%DEPS%\gs_installer.exe"
    del "%DEPS%\gs_installer.exe" >nul 2>&1

    set "GS_FOUND=0"
    where gswin64c.exe >nul 2>&1
    if %errorlevel% equ 0 set "GS_FOUND=1"
    if "!GS_FOUND!"=="0" (
        for /f "tokens=2*" %%A in ('reg query "HKLM\SOFTWARE\GPL Ghostscript" /s /v "GS_DLL" 2^>nul ^| find /i "GS_DLL"') do (
            set "GS_DLL=%%B"
        )
        if defined GS_DLL set "GS_FOUND=1"
    )

    if "!GS_FOUND!"=="1" (
        echo [OK] Ghostscript !L_SETUP_INSTALLED!
    ) else (
        echo !L_SETUP_GS_NOT_PATH!
    )
)

echo.
echo !L_SETUP_CHECK_LNK!
echo.

:: ---- Shortcuts (agregar un bloque set+call por cada nuevo script) ----
set "_LNK=!L_SHORTCUT_HEADER!"
set "_TGT=%ROOT%filename_header_REEMPLAZA_drag_and_drop.bat"
call :check_lnk

set "_LNK=!L_SHORTCUT_REDUCE!"
set "_TGT=%ROOT%reducir_peso_REEMPLAZA_drag_and_drop.bat"
call :check_lnk

set "_LNK=!L_SHORTCUT_GRAY!"
set "_TGT=%ROOT%escala_grises_REEMPLAZA_drag_and_drop.bat"
call :check_lnk

set "_LNK=!L_SHORTCUT_SPLIT!"
set "_TGT=%ROOT%dividir_paginas_drag_and_drop.bat"
call :check_lnk

set "_LNK=!L_SHORTCUT_DEL!"
set "_TGT=%ROOT%eliminar_paginas_drag_and_drop.bat"
call :check_lnk

set "_LNK=!L_SHORTCUT_MERGE!"
set "_TGT=%ROOT%combinar_PDFs_drag_and_drop.bat"
call :check_lnk

:fin
echo.
echo !L_SETUP_FINISH!
echo.
pause
exit

:: ============================================================
:check_lnk
set "LNK_NAME=%_LNK%"
set "LNK_TARGET=%_TGT%"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$wsh=New-Object -ComObject WScript.Shell; $dir=$wsh.SpecialFolders('SendTo'); $lnk=Join-Path $dir '%LNK_NAME%.lnk'; Get-ChildItem -Path $dir -Filter '*.lnk' | ForEach-Object { if ($_.FullName -ne $lnk) { $s=$wsh.CreateShortcut($_.FullName); if ($s.TargetPath -ieq '%LNK_TARGET%') { Remove-Item $_.FullName -Force } } }; if(Test-Path $lnk){if($wsh.CreateShortcut($lnk).TargetPath -ieq '%LNK_TARGET%'){exit 0}else{exit 2}}else{exit 1}"
set "ST=%ERRORLEVEL%"

if "!ST!"=="0" goto :lnk_already_ok
if "!ST!"=="2" goto :lnk_wrong
echo    [ ] %LNK_NAME%
set /p "R=        !L_SETUP_CREATE_LNK!"
goto :lnk_confirm

:lnk_wrong
echo    [!] %LNK_NAME%
set /p "R=        !L_SETUP_UPDATE_LNK!"

:lnk_confirm
if /i "!R!" neq "S" if /i "!R!" neq "Y" goto :lnk_ok
powershell -NoProfile -ExecutionPolicy Bypass -Command "$wsh=New-Object -ComObject WScript.Shell; $lnk=$wsh.CreateShortcut((Join-Path $wsh.SpecialFolders('SendTo') '%LNK_NAME%.lnk')); $lnk.TargetPath='%LNK_TARGET%'; $lnk.Save()"
echo    !L_SETUP_LNK_OK!
goto :lnk_ok

:lnk_already_ok
echo    [OK] %LNK_NAME%

:lnk_ok
exit /b
