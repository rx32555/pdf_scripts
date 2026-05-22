param($ListFile)
if (-not (Test-Path $ListFile)) { exit }

Start-Sleep -Milliseconds 600

$lines = Get-Content $ListFile | Where-Object { $_ -match '\S' } | Select-Object -Unique
if ($lines.Count -eq 0) {
    Remove-Item $ListFile -Force -ErrorAction SilentlyContinue
    exit
}

$shell = New-Object -ComObject Shell.Application
$groups = $lines | Group-Object { [System.IO.Path]::GetDirectoryName($_) }

foreach ($g in $groups) {
    $dir = $g.Name
    $window = $shell.Windows() | Where-Object {
        $null -ne $_ -and
        $null -ne $_.Document -and
        $null -ne $_.Document.Folder -and
        $_.Document.Folder.Self.Path -eq $dir
    } | Select-Object -First 1

    if ($window) {
        $view = $window.Document
        $first = $true
        foreach ($path in $g.Group) {
            $name = [System.IO.Path]::GetFileName($path)
            $item = $view.Folder.ParseName($name)
            if ($item) {
                if ($first) {
                    $view.SelectItem($item, 13) # SVSI_SELECT | SVSI_DESELECTOTHERS | SVSI_ENSUREVISIBLE
                    $first = $false
                } else {
                    $view.SelectItem($item, 9)  # SVSI_SELECT | SVSI_ENSUREVISIBLE
                }
            }
        }
    }
}

Remove-Item $ListFile -Force -ErrorAction SilentlyContinue
