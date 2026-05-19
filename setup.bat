@echo off
setlocal enabledelayedexpansion

set "ROOT=%~dp0"
set "DEPS=%ROOT%dependencias"
set "CPDF=%DEPS%\cpdf.exe"

echo.
echo  ==============================================
echo   Setup - Scripts PDF con cpdf
echo  ==============================================
echo.

if not exist "%DEPS%" mkdir "%DEPS%"

:: ---- Instalar cpdf ----
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

:: ---- Shortcuts en Enviar a ----
set "TARGET=%ROOT%filename_header_REEMPLAZA_drag_and_drop.bat"

powershell -NoProfile -ExecutionPolicy Bypass -Command "$wsh=New-Object -ComObject WScript.Shell; $lnk=Join-Path $wsh.SpecialFolders('SendTo') 'PDF - Encabezado con nombre de archivo(s) y sobreescribirlos.lnk'; if(Test-Path $lnk){if($wsh.CreateShortcut($lnk).TargetPath -eq '%TARGET%'){exit 0}else{exit 2}}else{exit 1}"
set "LNK_STATE=%ERRORLEVEL%"

if "!LNK_STATE!"=="0" (
    echo [OK] Acceso directo ya configurado correctamente.
    goto :fin
)
if "!LNK_STATE!"=="2" (
    echo [!] Acceso directo existe pero apunta a ruta distinta.
    set /p "RESP=Actualizar ruta? (S/N): "
) else (
    set /p "RESP=Crear acceso directo en 'Enviar a'? (S/N): "
)
if /i "!RESP!" neq "S" goto :fin

powershell -NoProfile -ExecutionPolicy Bypass -Command "$wsh=New-Object -ComObject WScript.Shell; $lnk=$wsh.CreateShortcut((Join-Path $wsh.SpecialFolders('SendTo') 'PDF - Encabezado con nombre de archivo(s) y sobreescribirlos.lnk')); $lnk.TargetPath='%TARGET%'; $lnk.Save()"
echo [OK] Acceso directo creado/actualizado en 'Enviar a'.

:fin
echo.
echo Setup completado.
echo.
pause
exit /b
