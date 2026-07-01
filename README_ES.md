[English](README.md) | **Español**

# Creador de ISOS de Windows con UUP Dump + Tiny11 con GitHub Actions

Este repositorio utiliza GitHub Actions para construir imágenes ISO de Windows 11 personalizadas, permite descargar la build que quieras desde UUP, aplicar parches de Tiny11 y personalizar la ISO con tus propios archivos. Todas las ISOs se almacenaran en release, para que puedas tener todas en tu propio repositorio sin ocupar espacio de tu PC.

## Características Principales

- **Descarga la última versión desde UUP:** Mediante la API de UUP puede seleccionar personalizar que versión de Windows, Channel/Ring, Arquitectura e Idioma, en caso que quiera una versión en especifico puede usar el ID de UUP para ser mas especifico.
- **Aplicar Tiny11:** Puede crear una imagen limpia de Windows, una imagen de Tiny11 o Tiny11 Virtual Machine (Tiny11 Core, esta versión no se recomienda para uso en PCs normales).
- **Agregar archivos personalizados en la ISO (`ISOFILES`):** Usando un`autounattend.xml` puedes personalizar mas tu instalación de Windows.
- **Guarda tus ISOs personalizadas en Releases:** Cada ISO que crees sera guardada por partes en la sección Releases de este repositorio, para que puedas tener todas en tu propio repositorio sin ocupar espacio de tu PC.

Opcionalmente tambien puede aplicar compresión de ESD y saltar los requisitos de Windows 11.

## Configuraciones

Puede personalizar lo siguiente:

- **`os_version`**: Windows 10/11.
- **`os_ring`**: Canal de actualizaciones: *Retail*, *Release Preview*, *Beta*, *Dev*, *Canary*.
- **`os_arch`**: *x64* (Intel/AMD) / *arm64* (Snapdragon/NVIDIA).
- **`uup_id`** (Opcional): Si deseas una build especifica puede colocarla aqui, para obtenerlo seleccione una build y copie de la barra de direcciones el ID como se muestra en la imagen:![alt text](<screenshot.webp>).
- **`uup_language`**: El idioma que desea para su imagen, puede ver cual es su region tag en [Microsoft Learn](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/available-language-packs-for-windows?view=windows-11), deberia de seguir un formato asi: en-US (Inglés de Estados Unidos), es-ES (Español de España), es-MX (Español de México), etc.
- **`build_type`**: Define el nivel de modificación de la ISO:
  - *Without any modifications*: Build oficial de Windows.
  - *Tiny11*: Aplica Tiny11.
  - *Tiny11 Virtual Machine*: Aplica Tiny11 Core. Recomendado **UNICAMENTE** para máquinas virtuales de prueba, esta versión no incluye Windows Defender, actualizaciones y puede tener problemas con algunos programas.
- **`esd_compression`**:  Comprime a `.esd`. El tamaño sera menor pero llevara mas tiempo, te recomendamos unicamente no seleccionarlo en caso que desee personalizar su imagen de Windows con NTLite o programas similares .
- **`bypass_reqs`**: Omite los requisitos de instalación de Windows 11.
- **`remove_edge` (Solo en Tiny11, no recomendado)**: Elimina Microsoft Edge. Puede causar problemas con algunas aplicaciones, en caso de no incluirlo puede instalar un navegador mediante Winget.
- **`strip_short_names` (Solo en Tiny11)**: Elimina los nombres cortos 8.3 de compatibilidad DOS (como `PROGRA~1`) de la imagen. Esto ayuda a mantener el sistema más limpio y puede mejorar el rendimiento. [Más información](https://schneegans.de/windows/no-8.3/#wim).
- **Ediciones de Windows (`edition_home`, `edition_pro`, `edition_homen`, `edition_pron`)**: Selecciona las ediciones que desea incluir en su ISO. Si aplica Tiny11 solo puede incluir una edición. Sobre las ediciones Home N/Pro N, no incluyen Windows Media Player/Media Player y otros componentes de reproducción multimedia, no recomendamos su uso para evitar problemas de compatibilidad con algunos programas.

## Inyectar tus propios archivos en tu ISO (o incluir un `autounattend.xml`)

Si quieres personalizar mas tu instalación o realizar una imagen identica para instalar en varios equipos puede colocar archivos en la carpeta `ISOFILES`

Cualquier archivo o carpeta que coloque ahi, se comprimira en la misma ISO. Cada archivo no puede exceder los 25 MB (mediante Git soporta hasta 100 MB).

*Nota: Hay un archivo llamado [Add files.md](./ISOFILES/Add%20files.md) dentro. te recomendamos que lo revises, este archivo no sera incluido en su ISO final.*

## Cómo empezar a usarlo

1. Haz un fork de este repositorio y situate en él.
2. (Opcional) Sube los archivos que desees incluir en ISOFILES.
3. Ve a la pestaña **Actions**.
4. Selecciona **Build Windows 11 Image** en el menú de la izquierda.
5. Haz clic en **Run workflow**.
6. Configure lo que desee.
7. Haz clic en el botón verde **Run workflow**. La creación puede tardar desde unos minutos hasta unas horas.

Una vez finalizado el proceso tienes 90 dias para descargar la ISO desde GitHub Actions Artifacts, tambien puedes encontrar las ISOs en la pestaña **Releases** divididas en partes, en caso que cree una versión de Tiny11 tendra tanto la original como la versión modificada por Tiny11.

Parte del código para obtener versiones mediante la API de UUP fue gracias a [marcinmajsc/uup-dump-build-and-get-windows-iso](https://github.com/marcinmajsc/uup-dump-build-and-get-windows-iso).
