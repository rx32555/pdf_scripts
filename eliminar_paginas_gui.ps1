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

# Archivos recibidos
$files = $args |
    Where-Object { $_ -match '\.pdf$' -and (Test-Path $_ -PathType Leaf) } |
    ForEach-Object { [System.IO.FileInfo]$_ }

if ($files.Count -eq 0) {
    [System.Windows.Forms.MessageBox]::Show(
        "No se recibieron archivos PDF.`nArrastra PDFs sobre el .bat para usarlo.",
        "Sin archivos",
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
            $j = Get-Content $combinarConfigPath -Raw | ConvertFrom-Json
            if ($null -ne $j.TemaOscuro) { $temaOscuro = [bool]$j.TemaOscuro }
        } catch {}
    }
    # Opciones propias
    $own = @{ ModoEliminar = $true; ModoNuevo = $false; AbrirAlTerminar = $false; AutoCerrar = $false }
    if (Test-Path $configPath) {
        try {
            $j = Get-Content $configPath -Raw | ConvertFrom-Json
            if ($null -ne $j.ModoEliminar)    { $own.ModoEliminar    = [bool]$j.ModoEliminar    }
            if ($null -ne $j.ModoNuevo)       { $own.ModoNuevo       = [bool]$j.ModoNuevo       }
            if ($null -ne $j.AbrirAlTerminar) { $own.AbrirAlTerminar = [bool]$j.AbrirAlTerminar }
            if ($null -ne $j.AutoCerrar)      { $own.AutoCerrar      = [bool]$j.AutoCerrar      }
        } catch {}
    }
    return @{
        TemaOscuro      = $temaOscuro
        ModoEliminar    = $own.ModoEliminar
        ModoNuevo       = $own.ModoNuevo
        AbrirAlTerminar = $own.AbrirAlTerminar
        AutoCerrar      = $own.AutoCerrar
    }
}

function Save-Config {
    # Escribir TemaOscuro en combinar_PDFs_config.json (archivo compartido)
    try {
        $j = if (Test-Path $combinarConfigPath) {
            Get-Content $combinarConfigPath -Raw | ConvertFrom-Json
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
    $s = if ($n -ne 1) { 's' } else { '' }
    $lblTitulo.Text = "$n PDF$s seleccionado$s"
}

# Deshabilitar "Abrir al terminar" cuando hay mas de 10 PDFs (para no abrir demasiados archivos)
function Update-AbrirState {
    $tooMany = $listBox.Items.Count -gt 10
    $chkAbrir.Visible = -not $tooMany
    $chkAbrir.Enabled = -not $tooMany
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

# Validacion de rango: digitos, comas, guiones y palabras clave de cpdf
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

# Helpers de tema
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

    $sunChar  = [char]0x25CB
    $moonChar = [char]0x25CF
    $btnTema.Text = if ($isDark) { "$sunChar Claro" } else { "$moonChar Oscuro" }

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

# Unicode helpers
$enye      = [char]0x00F1
$sunChar   = [char]0x25CB
$moonChar  = [char]0x25CF
$checkChar = [char]0x2713

# ---- Form ----
$form = New-Object System.Windows.Forms.Form
$form.Text            = "Eliminar p" + ([char]0x00E1) + "ginas de PDF"
$form.ClientSize      = New-Object System.Drawing.Size(560, 492)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
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
    $timerClose.Stop(); $timerClose.Dispose()
    foreach ($b in @($script:brText, $script:brSelText, $script:brRow1,
                     $script:brRow2, $script:brSelBg, $script:brAccent)) { $b.Dispose() }
    $script:sfVC.Dispose()
})

# ---- Fila superior: titulo + botones ----
# Layout top row (form w=560, margen=11):
#   lblTitulo  x=12  w=290  (termina en 302, gap de 6 antes de btnAgregar)
#   btnAgregar x=308 w=130  (termina en 438, gap de 6 antes de btnTema)
#   btnTema    x=448 w=100  (termina en 548)

$lblTitulo = New-Object System.Windows.Forms.Label
$lblTitulo.Location  = New-Object System.Drawing.Point(12, 12)
$lblTitulo.Size      = New-Object System.Drawing.Size(290, 16)
$lblTitulo.BackColor = $script:pal.Bg
$lblTitulo.ForeColor = $script:pal.Text

$btnTema = New-Object System.Windows.Forms.Button
$btnTema.Text     = if ($script:isDark) { "$sunChar Claro" } else { "$moonChar Oscuro" }
$btnTema.Location = New-Object System.Drawing.Point(448, 5)
$btnTema.Size     = New-Object System.Drawing.Size(100, 22)
$btnTema.Font     = New-Object System.Drawing.Font("Segoe UI", 9)
Set-BtnStyle $btnTema

$btnAgregar = New-Object System.Windows.Forms.Button
$btnAgregar.Text     = "+ A" + $enye + "adir PDF..."
$btnAgregar.Location = New-Object System.Drawing.Point(308, 5)
$btnAgregar.Size     = New-Object System.Drawing.Size(132, 22)
$btnAgregar.Font     = New-Object System.Drawing.Font("Segoe UI", 9)
Set-BtnStyle $btnAgregar

# ---- ListBox ----
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

$panelList = New-Object System.Windows.Forms.Panel
$panelList.Location  = New-Object System.Drawing.Point(11, 30)
$panelList.Size      = New-Object System.Drawing.Size(538, 158)
$panelList.BackColor = $script:pal.Border
$panelList.Padding   = New-Object System.Windows.Forms.Padding(1)
$panelList.Controls.Add($listBox)

# ---- Boton quitar de lista ----
$btnEliminar = New-Object System.Windows.Forms.Button
$btnEliminar.Text     = "Quitar de la lista  [Supr]"
$btnEliminar.Location = New-Object System.Drawing.Point(11, 196)
$btnEliminar.Size     = New-Object System.Drawing.Size(180, 26)
Set-BtnStyle $btnEliminar

# ---- Separador 1 ----
$sep1 = New-Object System.Windows.Forms.Label
$sep1.BackColor = $script:pal.Border
$sep1.Location  = New-Object System.Drawing.Point(11, 232)
$sep1.Size      = New-Object System.Drawing.Size(538, 1)

# ---- Fila Operacion ----
# Cada par de RadioButtons vive en su propio Panel para grupos de exclusion separados.

$lblOperacion = New-Object System.Windows.Forms.Label
$lblOperacion.Text      = "Operaci" + ([char]0x00F3) + "n:"
$lblOperacion.Location  = New-Object System.Drawing.Point(12, 244)
$lblOperacion.Size      = New-Object System.Drawing.Size(72, 18)
$lblOperacion.BackColor = $script:pal.Bg
$lblOperacion.ForeColor = $script:pal.Text

$pnlOperacion = New-Object System.Windows.Forms.Panel
$pnlOperacion.Location  = New-Object System.Drawing.Point(86, 240)
$pnlOperacion.Size      = New-Object System.Drawing.Size(462, 24)
$pnlOperacion.BackColor = $script:pal.Bg

$radEliminar = New-Object System.Windows.Forms.RadioButton
$radEliminar.Text      = "Eliminar estas p" + ([char]0x00E1) + "ginas"
$radEliminar.Checked   = $cfg.ModoEliminar
$radEliminar.Location  = New-Object System.Drawing.Point(0, 2)
$radEliminar.Size      = New-Object System.Drawing.Size(196, 20)
$radEliminar.BackColor = $script:pal.Bg
$radEliminar.ForeColor = $script:pal.Text

$radConservar = New-Object System.Windows.Forms.RadioButton
$radConservar.Text      = "Conservar estas p" + ([char]0x00E1) + "ginas"
$radConservar.Checked   = -not $cfg.ModoEliminar
$radConservar.Location  = New-Object System.Drawing.Point(202, 2)
$radConservar.Size      = New-Object System.Drawing.Size(220, 20)
$radConservar.BackColor = $script:pal.Bg
$radConservar.ForeColor = $script:pal.Text

$pnlOperacion.Controls.AddRange(@($radEliminar, $radConservar))

# ---- Fila Paginas: label + textbox con borde indicador + botones rapidos ----
# Layout (form w=560, margen=11):
#   x=12  w=62  "Paginas:"
#   x=78  w=240 [textbox con panel borde]
#   x=322 w=50  [Pag.1]
#   x=374 w=52  [Ultima]
#   x=428 w=54  [Pares]
#   x=484 w=64  [Impares]  -> borde derecho = 548

$lblPaginas = New-Object System.Windows.Forms.Label
$lblPaginas.Text      = "P" + ([char]0x00E1) + "ginas:"
$lblPaginas.Location  = New-Object System.Drawing.Point(12, 274)
$lblPaginas.Size      = New-Object System.Drawing.Size(62, 24)
$lblPaginas.BackColor = $script:pal.Bg
$lblPaginas.ForeColor = $script:pal.Text

$txtRange = New-Object System.Windows.Forms.TextBox
$txtRange.Location    = New-Object System.Drawing.Point(1, 1)
$txtRange.Size        = New-Object System.Drawing.Size(238, 22)
$txtRange.BackColor   = $script:pal.Input
$txtRange.ForeColor   = $script:pal.Text
$txtRange.BorderStyle = "None"
$txtRange.Font        = New-Object System.Drawing.Font("Segoe UI", 10)

$panelRange = New-Object System.Windows.Forms.Panel
$panelRange.Location  = New-Object System.Drawing.Point(78, 272)
$panelRange.Size      = New-Object System.Drawing.Size(240, 24)
$panelRange.BackColor = $script:pal.Border
$panelRange.Padding   = New-Object System.Windows.Forms.Padding(1)
$panelRange.Controls.Add($txtRange)

$btnQ1 = New-Object System.Windows.Forms.Button
$btnQ1.Text     = "P" + ([char]0x00E1) + "g. 1"
$btnQ1.Location = New-Object System.Drawing.Point(322, 270)
$btnQ1.Size     = New-Object System.Drawing.Size(50, 26)
$btnQ1.Font     = New-Object System.Drawing.Font("Segoe UI", 8)
Set-BtnStyle $btnQ1

$btnQLast = New-Object System.Windows.Forms.Button
$btnQLast.Text     = ([char]0x00DA) + "ltima"
$btnQLast.Location = New-Object System.Drawing.Point(374, 270)
$btnQLast.Size     = New-Object System.Drawing.Size(52, 26)
$btnQLast.Font     = New-Object System.Drawing.Font("Segoe UI", 8)
Set-BtnStyle $btnQLast

$btnQPar = New-Object System.Windows.Forms.Button
$btnQPar.Text     = "Pares"
$btnQPar.Location = New-Object System.Drawing.Point(428, 270)
$btnQPar.Size     = New-Object System.Drawing.Size(54, 26)
$btnQPar.Font     = New-Object System.Drawing.Font("Segoe UI", 8)
Set-BtnStyle $btnQPar

$btnQImp = New-Object System.Windows.Forms.Button
$btnQImp.Text     = "Impares"
$btnQImp.Location = New-Object System.Drawing.Point(484, 270)
$btnQImp.Size     = New-Object System.Drawing.Size(64, 26)
$btnQImp.Font     = New-Object System.Drawing.Font("Segoe UI", 8)
Set-BtnStyle $btnQImp

$lblHint = New-Object System.Windows.Forms.Label
$lblHint.Text      = "Ejemplos:  1,3,5-7     2-end     odd     even     1,3,5-end"
$lblHint.Location  = New-Object System.Drawing.Point(78, 300)
$lblHint.Size      = New-Object System.Drawing.Size(470, 14)
$lblHint.BackColor = $script:pal.Bg
$lblHint.ForeColor = $script:pal.TextDim
$lblHint.Font      = New-Object System.Drawing.Font("Segoe UI", 7.5)

# ---- Separador 2 ----
$sep2 = New-Object System.Windows.Forms.Label
$sep2.BackColor = $script:pal.Border
$sep2.Location  = New-Object System.Drawing.Point(11, 322)
$sep2.Size      = New-Object System.Drawing.Size(538, 1)

# ---- Fila Guardar ----
$lblGuardar = New-Object System.Windows.Forms.Label
$lblGuardar.Text      = "Guardar:"
$lblGuardar.Location  = New-Object System.Drawing.Point(12, 334)
$lblGuardar.Size      = New-Object System.Drawing.Size(62, 18)
$lblGuardar.BackColor = $script:pal.Bg
$lblGuardar.ForeColor = $script:pal.Text

$pnlGuardar = New-Object System.Windows.Forms.Panel
$pnlGuardar.Location  = New-Object System.Drawing.Point(78, 330)
$pnlGuardar.Size      = New-Object System.Drawing.Size(470, 24)
$pnlGuardar.BackColor = $script:pal.Bg

$radReemplazar = New-Object System.Windows.Forms.RadioButton
$radReemplazar.Text      = "Reemplazar original"
$radReemplazar.Checked   = -not $cfg.ModoNuevo
$radReemplazar.Location  = New-Object System.Drawing.Point(0, 2)
$radReemplazar.Size      = New-Object System.Drawing.Size(168, 20)
$radReemplazar.BackColor = $script:pal.Bg
$radReemplazar.ForeColor = $script:pal.Text

$radNuevo = New-Object System.Windows.Forms.RadioButton
$radNuevo.Text      = "Nuevo archivo  (_editado.pdf)"
$radNuevo.Checked   = $cfg.ModoNuevo
$radNuevo.Location  = New-Object System.Drawing.Point(172, 2)
$radNuevo.Size      = New-Object System.Drawing.Size(298, 20)
$radNuevo.BackColor = $script:pal.Bg
$radNuevo.ForeColor = $script:pal.Text

$pnlGuardar.Controls.AddRange(@($radReemplazar, $radNuevo))

# ---- Fila inferior: dos checkboxes (izq) + boton Procesar (der) ----
# pnlGuardar bottom = 330+24 = 354, gap de 8 hasta y=362
# Layout: chkAbrir x=12 w=175 | chkCerrar x=192 w=172 | btnProcesar x=368 w=180

$chkCerrar = New-Object System.Windows.Forms.CheckBox
$chkCerrar.Text      = "Cerrar ventana al terminar"
$chkCerrar.Checked   = $cfg.AutoCerrar
$chkCerrar.Location  = New-Object System.Drawing.Point(12, 364)
$chkCerrar.Size      = New-Object System.Drawing.Size(185, 20)
$chkCerrar.ForeColor = $script:pal.Text
$chkCerrar.BackColor = $script:pal.Bg

$chkAbrir = New-Object System.Windows.Forms.CheckBox
$chkAbrir.Text      = "Abrir al terminar"
$chkAbrir.Checked   = $cfg.AbrirAlTerminar
$chkAbrir.Location  = New-Object System.Drawing.Point(202, 364)
$chkAbrir.Size      = New-Object System.Drawing.Size(155, 20)
$chkAbrir.ForeColor = $script:pal.Text
$chkAbrir.BackColor = $script:pal.Bg

$btnProcesar = New-Object System.Windows.Forms.Button
$btnProcesar.Text      = "Procesar"
$btnProcesar.Location  = New-Object System.Drawing.Point(368, 358)
$btnProcesar.Size      = New-Object System.Drawing.Size(180, 32)
$btnProcesar.FlatStyle = "Flat"
$btnProcesar.BackColor = $script:pal.Accent
$btnProcesar.ForeColor = [System.Drawing.Color]::White
$btnProcesar.FlatAppearance.BorderSize         = 0
$btnProcesar.FlatAppearance.MouseOverBackColor = $script:pal.AccHover
$btnProcesar.FlatAppearance.MouseDownBackColor = $script:pal.AccPress
$form.AcceptButton = $btnProcesar

# btnProcesar bottom = 358+32 = 390
# ---- Resultado: status + lista de omitidos (scrollable) ----
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location  = New-Object System.Drawing.Point(12, 396)
$lblStatus.Size      = New-Object System.Drawing.Size(536, 18)
$lblStatus.BackColor = $script:pal.Bg
$lblStatus.ForeColor = $script:pal.TextDim
$lblStatus.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$lblStatus.Text      = ""

# Panel con borde de 1px que envuelve el RichTextBox de omitidos
# Visible solo cuando hay archivos omitidos
$panelSkipped = New-Object System.Windows.Forms.Panel
$panelSkipped.Location  = New-Object System.Drawing.Point(12, 418)
$panelSkipped.Size      = New-Object System.Drawing.Size(536, 52)
$panelSkipped.BackColor = $script:pal.Border
$panelSkipped.Padding   = New-Object System.Windows.Forms.Padding(1)
$panelSkipped.Visible   = $false

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

# Timer autocerrar
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

# Lista de botones temables
$script:themedButtons = @($btnAgregar, $btnTema, $btnEliminar,
                          $btnQ1, $btnQLast, $btnQPar, $btnQImp)

# ---- Owner draw del ListBox ----
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

# ---- Tooltips ----
$tip = New-Object System.Windows.Forms.ToolTip
$tip.AutoPopDelay = 6000; $tip.InitialDelay = 600; $tip.ReshowDelay = 300
$tip.SetToolTip($listBox,      "Lista de PDFs a procesar. Selecciona uno y pulsa [Supr] o el boton para quitarlo de la lista")
$tip.SetToolTip($btnEliminar,  "Quitar el PDF seleccionado de la lista (no borra el archivo del disco)")
$tip.SetToolTip($btnAgregar,   "Agregar mas PDFs mediante dialogo de seleccion")
$tip.SetToolTip($radEliminar,  "Las paginas indicadas seran eliminadas del PDF")
$tip.SetToolTip($radConservar, "Solo las paginas indicadas se conservaran; el resto se elimina")
$tip.SetToolTip($txtRange,     "Rango de paginas. Ejemplos: 1,3,5-7 | 2-end | odd | even")
$tip.SetToolTip($btnQ1,        "Agregar pagina 1 al rango (portadas)")
$tip.SetToolTip($btnQLast,     "Agregar ultima pagina al rango (usar 'end')")
$tip.SetToolTip($btnQPar,      "Agregar 'even' al rango (paginas pares)")
$tip.SetToolTip($btnQImp,      "Agregar 'odd' al rango (paginas impares)")
$tip.SetToolTip($radReemplazar,"Sobreescribe el PDF original con el resultado")
$tip.SetToolTip($radNuevo,     "Crea un archivo nuevo con sufijo _editado.pdf en la misma carpeta")
$tip.SetToolTip($chkCerrar,    "Cerrar la ventana automaticamente 5 segundos despues de completar sin errores")
$tip.SetToolTip($btnProcesar,  "Aplicar la operacion a todos los PDFs de la lista")

# ---- Poblar lista ----
foreach ($f in $files) {
    [void]$listBox.Items.Add((Get-DisplayName $f.FullName))
    [void]$script:rutas.Add($f.FullName)
}
$listBox.SelectedIndex = 0
Update-TitleLabel
Update-AbrirState   # deshabilitar chkAbrir si hay mas de 10 PDFs de entrada
$lblFolder.Text = "Carpeta: " + $files[0].DirectoryName

# ---- Eventos ----
$btnTema.Add_Click({ Apply-Theme (-not $script:isDark) })

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

# Drag & drop: agregar archivos externos desde el Explorador
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

# ---- Procesar ----
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
            "No se encontro cpdf.exe.`nEjecuta setup.bat primero.",
            "Error", [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }

    $modoEliminar = $radEliminar.Checked
    $modoNuevo    = $radNuevo.Checked
    $accion       = if ($modoEliminar) { "eliminar" } else { "conservar" }

    $resp = [System.Windows.Forms.MessageBox]::Show(
        "Se va a $accion las p" + [char]0x00E1 + "ginas [$range] en $($script:rutas.Count) PDF(s).`n" +
        $(if ($modoNuevo) { "Se generaran archivos nuevos con sufijo _editado." } else { "Se sobreescribiran los originales." }) +
        "`n`n" + [char]0x00BF + "Continuar?",
        "Confirmar",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Question)
    if ($resp -ne [System.Windows.Forms.DialogResult]::Yes) { return }

    $btnProcesar.Enabled  = $false
    $lblStatus.ForeColor  = $script:pal.TextDim
    $lblStatus.Text       = "Procesando..."
    $panelSkipped.Visible = $false
    $rtbSkipped.Clear()
    $form.Refresh()

    # logLines: "[Omitido]  nombre - motivo"  o  "[Error]  nombre - motivo"
    $logLines     = [System.Collections.ArrayList]@()
    $outputFiles  = [System.Collections.ArrayList]@()   # archivos generados, para abrir al terminar
    $errCount     = 0
    $processed    = 0

    # NOTA: no usar 'continue' dentro de foreach en un scriptblock de evento:
    # en PowerShell actua como 'break' y aborta el loop. Usar if/else.
    foreach ($ruta in $script:rutas) {
        $nombre = [System.IO.Path]::GetFileName($ruta)
        $nPags  = if ($script:pagCount.ContainsKey($ruta)) { [int]$script:pagCount[$ruta] } else { 0 }

        if ($modoEliminar -and $nPags -eq 1) {
            # PDF de 1 pagina: no hay nada que eliminar
            [void]$logLines.Add("OMIT: $nombre  - 1 pag., nada que eliminar")
        } else {
            $uid = [System.IO.Path]::GetRandomFileName() -replace '\.', ''
            $tmp = [System.IO.Path]::Combine(
                [System.IO.Path]::GetDirectoryName($ruta),
                "_eptmp_$uid.pdf")

            # cpdf no tiene -remove-pages. Para "eliminar" calculamos el complemento
            # (paginas a conservar) con Get-KeepRange y lo pasamos como seleccion directa.
            # Para "conservar" se pasa el rango tal cual.
            $cpdfRange = if ($modoEliminar) { Get-KeepRange $range $nPags } else { $range }

            if ($modoEliminar -and $null -eq $cpdfRange) {
                # Rango cubre todas las paginas, o no se pudo leer el total
                if ($nPags -gt 0) {
                    [void]$logLines.Add("OMIT: $nombre  - el rango eliminar" + [char]0x00ED + "a todas las p" + [char]0x00E1 + "gs.")
                } else {
                    $errCount++
                    [void]$logLines.Add("ERR:  $nombre  - no se pudo leer el n" + [char]0x00FA + "mero de p" + [char]0x00E1 + "ginas")
                }
            } else {
                try {
                    $cpdfOut = & $cpdfExe $ruta $cpdfRange -o $tmp 2>&1

                    if (-not (Test-Path $tmp)) {
                        $errMsg = if ($cpdfOut) { ($cpdfOut -join ' ').Trim() } `
                                  else          { "cpdf no gener" + [char]0x00F3 + " archivo de salida" }
                        throw $errMsg
                    }

                    # Verificar que el resultado tiene al menos 1 pagina
                    $resultPags = 0
                    $raw = & $cpdfExe -pages $tmp 2>$null
                    [int]::TryParse(($raw -join '').Trim(), [ref]$resultPags) | Out-Null

                    if ($resultPags -eq 0) {
                        Remove-Item $tmp -Force -ErrorAction SilentlyContinue
                        [void]$logLines.Add("OMIT: $nombre  - resultado sin p" + [char]0x00E1 + "ginas")
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
            "$checkChar $processed procesados,  $skipCount omitido(s)."
        } else {
            "$checkChar $processed PDF(s) procesados correctamente."
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
        $lblStatus.Text      = "$checkChar $processed procesados / $errCount no se procesaron. Ver detalles."
        $btnProcesar.Enabled = $true
    } elseif ($processed -eq 0 -and $errCount -gt 0) {
        # Todo fallo
        $lblStatus.ForeColor = $colorErr
        $lblStatus.Text      = "No se procesaron los archivos. Ver detalles."
        $btnProcesar.Enabled = $true
    } else {
        # processed=0, errCount=0: todos omitidos
        $lblStatus.ForeColor = $colorWarn
        $lblStatus.Text      = "Ning" + [char]0x00FA + "n PDF fue modificado (todos omitidos)."
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
