$es = Get-Content locales\es.json -Raw | ConvertFrom-Json
$en = Get-Content locales\en.json -Raw | ConvertFrom-Json

$keys = [ordered]@{
  'L_GUI_LBL_FOLDER'=@('Carpeta:','Folder:');
  'L_GUI_CHK_DISABLED'=@('(Deshabilitado: demasiados PDF)','(Disabled: too many PDFs)');
  'L_GUI_TIP_ADD'=@('Agregar mas ficheros PDF a la lista mediante dialogo de seleccion','Add more PDF files via selection dialog');
  'L_GUI_TIP_UP'=@('Subir el PDF seleccionado una posicion','Move selected PDF up one position');
  'L_GUI_TIP_DOWN'=@('Bajar el PDF seleccionado una posicion','Move selected PDF down one position');
  'L_GUI_TIP_NAME'=@('Ordenar alfabeticamente por nombre de archivo','Sort alphabetically by file name');
  'L_GUI_TIP_DATE'=@('Ordenar por fecha de modificacion (mas antiguo primero)','Sort by modification date (oldest first)');
  'L_GUI_TIP_SIZE'=@('Ordenar por tamano de archivo (mas pequeno primero)','Sort by file size (smallest first)');
  'L_GUI_TIP_INVERT'=@('Invertir el orden actual de la lista','Reverse the current list order');
  'L_GUI_TIP_DEL'=@('Quitar el PDF seleccionado de la lista (no borra el archivo del disco)','Remove selected PDF from list (does not delete file)');
  'L_GUI_TIP_OUT'=@('Nombre del archivo resultante. Se guarda en la carpeta del primer PDF','Output file name. Saved in the first PDF''s folder');
  'L_GUI_TIP_OPEN'=@('Abrir el PDF combinado con el visor predeterminado al terminar','Open the combined PDF when finished');
  'L_GUI_TIP_CLOSE'=@('Cerrar la ventana automaticamente 5 segundos despues de combinar','Close window automatically 5s after merging');
  'L_GUI_TIP_TOC'=@('Agregar pagina de indice al inicio con marcadores','Add table of contents with bookmarks at the beginning');
  'L_GUI_TIP_MERGE'=@('Combinar todos los PDFs en el orden mostrado','Merge all PDFs in the shown order');
  'L_GUI_TIP_THEME'=@('Cambiar entre tema oscuro y claro','Switch between dark and light theme');
  'L_GUI_TIP_RDO_DEL'=@('Las paginas indicadas seran eliminadas del PDF','The specified pages will be removed from the PDF');
  'L_GUI_TIP_RDO_KEEP'=@('Solo las paginas indicadas se conservaran; el resto se elimina','Only specified pages will be kept; others are removed');
  'L_GUI_TIP_RANGE'=@('Rango de paginas. Ejemplos: 1,3,5-7 | 2-end | odd | even','Page range. Examples: 1,3,5-7 | 2-end | odd | even');
  'L_GUI_TIP_P1'=@('Agregar pagina 1 al rango (portadas)','Add page 1 to range (covers)');
  'L_GUI_TIP_PLAST'=@('Agregar ultima pagina al rango (usar ''end'')','Add last page to range (use ''end'')');
  'L_GUI_TIP_PEVEN'=@('Agregar ''even'' al rango (paginas pares)','Add ''even'' to range (even pages)');
  'L_GUI_TIP_PODD'=@('Agregar ''odd'' al rango (paginas impares)','Add ''odd'' to range (odd pages)');
  'L_GUI_TIP_RDO_OVERWRITE'=@('Sobreescribe el PDF original con el resultado','Overwrites original PDF with the result');
  'L_GUI_TIP_RDO_NEW'=@('Crea un archivo nuevo con sufijo _editado.pdf en la misma carpeta','Creates a new file with _edited.pdf suffix in the same folder');
  'L_GUI_TIP_PROCESS'=@('Aplicar la operacion a todos los PDFs de la lista','Apply operation to all PDFs in the list');
  'L_GUI_LOG_OMIT_1PAG'=@('OMIT: {0}  - 1 pag., nada que eliminar','OMIT: {0}  - 1 page, nothing to remove');
  'L_GUI_LOG_OMIT_ALL'=@('OMIT: {0}  - el rango eliminaria todas las pags.','OMIT: {0}  - range would remove all pages');
  'L_GUI_LOG_ERR_FAIL'=@('ERR: {0}  - Fallo al procesar.','ERR: {0}  - Processing failed.');
  'L_GUI_LOG_ERR_NOPAGS'=@('ERR: {0}  - No se detectaron paginas en el resultado.','ERR: {0}  - No pages detected in the result.')
}

foreach ($key in $keys.Keys) {
    Add-Member -InputObject $es -MemberType NoteProperty -Name $key -Value $keys[$key][0] -Force
    Add-Member -InputObject $en -MemberType NoteProperty -Name $key -Value $keys[$key][1] -Force
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$esJson = $es | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot "locales\es.json"), $esJson, $utf8NoBom)

$enJson = $en | ConvertTo-Json -Depth 10
[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot "locales\en.json"), $enJson, $utf8NoBom)
