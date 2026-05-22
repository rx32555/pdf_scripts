$es = Get-Content locales\es.json -Raw | ConvertFrom-Json
$en = Get-Content locales\en.json -Raw | ConvertFrom-Json

$keys = [ordered]@{
  'L_GUI_LBL_OP'=@('Operacion:','Operation:');
  'L_GUI_HINT_RANGE'=@('Ejemplos:  1,3,5-7     2-end     odd     even     1,3,5-end','Examples:  1,3,5-7     2-end     odd     even     1,3,5-end');
  'L_GUI_LBL_SAVE'=@('Guardar:','Save as:');
  'L_GUI_RDO_REPLACE'=@('Reemplazar original','Replace original');
  'L_GUI_RDO_NEW_FILE'=@('Nuevo archivo  (_editado.pdf)','New file  (_edited.pdf)');
  'L_GUI_LOG_ERR_READ_PAGES'=@('ERR:  {0}  - no se pudo leer el numero de paginas','ERR:  {0}  - could not read page count');
  'L_GUI_LOG_ERR_NOCPDF'=@('cpdf no genero archivo de salida','cpdf did not generate output file');
  'L_GUI_STATUS_OK_SKIPPED'=@('{0} procesados,  {1} omitido(s).','{0} processed,  {1} skipped.');
  'L_GUI_STATUS_OK'=@('{0} PDF(s) procesados correctamente.','{0} PDF(s) processed successfully.');
  'L_GUI_STATUS_WARN'=@('{0} procesados / {1} no se procesaron. Ver detalles.','{0} processed / {1} failed. See details.');
  'L_GUI_STATUS_ERR_ALL'=@('No se procesaron los archivos. Ver detalles.','No files were processed. See details.');
  'L_GUI_STATUS_OMIT_ALL'=@('Ningun PDF fue modificado (todos omitidos).','No PDF was modified (all skipped).');
  'L_GUI_ERR_CPDF'=@("No se encontro cpdf.exe.`nEjecuta setup.bat primero.","cpdf.exe not found.`nRun setup.bat first.");
  'L_GUI_ERR_PROT'=@("No se pudo generar el archivo.`nVerifica que los PDFs no esten protegidos.","Could not generate file.`nVerify PDFs are not protected.");
  'L_GUI_MSG_CONFIRM'=@("Se va a {0} las paginas [{1}] en {2} PDF(s).`n{3}`n`nContinuar?","About to {0} pages [{1}] in {2} PDF(s).`n{3}`n`nContinue?");
  'L_GUI_MSG_CONFIRM_DEL'=@('eliminar','remove');
  'L_GUI_MSG_CONFIRM_KEEP'=@('conservar','keep');
  'L_GUI_MSG_CONFIRM_NEW'=@('Se generaran archivos nuevos con sufijo _editado.','New files with _edited suffix will be generated.');
  'L_GUI_MSG_CONFIRM_REP'=@('Se sobreescribiran los originales.','Original files will be overwritten.')
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
