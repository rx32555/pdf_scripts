@echo off
setlocal enabledelayedexpansion

set "ROOT=%~dp0"
set "DEPS=%ROOT%dependencias"
set "CPDF=%DEPS%\cpdf.exe"
set "SZIP=%DEPS%\7za.exe"

echo.
echo  ==============================================
echo   Setup - Scripts PDF
echo  ==============================================
echo.

if not exist "%DEPS%" mkdir "%DEPS%"

:: ---- cpdf ----
if exist "%CPDF%" (
    echo [OK] cpdf.exe ya presente en dependencias\
) else (
    echo Descargando cpdf ^(~30 MB^)...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; $tmp=[System.IO.Path]::GetTempPath(); $zip=Join-Path $tmp 'cpdf_binaries.zip'; Invoke-WebRequest -Uri 'https://github.com/coherentgraphics/cpdf-binaries/archive/refs/heads/master.zip' -OutFile $zip -UseBasicParsing"
    if errorlevel 1 ( echo [ERROR] Fallo la descarga. Verifica conexion a internet. & pause & exit /b 1 )

    echo Extrayendo binario...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$tmp=[System.IO.Path]::GetTempPath(); $zip=Join-Path $tmp 'cpdf_binaries.zip'; $ext=Join-Path $tmp 'cpdf_extract'; Expand-Archive -Path $zip -DestinationPath $ext -Force"
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$tmp=[System.IO.Path]::GetTempPath(); $ext=Join-Path $tmp 'cpdf_extract'; $f=Get-ChildItem $ext -Recurse -Filter 'cpdf.exe' | Where-Object {$_.DirectoryName -match 'Windows64'} | Select-Object -First 1; if($f){Copy-Item $f.FullName -Destination '%CPDF%'}else{exit 1}"
    if errorlevel 1 ( echo [ERROR] No se encontro cpdf.exe en el paquete descargado. & pause & exit /b 1 )

    powershell -NoProfile -ExecutionPolicy Bypass -Command "$tmp=[System.IO.Path]::GetTempPath(); Remove-Item (Join-Path $tmp 'cpdf_binaries.zip'),(Join-Path $tmp 'cpdf_extract') -Recurse -Force -ErrorAction SilentlyContinue"
    echo [OK] cpdf.exe instalado correctamente.
)

echo.

:: ---- 7za (portable) ----
:: Bootstrap: 7zr.exe (standalone ~600KB, solo formato .7z) extrae el paquete
:: extra de 7-zip que contiene 7za.exe (soporta todos los formatos, incluido NSIS)
if exist "%SZIP%" (
    echo [OK] 7za.exe ya presente en dependencias\
) else (
    echo Descargando 7-Zip portable...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; $deps='%DEPS%'; Invoke-WebRequest -Uri 'https://github.com/ip7z/7zip/releases/download/26.01/7zr.exe' -OutFile (Join-Path $deps '7zr.exe') -UseBasicParsing; Invoke-WebRequest -Uri 'https://github.com/ip7z/7zip/releases/download/26.01/7z2601-extra.7z' -OutFile (Join-Path $deps '7z_extra.7z') -UseBasicParsing"
    if errorlevel 1 ( echo [ERROR] Fallo la descarga. Verifica conexion a internet. & pause & exit /b 1 )

    echo Extrayendo 7za.exe...
    "%DEPS%\7zr.exe" x "%DEPS%\7z_extra.7z" -y -o"%DEPS%\7z_ext" >nul
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$deps='%DEPS%'; $f=Get-ChildItem (Join-Path $deps '7z_ext') -Recurse -Filter '7za.exe' | Select-Object -Last 1; if($f){Copy-Item $f.FullName -Destination '%SZIP%'}else{exit 1}"
    if errorlevel 1 ( echo [ERROR] No se encontro 7za.exe en el paquete. & pause & exit /b 1 )

    del "%DEPS%\7zr.exe" "%DEPS%\7z_extra.7z" >nul 2>&1
    rmdir /s /q "%DEPS%\7z_ext" >nul 2>&1
    echo [OK] 7za.exe instalado en dependencias\
)

echo.

:: ---- Ghostscript ----
where gswin64c.exe >nul 2>&1
if %errorlevel% equ 0 (
    echo [OK] Ghostscript encontrado en el sistema.
) else (
    echo [!] Ghostscript no encontrado. Descargando instalador oficial ^(~80 MB^)...
    powershell -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='SilentlyContinue'; $deps='%DEPS%'; Invoke-WebRequest -Uri 'https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs10071/gs10071w64.exe' -OutFile (Join-Path $deps 'gs_installer.exe') -UseBasicParsing"
    if errorlevel 1 ( echo [ERROR] Fallo la descarga. Verifica conexion a internet. & pause & exit /b 1 )

    echo.
    echo  ----------------------------------------------
    echo   INSTALACION DE GHOSTSCRIPT
    echo   - Siguiente, Siguiente, Instalar
    echo   - Dejar ruta por defecto
    echo   - La opcion "Add to PATH" viene marcada
    echo     por defecto: dejarla asi
    echo  ----------------------------------------------
    echo.
    pause
    start /wait "%DEPS%\gs_installer.exe"
    del "%DEPS%\gs_installer.exe" >nul 2>&1

    where gswin64c.exe >nul 2>&1
    if %errorlevel% equ 0 (
        echo [OK] Ghostscript instalado correctamente.
    ) else (
        echo [!] Ghostscript no detectado en PATH aun.
        echo     Si acabas de instalarlo, cierra y vuelve a abrir esta ventana.
    )
)

echo.
echo Verificando accesos directos en 'Enviar a'...
echo.

:: ---- Shortcuts (agregar un bloque set+call por cada nuevo script) ----
set "_LNK=PDF - Encabezado con nombre de archivo(s) y sobreescribirlos"
set "_TGT=%ROOT%filename_header_REEMPLAZA_drag_and_drop.bat"
call :check_lnk

set "_LNK=PDF - Reducir peso reemplazando archivo(s)"
set "_TGT=%ROOT%reducir_peso_REEMPLAZA_drag_and_drop.bat"
call :check_lnk

set "_LNK=PDF - Convertir a escala de grises reemplazando archivo(s)"
set "_TGT=%ROOT%escala_grises_REEMPLAZA_drag_and_drop.bat"
call :check_lnk

set "_LNK=PDF - Dividir en paginas individuales"
set "_TGT=%ROOT%dividir_paginas_drag_and_drop.bat"
call :check_lnk

set "_LNK=PDF - Combinar varios en uno"
set "_TGT=%ROOT%combinar_PDFs_drag_and_drop.bat"
call :check_lnk

:fin
echo.
echo Setup completado.
echo.
pause
exit

:: ============================================================
:check_lnk
set "LNK_NAME=%_LNK%"
set "LNK_TARGET=%_TGT%"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$wsh=New-Object -ComObject WScript.Shell; $lnk=Join-Path $wsh.SpecialFolders('SendTo') '%LNK_NAME%.lnk'; if(Test-Path $lnk){if($wsh.CreateShortcut($lnk).TargetPath -eq '%LNK_TARGET%'){exit 0}else{exit 2}}else{exit 1}"
set "ST=%ERRORLEVEL%"

if "!ST!"=="0" goto :lnk_already_ok
if "!ST!"=="2" goto :lnk_wrong
echo    [ ] %LNK_NAME%
set /p "R=        Crear en 'Enviar a'? (S/N): "
goto :lnk_confirm

:lnk_wrong
echo    [!] %LNK_NAME%
set /p "R=        Ruta incorrecta. Actualizar? (S/N): "

:lnk_confirm
if /i "!R!" neq "S" goto :lnk_ok
powershell -NoProfile -ExecutionPolicy Bypass -Command "$wsh=New-Object -ComObject WScript.Shell; $lnk=$wsh.CreateShortcut((Join-Path $wsh.SpecialFolders('SendTo') '%LNK_NAME%.lnk')); $lnk.TargetPath='%LNK_TARGET%'; $lnk.Save()"
echo    [OK] Acceso directo creado/actualizado.
goto :lnk_ok

:lnk_already_ok
echo    [OK] %LNK_NAME%

:lnk_ok
exit /b
