param(
    [string]$Lang = ""
)
$localesDir = $PSScriptRoot
$configFile = Join-Path $localesDir "lang_config.txt"

if ([string]::IsNullOrWhiteSpace($Lang)) {
    if (Test-Path $configFile) {
        $Lang = (Get-Content $configFile -Raw).Trim()
    } else {
        $Lang = (Get-UICulture).TwoLetterISOLanguageName
        if ($Lang -ne 'es') { $Lang = 'en' }
    }
}

[System.IO.File]::WriteAllText($configFile, $Lang, [System.Text.Encoding]::UTF8)

$jsonFile = Join-Path $localesDir "$($Lang).json"
if (-not (Test-Path $jsonFile)) { $jsonFile = Join-Path $localesDir "en.json" }

$dict = Get-Content $jsonFile -Raw | ConvertFrom-Json
$batLines = [System.Collections.Generic.List[string]]::new()
$batLines.Add("@echo off")
$batLines.Add("chcp 65001 >nul")
foreach ($key in $dict.psobject.properties.name) {
    if ($key -match "^L_GUI_") { continue }
    $val = $dict.$key -replace '"', '\"'
    $val = $val -replace "`n", " " -replace "`r", ""
    $batLines.Add("set `"$key=$val`"")
}
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText((Join-Path $localesDir "compiled_lang.bat"), ($batLines -join "`r`n"), $utf8NoBom)
