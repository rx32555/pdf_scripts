# pdf_scripts

Colección de scripts Windows (.bat) para operaciones sobre archivos PDF, usando [cpdf](http://www.coherentpdf.com/) como motor. Compatibles con drag & drop y con el menú contextual **Enviar a** de Windows.

**Soporte bilingüe integrado:** La interfaz gráfica, los nombres de los accesos directos y los mensajes por consola se adaptan al idioma de tu preferencia (Español / Inglés).

## Requisitos

- Windows 10 o superior
- PowerShell 5.1 (incluido en Windows 10+)
- Conexión a internet solo para la primera ejecución de `setup.bat`

## Instalación

```bat
setup.bat
```

Al ejecutarlo por primera vez:
1. Te preguntará qué idioma prefieres (Español / Inglés). Toda la configuración visual y los accesos directos se adaptarán a esta elección. Puedes volver a ejecutar el `setup.bat` cuando quieras para cambiar de idioma.
2. Descarga `cpdf.exe` en la carpeta `dependencias\`
3. Descarga `7za.exe` (7-Zip portable) en la carpeta `dependencias\`
4. Verifica si Ghostscript está instalado en el sistema; si no, descarga el instalador oficial y lo lanza — seguir el asistente dejando las opciones por defecto (la opción *Add to PATH* viene marcada, no cambiarla)
5. Verifica los accesos directos en el menú **Enviar a**: limpia duplicados si cambiaste de idioma, y crea o actualiza los accesos directos.

A partir de ahí los scripts funcionan sin conexión a internet.

## Scripts disponibles

| Archivo | Descripción |
|---|---|
| `filename_header_REEMPLAZA_drag_and_drop.bat` | Inserta el nombre del archivo como encabezado en cada página y sobreescribe el PDF original |
| `reducir_peso_REEMPLAZA_drag_and_drop.bat` | Reduce el peso del PDF con calidad `/ebook` (150 dpi) y sobreescribe el original |
| `escala_grises_REEMPLAZA_drag_and_drop.bat` | Convierte el PDF a escala de grises y sobreescribe el original |
| `dividir_paginas_drag_and_drop.bat` | Separa cada página en un archivo individual (`nombre_p1.pdf`, `nombre_p2.pdf`…) junto al original |
| `combinar_PDFs_drag_and_drop.bat` + `combinar_PDFs_gui.ps1` | Abre una ventana para reordenar los PDFs arrastrados (↑↓ manual, por nombre o por fecha) y los combina en un archivo nuevo |
| `eliminar_paginas_drag_and_drop.bat` + `eliminar_paginas_gui.ps1` | Elimina o conserva páginas según un rango (`1,3,5-7` / `2-end` / `odd` / `even`). Botones rápidos para portada, última página, pares e impares. Opción de reemplazar el original o guardar como `_editado.pdf`. Opciones: abrir archivos resultantes al terminar (visible solo con ≤10 PDFs) y cerrar ventana automáticamente |

> **Seguridad al reemplazar:** Los scripts etiquetados como `REEMPLAZA` no borran los archivos de forma permanente. Antes de sobreescribirlos, el PDF original es enviado a la Papelera de reciclaje de Windows con el sufijo `_original.pdf`. Si procesaste un archivo por error, puedes restaurarlo fácilmente desde allí sin generar conflictos.

## Uso

**Drag & Drop** — Arrastrar uno o varios PDFs sobre el `.bat`.

**Enviar a** — Click derecho → **Enviar a** → nombre del script, configurado por `setup.bat`.

## Dependencias

`setup.bat` descarga y configura todo automáticamente en `dependencias\` (carpeta ignorada por git).

| Herramienta | Usado por | Licencia |
|---|---|---|
| [cpdf](http://www.coherentpdf.com/) | Encabezado, dividir páginas, combinar | Gratuito para uso no comercial |
| [Ghostscript](https://www.ghostscript.com/) | Reducir peso, escala de grises, índice de combinar | AGPL / Comercial |
| [7-Zip](https://www.7-zip.org/) | Extracción de dependencias | LGPL |

## Licencia

MIT — ver [LICENSE](LICENSE).
