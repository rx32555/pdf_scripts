Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# DWM: barra de titulo oscura (Windows 10 v2004+ / Windows 11)
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

# Archivos recibidos por argumento
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

# Estado
$script:rutas         = [System.Collections.ArrayList]@()
$script:pagCount      = @{}
$script:dragFromIndex = -1
$script:dragStartPos  = $null

# Paleta de colores
$clrBg       = [System.Drawing.Color]::FromArgb( 30,  30,  30)   # fondo form
$clrSurface  = [System.Drawing.Color]::FromArgb( 37,  37,  38)   # fila par listbox
$clrSurface2 = [System.Drawing.Color]::FromArgb( 45,  45,  48)   # fila impar / textbox
$clrBorder   = [System.Drawing.Color]::FromArgb( 62,  62,  66)   # bordes / separador
$clrText     = [System.Drawing.Color]::FromArgb(220, 220, 220)   # texto principal
$clrTextDim  = [System.Drawing.Color]::FromArgb(140, 140, 140)   # texto secundario
$clrAccent   = [System.Drawing.Color]::FromArgb(  0, 120, 212)   # azul acento
$clrAccHover = [System.Drawing.Color]::FromArgb( 16, 110, 190)
$clrAccPress = [System.Drawing.Color]::FromArgb(  0,  90, 158)
$clrSelectBg = [System.Drawing.Color]::FromArgb( 28,  58,  90)   # fondo fila seleccionada
$clrBtnHover = [System.Drawing.Color]::FromArgb( 62,  62,  66)
$clrBtnPress = [System.Drawing.Color]::FromArgb( 20,  20,  20)

# Brushes cacheados para el owner draw (evitar GDI leaks)
$script:brText    = [System.Drawing.SolidBrush]::new($clrText)
$script:brWhite   = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::White)
$script:brRow1    = [System.Drawing.SolidBrush]::new($clrSurface)
$script:brRow2    = [System.Drawing.SolidBrush]::new($clrSurface2)
$script:brSelBg   = [System.Drawing.SolidBrush]::new($clrSelectBg)
$script:brAccent  = [System.Drawing.SolidBrush]::new($clrAccent)
$script:sfVCenter = New-Object System.Drawing.StringFormat
$script:sfVCenter.LineAlignment = [System.Drawing.StringAlignment]::Center

# Consultar numero de paginas con cpdf (antes de abrir el form)
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

# Helpers (logica sin cambios respecto a version anterior)
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

function Move-Item($from, $to) {
    if ($from -eq $to) { return }
    $d = $listBox.Items[$from];  $listBox.Items.RemoveAt($from)
    $r = $script:rutas[$from];   $script:rutas.RemoveAt($from)
    $at = if ($to -gt $from) { $to - 1 } else { $to }
    $listBox.Items.Insert($at, $d);  $script:rutas.Insert($at, $r)
}

function Refresh-Folder {
    $lblFolder.Text = "Destino: " + [System.IO.Path]::GetDirectoryName($script:rutas[0])
}

function Remove-Selected {
    $i = $listBox.SelectedIndex
    if ($i -lt 0 -or $listBox.Items.Count -le 1) { return }
    $listBox.Items.RemoveAt($i);  $script:rutas.RemoveAt($i)
    $listBox.SelectedIndex = [Math]::Min($i, $listBox.Items.Count - 1)
    Refresh-Folder
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
        [void]$listBox.Items.Add((Get-DisplayName $p.Ruta))
        [void]$script:rutas.Add($p.Ruta)
    }
    $listBox.SelectedIndex = 0;  Refresh-Folder
}

function Invertir-Lista {
    $copia = [System.Collections.ArrayList]@($script:rutas);  $copia.Reverse()
    $listBox.Items.Clear();  $script:rutas.Clear()
    foreach ($r in $copia) {
        [void]$listBox.Items.Add((Get-DisplayName $r))
        [void]$script:rutas.Add($r)
    }
    $listBox.SelectedIndex = 0;  Refresh-Folder
}

# Helper: aplicar estilo oscuro a botones secundarios
function Set-DarkButton($btn) {
    $btn.FlatStyle = "Flat"
    $btn.BackColor = $clrSurface2
    $btn.ForeColor = $clrText
    $btn.FlatAppearance.BorderColor        = $clrBorder
    $btn.FlatAppearance.BorderSize         = 1
    $btn.FlatAppearance.MouseOverBackColor = $clrBtnHover
    $btn.FlatAppearance.MouseDownBackColor = $clrBtnPress
}

# Unicode via escape (fuente 100% ASCII)
$arrowUp   = [char]0x2191
$arrowDown = [char]0x2193
$enye      = [char]0x00F1

# Form
$form = New-Object System.Windows.Forms.Form
$form.Text            = "Combinar PDFs"
$form.ClientSize      = New-Object System.Drawing.Size(560, 420)
$form.StartPosition   = "CenterScreen"
$form.FormBorderStyle = "FixedDialog"
$form.MaximizeBox     = $false
$form.BackColor       = $clrBg
$form.ForeColor       = $clrText
$form.Font            = New-Object System.Drawing.Font("Segoe UI", 9)

$form.Add_HandleCreated({
    param($s, $e)
    try {
        $dark = 1
        [void][DwmApi]::DwmSetWindowAttribute($s.Handle, 20, [ref]$dark, 4)
        [void][DwmApi]::DwmSetWindowAttribute($s.Handle, 19, [ref]$dark, 4)
    } catch {}
})

$form.Add_FormClosed({
    $script:brText.Dispose();   $script:brWhite.Dispose()
    $script:brRow1.Dispose();   $script:brRow2.Dispose()
    $script:brSelBg.Dispose();  $script:brAccent.Dispose()
    $script:sfVCenter.Dispose()
})

# Titulo
$n = $files.Count;  $sufijo = if ($n -ne 1) { 's' } else { '' }

$lblTitulo = New-Object System.Windows.Forms.Label
$lblTitulo.Text      = "$n PDF$sufijo - usa $arrowUp $arrowDown o arrastra para reordenar:"
$lblTitulo.Location  = New-Object System.Drawing.Point(12, 10)
$lblTitulo.Size      = New-Object System.Drawing.Size(490, 16)
$lblTitulo.BackColor = $clrBg
$lblTitulo.ForeColor = $clrText

# ListBox con borde via panel contenedor (1px del color de borde)
$listBox = New-Object System.Windows.Forms.ListBox
$listBox.Font           = New-Object System.Drawing.Font("Segoe UI", 10)
$listBox.IntegralHeight = $false
$listBox.AllowDrop      = $true
$listBox.BackColor      = $clrSurface
$listBox.ForeColor      = $clrText
$listBox.BorderStyle    = "None"
$listBox.DrawMode       = [System.Windows.Forms.DrawMode]::OwnerDrawFixed
$listBox.ItemHeight     = 30
$listBox.Location       = New-Object System.Drawing.Point(1, 1)
$listBox.Size           = New-Object System.Drawing.Size(468, 200)

$panelList = New-Object System.Windows.Forms.Panel
$panelList.Location  = New-Object System.Drawing.Point(11, 29)
$panelList.Size      = New-Object System.Drawing.Size(470, 202)
$panelList.BackColor = $clrBorder
$panelList.Padding   = New-Object System.Windows.Forms.Padding(1)
$panelList.Controls.Add($listBox)

# Botones Up / Down
$btnUp = New-Object System.Windows.Forms.Button
$btnUp.Text     = $arrowUp
$btnUp.Location = New-Object System.Drawing.Point(490, 30)
$btnUp.Size     = New-Object System.Drawing.Size(58, 38)
$btnUp.Font     = New-Object System.Drawing.Font("Segoe UI", 14)
Set-DarkButton $btnUp

$btnDown = New-Object System.Windows.Forms.Button
$btnDown.Text     = $arrowDown
$btnDown.Location = New-Object System.Drawing.Point(490, 74)
$btnDown.Size     = New-Object System.Drawing.Size(58, 38)
$btnDown.Font     = New-Object System.Drawing.Font("Segoe UI", 14)
Set-DarkButton $btnDown

# Botones ordenar / gestionar (fila unica)
$btnNombre = New-Object System.Windows.Forms.Button
$btnNombre.Text     = "Nombre"
$btnNombre.Location = New-Object System.Drawing.Point(12, 244)
$btnNombre.Size     = New-Object System.Drawing.Size(80, 28)
Set-DarkButton $btnNombre

$btnFecha = New-Object System.Windows.Forms.Button
$btnFecha.Text     = "Fecha"
$btnFecha.Location = New-Object System.Drawing.Point(98, 244)
$btnFecha.Size     = New-Object System.Drawing.Size(80, 28)
Set-DarkButton $btnFecha

$btnTamano = New-Object System.Windows.Forms.Button
$btnTamano.Text     = "Tama" + $enye + "o"
$btnTamano.Location = New-Object System.Drawing.Point(184, 244)
$btnTamano.Size     = New-Object System.Drawing.Size(80, 28)
Set-DarkButton $btnTamano

$btnInvertir = New-Object System.Windows.Forms.Button
$btnInvertir.Text     = "Invertir"
$btnInvertir.Location = New-Object System.Drawing.Point(270, 244)
$btnInvertir.Size     = New-Object System.Drawing.Size(76, 28)
Set-DarkButton $btnInvertir

$btnEliminar = New-Object System.Windows.Forms.Button
$btnEliminar.Text     = "Eliminar  [Supr]"
$btnEliminar.Location = New-Object System.Drawing.Point(364, 244)
$btnEliminar.Size     = New-Object System.Drawing.Size(184, 28)
Set-DarkButton $btnEliminar

# Separador (label plano con color de borde como fondo)
$sep = New-Object System.Windows.Forms.Label
$sep.BackColor   = $clrBorder
$sep.BorderStyle = "None"
$sep.Location    = New-Object System.Drawing.Point(12, 286)
$sep.Size        = New-Object System.Drawing.Size(536, 1)

# Nombre de salida
$lblOut = New-Object System.Windows.Forms.Label
$lblOut.Text      = "Nombre del archivo de salida:"
$lblOut.Location  = New-Object System.Drawing.Point(12, 296)
$lblOut.Size      = New-Object System.Drawing.Size(210, 16)
$lblOut.BackColor = $clrBg
$lblOut.ForeColor = $clrText

$txtOut = New-Object System.Windows.Forms.TextBox
$txtOut.Text        = "combinado.pdf"
$txtOut.Location    = New-Object System.Drawing.Point(12, 315)
$txtOut.Size        = New-Object System.Drawing.Size(348, 24)
$txtOut.BackColor   = $clrSurface2
$txtOut.ForeColor   = $clrText
$txtOut.BorderStyle = "FixedSingle"

# Checkbox abrir al terminar
$chkAbrir = New-Object System.Windows.Forms.CheckBox
$chkAbrir.Text      = "Abrir PDF al terminar"
$chkAbrir.Checked   = $true
$chkAbrir.Location  = New-Object System.Drawing.Point(12, 346)
$chkAbrir.Size      = New-Object System.Drawing.Size(180, 20)
$chkAbrir.ForeColor = $clrText
$chkAbrir.BackColor = $clrBg

# Boton Combinar (acento azul)
$btnCombinar = New-Object System.Windows.Forms.Button
$btnCombinar.Text      = "Combinar"
$btnCombinar.Location  = New-Object System.Drawing.Point(368, 311)
$btnCombinar.Size      = New-Object System.Drawing.Size(180, 32)
$btnCombinar.FlatStyle = "Flat"
$btnCombinar.BackColor = $clrAccent
$btnCombinar.ForeColor = [System.Drawing.Color]::White
$btnCombinar.FlatAppearance.BorderSize         = 0
$btnCombinar.FlatAppearance.MouseOverBackColor = $clrAccHover
$btnCombinar.FlatAppearance.MouseDownBackColor = $clrAccPress
$form.AcceptButton = $btnCombinar

# Etiqueta destino
$lblFolder = New-Object System.Windows.Forms.Label
$lblFolder.Location  = New-Object System.Drawing.Point(12, 400)
$lblFolder.Size      = New-Object System.Drawing.Size(536, 14)
$lblFolder.BackColor = $clrBg
$lblFolder.ForeColor = $clrTextDim
$lblFolder.Font      = New-Object System.Drawing.Font("Segoe UI", 7.5)

# Owner draw del ListBox
$listBox.Add_DrawItem({
    param($s, $e)
    if ($e.Index -lt 0 -or $e.Index -ge $listBox.Items.Count) { return }

    $selected = $e.State -band [System.Windows.Forms.DrawItemState]::Selected

    # Fondo de fila
    $bgBrush = if ($selected)            { $script:brSelBg }
               elseif ($e.Index % 2 -eq 0) { $script:brRow1  }
               else                        { $script:brRow2  }
    $e.Graphics.FillRectangle($bgBrush, $e.Bounds)

    # Barra de acento izquierda en fila seleccionada
    if ($selected) {
        $bar = New-Object System.Drawing.Rectangle($e.Bounds.X, $e.Bounds.Y, 3, $e.Bounds.Height)
        $e.Graphics.FillRectangle($script:brAccent, $bar)
    }

    # Texto centrado verticalmente con padding izquierdo
    $txtBrush = if ($selected) { $script:brWhite } else { $script:brText }
    $pad      = 12
    $txtRect  = New-Object System.Drawing.RectangleF(
        ($e.Bounds.X + $pad), $e.Bounds.Y,
        ($e.Bounds.Width - $pad), $e.Bounds.Height)
    $e.Graphics.DrawString($listBox.Items[$e.Index], $listBox.Font, $txtBrush, $txtRect, $script:sfVCenter)
})

# Tooltips
$tip = New-Object System.Windows.Forms.ToolTip
$tip.AutoPopDelay = 6000
$tip.InitialDelay = 600
$tip.ReshowDelay  = 300

$tip.SetToolTip($listBox,     "Selecciona un elemento y usa los botones, o arrastralo directamente")
$tip.SetToolTip($btnUp,       "Subir el PDF seleccionado una posicion")
$tip.SetToolTip($btnDown,     "Bajar el PDF seleccionado una posicion")
$tip.SetToolTip($btnNombre,   "Ordenar alfabeticamente por nombre de archivo")
$tip.SetToolTip($btnFecha,    "Ordenar por fecha de modificacion (mas antiguo primero)")
$tip.SetToolTip($btnTamano,   "Ordenar por tamano de archivo (mas pequeno primero)")
$tip.SetToolTip($btnInvertir, "Invertir el orden actual de la lista")
$tip.SetToolTip($btnEliminar, "Quitar el PDF seleccionado de la lista (no borra el archivo del disco)")
$tip.SetToolTip($txtOut,      "Nombre del archivo resultante. Se guarda en la carpeta del primer PDF")
$tip.SetToolTip($chkAbrir,    "Abrir el PDF combinado con el visor predeterminado al terminar")
$tip.SetToolTip($btnCombinar, "Combinar todos los PDFs en el orden mostrado")

# Poblar lista
foreach ($f in $files) {
    [void]$listBox.Items.Add((Get-DisplayName $f.FullName))
    [void]$script:rutas.Add($f.FullName)
}
$listBox.SelectedIndex = 0
Refresh-Folder

# Eventos: Up / Down
$btnUp.Add_Click({
    $i = $listBox.SelectedIndex
    if ($i -gt 0) { Swap-Item $i ($i-1); $listBox.SelectedIndex = $i-1; Refresh-Folder }
})
$btnDown.Add_Click({
    $i = $listBox.SelectedIndex
    if ($i -ge 0 -and $i -lt $listBox.Items.Count-1) { Swap-Item $i ($i+1); $listBox.SelectedIndex = $i+1; Refresh-Folder }
})

# Eventos: ordenar / invertir / eliminar
$btnNombre.Add_Click(   { Sort-Lista 'nombre' })
$btnFecha.Add_Click(    { Sort-Lista 'fecha'  })
$btnTamano.Add_Click(   { Sort-Lista 'tamano' })
$btnInvertir.Add_Click( { Invertir-Lista      })
$btnEliminar.Add_Click( { Remove-Selected     })

$listBox.Add_KeyDown({
    param($s, $e)
    if ($e.KeyCode -eq [System.Windows.Forms.Keys]::Delete) { Remove-Selected }
})

# Drag & drop interno
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
    param($s, $e); $e.Effect = [System.Windows.Forms.DragDropEffects]::Move
})
$listBox.Add_DragDrop({
    param($s, $e)
    $pt   = $listBox.PointToClient([System.Windows.Forms.Cursor]::Position)
    $to   = $listBox.IndexFromPoint($pt)
    if ($to -lt 0) { $to = $listBox.Items.Count }
    $from = $script:dragFromIndex
    if ($from -ge 0 -and $from -ne $to) {
        Move-Item $from $to
        $at = if ($to -gt $from) { $to-1 } else { $to }
        $listBox.SelectedIndex = [Math]::Min($at, $listBox.Items.Count-1)
        Refresh-Folder
    }
    $script:dragFromIndex = -1
})
$listBox.Add_MouseUp({ $script:dragFromIndex = -1; $script:dragStartPos = $null })

# Combinar
$btnCombinar.Add_Click({
    $nombre = $txtOut.Text.Trim()
    if (-not $nombre) { $nombre = "combinado" }
    if ($nombre -notmatch '\.pdf$') { $nombre += ".pdf" }

    $dirSalida  = [System.IO.Path]::GetDirectoryName($script:rutas[0])
    $rutaSalida = [System.IO.Path]::Combine($dirSalida, $nombre)

    if (-not (Test-Path $cpdfExe)) {
        [System.Windows.Forms.MessageBox]::Show(
            "No se encontro cpdf.exe.`nEjecuta setup.bat primero.",
            "Error", [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
        return
    }
    if (Test-Path $rutaSalida) {
        $resp = [System.Windows.Forms.MessageBox]::Show(
            "Ya existe '$nombre'. Sobreescribir?",
            "Confirmar", [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question)
        if ($resp -ne [System.Windows.Forms.DialogResult]::Yes) { return }
    }

    $argsCpdf = [System.Collections.ArrayList]@()
    foreach ($r in $script:rutas) { [void]$argsCpdf.Add($r) }
    [void]$argsCpdf.Add("-o");  [void]$argsCpdf.Add($rutaSalida)
    & $cpdfExe @argsCpdf 2>&1 | Out-Null

    if (Test-Path $rutaSalida) {
        if ($chkAbrir.Checked) { Start-Process $rutaSalida }
        [System.Windows.Forms.MessageBox]::Show(
            "Archivo generado:`n$rutaSalida",
            "Listo", [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Information)
        $form.Close()
    } else {
        [System.Windows.Forms.MessageBox]::Show(
            "No se pudo generar el archivo.`nVerifica que los PDFs no esten protegidos.",
            "Error", [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
})

# Mostrar
$form.Controls.AddRange(@(
    $lblTitulo, $panelList, $btnUp, $btnDown,
    $btnNombre, $btnFecha, $btnTamano, $btnInvertir, $btnEliminar,
    $sep, $lblOut, $txtOut, $chkAbrir, $btnCombinar, $lblFolder
))
[void]$form.ShowDialog()
