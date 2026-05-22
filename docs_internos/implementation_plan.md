# Revisión del proyecto pdf_scripts y Propuesta de Mejoras

He revisado a fondo el proyecto en `S:\gastos comunes\z.Aplicaciones\Scripts\pdf_scripts`. El nivel de los scripts es excelente: el uso de PowerShell con Windows Forms para las interfaces, el soporte para modo oscuro consultando DwmApi, la persistencia en JSON y la generación nativa de índices PostScript muestran un trabajo muy cuidado.

Sin embargo, he identificado tres áreas principales donde el proyecto se puede mejorar significativamente para mejorar la experiencia del usuario y la robustez.

## Open Questions

¿Te gustaría que aplique todas estas mejoras, o prefieres enfocarte solo en algunas? Si tienes alguna otra idea en mente (por ejemplo, agregar más calidades para reducir el peso), dímelo para incluirlo en el plan.

## Proposed Changes

### 1. Interfaces Redimensionables (Sizable GUI)
Actualmente, las ventanas de `combinar_PDFs_gui.ps1` y `eliminar_paginas_gui.ps1` tienen un tamaño fijo (`FixedDialog`). Cuando se trabaja con nombres de archivo muy largos o muchos PDFs, la lista puede sentirse estrecha.
- **Cambio:** Cambiar `FormBorderStyle` a `Sizable` (o `SizableToolWindow`).
- **Cambio:** Configurar la propiedad `Anchor` de todos los controles de la interfaz para que, al estirar la ventana, el cuadro de lista (`$listBox`) crezca para llenar el espacio, mientras que los botones se mantengan anclados a sus respectivos bordes (derecha, abajo).

### 2. Seguridad en los Scripts de Reemplazo (Uso de la Papelera)
Los scripts `.bat` que indican `REEMPLAZA` (como `reducir_peso`, `escala_grises` y `filename_header`) sobreescriben el archivo original con `copy /Y` y lo eliminan. Si algo sale mal o el usuario no está satisfecho con el resultado, el archivo original se pierde irremediablemente.
- **Cambio:** Modificar los `.bat` para que, antes de mover el archivo temporal al original, envíen el archivo original a la **Papelera de reciclaje** usando un comando rápido de PowerShell (`[Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile(..., 'SendToRecycleBin')`). Así, el usuario siempre podrá recuperarlos si se equivoca.

### 3. Mejor Detección de Ghostscript
Actualmente, `setup.bat` y `reducir_peso_REEMPLAZA_drag_and_drop.bat` confían en que `gswin64c.exe` esté en el `PATH`. Aunque el instalador suele añadirlo, a veces falla o el usuario desmarca la opción.
- **Cambio:** Mejorar el bloque de detección. Si `where gswin64c.exe` falla, consultar el Registro de Windows (`HKLM\SOFTWARE\GPL Ghostscript`) para localizar el ejecutable automáticamente sin depender del `PATH`. Esto hará que los scripts sean a prueba de balas.

### [Component Name] Archivos a Modificar

#### [MODIFY] [combinar_PDFs_gui.ps1](file:///S:/gastos%20comunes/z.Aplicaciones/Scripts/pdf_scripts/combinar_PDFs_gui.ps1)
Añadir soporte de redimensionamiento (Anchors).

#### [MODIFY] [eliminar_paginas_gui.ps1](file:///S:/gastos%20comunes/z.Aplicaciones/Scripts/pdf_scripts/eliminar_paginas_gui.ps1)
Añadir soporte de redimensionamiento (Anchors).

#### [MODIFY] [reducir_peso_REEMPLAZA_drag_and_drop.bat](file:///S:/gastos%20comunes/z.Aplicaciones/Scripts/pdf_scripts/reducir_peso_REEMPLAZA_drag_and_drop.bat)
Uso de la papelera de reciclaje y detección mejorada de Ghostscript.

#### [MODIFY] [escala_grises_REEMPLAZA_drag_and_drop.bat](file:///S:/gastos%20comunes/z.Aplicaciones/Scripts/pdf_scripts/escala_grises_REEMPLAZA_drag_and_drop.bat)
Uso de la papelera de reciclaje y detección mejorada de Ghostscript.

#### [MODIFY] [filename_header_REEMPLAZA_drag_and_drop.bat](file:///S:/gastos%20comunes/z.Aplicaciones/Scripts/pdf_scripts/filename_header_REEMPLAZA_drag_and_drop.bat)
Uso de la papelera de reciclaje.

#### [MODIFY] [setup.bat](file:///S:/gastos%20comunes/z.Aplicaciones/Scripts/pdf_scripts/setup.bat)
Detección de Ghostscript por Registro si falla el PATH.

## Verification Plan
1. Ejecutar las GUIs para comprobar que las ventanas se pueden estirar y los controles se adaptan correctamente.
2. Ejecutar uno de los `.bat` de reemplazo y verificar que el archivo original se encuentre en la papelera de reciclaje de Windows.
3. Probar la ejecución en un entorno donde Ghostscript no esté en el PATH pero sí instalado.
