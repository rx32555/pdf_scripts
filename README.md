# pdf_scripts

Colección de scripts Windows (.bat) para operaciones sobre archivos PDF, usando [cpdf](http://www.coherentpdf.com/) como motor. Compatibles con drag & drop y con el menú contextual **Enviar a** de Windows.

## Requisitos

- Windows 10 o superior
- PowerShell 5.1 (incluido en Windows 10+)
- Conexión a internet solo para la primera ejecución de `setup.bat`

No es necesario instalar nada manualmente. El setup descarga las dependencias automáticamente.

## Instalación

```bat
setup.bat
```

Al ejecutarlo por primera vez:
1. Descarga `cpdf.exe` en la carpeta `dependencias\`
2. Ofrece crear accesos directos en el menú **Enviar a** para cada script disponible

A partir de ahí los scripts funcionan sin conexión a internet.

## Scripts disponibles

| Archivo | Descripción |
|---|---|
| `filename_header_REEMPLAZA_drag_and_drop.bat` | Inserta el nombre del archivo como encabezado en cada página y sobreescribe el PDF original |
| `reducir_peso_REEMPLAZA_drag_and_drop.bat` | Reduce el peso del PDF con calidad `/ebook` y sobreescribe el original |

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
