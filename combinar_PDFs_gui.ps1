Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

try {
    Add-Type -TypeDefinition '
using System;
using System.Runtime.InteropServices;
public class DwmApi {
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

# Config persistente
$configPath = [System.IO.Path]::Combine($PSScriptRoot, "combinar_PDFs_config.json")

function Load-Config {
    if (Test-Path $configPath) {
        try {
            $j = Get-Content $configPath -Raw -Encoding UTF8 | ConvertFrom-Json
            return @{
                AbrirAlTerminar  = [bool]$j.AbrirAlTerminar
                TemaOscuro       = [bool]$j.TemaOscuro
                CerrarAlTerminar = if ($null -eq $j.CerrarAlTerminar) { $true  } else { [bool]$j.CerrarAlTerminar }
                GenerarIndice    = if ($null -eq $j.GenerarIndice)    { $false } else { [bool]$j.GenerarIndice    }
                WindowWidth      = if ($null -eq $j.WindowWidth)      { 560 } else { [int]$j.WindowWidth }
                WindowHeight     = if ($null -eq $j.WindowHeight)     { 420 } else { [int]$j.WindowHeight }
            }
        } catch {}
    }
    return @{ AbrirAlTerminar = $true; TemaOscuro = $true; CerrarAlTerminar = $true; GenerarIndice = $false; WindowWidth = 560; WindowHeight = 420 }
}

function Save-Config {
    try {
        [ordered]@{
            AbrirAlTerminar  = $chkAbrir.Checked
            TemaOscuro       = $script:isDark
            CerrarAlTerminar = $chkCerrar.Checked
            GenerarIndice    = $chkToc.Checked
        } | ConvertTo-Json | Set-Content $configPath -Encoding UTF8
    } catch {}
}

$cfg = Load-Config
$script:isDark = $cfg.TemaOscuro

# Paletas de color
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
    }
}

$script:pal = if ($script:isDark) { $palettes.dark } else { $palettes.light }

# Estado
$script:rutas         = [System.Collections.ArrayList]@()
$script:pagCount      = @{}
$script:dragFromIndex = -1
$script:dragStartPos  = $null
$script:countdown     = 0
$script:outputDir     = $files[0].DirectoryName

# Brushes para owner draw (se recrean al cambiar tema)
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

# Consultar paginas con cpdf
$cpdfExe = [System.IO.Path]::Combine($PSScriptRoot, "dependencias", "cpdf.exe")
if (Test-Path $cpdfExe) {
    foreach ($f in $files) {
        try {
            $raw = & $cpdfExe -pages $f.FullName 2>$null
            $n   = 0
            if ([int]::TryParse(($raw -join '').Trim(), [ref]$n)) {
                $script:pagCount[$f.FullName] = $n
            }
        } catch {}
    }
}

# Helpers de lista (logica sin cambios)
function Get-DisplayName($ruta) {
    $nombre = [System.IO.Path]::GetFileName($ruta)
    $n = $script:pagCount[$ruta]
    if ($n -gt 0) { return "$nombre  ($n pags.)" }
    return $nombre
}
function Swap-Item($i, $j) {
    $d = $listBox.Items[$i];  $listBox.Items.RemoveAt($i);  $listBox.Items.Insert($j, $d)
    $r = $script:rutas[$i];   $script:rutas.RemoveAt($i);   $script:rutas.Insert($j, $r)
}
function Reorder-ListItem($from, $to) {
    if ($from -eq $to) { return }
    $d = $listBox.Items[$from];  $listBox.Items.RemoveAt($from)
    $r = $script:rutas[$from];   $script:rutas.RemoveAt($from)
    $at = if ($to -gt $from) { $to - 1 } else { $to }
    $listBox.Items.Insert($at, $d);  $script:rutas.Insert($at, $r)
}
function Refresh-Folder { $lblFolder.Text = $script:langDict.L_GUI_LBL_DEST + " " + $script:outputDir }
function Remove-Selected {
    $i = $listBox.SelectedIndex
    if ($i -lt 0 -or $listBox.Items.Count -le 1) { return }
    $listBox.Items.RemoveAt($i);  $script:rutas.RemoveAt($i)
    $listBox.SelectedIndex = [Math]::Min($i, $listBox.Items.Count - 1)
    Update-TitleLabel;  Refresh-Folder
}
function Sort-Lista($modo) {
    $pares = 0..($listBox.Items.Count - 1) | ForEach-Object {
        $r = $script:rutas[$_];  $fi = Get-Item $r
        [PSCustomObject]@{ Ruta=$r; Nombre=$fi.Name; Fecha=$fi.LastWriteTime; Tamano=$fi.Length }
    }
    $ordenados = switch ($modo) {
        'nombre' { $pares | Sort-Object Nombre }
        'fecha'  { $pares | Sort-Object Fecha  }
        'tamano' { $pares | Sort-Object Tamano }
    }
    $listBox.Items.Clear();  $script:rutas.Clear()
    foreach ($p in $ordenados) {
        [void]$listBox.Items.Add((Get-DisplayName $p.Ruta));  [void]$script:rutas.Add($p.Ruta)
    }
    $listBox.SelectedIndex = 0;  Refresh-Folder
}
function Invertir-Lista {
    $copia = [System.Collections.ArrayList]@($script:rutas);  $copia.Reverse()
    $listBox.Items.Clear();  $script:rutas.Clear()
    foreach ($r in $copia) {
        [void]$listBox.Items.Add((Get-DisplayName $r));  [void]$script:rutas.Add($r)
    }
    $listBox.SelectedIndex = 0;  Refresh-Folder
}
function Update-TitleLabel {
    $n = $listBox.Items.Count
    $up = [char]0x2191;  $dn = [char]0x2193
    $lblTitulo.Text = "$n $($script:langDict.L_GUI_LBL_TITLE_1) $up $dn $($script:langDict.L_GUI_LBL_TITLE_2)"
}
function Add-Files($paths) {
    $added = 0
    foreach ($path in $paths) {
        $path = [string]$path
        if ($path -match '\.pdf$' -and (Test-Path $path -PathType Leaf) -and ($script:rutas -notcontains $path)) {
            if (Test-Path $cpdfExe) {
                try {
                    $raw = & $cpdfExe -pages $path 2>$null
                    $n = 0
                    if ([int]::TryParse(($raw -join '').Trim(), [ref]$n)) { $script:pagCount[$path] = $n }
                } catch {}
            }
            [void]$listBox.Items.Add((Get-DisplayName $path))
            [void]$script:rutas.Add($path)
            $added++
        }
    }
    if ($added -gt 0) { Update-TitleLabel; Refresh-Folder }
}

# Generacion de indice TOC
function EscPS([string]$str) {
    $sb = [System.Text.StringBuilder]::new()
    foreach ($c in $str.ToCharArray()) {
        $code = [int][char]$c
        if    ($c -eq '\')                       { [void]$sb.Append('\\') }
        elseif($c -eq '(')                       { [void]$sb.Append('\(') }
        elseif($c -eq ')')                       { [void]$sb.Append('\)') }
        elseif($code -ge 32  -and $code -le 126) { [void]$sb.Append($c)  }
        elseif($code -ge 128 -and $code -le 255) { [void]$sb.Append('\' + [Convert]::ToString($code,8).PadLeft(3,'0')) }
    }
    return $sb.ToString()
}

function Build-TocPS($entries, $docTitle) {
    $ml = 56; $mr = 556   # Carta: 612 pts ancho, margenes simetricos de 56 pts
    $maxLines   = 33
    $totalCount = $entries.Count
    $arr   = @($entries)
    $shown = if ($totalCount -gt $maxLines) { $arr[0..($maxLines - 1)] } else { $arr }

    $titleE  = EscPS $docTitle
    $dateE   = EscPS (Get-Date -Format 'dd/MM/yyyy HH:mm')
    $footerE = EscPS (([char]0x00CD) + 'ndice de documentos combinados')

    $L = [System.Collections.Generic.List[string]]::new()
    $L.Add('%!PS-Adobe-3.0')
    $L.Add('%%Pages: 1')
    $L.Add('%%EndComments')
    $L.Add('%%Page: 1 1')
    # Declarar tamano A4 (595x842 pts) explicitamente; sin esto GS usa Letter y Y=806 queda fuera de pagina
    $L.Add('<< /PageSize [612 792] /ImagingBBox null >> setpagedevice')
    # Definiciones dentro de la pagina para evitar problemas de scope prolog/pagina
    $L.Add('/ReencodeISO {')
    $L.Add('  exch findfont dup length dict begin')
    $L.Add('    { 1 index /FID ne { def } { pop pop } ifelse } forall')
    $L.Add('    /Encoding ISOLatin1Encoding def currentdict end definefont pop')
    $L.Add('} def')
    $L.Add('/Helvetica /Helvetica-L1 ReencodeISO')
    $L.Add('/Helvetica-Bold /HelveticaBold-L1 ReencodeISO')
    $L.Add('/TF /HelveticaBold-L1 findfont 15   scalefont def')
    $L.Add('/BF /Helvetica-L1     findfont  9.5 scalefont def')
    $L.Add('/SF /Helvetica-L1     findfont  7.5 scalefont def')
    # Cabecera visual  (coordenadas Y para Carta: 792 pts, margen sup ~26 pts)
    $L.Add("TF setfont $ml 766 moveto ($titleE) show")
    $L.Add("SF setfont 0.45 setgray $ml 752 moveto (Generado: $dateE) show 0 setgray")
    $L.Add("0.65 setgray 0.4 setlinewidth $ml 746 moveto $mr 746 lineto stroke 0 setgray")
    $L.Add("SF setfont 0.45 setgray $ml 737 moveto (Archivo) show")
    $L.Add("(Pag.) dup stringwidth pop $mr exch sub 737 moveto show 0 setgray")
    $L.Add("0.65 setgray 0.3 setlinewidth $ml 732 moveto $mr 732 lineto stroke 0 setgray")

    $y = 719; $lineH = 18
    $bookmarks = [System.Collections.Generic.List[string]]::new()

    foreach ($e in $shown) {
        $raw   = if ($e.Name.Length -gt 65) { $e.Name.Substring(0, 62) + '...' } else { $e.Name }
        $nameE = EscPS $raw
        $pgE   = EscPS "pag. $($e.StartPage)"
        $sepY  = $y - 6
        $lly   = $y - 3
        $ury   = $y + 13

        # Contenido visual
        $L.Add("BF setfont $ml $y moveto ($nameE) show")
        $L.Add("($pgE) dup stringwidth pop $mr exch sub $y moveto show")
        $L.Add("0.87 setgray 0.25 setlinewidth $ml $sepY moveto $mr $sepY lineto stroke 0 setgray")

        # Hipervínculo: anota el area del texto para que sea clickeable
        $L.Add("[ /Rect [$ml $lly $mr $ury] /Page $($e.StartPage) /View [/XYZ null null null] /Subtype /Link /ANN pdfmark")

        # Bookmark para panel de navegacion
        $bookmarks.Add("[ /Title ($nameE) /Page $($e.StartPage) /View [/FIT] /OUT pdfmark")

        $y -= $lineH
    }
    if ($totalCount -gt $maxLines) {
        $moreE = EscPS "... y $($totalCount - $maxLines) archivo(s) mas"
        $L.Add("SF setfont 0.5 setgray $ml $y moveto ($moreE) show 0 setgray")
    }

    # Bookmarks (pdfmarks de nivel documento, se añaden antes de showpage)
    foreach ($bkm in $bookmarks) { $L.Add($bkm) }

    # Pie de pagina
    $L.Add("SF setfont 0.5 setgray $ml 30 moveto ($footerE) show 0 setgray")
    $L.Add('showpage')
    $L.Add('%%EOF')

    return $L -join "`r`n"
}

function Add-TocAndBookmarks($combinedPdf, $outputPdf) {
    $gsExe = 'gswin64c.exe'
    if (-not (Get-Command $gsExe -ErrorAction SilentlyContinue)) {
        [System.Windows.Forms.MessageBox]::Show(
            $script:langDict.L_GUI_ERR_GS,
            "Error", [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return $false
    }

    # Calcular pagina de inicio de cada archivo
    # (pagina 1 = indice TOC, contenido empieza en pagina 2)
    $pageOffset = 2
    $entries = [System.Collections.ArrayList]@()
    foreach ($r in $script:rutas) {
        $n = if ($script:pagCount.ContainsKey($r)) { [int]$script:pagCount[$r] } else { 1 }
        [void]$entries.Add([PSCustomObject]@{
            Name      = [System.IO.Path]::GetFileName($r)
            StartPage = $pageOffset
        })
        $pageOffset += $n
    }

    $docTitle = [System.IO.Path]::GetFileNameWithoutExtension($outputPdf)
    if ([string]::IsNullOrWhiteSpace($docTitle)) { $docTitle = 'Documentos combinados' }
    $uid      = [System.IO.Path]::GetRandomFileName() -replace '\.', ''
    $tocPs    = [System.IO.Path]::Combine($script:outputDir, "_toctmp_$uid.ps")

    try {
        # Generar PostScript con hipervinculos y bookmarks vía pdfmark
        $psContent = Build-TocPS $entries $docTitle
        [System.IO.File]::WriteAllText($tocPs, $psContent, [System.Text.Encoding]::ASCII)

        # Un solo run de GS: procesa toc.ps (pag.1 con pdfmarks) + combined.pdf (resto)
        # Los /Page N en pdfmarks referencian el documento final completo directamente
        if (Test-Path $outputPdf) { Remove-Item $outputPdf -Force }
        $gsOut = & $gsExe -sDEVICE=pdfwrite -dNOPAUSE -dBATCH `
                          "-sOutputFile=$outputPdf" $tocPs $combinedPdf 2>&1

        if (-not (Test-Path $outputPdf)) {
            [System.Windows.Forms.MessageBox]::Show(
                $script:langDict.L_GUI_ERR_GS_FAIL + "`n`n$($gsOut -join "`n")",
                "Error GS", [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning)
            return $false
        }
        return $true

    } catch {
        [System.Windows.Forms.MessageBox]::Show(
            $script:langDict.L_GUI_ERR_INDEX + " $_", "Error",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Warning)
        return $false
    } finally {
        if (Test-Path $tocPs) { Remove-Item $tocPs -Force -ErrorAction SilentlyContinue }
    }
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

    $form.BackColor     = $script:pal.Bg
    $panelList.BackColor = $script:pal.Border
    $listBox.BackColor  = $script:pal.Surface
    $sep.BackColor      = $script:pal.Border
    $txtOut.BackColor   = $script:pal.Input
    $txtOut.ForeColor   = $script:pal.Text

    foreach ($lbl in @($lblTitulo, $lblOut, $lblFolder)) {
        $lbl.BackColor = $script:pal.Bg;  $lbl.ForeColor = $script:pal.Text
    }
    $lblFolder.ForeColor = $script:pal.TextDim
    $lblStatus.BackColor = $script:pal.Bg
    $chkAbrir.BackColor  = $script:pal.Bg
    $chkAbrir.ForeColor  = $script:pal.Text
    $chkCerrar.BackColor = $script:pal.Bg
    $chkCerrar.ForeColor = $script:pal.Text
    $chkToc.BackColor    = $script:pal.Bg
    $chkToc.ForeColor    = $script:pal.Text

    foreach ($btn in $script:themedButtons) { Set-BtnStyle $btn }

    $btnTema.Text = if ($isDark) { "$sunChar $($script:langDict.L_GUI_BTN_LIGHT)" } else { "$moonChar $($script:langDict.L_GUI_BTN_DARK)" }

    try {
        $dv = if ($isDark) { 1 } else { 0 }
        [void][DwmApi]::DwmSetWindowAttribute($form.Handle, 20, [ref]$dv, 4)
        [void][DwmApi]::DwmSetWindowAttribute($form.Handle, 19, [ref]$dv, 4)
    } catch {}

    $listBox.Invalidate()
    $form.Refresh()
    Save-Config
}

# Unicode via escape
$arrowUp    = [char]0x2191
$arrowDown  = [char]0x2193
$enye       = [char]0x00F1
$sunChar    = [char]0x25CB
$moonChar   = [char]0x25CF
$checkChar  = [char]0x2713

# Form
$form = New-Object System.Windows.Forms.Form
$form.Text            = $script:langDict.L_GUI_TITLE_MERGE
$form.ClientSize      = New-Object System.Drawing.Size(560, 420)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "Sizable"
$form.MinimumSize     = New-Object System.Drawing.Size(560, 420)
$form.MaximizeBox     = $false
$form.BackColor       = $script:pal.Bg
$form.ForeColor       = $script:pal.Text
$form.Font            = New-Object System.Drawing.Font("Segoe UI", 9)

$form.Add_HandleCreated({
    param($s, $e)
    try {
        $dv = if ($script:isDark) { 1 } else { 0 }
        [void][DwmApi]::DwmSetWindowAttribute($s.Handle, 20, [ref]$dv, 4)
        [void][DwmApi]::DwmSetWindowAttribute($s.Handle, 19, [ref]$dv, 4)
    } catch {}
})

$form.Add_FormClosed({
    Save-Config
    $timerClose.Stop()
    $timerClose.Dispose()
    foreach ($b in @($script:brText, $script:brSelText, $script:brRow1,
                     $script:brRow2, $script:brSelBg, $script:brAccent)) { $b.Dispose() }
    $script:sfVC.Dispose()
})

# Titulo
$n = $files.Count;  $sufijo = if ($n -ne 1) { 's' } else { '' }

$lblTitulo = New-Object System.Windows.Forms.Label
$lblTitulo.Text      = "$n $($script:langDict.L_GUI_LBL_TITLE_1) $arrowUp $arrowDown $($script:langDict.L_GUI_LBL_TITLE_2)"
$lblTitulo.Location  = New-Object System.Drawing.Point(12, 10)
$lblTitulo.Size      = New-Object System.Drawing.Size(300, 16)
$lblTitulo.BackColor = $script:pal.Bg
$lblTitulo.ForeColor = $script:pal.Text

# Boton agregar PDF (top-right, antes del tema)
$btnAgregar = New-Object System.Windows.Forms.Button
$btnAgregar.Text     = $script:langDict.L_GUI_BTN_ADD
$btnAgregar.Location = New-Object System.Drawing.Point(318, 5)
$btnAgregar.Size     = New-Object System.Drawing.Size(122, 22)
$btnAgregar.Font     = New-Object System.Drawing.Font("Segoe UI", 9)
$btnAgregar.Anchor   = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
Set-BtnStyle $btnAgregar

# Boton tema (top-right)
$btnTema = New-Object System.Windows.Forms.Button
$btnTema.Text     = if ($script:isDark) { "$sunChar $($script:langDict.L_GUI_BTN_LIGHT)" } else { "$moonChar $($script:langDict.L_GUI_BTN_DARK)" }
$btnTema.Location = New-Object System.Drawing.Point(448, 5)
$btnTema.Size     = New-Object System.Drawing.Size(100, 22)
$btnTema.Font     = New-Object System.Drawing.Font("Segoe UI", 9)
$btnTema.Anchor   = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
Set-BtnStyle $btnTema

# ListBox + panel borde
$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Font           = New-Object System.Drawing.Font("Segoe UI", 10)
$listBox.IntegralHeight = $false
$listBox.AllowDrop      = $true
$listBox.BackColor      = $script:pal.Surface
$listBox.ForeColor      = $script:pal.Text
$listBox.BorderStyle    = "None"
$listBox.DrawMode       = [System.Windows.Forms.DrawMode]::OwnerDrawFixed
$listBox.ItemHeight     = 30
$listBox.Location       = New-Object System.Drawing.Point(1, 1)
$listBox.Size           = New-Object System.Drawing.Size(468, 200)
$listBox.Anchor         = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

$panelList = New-Object System.Windows.Forms.Panel
$panelList.Location  = New-Object System.Drawing.Point(11, 29)
$panelList.Size      = New-Object System.Drawing.Size(470, 202)
$panelList.BackColor = $script:pal.Border
$panelList.Padding   = New-Object System.Windows.Forms.Padding(1)
$panelList.Anchor    = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$panelList.Controls.Add($listBox)

# Botones Up / Down
$btnUp = New-Object System.Windows.Forms.Button
$btnUp.Text     = $arrowUp
$btnUp.Location = New-Object System.Drawing.Point(490, 30)
$btnUp.Size     = New-Object System.Drawing.Size(58, 38)
$btnUp.Font     = New-Object System.Drawing.Font("Segoe UI", 14)
$btnUp.Anchor   = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
Set-BtnStyle $btnUp

$btnDown = New-Object System.Windows.Forms.Button
$btnDown.Text     = $arrowDown
$btnDown.Location = New-Object System.Drawing.Point(490, 74)
$btnDown.Size     = New-Object System.Drawing.Size(58, 38)
$btnDown.Font     = New-Object System.Drawing.Font("Segoe UI", 14)
$btnDown.Anchor   = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
Set-BtnStyle $btnDown

# Botones ordenar / gestionar
$btnNombre = New-Object System.Windows.Forms.Button
$btnNombre.Text     = $script:langDict.L_GUI_BTN_NAME
$btnNombre.Location = New-Object System.Drawing.Point(12, 244)
$btnNombre.Size     = New-Object System.Drawing.Size(80, 28)
$btnNombre.Anchor   = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
Set-BtnStyle $btnNombre

$btnFecha = New-Object System.Windows.Forms.Button
$btnFecha.Text     = $script:langDict.L_GUI_BTN_DATE
$btnFecha.Location = New-Object System.Drawing.Point(98, 244)
$btnFecha.Size     = New-Object System.Drawing.Size(80, 28)
$btnFecha.Anchor   = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
Set-BtnStyle $btnFecha

$btnTamano = New-Object System.Windows.Forms.Button
$btnTamano.Text     = $script:langDict.L_GUI_BTN_SIZE
$btnTamano.Location = New-Object System.Drawing.Point(184, 244)
$btnTamano.Size     = New-Object System.Drawing.Size(80, 28)
$btnTamano.Anchor   = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
Set-BtnStyle $btnTamano

$btnInvertir = New-Object System.Windows.Forms.Button
$btnInvertir.Text     = $script:langDict.L_GUI_BTN_INVERT
$btnInvertir.Location = New-Object System.Drawing.Point(270, 244)
$btnInvertir.Size     = New-Object System.Drawing.Size(76, 28)
$btnInvertir.Anchor   = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
Set-BtnStyle $btnInvertir

$btnEliminar = New-Object System.Windows.Forms.Button
$btnEliminar.Text     = $script:langDict.L_GUI_BTN_DEL
$btnEliminar.Location = New-Object System.Drawing.Point(364, 244)
$btnEliminar.Size     = New-Object System.Drawing.Size(184, 28)
$btnEliminar.Anchor   = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left
Set-BtnStyle $btnEliminar

# Lista de botones que Apply-Theme debe actualizar (excluye Combinar)
$script:themedButtons = @($btnAgregar, $btnTema, $btnUp, $btnDown, $btnNombre, $btnFecha,
                          $btnTamano, $btnInvertir, $btnEliminar)

# Separador
$sep = New-Object System.Windows.Forms.Label
$sep.BackColor   = $script:pal.Border
$sep.BorderStyle = "None"
$sep.Location    = New-Object System.Drawing.Point(12, 286)
$sep.Size        = New-Object System.Drawing.Size(536, 1)
$sep.Anchor      = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

# Nombre de salida
$lblOut = New-Object System.Windows.Forms.Label
$lblOut.Text      = $script:langDict.L_GUI_LBL_OUT
$lblOut.Location  = New-Object System.Drawing.Point(12, 296)
$lblOut.Size      = New-Object System.Drawing.Size(210, 16)
$lblOut.BackColor = $script:pal.Bg
$lblOut.ForeColor = $script:pal.Text
$lblOut.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left

$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Text        = "combinado.pdf"
$txtOut.Location    = New-Object System.Drawing.Point(12, 315)
$txtOut.Size        = New-Object System.Drawing.Size(348, 24)
$txtOut.BackColor   = $script:pal.Input
$txtOut.ForeColor   = $script:pal.Text
$txtOut.BorderStyle = "FixedSingle"
$txtOut.Anchor      = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

# Checkboxes (estado desde config)
$chkAbrir = New-Object System.Windows.Forms.CheckBox
$chkAbrir.Text      = $script:langDict.L_GUI_CHK_OPEN
$chkAbrir.Checked   = $cfg.AbrirAlTerminar
$chkAbrir.Location  = New-Object System.Drawing.Point(12, 346)
$chkAbrir.Size      = New-Object System.Drawing.Size(180, 20)
$chkAbrir.ForeColor = $script:pal.Text
$chkAbrir.BackColor = $script:pal.Bg
$chkAbrir.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left

$chkCerrar = New-Object System.Windows.Forms.CheckBox
$chkCerrar.Text      = $script:langDict.L_GUI_CHK_CLOSE
$chkCerrar.Checked   = $cfg.CerrarAlTerminar
$chkCerrar.Location  = New-Object System.Drawing.Point(200, 346)
$chkCerrar.Size      = New-Object System.Drawing.Size(210, 20)
$chkCerrar.ForeColor = $script:pal.Text
$chkCerrar.BackColor = $script:pal.Bg
$chkCerrar.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left

$chkToc = New-Object System.Windows.Forms.CheckBox
$chkToc.Text      = $script:langDict.L_GUI_CHK_TOC
$chkToc.Checked   = $cfg.GenerarIndice
$chkToc.Location  = New-Object System.Drawing.Point(416, 346)
$chkToc.Size      = New-Object System.Drawing.Size(132, 20)
$chkToc.ForeColor = $script:pal.Text
$chkToc.BackColor = $script:pal.Bg
$chkToc.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left

# Boton Combinar
$btnCombinar = New-Object System.Windows.Forms.Button
$btnCombinar.Text      = $script:langDict.L_GUI_BTN_MERGE
$btnCombinar.Location  = New-Object System.Drawing.Point(368, 311)
$btnCombinar.Size      = New-Object System.Drawing.Size(180, 32)
$btnCombinar.FlatStyle = "Flat"
$btnCombinar.BackColor = $script:pal.Accent
$btnCombinar.ForeColor = [System.Drawing.Color]::White
$btnCombinar.FlatAppearance.BorderSize         = 0
$btnCombinar.FlatAppearance.MouseOverBackColor = $script:pal.AccHover
$btnCombinar.FlatAppearance.MouseDownBackColor = $script:pal.AccPress
$btnCombinar.Anchor                        = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Right
$form.AcceptButton = $btnCombinar

# Etiqueta destino
$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Location  = New-Object System.Drawing.Point(12, 392)
$lblFolder.Size      = New-Object System.Drawing.Size(536, 14)
$lblFolder.BackColor = $script:pal.Bg
$lblFolder.ForeColor = $script:pal.TextDim
$lblFolder.Font      = New-Object System.Drawing.Font("Segoe UI", 7.5)
$lblFolder.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

# Label de estado (resultado de la operacion)
$lblStatus = New-Object System.Windows.Forms.Label
$lblStatus.Location  = New-Object System.Drawing.Point(12, 370)
$lblStatus.Size      = New-Object System.Drawing.Size(536, 16)
$lblStatus.BackColor = $script:pal.Bg
$lblStatus.ForeColor = $script:pal.TextDim
$lblStatus.Font      = New-Object System.Drawing.Font("Segoe UI", 9)
$lblStatus.Text      = ""
$lblStatus.Anchor    = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right

# Timer para autocerrar tras combinar
$timerClose          = New-Object System.Windows.Forms.Timer
$timerClose.Interval = 1000

# Owner draw del ListBox
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

# Tooltips
$tip = New-Object System.Windows.Forms.ToolTip
$tip.AutoPopDelay = 6000;  $tip.InitialDelay = 600;  $tip.ReshowDelay = 300

$tip.SetToolTip($listBox,     $script:langDict.L_GUI_TIP_LIST)
$tip.SetToolTip($btnAgregar,  $script:langDict.L_GUI_TIP_ADD)
$tip.SetToolTip($btnUp,       $script:langDict.L_GUI_TIP_UP)
$tip.SetToolTip($btnDown,     $script:langDict.L_GUI_TIP_DOWN)
$tip.SetToolTip($btnNombre,   $script:langDict.L_GUI_TIP_NAME)
$tip.SetToolTip($btnFecha,    $script:langDict.L_GUI_TIP_DATE)
$tip.SetToolTip($btnTamano,   $script:langDict.L_GUI_TIP_SIZE)
$tip.SetToolTip($btnInvertir, $script:langDict.L_GUI_TIP_INVERT)
$tip.SetToolTip($btnEliminar, $script:langDict.L_GUI_TIP_DEL)
$tip.SetToolTip($txtOut,      $script:langDict.L_GUI_TIP_OUT)
$tip.SetToolTip($chkAbrir,    $script:langDict.L_GUI_TIP_OPEN)
$tip.SetToolTip($chkCerrar,   $script:langDict.L_GUI_TIP_CLOSE)
$tip.SetToolTip($chkToc,      $script:langDict.L_GUI_TIP_TOC)
$tip.SetToolTip($btnCombinar, $script:langDict.L_GUI_TIP_MERGE)
$tip.SetToolTip($btnTema,     $script:langDict.L_GUI_TIP_THEME)

# Poblar lista y ordenar por nombre por defecto
foreach ($f in $files) {
    [void]$listBox.Items.Add((Get-DisplayName $f.FullName))
    [void]$script:rutas.Add($f.FullName)
}
$listBox.SelectedIndex = 0
Refresh-Folder
Sort-Lista 'nombre'
$txtOut.Text = [System.IO.Path]::GetFileNameWithoutExtension($script:rutas[0]) + "_merged.pdf"

# Eventos
$btnUp.Add_Click({
    $i = $listBox.SelectedIndex
    if ($i -gt 0) { Swap-Item $i ($i-1); $listBox.SelectedIndex = $i-1; Refresh-Folder }
})
$btnDown.Add_Click({
    $i = $listBox.SelectedIndex
    if ($i -ge 0 -and $i -lt $listBox.Items.Count-1) { Swap-Item $i ($i+1); $listBox.SelectedIndex = $i+1; Refresh-Folder }
})
$btnNombre.Add_Click(   { Sort-Lista 'nombre' })
$btnFecha.Add_Click(    { Sort-Lista 'fecha'  })
$btnTamano.Add_Click(   { Sort-Lista 'tamano' })
$btnInvertir.Add_Click( { Invertir-Lista      })
$btnEliminar.Add_Click( { Remove-Selected     })

$btnAgregar.Add_Click({
    $dlg = New-Object System.Windows.Forms.OpenFileDialog
    $dlg.Title      = $script:langDict.L_GUI_DLG_ADD
    $dlg.Filter     = "PDF (*.pdf)|*.pdf"
    $dlg.Multiselect = $true
    if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        Add-Files $dlg.FileNames
    }
    $dlg.Dispose()
})

$btnTema.Add_Click({ Apply-Theme (-not $script:isDark) })
$listBox.Add_Resize({ $listBox.Invalidate() })

$timerClose.Add_Tick({
    $script:countdown--
    if ($script:countdown -le 0) {
        $timerClose.Stop()
        $form.Close()
    } else {
        $lblStatus.Text = "$(([char]0x2713)) $($script:langDict.L_GUI_STATUS_DONE) $($script:countdown)s..."
    }
})

$chkAbrir.Add_CheckedChanged({  Save-Config })
$chkCerrar.Add_CheckedChanged({ Save-Config })
$chkToc.Add_CheckedChanged({   Save-Config })

$listBox.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Delete) { Remove-Selected }
})

# Drag & drop
$listBox.Add_MouseDown({
    param($s, $e)
    if ($e.Button -eq [System.Windows.Forms.MouseButtons]::Left) {
        $script:dragFromIndex = $listBox.IndexFromPoint($e.Location)
        $script:dragStartPos  = $e.Location
    }
})
$listBox.Add_MouseMove({
    param($s, $e)
    if ($e.Button -ne [System.Windows.Forms.MouseButtons]::Left) { return }
    if ($script:dragFromIndex -lt 0 -or $null -eq $script:dragStartPos) { return }
    $dx = [Math]::Abs($e.X - $script:dragStartPos.X)
    $dy = [Math]::Abs($e.Y - $script:dragStartPos.Y)
    $th = [System.Windows.Forms.SystemInformation]::DragSize
    if ($dx -gt $th.Width -or $dy -gt $th.Height) {
        $script:dragStartPos = $null
        [void]$listBox.DoDragDrop($script:dragFromIndex, [System.Windows.Forms.DragDropEffects]::Move)
    }
})
$listBox.Add_DragOver({
    param($s, $e)
    if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::Copy
    } else {
        $e.Effect = [System.Windows.Forms.DragDropEffects]::Move
    }
})
$listBox.Add_DragDrop({
    param($s, $e)
    if ($e.Data.GetDataPresent([System.Windows.Forms.DataFormats]::FileDrop)) {
        # Archivos externos arrastrados desde el explorador
        $dropped = $e.Data.GetData([System.Windows.Forms.DataFormats]::FileDrop)
        Add-Files $dropped
        $script:dragFromIndex = -1
    } else {
        # Reordenado interno
        $pt   = $listBox.PointToClient([System.Windows.Forms.Cursor]::Position)
        $to   = $listBox.IndexFromPoint($pt)
        if ($to -lt 0) { $to = $listBox.Items.Count }
        $from = $script:dragFromIndex
        if ($from -ge 0 -and $from -ne $to) {
            Reorder-ListItem $from $to
            $at = if ($to -gt $from) { $to-1 } else { $to }
            $listBox.SelectedIndex = [Math]::Min($at, $listBox.Items.Count-1)
            Refresh-Folder
        }
        $script:dragFromIndex = -1
    }
})
$listBox.Add_MouseUp({ $script:dragFromIndex = -1; $script:dragStartPos = $null })

# Combinar
$btnCombinar.Add_Click({
    $nombre = $txtOut.Text.Trim()
    if (-not $nombre) { $nombre = "combinado" }
    if ($nombre -notmatch '\.pdf$') { $nombre += ".pdf" }
    $dirSalida  = $script:outputDir
    $rutaSalida = [System.IO.Path]::Combine($dirSalida, $nombre)
    if (-not (Test-Path $cpdfExe)) {
        [System.Windows.Forms.MessageBox]::Show("No se encontro cpdf.exe.`nEjecuta setup.bat primero.",
            "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    if (Test-Path $rutaSalida) {
        $resp = [System.Windows.Forms.MessageBox]::Show("Ya existe '$nombre'. Sobreescribir?",
            "Confirmar", [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($resp -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    }
    # Si se pide indice, combinar primero en temporal y luego procesar
    $cpdfTarget = if ($chkToc.Checked) {
        $uid = [System.IO.Path]::GetRandomFileName() -replace '\.', ''
        [System.IO.Path]::Combine($script:outputDir, "_cptmp_$uid.pdf")
    } else { $rutaSalida }

    $argsCpdf = [System.Collections.ArrayList]@()
    foreach ($r in $script:rutas) { [void]$argsCpdf.Add($r) }
    [void]$argsCpdf.Add("-o");  [void]$argsCpdf.Add($cpdfTarget)
    & $cpdfExe @argsCpdf 2>&1 | Out-Null

    if ($chkToc.Checked -and (Test-Path $cpdfTarget)) {
        $tocOk = Add-TocAndBookmarks $cpdfTarget $rutaSalida
        if (-not $tocOk -and -not (Test-Path $rutaSalida)) {
            # fallback: usar el combinado sin indice
            try { [System.IO.File]::Move($cpdfTarget, $rutaSalida) } catch {}
        } else {
            if (Test-Path $cpdfTarget) { Remove-Item $cpdfTarget -Force -ErrorAction SilentlyContinue }
        }
    }

    if (Test-Path $rutaSalida) {
        if ($chkAbrir.Checked) { Start-Process $rutaSalida }
        $colorOk = if ($script:isDark) { [System.Drawing.Color]::FromArgb(100, 220, 140) } `
                                  else { [System.Drawing.Color]::FromArgb(0, 140, 50) }
        $lblStatus.ForeColor = $colorOk
        $btnCombinar.Enabled = $false
        if ($chkCerrar.Checked) {
            $script:countdown = 5
            $lblStatus.Text = "$(([char]0x2713)) $($script:langDict.L_GUI_STATUS_DONE) $($script:countdown)s..."
            $timerClose.Start()
        } else {
            $lblStatus.Text = "$(([char]0x2713)) $($script:langDict.L_GUI_STATUS_DONE) OK"
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show($script:langDict.L_GUI_ERR_PROT,
            "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# Mostrar
$form.Controls.AddRange(@(
    $lblTitulo, $btnAgregar, $btnTema, $panelList, $btnUp, $btnDown,
    $btnNombre, $btnFecha, $btnTamano, $btnInvertir, $btnEliminar,
    $sep, $lblOut, $txtOut, $chkAbrir, $chkCerrar, $chkToc, $btnCombinar, $lblStatus, $lblFolder
))
[void]$form.ShowDialog()
