# Windows 11 ISO Builder UUP Dump + Tiny11 with GitHub Actions

Este repositorio utiliza GitHub Actions para construir imágenes ISO de Windows 11 personalizadas, permite descargar la build que quieras desde UUP, aplicar parches de Tiny11 y personalizar la ISO con tus propios archivos. Todas las ISOs se almacenaran en release, para que puedas tener todas en tu propio repositorio sin ocupar espacio de tu PC.

## Características Principales

- **Descarga la última versión desde UUP:** Mediante la API de UUP puede seleccionar personalizar que versión de Windows, Channel/Ring, Arquitectura e Idioma, en caso que quiera una versión en especifico puede usar el ID de UUP para ser mas especifico.
- **Aplicar Tiny11:** Puede crear una imagen limpia de Windows, una imagen de Tiny11 o Tiny11 Virtual Machine (Tiny11 Core, esta versión no se recomienda para uso en PCs normales).
- **Agregar archivos personalizados en la ISO (`ISOFILES`):** Usando un`autounattend.xml` puedes personalizar mas tu instalación de Windows, te recomendamos que revises [Add files.md](./ISOFILES/Add%20files.md).

Opcionalmente tambien puede aplicar compresión de ESD y saltar los requisitos de Windows 11.
---

## ⚙️ Opciones disponibles (Configuración del Workflow)

Al presionar **Run workflow** en la pestaña de Actions, tendrás disponibles las siguientes opciones para configurar exactamente qué ISO deseas generar:

- **`os_version`**: Windows 10/11.
- **`os_ring`**: Canal de actualizaciones: *Retail*, *Release Preview*, *Beta*, *Dev*, *Canary*.
- **`os_arch`**: *x64* (Intel/AMD) / *arm64* (Snapdragon/NVIDIA).
- **`uup_id`** (Opcional): Si deseas una build especifica puede colocarla aqui, para obtenerlo seleccione una build y copie de la barra de direcciones el ID como se muestra en la imagen:![alt text](<screenshot.png>).
- **`uup_language`**: El idioma que desea para su imagen, puede ver cual es su region tag en [Microsoft Learn](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/available-language-packs-for-windows?view=windows-11), deberia de seguir un formato asi: en-US (Inglés de Estados Unidos), es-ES (Español de España), es-MX (Español de México), etc.
- **`build_type`**: Define el nivel de modificación de la ISO:
  - *Without any modifications*: Build oficial de Windows.
  - *Tiny11*: Aplica Tiny11.
  - *Tiny11 Virtual Machine*: Aplica Tiny11 Core. Recomendado **UNICAMENTE** para máquinas virtuales de prueba, esta versión no incluye Windows Defender, actualizaciones y puede tener problemas con algunos programas.
- **`esd_compression`**:  Comprime a `.esd`. El tamaño sera menor pero llevara mas tiempo, te recomendamos unicamente no seleccionarlo en caso que desee personalizar su imagen de Windows con NTLite o programas similares .
- **`bypass_reqs`**: Omite los requisitos de instalación de Windows 11. Solo aplica si usas la opción *Tiny11*.
- **Ediciones de Windows (`edition_home`, `edition_pro`, `edition_homen`, `edition_pron`)**: Selecciona las ediciones que desea incluir en su ISO. Si aplica Tiny11 solo puede incluir una edición. Sobre las ediciones Home N/Pro N, no incluyen Windows Media Player/Media Player y otros componentes de reproducción multimedia, no recomendamos su uso para evitar problemas de compatibilidad con algunos programas.

---

## Inyectar tus propios archivos en tu ISO (o incluir un `autounattend.xml`)

Si quieres personalizar mas tu instalación o realizar una imagen identica para instalar en varios equipos puede colocar archivos en la carpeta `ISOFILES`:

1. Dirígete a la carpeta `ISOFILES` en la raíz de este repositorio.
2. Sube allí los archivos o carpetas que quieras inyectar. Cada archivo no puede exceder los 100 MB 
3. *Nota: Hay un archivo llamado `Add files.md` allí dentro. Su única función es evitar que Git borre la carpeta vacía; será ignorado automáticamente durante la inyección.*
4. ¡Listo! Al correr el Workflow (cualquiera de los 3 tipos de build), el sistema detectará tus archivos y los copiará de forma nativa a la raíz de la ISO terminada.

Si inyectas un archivo `autounattend.xml` personalizado, este tendrá prioridad absoluta y sobreescribirá cualquier configuración predeterminada de Tiny11, permitiéndote automatizar tu instalación de principio a fin.

---

## Cómo empezar a usarlo

1. Ve a la pestaña **Actions** en tu repositorio de GitHub.
2. Selecciona **Build Windows 11 Image** en el menú de la izquierda.
3. Haz clic en **Run workflow**.
4. Rellena los datos (URL de UUP, Tipo de build, y si deseas compresión ESD).
5. Haz clic en el botón verde **Run workflow** y ¡relájate! 

El servidor de GitHub se encargará de todo. Una vez finalizado el proceso (suele tomar entre 20 a 45 minutos dependiendo de la compresión), podrás dirigirte a la sección **Releases** de este repositorio para descargar tu nueva y reluciente ISO de Windows 11.
