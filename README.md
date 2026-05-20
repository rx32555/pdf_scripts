# pdf_scripts

Colección de scripts Windows (.bat) para operaciones sobre archivos PDF, usando [cpdf](http://www.coherentpdf.com/) como motor. Compatibles con drag & drop y con el menú contextual **Enviar a** de Windows.

## Requisitos

- Windows 10 o superior
- PowerShell 5.1 (incluido en Windows 10+)
- Conexión a internet solo para la primera ejecución de `setup.bat`

## Instalación

```bat
setup.bat
```

Al ejecutarlo por primera vez:
1. Descarga `cpdf.exe` en la carpeta `dependencias\`
2. Descarga `7za.exe` (7-Zip portable) en la carpeta `dependencias\`
3. Verifica si Ghostscript está instalado en el sistema; si no, descarga el instalador oficial y lo lanza — seguir el asistente dejando las opciones por defecto (la opción *Add to PATH* viene marcada, no cambiarla)
4. Verifica los accesos directos en el menú **Enviar a**: crea o actualiza solo los que falten o apunten a una ruta incorrecta

A partir de ahí los scripts funcionan sin conexión a internet.

## Scripts disponibles

| Archivo | Descripción |
|---|---|
| `filename_header_REEMPLAZA_drag_and_drop.bat` | Inserta el nombre del archivo como encabezado en cada página y sobreescribe el PDF original |
| `reducir_peso_REEMPLAZA_drag_and_drop.bat` | Reduce el peso del PDF con calidad `/printer` (300 dpi, apta para imprimir) y sobreescribe el original |
| `escala_grises_REEMPLAZA_drag_and_drop.bat` | Convierte el PDF a escala de grises y sobreescribe el original |
| `dividir_paginas_drag_and_drop.bat` | Separa cada página en un archivo individual (`nombre_p1.pdf`, `nombre_p2.pdf`…) junto al original |
| `combinar_PDFs_drag_and_drop.bat` + `combinar_PDFs_gui.ps1` | Abre una ventana para reordenar los PDFs arrastrados (↑↓ manual, por nombre o por fecha) y los combina en un archivo nuevo |

## Uso

**Drag & Drop** — Arrastrar uno o varios PDFs sobre el `.bat`.

**Menú contextual** — Click derecho sobre PDF(s) → Enviar a → nombre del script (configurado por `setup.bat`).

## Dependencias

`setup.bat` descarga y configura todo automáticamente en `dependencias\` (carpeta ignorada por git).

| Herramienta | Usado por | Licencia |
|---|---|---|
| [cpdf](http://www.coherentpdf.com/) | Scripts de encabezado | Gratuito para uso no comercial |
| [Ghostscript](https://www.ghostscript.com/) | Scripts de reducción de peso | AGPL / Comercial |
| [7-Zip](https://www.7-zip.org/) | Extracción de dependencias | LGPL |

## Licencia

MIT — ver [LICENSE](LICENSE).
