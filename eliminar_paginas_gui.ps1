Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

try {
    Add-Type -TypeDefinition '
using System;
using System.Runtime.InteropServices;
public class DwmApi2 {
    [DllImport("dwmapi.dll")]
    public static extern int DwmSetWindowAttribute(IntPtr hwnd, int attr, ref int val, int size);
}
'
} catch {}

[void][System.Windows.Forms.Application]::EnableVisualStyles()

function Load-Lang {
    $localesDir = [System.IO.Path]::Combine($PSScriptRoot, "locales")
    $configFile = [System.IO.Path]::Combine($localesDir, "lang_config.txt")
    $lang = "en"
    if (Test-Path $configFile) {
        $lang = (Get-Content $configFile -Raw).Trim()
    }
    $jsonFile = [System.IO.Path]::Combine($localesDir, "$lang.json")
    if (-not (Test-Path $jsonFile)) { $jsonFile = [System.IO.Path]::Combine($localesDir, "en.json") }
    return Get-Content $jsonFile -Raw -Encoding UTF8 | ConvertFrom-Json
}
$script:langDict = Load-Lang

# Archivos recibidos
$files = $args |
    Where-Object { $_ -match '\.pdf$' -and (Test-Path $_ -PathType Leaf) } |
    ForEach-Object { [System.IO.FileInfo]$_ }

if ($files.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show(
        $script:langDict.L_GUI_NO_PDF,
        "Error",
        [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]::Warning)
    exit
}

# Config: tema compartido con combinar_PDFs_config.json; opciones propias en eliminar_paginas_config.json
$configPath         = [System.IO.Path]::Combine($PSScriptRoot, "eliminar_paginas_config.json")
$combinarConfigPath = [System.IO.Path]::Combine($PSScriptRoot, "combinar_PDFs_config.json")

function Load-Config {
    # TemaOscuro: leer de combinar_PDFs_config.json para que ambas ventanas compartan tema
    $temaOscuro = $true
    if (Test-Path $combinarConfigPath) {
        try {
            $j = Get-Content $combinarConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $j.TemaOscuro) { $temaOscuro = [bool]$j.TemaOscuro }
        } catch {}
    }
    # Opciones propias
    $own = @{ ModoEliminar = $true; ModoNuevo = $false; AbrirAlTerminar = $false; AutoCerrar = $false; WindowWidth = 560; WindowHeight = 492 }
    if (Test-Path $configPath) {
        try {
            $j = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
            if ($null -ne $j.ModoEliminar)    { $own.ModoEliminar    = [bool]$j.ModoEliminar    }
            if ($null -ne $j.ModoNuevo)       { $own.ModoNuevo       = [bool]$j.ModoNuevo       }
            if ($null -ne $j.AbrirAlTerminar) { $own.AbrirAlTerminar = [bool]$j.AbrirAlTerminar }
            if ($null -ne $j.AutoCerrar)      { $own.AutoCerrar      = [bool]$j.AutoCerrar      }
            if ($null -ne $j.WindowWidth)     { $own.WindowWidth     = [int]$j.WindowWidth      }
            if ($null -ne $j.WindowHeight)    { $own.WindowHeight    = [int]$j.WindowHeight     }
        } catch {}
    }
    return @{
        TemaOscuro      = $temaOscuro
        ModoEliminar    = $own.ModoEliminar
        ModoNuevo       = $own.ModoNuevo
        AbrirAlTerminar = $own.AbrirAlTerminar
        AutoCerrar      = $own.AutoCerrar
        WindowWidth     = $own.WindowWidth
        WindowHeight    = $own.WindowHeight
    }
}

function Save-Config {
    # Escribir TemaOscuro en combinar_PDFs_config.json (archivo compartido)
    try {
        $j = if (Test-Path $combinarConfigPath) {
            Get-Content $combinarConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
        } else { [PSCustomObject]@{} }
        $j | Add-Member -NotePropertyName 'TemaOscuro' -NotePropertyValue $script:isDark -Force
        $j | ConvertTo-Json | Set-Content $combinarConfigPath -Encoding UTF8
    } catch {}
    # Guardar opciones propias
    try {
        [ordered]@{
            ModoEliminar    = $radEliminar.Checked
            ModoNuevo       = $radNuevo.Checked
            AbrirAlTerminar = $chkAbrir.Checked
            AutoCerrar      = $chkCerrar.Checked
            TemaOscuro      = $script:isDark
        } | ConvertTo-Json | Set-Content $configPath -Encoding UTF8
    } catch {}
}

$cfg = Load-Config
$script:isDark = $cfg.TemaOscuro

# Paletas de color (identicas a combinar_PDFs_gui.ps1)
$palettes = @{
    dark = @{
        Bg       = [System.Drawing.Color]::FromArgb( 30,  30,  30)
        Surface  = [System.Drawing.Color]::FromArgb( 37,  37,  38)
        Surface2 = [System.Drawing.Color]::FromArgb( 45,  45,  48)
        Border   = [System.Drawing.Color]::FromArgb( 62,  62,  66)
        Text     = [System.Drawing.Color]::FromArgb(220, 220, 220)
        TextDim  = [System.Drawing.Color]::FromArgb(140, 140, 140)
        Accent   = [System.Drawing.Color]::FromArgb(  0, 120, 212)
        AccHover = [System.Drawing.Color]::FromArgb( 16, 110, 190)
        AccPress = [System.Drawing.Color]::FromArgb(  0,  90, 158)
        SelectBg = [System.Drawing.Color]::FromArgb( 28,  58,  90)
        SelText  = [System.Drawing.Color]::FromArgb(255, 255, 255)
        BtnHover = [System.Drawing.Color]::FromArgb( 62,  62,  66)
        BtnPress = [System.Drawing.Color]::FromArgb( 20,  20,  20)
        Input    = [System.Drawing.Color]::FromArgb( 58,  58,  62)
        RangeBad = [System.Drawing.Color]::FromArgb(160,  40,  40)
        RangeOk  = [System.Drawing.Color]::FromArgb( 40, 130,  60)
    }
    light = @{
        Bg       = [System.Drawing.Color]::FromArgb(245, 245, 245)
        Surface  = [System.Drawing.Color]::FromArgb(255, 255, 255)
        Surface2 = [System.Drawing.Color]::FromArgb(235, 235, 235)
        Border   = [System.Drawing.Color]::FromArgb(200, 200, 200)
        Text     = [System.Drawing.Color]::FromArgb( 30,  30,  30)
        TextDim  = [System.Drawing.Color]::FromArgb(100, 100, 100)
        Accent   = [System.Drawing.Color]::FromArgb(  0, 120, 212)
        AccHover = [System.Drawing.Color]::FromArgb( 16, 110, 190)
        AccPress = [System.Drawing.Color]::FromArgb(  0,  90, 158)
        SelectBg = [System.Drawing.Color]::FromArgb(204, 228, 247)
        SelText  = [System.Drawing.Color]::FromArgb( 30,  30,  30)
        BtnHover = [System.Drawing.Color]::FromArgb(220, 220, 220)
        BtnPress = [System.Drawing.Color]::FromArgb(195, 195, 195)
        Input    = [System.Drawing.Color]::FromArgb(255, 255, 255)
        RangeBad = [System.Drawing.Color]::FromArgb(200,  60,  60)
        RangeOk  = [System.Drawing.Color]::FromArgb( 30, 140,  60)
    }
}

$script:pal = if ($script:isDark) { $palettes.dark } else { $palettes.light }

# Estado
$script:rutas    = [System.Collections.ArrayList]@()
$script:pagCount = @{}

# Brushes para owner draw
$script:brText    = [System.Drawing.SolidBrush]::new($script:pal.Text)
$script:brSelText = [System.Drawing.SolidBrush]::new($script:pal.SelText)
$script:brRow1    = [System.Drawing.SolidBrush]::new($script:pal.Surface)
$script:brRow2    = [System.Drawing.SolidBrush]::new($script:pal.Surface2)
$script:brSelBg   = [System.Drawing.SolidBrush]::new($script:pal.SelectBg)
$script:brAccent  = [System.Drawing.SolidBrush]::new($script:pal.Accent)
$script:sfVC      = New-Object System.Drawing.StringFormat
$script:sfVC.LineAlignment = [System.Drawing.StringAlignment]::Center

function Update-Brushes {
    foreach ($b in @($script:brText, $script:brSelText, $script:brRow1,
                     $script:brRow2, $script:brSelBg, $script:brAccent)) { $b.Dispose() }
    $script:brText    = [System.Drawing.SolidBrush]::new($script:pal.Text)
    $script:brSelText = [System.Drawing.SolidBrush]::new($script:pal.SelText)
    $script:brRow1    = [System.Drawing.SolidBrush]::new($script:pal.Surface)
    $script:brRow2    = [System.Drawing.SolidBrush]::new($script:pal.Surface2)
    $script:brSelBg   = [System.Drawing.SolidBrush]::new($script:pal.SelectBg)
    $script:brAccent  = [System.Drawing.SolidBrush]::new($script:pal.Accent)
}

# cpdf
$cpdfExe = [System.IO.Path]::Combine($PSScriptRoot, "dependencias", "cpdf.exe")

function Get-PageCount($path) {
    if (-not (Test-Path $cpdfExe)) { return 0 }
    try {
        $raw = & $cpdfExe -pages $path 2>$null
        $n   = 0
        if ([int]::TryParse(($raw -join '').Trim(), [ref]$n)) {
            $script:pagCount[$path] = $n
            return $n
        }
    } catch {}
    return 0
}

foreach ($f in $files) { Get-PageCount $f.FullName | Out-Null }

# Dado un rango de paginas a ELIMINAR y el total de paginas del PDF,
# devuelve el rango de paginas a CONSERVAR (complemento), o $null si
# el rango cubre todas las paginas.
# Necesario porque cpdf no tiene -remove-pages: solo acepta seleccion de paginas a conservar.
function Get-KeepRange([string]$removeRange, [int]$totalPages) {
    if ($totalPages -le 0) { return $null }
    $toRemove = [System.Collections.Generic.HashSet[int]]::new()
    foreach ($token in ($removeRange -split ',')) {
        $token = $token.Trim()
        if     ($token -eq 'odd')              { 1..$totalPages | Where-Object { $_ % 2 -eq 1 } | ForEach-Object { [void]$toRemove.Add($_) } }
        elseif ($token -eq 'even')             { 1..$totalPages | Where-Object { $_ % 2 -eq 0 } | ForEach-Object { [void]$toRemove.Add($_) } }
        elseif ($token -eq 'end')              { [void]$toRemove.Add($totalPages) }
        elseif ($token -eq 'reverse')          { 1..$totalPages | ForEach-Object { [void]$toRemove.Add($_) } }
        elseif ($token -match '^(\d+)-end$')   { $s=[int]$Matches[1]; if ($s -le $totalPages) { $s..$totalPages | ForEach-Object { [void]$toRemove.Add($_) } } }
        elseif ($token -match '^(\d+)-(\d+)$') {
            # Acepta rangos invertidos ("5-2" = paginas 2,3,4,5), igual que cpdf
            $a=[int]$Matches[1]; $b=[int]$Matches[2]
            $s=[Math]::Min($a,$b); $e=[Math]::Min([Math]::Max($a,$b),$totalPages)
            if ($s -ge 1 -and $s -le $e) { $s..$e | ForEach-Object { [void]$toRemove.Add($_) } }
        }
        elseif ($token -match '^(\d+)$')        { $p=[int]$Matches[1]; if ($p -ge 1 -and $p -le $totalPages) { [void]$toRemove.Add($p) } }
    }
    $toKeep = @(1..$totalPages | Where-Object { -not $toRemove.Contains($_) })
    if ($toKeep.Count -eq 0) { return $null }
    $parts = [System.Collections.ArrayList]@()
    $s = $toKeep[0]; $p = $toKeep[0]
    for ($i = 1; $i -lt $toKeep.Count; $i++) {
        if ($toKeep[$i] -eq $p + 1) { $p = $toKeep[$i] }
        else { [void]$parts.Add($(if ($s -eq $p) { "$s" } else { "$s-$p" })); $s=$toKeep[$i]; $p=$toKeep[$i] }
    }
    [void]$parts.Add($(if ($s -eq $p) { "$s" } else { "$s-$p" }))
    return $parts -join ','
}

function Get-DisplayName($ruta) {
    $nombre = [System.IO.Path]::GetFileName($ruta)
    $n = $script:pagCount[$ruta]
    if ($n -gt 0) { return "$nombre  ($n pags.)" }
    return $nombre
}

function Remove-Selected {
    $i = $listBox.SelectedIndex
    if ($i -lt 0 -or $listBox.Items.Count -le 1) { return }
    $listBox.Items.RemoveAt($i)
    $script:rutas.RemoveAt($i)
    $listBox.SelectedIndex = [Math]::Min($i, $listBox.Items.Count - 1)
    Update-TitleLabel
    Update-AbrirState
}

function Update-TitleLabel {
    $n = $listBox.Items.Count
    $arrowUp = [char]0x2191; $arrowDown = [char]0x2193
    $lblTitulo.Text = "$n $($script:langDict.L_GUI_LBL_TITLE_1) $arrowUp $arrowDown $($script:langDict.L_GUI_LBL_TITLE_2)"
}

function Update-AbrirState {
    $tooMany = $listBox.Items.Count -gt 10
    $chkAbrir.Visible = -not $tooMany
    if ($tooMany) {
        $chkAbrir.Checked = $false
        $chkAbrir.Text = $script:langDict.L_GUI_CHK_DISABLED
        $chkAbrir.Enabled = $false
    } else {
        $chkAbrir.Text = $script:langDict.L_GUI_CHK_OPEN
        $chkAbrir.Enabled = $true
    }
}

function Add-Files($paths) {
    $added = 0
    foreach ($path in $paths) {
        $path = [string]$path
        if ($path -match '\.pdf$' -and (Test-Path $path -PathType Leaf) -and ($script:rutas -notcontains $path)) {
            Get-PageCount $path | Out-Null
            [void]$listBox.Items.Add((Get-DisplayName $path))
            [void]$script:rutas.Add($path)
            $added++
        }
    }
    if ($added -gt 0) {
        Update-TitleLabel
        Update-AbrirState
    }
}

function Test-RangeValid($range) {
    if ([string]::IsNullOrWhiteSpace($range)) { return $false }
    $clean = $range.Trim()
    return $clean -match '^((\d+(-(\d+|end))?|end|odd|even|reverse)(,(\d+(-(\d+|end))?|end|odd|even|reverse))*)$'
}

function Append-Range($token) {
    $cur = $txtRange.Text.Trim()
    if ($cur -eq '') { $txtRange.Text = $token }
    else             { $txtRange.Text = $cur + ',' + $token }
    $txtRange.Focus()
    $txtRange.SelectionStart = $txtRange.Text.Length
    Update-RangeIndicator
}

function Update-RangeIndicator {
    $valid = Test-RangeValid $txtRange.Text
    $panelRange.BackColor = if ($txtRange.Text.Trim() -eq '') { $script:pal.Border }
                            elseif ($valid)                   { $script:pal.RangeOk }
                            else                              { $script:pal.RangeBad }
}

function Set-BtnStyle($btn) {
    $btn.FlatStyle = "Flat"
    $btn.BackColor = $script:pal.Surface2
    $btn.ForeColor = $script:pal.Text
    $btn.FlatAppearance.BorderColor        = $script:pal.Border
    $btn.FlatAppearance.BorderSize         = 1
    $btn.FlatAppearance.MouseOverBackColor = $script:pal.BtnHover
    $btn.FlatAppearance.MouseDownBackColor = $script:pal.BtnPress
}

function Apply-Theme($isDark) {
    $script:isDark = $isDark
    $script:pal    = if ($isDark) { $palettes.dark } else { $palettes.light }
    Update-Brushes

    $form.BackColor         = $script:pal.Bg
    $panelList.BackColor    = $script:pal.Border
    $listBox.BackColor      = $script:pal.Surface
    $pnlOperacion.BackColor = $script:pal.Bg
    $pnlGuardar.BackColor   = $script:pal.Bg
    $sep1.BackColor         = $script:pal.Border
    $sep2.BackColor         = $script:pal.Border
    $txtRange.BackColor     = $script:pal.Input
    $txtRange.ForeColor     = $script:pal.Text
    $panelSkipped.BackColor = $script:pal.Border
    $rtbSkipped.BackColor   = $script:pal.Surface2
    $rtbSkipped.ForeColor   = $script:pal.TextDim

    foreach ($lbl in @($lblTitulo, $lblOperacion, $lblPaginas, $lblHint, $lblGuardar, $lblFolder)) {
        $lbl.BackColor = $script:pal.Bg
        $lbl.ForeColor = $script:pal.Text
    }
    $lblHint.ForeColor   = $script:pal.TextDim
    $lblFolder.ForeColor = $script:pal.TextDim
    $lblStatus.BackColor = $script:pal.Bg

    foreach ($rad in @($radEliminar, $radConservar, $radReemplazar, $radNuevo)) {
        $rad.BackColor = $script:pal.Bg
        $rad.ForeColor = $script:pal.Text
    }
    $chkAbrir.BackColor  = $script:pal.Bg
    $chkAbrir.ForeColor  = $script:pal.Text
    $chkCerrar.BackColor = $script:pal.Bg
    $chkCerrar.ForeColor = $script:pal.Text

    foreach ($btn in $script:themedButtons) { Set-BtnStyle $btn }

    $btnTema.Text = if ($isDark) { "$sunChar $($script:langDict.L_GUI_BTN_LIGHT)" } else { "$moonChar $($script:langDict.L_GUI_BTN_DARK)" }

    try {
        $dv = if ($isDark) { 1 } else { 0 }
        [void][DwmApi2]::DwmSetWindowAttribute($form.Handle, 20, [ref]$dv, 4)
        [void][DwmApi2]::DwmSetWindowAttribute($form.Handle, 19, [ref]$dv, 4)
    } catch {}

    Update-RangeIndicator
    $listBox.Invalidate()
    $form.Refresh()
    Save-Config
}

$enye      = [char]0x00F1
$sunChar   = [char]0x25CB
$moonChar  = [char]0x25CF
$checkChar = [char]0x2713

$form = New-Object System.Windows.Forms.Form
$form.Text            = $script:langDict.L_GUI_TITLE_DEL
$form.ClientSize      = New-Object System.Drawing.Size(560, 492)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "Sizable"
$form.MinimumSize     = New-Object System.Drawing.Size(560, 492)
$form.MaximizeBox     = $false
$form.BackColor       = $script:pal.Bg
$form.ForeColor       = $script:pal.Text
$form.Font            = New-Object System.Drawing.Font("Segoe UI", 9)

$form.Add_HandleCreated({
    param($s, $e)
    try {
        $dv = if ($script:isDark) { 1 } else { 0 }
        [void][DwmApi2]::DwmSetWindowAttribute($s.Handle, 20, [ref]$dv, 4)
        [void][DwmApi2]::DwmSetWindowAttribute($s.Handle, 19, [ref]$dv, 4)
    } catch {}
})

$form.Add_FormClosed({
    Save-Config
    $timerClose.Stop(); $timerClose.Dispose()
    foreach ($b in @($script:brText, $script:brSelText, $script:brRow1,
                     $script:brRow2, $script:brSelBg, $script:brAccent)) { $b.Dispose() }
    $script:sfVC.Dispose()
})

$lblTitulo = New-Object System.Windows.Forms.Label
$lblTitulo.Location  = New-Object System.Drawing.Point(12, 12)
$lblTitulo.Size      = New-Object System.Drawing.Size(290, 16)
$lblTitulo.BackColor = $script:pal.Bg
$lblTitulo.ForeColor = $script:pal.Text

$btnTema = New-Object System.Windows.Forms.Button
$btnTema.Text     = if ($script:isDark) { "$sunChar $($script:langDict.L_GUI_BTN_LIGHT)" } else { "$moonChar $($script:langDict.L_GUI_BTN_DARK)" }
$btnTema.Location = New-Object System.Drawing.Point(448, 5)
$btnTema.Size     = New-Object System.Drawing.Size(100, 22)
$btnTema.Font     = New-Object System.Drawing.Font("Segoe UI", 9)
$btnTema.Anchor   = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
Set-BtnStyle $btnTema

$btnAgregar = New-Object System.Windows.Forms.Button
$btnAgregar.Text     = $script:langDict.L_GUI_BTN_ADD
$btnAgregar.Location = New-Object System.Drawing.Point(308, 5)
$btnAgregar.Size     = New-Object System.Drawing.Size(132, 22)
$btnAgregar.Font     = New-Object System.Drawing.Font("Segoe UI", 9)
$btnAgregar.Anchor   = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
Set-BtnStyle $btnAgregar

$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Font           = New-Object System.Drawing.Font("Segoe UI", 10)
$listBox.IntegralHeight = $false
$listBox.AllowDrop      = $true
$listBox.BackColor      = $script:pal.Surface
$listBox.ForeColor      = $script:pal.Text
$listBox.BorderStyle    = "None"
$listBox.DrawMode       = [System.Windows.Forms.DrawMode]::OwnerDrawFixed
$listBox.ItemHeight     = 28
$listBox.Location       = New-Object System.Drawing.Point(1, 1)
$listBox.Size           = New-Object System.Drawing.Size(536, 156)
$listBox.Anchor         = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$panelList = New-Object System.Windows.Forms.Panel
$panelList.Location  = New-Object System.Drawing.Point(11, 30)
$panelList.Size      = New-Object System.Drawing.Size(538, 158)
$panelList.BackColor = $script:pal.Border
$panelList.Padding   = New-Object System.Windows.Forms.Padding(1)
$panelList.Anchor    = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$panelList.Controls.Add($listBox)

$btnEliminar = New-Object System.Windows.Forms.Button
$btnEliminar.Text     = "$($script:langDict.L_GUI_BTN_DEL)  [Supr]"
$btnEliminar.Location = New-Object System.Drawing.Point(11, 196)
$btnEliminar.Size     = New-Object System.Drawing.Size(180, 26)
$btnEliminar.Anchor   = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
Set-BtnStyle $btnEliminar

$sep1 = New-Object System.Windows.Forms.Label
$sep1.BackColor = $script:pal.Border
$sep1.Location  = New-Object System.Drawing.Point(11, 232)
$sep1.Size      = New-Object System.Drawing.Size(538, 1)
$sep1.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$lblOperacion = New-Object System.Windows.Forms.Label
$lblOperacion.Text      = $script:langDict.L_GUI_LBL_OP
$lblOperacion.Location  = New-Object System.Drawing.Point(12, 244)
$lblOperacion.Size      = New-Object System.Drawing.Size(72, 18)
$lblOperacion.BackColor = $script:pal.Bg
$lblOperacion.ForeColor = $script:pal.Text
$lblOperacion.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left

$pnlOperacion = New-Object System.Windows.Forms.Panel
$pnlOperacion.Location  = New-Object System.Drawing.Point(86, 240)
$pnlOperacion.Size      = New-Object System.Drawing.Size(462, 24)
$pnlOperacion.BackColor = $script:pal.Bg
$pnlOperacion.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left

$radEliminar = New-Object System.Windows.Forms.RadioButton
$radEliminar.Text      = $script:langDict.L_GUI_RDO_DEL
$radEliminar.Checked   = $cfg.ModoEliminar
$radEliminar.Location  = New-Object System.Drawing.Point(0, 2)
$radEliminar.Size      = New-Object System.Drawing.Size(196, 20)
$radEliminar.BackColor = $script:pal.Bg
$radEliminar.ForeColor = $script:pal.Text

$radConservar = New-Object System.Windows.Forms.RadioButton
$radConservar.Text      = $script:langDict.L_GUI_RDO_KEEP
$radConservar.Checked   = -not $cfg.ModoEliminar
$radConservar.Location  = New-Object System.Drawing.Point(202, 2)
$radConservar.Size      = New-Object System.Drawing.Size(220, 20)
$radConservar.BackColor = $script:pal.Bg
$radConservar.ForeColor = $script:pal.Text

$pnlOperacion.Controls.AddRange(@($radEliminar, $radConservar))

$lblPaginas = New-Object System.Windows.Forms.Label
$lblPaginas.Text      = $script:langDict.L_GUI_LBL_PAGES
$lblPaginas.Location  = New-Object System.Drawing.Point(12, 274)
$lblPaginas.Size      = New-Object System.Drawing.Size(62, 24)
$lblPaginas.BackColor = $script:pal.Bg
$lblPaginas.ForeColor = $script:pal.Text
$lblPaginas.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left

$txtRange = New-Object System.Windows.Forms.TextBox
$txtRange.Location    = New-Object System.Drawing.Point(1, 1)
$txtRange.Size        = New-Object System.Drawing.Size(238, 22)
$txtRange.BackColor   = $script:pal.Input
$txtRange.ForeColor   = $script:pal.Text
$txtRange.BorderStyle = "None"
$txtRange.Font        = New-Object System.Drawing.Font("Segoe UI", 10)
$txtRange.Anchor      = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$panelRange = New-Object System.Windows.Forms.Panel
$panelRange.Location  = New-Object System.Drawing.Point(78, 272)
$panelRange.Size      = New-Object System.Drawing.Size(240, 24)
$panelRange.BackColor = $script:pal.Border
$panelRange.Padding   = New-Object System.Windows.Forms.Padding(1)
$panelRange.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$panelRange.Controls.Add($txtRange)

$btnQ1 = New-Object System.Windows.Forms.Button
$btnQ1.Text     = $script:langDict.L_GUI_BTN_FIRST
$btnQ1.Location = New-Object System.Drawing.Point(322, 270)
$btnQ1.Size     = New-Object System.Drawing.Size(50, 26)
$btnQ1.Font     = New-Object System.Drawing.Font("Segoe UI", 8)
$btnQ1.Anchor   = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
Set-BtnStyle $btnQ1

$btnQLast = New-Object System.Windows.Forms.Button
$btnQLast.Text     = $script:langDict.L_GUI_BTN_LAST
$btnQLast.Location = New-Object System.Drawing.Point(374, 270)
$btnQLast.Size     = New-Object System.Drawing.Size(52, 26)
$btnQLast.Font     = New-Object System.Drawing.Font("Segoe UI", 8)
$btnQLast.Anchor   = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
Set-BtnStyle $btnQLast

$btnQPar = New-Object System.Windows.Forms.Button
$btnQPar.Text     = $script:langDict.L_GUI_BTN_EVEN
$btnQPar.Location = New-Object System.Drawing.Point(428, 270)
$btnQPar.Size     = New-Object System.Drawing.Size(54, 26)
$btnQPar.Font     = New-Object System.Drawing.Font("Segoe UI", 8)
$btnQPar.Anchor   = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
Set-BtnStyle $btnQPar

$btnQImp = New-Object System.Windows.Forms.Button
$btnQImp.Text     = $script:langDict.L_GUI_BTN_ODD
$btnQImp.Location = New-Object System.Drawing.Point(484, 270)
$btnQImp.Size     = New-Object System.Drawing.Size(64, 26)
$btnQImp.Font     = New-Object System.Drawing.Font("Segoe UI", 8)
$btnQImp.Anchor   = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
Set-BtnStyle $btnQImp

$lblHint = New-Object System.Windows.Forms.Label
$lblHint.Text      = $script:langDict.L_GUI_HINT_RANGE
$lblHint.Location  = New-Object System.Drawing.Point(78, 300)
$lblHint.Size      = New-Object System.Drawing.Size(470, 14)
$lblHint.BackColor = $script:pal.Bg
$lblHint.ForeColor = $script:pal.TextDim
$lblHint.Font      = New-Object System.Drawing.Font("Segoe UI", 7.5)
$lblHint.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$sep2 = New-Object System.Windows.Forms.Label
$sep2.BackColor = $script:pal.Border
$sep2.Location  = New-Object System.Drawing.Point(11, 322)
$sep2.Size      = New-Object System.Drawing.Size(538, 1)
$sep2.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$lblGuardar = New-Object System.Windows.Forms.Label
$lblGuardar.Text      = $script:langDict.L_GUI_LBL_SAVE
$lblGuardar.Location  = New-Object System.Drawing.Point(12, 334)
$lblGuardar.Size      = New-Object System.Drawing.Size(62, 18)
$lblGuardar.BackColor = $script:pal.Bg
$lblGuardar.ForeColor = $script:pal.Text
$lblGuardar.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left

$pnlGuardar = New-Object System.Windows.Forms.Panel
$pnlGuardar.Location  = New-Object System.Drawing.Point(78, 330)
$pnlGuardar.Size      = New-Object System.Drawing.Size(470, 24)
$pnlGuardar.BackColor = $script:pal.Bg
$pnlGuardar.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left

$radReemplazar = New-Object System.Windows.Forms.RadioButton
$radReemplazar.Text      = $script:langDict.L_GUI_RDO_REPLACE
$radReemplazar.Checked   = -not $cfg.ModoNuevo
$radReemplazar.Location  = New-Object System.Drawing.Point(0, 2)
$radReemplazar.Size      = New-Object System.Drawing.Size(168, 20)
$radReemplazar.BackColor = $script:pal.Bg
$radReemplazar.ForeColor = $script:pal.Text

$radNuevo = New-Object System.Windows.Forms.RadioButton
$radNuevo.Text      = $script:langDict.L_GUI_RDO_NEW_FILE
$radNuevo.Checked   = $cfg.ModoNuevo
$radNuevo.Location  = New-Object System.Drawing.Point(172, 2)
$radNuevo.Size      = New-Object System.Drawing.Size(298, 20)
$radNuevo.BackColor = $script:pal.Bg
$radNuevo.ForeColor = $script:pal.Text

$pnlGuardar.Controls.AddRange(@($radReemplazar, $radNuevo))

$chkCerrar = New-Object System.Windows.Forms.CheckBox
$chkCerrar.Text      = $script:langDict.L_GUI_CHK_CLOSE
$chkCerrar.Checked   = $cfg.AutoCerrar
$chkCerrar.Location  = New-Object System.Drawing.Point(12, 364)
$chkCerrar.Size      = New-Object System.Drawing.Size(185, 20)
$chkCerrar.ForeColor = $script:pal.Text
$chkCerrar.BackColor = $script:pal.Bg
$chkCerrar.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left

$chkAbrir = New-Object System.Windows.Forms.CheckBox
$chkAbrir.Text      = $script:langDict.L_GUI_CHK_OPEN
$chkAbrir.Checked   = $cfg.AbrirAlTerminar
$chkAbrir.Location  = New-Object System.Drawing.Point(202, 364)
$chkAbrir.Size      = New-Object System.Drawing.Size(155, 20)
$chkAbrir.ForeColor = $script:pal.Text
$chkAbrir.BackColor = $script:pal.Bg
$chkAbrir.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left

$btnProcesar = New-Object System.Windows.Forms.Button
$btnProcesar.Text      = $script:langDict.L_GUI_BTN_PROCESS
$btnProcesar.Location  = New-Object System.Drawing.Point(368, 358)
$btnProcesar.Size      = New-Object System.Drawing.Size(180, 32)
$btnProcesar.FlatStyle = "Flat"
$btnProcesar.BackColor = $script:pal.Accent
$btnProcesar.ForeColor = [System.Drawing.Color]::White
$btnProcesar.FlatAppearance.BorderSize         = 0
$btnProcesar.FlatAppearance.MouseOverBackColor = $script:pal.AccHover
$btnProcesar.FlatAppearance.MouseDownBackColor = $script:pal.AccPress
$btnProcesar.Anchor                        = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
$form.AcceptButton = $btnProcesar

$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location  = New-Object System.Drawing.Point(12, 396)
$lblStatus.Size      = New-Object System.Drawing.Size(536, 18)
$lblStatus.BackColor = $script:pal.Bg
$lblStatus.ForeColor = $script:pal.TextDim
$lblStatus.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$lblStatus.Text      = ""
$lblStatus.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$panelSkipped = New-Object System.Windows.Forms.Panel
$panelSkipped.Location  = New-Object System.Drawing.Point(12, 418)
$panelSkipped.Size      = New-Object System.Drawing.Size(536, 52)
$panelSkipped.BackColor = $script:pal.Border
$panelSkipped.Padding   = New-Object System.Windows.Forms.Padding(1)
$panelSkipped.Visible   = $false
$panelSkipped.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$rtbSkipped = New-Object System.Windows.Forms.RichTextBox
$rtbSkipped.Dock        = [System.Windows.Forms.DockStyle]::Fill
$rtbSkipped.BackColor   = $script:pal.Surface2
$rtbSkipped.ForeColor   = $script:pal.TextDim
$rtbSkipped.Font        = New-Object System.Drawing.Font("Segoe UI", 8)
$rtbSkipped.ReadOnly    = $true
$rtbSkipped.BorderStyle = "None"
$rtbSkipped.ScrollBars  = "Vertical"
$rtbSkipped.Text        = ""
$panelSkipped.Controls.Add($rtbSkipped)

$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Location  = New-Object System.Drawing.Point(12, 474)
$lblFolder.Size      = New-Object System.Drawing.Size(536, 14)
$lblFolder.BackColor = $script:pal.Bg
$lblFolder.ForeColor = $script:pal.TextDim
$lblFolder.Font      = New-Object System.Drawing.Font("Segoe UI", 7.5)
$lblFolder.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$script:countdown    = 0
$timerClose          = New-Object System.Windows.Forms.Timer
$timerClose.Interval = 1000
$timerClose.Add_Tick({
    $script:countdown--
    if ($script:countdown -le 0) {
        $timerClose.Stop(); $form.Close()
    } else {
        $lblStatus.Text = "$checkChar Procesado. Cerrando en $($script:countdown)s..."
    }
})

$script:themedButtons = @($btnAgregar, $btnTema, $btnEliminar,
                          $btnQ1, $btnQLast, $btnQPar, $btnQImp)

$listBox.Add_DrawItem({
    param($s, $e)
    if ($e.Index -lt 0 -or $e.Index -ge $listBox.Items.Count) { return }
    $sel = $e.State -band [System.Windows.Forms.DrawItemState]::Selected
    $bg  = if ($sel) { $script:brSelBg } elseif ($e.Index % 2 -eq 0) { $script:brRow1 } else { $script:brRow2 }
    $e.Graphics.FillRectangle($bg, $e.Bounds)
    if ($sel) {
        $bar = New-Object System.Drawing.Rectangle($e.Bounds.X, $e.Bounds.Y, 3, $e.Bounds.Height)
        $e.Graphics.FillRectangle($script:brAccent, $bar)
    }
    $fg      = if ($sel) { $script:brSelText } else { $script:brText }
    $txtRect = New-Object System.Drawing.RectangleF(($e.Bounds.X + 12), $e.Bounds.Y, ($e.Bounds.Width - 12), $e.Bounds.Height)
    $e.Graphics.DrawString($listBox.Items[$e.Index], $listBox.Font, $fg, $txtRect, $script:sfVC)
})

$tip = New-Object System.Windows.Forms.ToolTip
$tip.AutoPopDelay = 6000; $tip.InitialDelay = 600; $tip.ReshowDelay = 300
$tip.SetToolTip($listBox,      $script:langDict.L_GUI_TIP_LIST)
$tip.SetToolTip($btnEliminar,  $script:langDict.L_GUI_TIP_DEL)
$tip.SetToolTip($btnAgregar,   $script:langDict.L_GUI_TIP_ADD)
$tip.SetToolTip($radEliminar,  $script:langDict.L_GUI_TIP_RDO_DEL)
$tip.SetToolTip($radConservar, $script:langDict.L_GUI_TIP_RDO_KEEP)
$tip.SetToolTip($txtRange,     $script:langDict.L_GUI_TIP_RANGE)
$tip.SetToolTip($btnQ1,        $script:langDict.L_GUI_TIP_P1)
$tip.SetToolTip($btnQLast,     $script:langDict.L_GUI_TIP_PLAST)
$tip.SetToolTip($btnQPar,      $script:langDict.L_GUI_TIP_PEVEN)
$tip.SetToolTip($btnQImp,      $script:langDict.L_GUI_TIP_PODD)
$tip.SetToolTip($radReemplazar,$script:langDict.L_GUI_TIP_RDO_OVERWRITE)
$tip.SetToolTip($radNuevo,     $script:langDict.L_GUI_TIP_RDO_NEW)
$tip.SetToolTip($chkCerrar,    $script:langDict.L_GUI_TIP_CLOSE)
$tip.SetToolTip($chkAbrir,     $script:langDict.L_GUI_TIP_OPEN)
$tip.SetToolTip($btnProcesar,  $script:langDict.L_GUI_TIP_PROCESS)

foreach ($f in $files) {
    [void]$listBox.Items.Add((Get-DisplayName $f.FullName))
    [void]$script:rutas.Add($f.FullName)
}
$listBox.SelectedIndex = 0
Update-TitleLabel
Update-AbrirState
$lblFolder.Text = $script:langDict.L_GUI_LBL_FOLDER + " " + $files[0].DirectoryName

$btnTema.Add_Click({ Apply-Theme (-not $script:isDark) })
$listBox.Add_Resize({ $listBox.Invalidate() })
$btnEliminar.Add_Click({ Remove-Selected })

$btnAgregar.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title       = "Seleccionar PDFs"
    $dlg.Filter      = "PDF (*.pdf)|*.pdf"
    $dlg.Multiselect = $true
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { Add-Files $dlg.FileNames }
    $dlg.Dispose()
})

$btnQ1.Add_Click(    { Append-Range '1'    })
$btnQLast.Add_Click( { Append-Range 'end'  })
$btnQPar.Add_Click(  { Append-Range 'even' })
$btnQImp.Add_Click(  { Append-Range 'odd'  })

$txtRange.Add_TextChanged({ Update-RangeIndicator })

$listBox.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Delete) { Remove-Selected }
})

$listBox.Add_DragOver({
    param($s, $e)
    if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy
    }
})
$listBox.Add_DragDrop({
    param($s, $e)
    if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        Add-Files ($e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop))
    }
})

$radEliminar.Add_CheckedChanged({ Save-Config })
$radNuevo.Add_CheckedChanged(   { Save-Config })
$chkAbrir.Add_CheckedChanged(   { Save-Config })
$chkCerrar.Add_CheckedChanged(  { Save-Config })

$btnProcesar.Add_Click({
    $range = $txtRange.Text.Trim()
    if (-not (Test-RangeValid $range)) {
        [System.Windows.Forms.MessageBox]::Show(
            "Rango de p" + [char]0x00E1 + "ginas no v" + [char]0x00E1 + "lido.`n`nEjemplos:`n  1,3,5-7`n  2-end`n  odd`n  even",
            "Rango inv" + [char]0x00E1 + "lido",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        $txtRange.Focus()
        return
    }

    if (-not (Test-Path $cpdfExe)) {
        [System.Windows.Forms.MessageBox]::Show(
            $script:langDict.L_GUI_ERR_CPDF,
            "Error", [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    $modoEliminar = $radEliminar.Checked
    $modoNuevo    = $radNuevo.Checked
    $accion       = if ($modoEliminar) { $script:langDict.L_GUI_MSG_CONFIRM_DEL } else { $script:langDict.L_GUI_MSG_CONFIRM_KEEP }

    $resp = [System.Windows.Forms.MessageBox]::Show(
        ($script:langDict.L_GUI_MSG_CONFIRM -f $accion, $range, $script:rutas.Count, $(if ($modoNuevo) { $script:langDict.L_GUI_MSG_CONFIRM_NEW } else { $script:langDict.L_GUI_MSG_CONFIRM_REP })),
        "Confirm",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($resp -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $btnProcesar.Enabled  = $false
    $lblStatus.ForeColor  = $script:pal.TextDim
    $lblStatus.Text       = "Procesando..."
    $panelSkipped.Visible = $false
    $rtbSkipped.Clear()
    $form.Refresh()

    $logLines     = [System.Collections.ArrayList]@()
    $outputFiles  = [System.Collections.ArrayList]@()
    $errCount     = 0
    $processed    = 0

    foreach ($ruta in $script:rutas) {
        $nombre = [System.IO.Path]::GetFileName($ruta)
        $nPags  = if ($script:pagCount.ContainsKey($ruta)) { [int]$script:pagCount[$ruta] } else { 0 }

        if ($modoEliminar -and $nPags -eq 1) {
            [void]$logLines.Add(($script:langDict.L_GUI_LOG_OMIT_1PAG -f $nombre))
        } else {
            $uid = [System.IO.Path]::GetRandomFileName() -replace '\.', ''
            $tmp = [System.IO.Path]::Combine(
                [System.IO.Path]::GetDirectoryName($ruta),
                "_eptmp_$uid.pdf")

            $cpdfRange = if ($modoEliminar) { Get-KeepRange $range $nPags } else { $range }

            if ($modoEliminar -and $null -eq $cpdfRange) {
                if ($nPags -gt 0) {
                    [void]$logLines.Add(($script:langDict.L_GUI_LOG_OMIT_ALL -f $nombre))
                } else {
                    $errCount++
                    [void]$logLines.Add(($script:langDict.L_GUI_LOG_ERR_READ_PAGES -f $nombre))
                }
            } else {
                try {
                    $cpdfOut = & $cpdfExe $ruta $cpdfRange -o $tmp 2>&1

                    if (-not (Test-Path $tmp)) {
                        $errMsg = if ($cpdfOut) { ($cpdfOut -join ' ').Trim() } `
                                  else          { $script:langDict.L_GUI_LOG_ERR_NOCPDF }
                        throw $errMsg
                    }

                    $resultPags = 0
                    $raw = & $cpdfExe -pages $tmp 2>$null
                    [int]::TryParse(($raw -join '').Trim(), [ref]$resultPags) | Out-Null

                    if ($resultPags -lt 1) {
                        throw ($script:langDict.L_GUI_LOG_ERR_NOPAGS -f "")
                    } else {
                        if ($modoNuevo) {
                            $dir  = [System.IO.Path]::GetDirectoryName($ruta)
                            $base = [System.IO.Path]::GetFileNameWithoutExtension($ruta)
                            $dest = [System.IO.Path]::Combine($dir, $base + "_editado.pdf")
                            if (Test-Path $dest) { Remove-Item $dest -Force }
                            [System.IO.File]::Move($tmp, $dest)
                            [void]$outputFiles.Add($dest)
                        } else {
                            Remove-Item $ruta -Force
                            [System.IO.File]::Move($tmp, $ruta)
                            [void]$outputFiles.Add($ruta)
                        }
                        $processed++
                    }
                } catch {
                    $errCount++
                    $errDetail = ($_.ToString() -replace "`r`n", " " -replace "`n", " ").Trim()
                    [void]$logLines.Add("ERR:  $nombre  - $errDetail")
                    if (Test-Path $tmp -ErrorAction SilentlyContinue) {
                        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
                    }
                }
            }
        }
    }

    # --- Resultado ---
    $colorOk   = if ($script:isDark) { [System.Drawing.Color]::FromArgb(100, 220, 140) } `
                                else { [System.Drawing.Color]::FromArgb(  0, 140,  50) }
    $colorWarn = if ($script:isDark) { [System.Drawing.Color]::FromArgb(220, 180,  60) } `
                                else { [System.Drawing.Color]::FromArgb(160, 100,   0) }
    $colorErr  = if ($script:isDark) { [System.Drawing.Color]::FromArgb(220, 100, 100) } `
                                else { [System.Drawing.Color]::FromArgb(180,   0,   0) }

    $skipCount = @($logLines | Where-Object { $_ -like 'OMIT:*' }).Count

    if ($processed -gt 0 -and $errCount -eq 0) {
        # Exito total (puede haber omitidos pero ningun error)
        $lblStatus.ForeColor = $colorOk
        $lblStatus.Text = if ($skipCount -gt 0) {
            "$checkChar " + ($script:langDict.L_GUI_STATUS_OK_SKIPPED -f $processed, $skipCount)
        } else {
            "$checkChar " + ($script:langDict.L_GUI_STATUS_OK -f $processed)
        }
        if ($chkAbrir.Checked -and $chkAbrir.Enabled -and $outputFiles.Count -gt 0) {
            foreach ($f in $outputFiles) { Start-Process $f }
        }
        if ($chkCerrar.Checked) {
            $script:countdown = 5
            $timerClose.Start()
        } else {
            $btnProcesar.Enabled = $true
        }
    } elseif ($processed -gt 0 -and $errCount -gt 0) {
        # Exito parcial con errores
        $lblStatus.ForeColor = $colorWarn
        $lblStatus.Text      = "$checkChar " + ($script:langDict.L_GUI_STATUS_WARN -f $processed, $errCount)
        $btnProcesar.Enabled = $true
    } elseif ($processed -eq 0 -and $errCount -gt 0) {
        # Todo fallo
        $lblStatus.ForeColor = $colorErr
        $lblStatus.Text      = $script:langDict.L_GUI_STATUS_ERR_ALL
        $btnProcesar.Enabled = $true
    } else {
        # processed=0, errCount=0: todos omitidos
        $lblStatus.ForeColor = $colorWarn
        $lblStatus.Text      = $script:langDict.L_GUI_STATUS_OMIT_ALL
        $btnProcesar.Enabled = $true
    }

    # Log en panel scrollable: errores primero (rojo), omitidos despues (ambar)
    if ($logLines.Count -gt 0) {
        $rtbSkipped.Clear()
        $errLines  = @($logLines | Where-Object { $_ -like 'ERR:*'  })
        $skipLines = @($logLines | Where-Object { $_ -like 'OMIT:*' })
        foreach ($line in ($errLines + $skipLines)) {
            $lc = if ($line -like 'ERR:*') { $colorErr } else { $colorWarn }
            $rtbSkipped.SelectionColor = $lc
            $rtbSkipped.AppendText($line + "`n")
        }
        $panelSkipped.Visible = $true
    }
})

# ---- Mostrar ----
$form.Controls.AddRange(@(
    $lblTitulo, $btnAgregar, $btnTema,
    $panelList,
    $btnEliminar,
    $sep1,
    $lblOperacion, $pnlOperacion,
    $lblPaginas, $panelRange,
    $btnQ1, $btnQLast, $btnQPar, $btnQImp,
    $lblHint,
    $sep2,
    $lblGuardar, $pnlGuardar,
    $chkAbrir, $chkCerrar, $btnProcesar,
    $lblStatus, $panelSkipped, $lblFolder
))
Update-RangeIndicator
[void]$form.ShowDialog()
