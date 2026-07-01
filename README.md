**English** | [Español](README_ES.md)

# Windows ISO Builder UUP Dump + Tiny11 with GitHub Actions

This repository uses GitHub Actions to build custom Windows 11 ISO images. It allows you to download any build you want from UUP, apply Tiny11 patches, and customize the ISO with your own files. All ISOs will be stored in releases, so you can have them all in your own repository without taking up space on your PC.

## Key Features

- **Download the latest version from UUP:** Through the UUP API, you can customize which Windows version, Channel/Ring, Architecture, and Language you want. If you want a specific version, you can use the UUP ID to be more precise.
- **Apply Tiny11:** You can create a clean Windows image, a Tiny11 image, or a Tiny11 Virtual Machine (Tiny11 Core; this version is not recommended for use on normal PCs).
- **Add custom files to the ISO (`ISOFILES`):** Using an `autounattend.xml` you can further customize your Windows installation.
- **Save your custom ISOs in Releases:** Every ISO you create will be saved in parts in the Releases section of this repository, so you can have them all in your own repository without taking up space on your PC. They will also be available for 90 days without being split into parts as an Artifact in the Workflow that generated it.

Optionally, you can also apply ESD compression and bypass Windows 11 requirements.

## Configurations

You can customize the following:

- **`os_version`**: Windows 10/11.
- **`os_ring`**: Update channel: *Retail*, *Release Preview*, *Beta*, *Dev*, *Canary*.
- **`os_arch`**: *x64* (Intel/AMD) / *arm64* (Snapdragon/NVIDIA).
- **`uup_id`** (Optional): If you want a specific build, you can place its ID here. To get it, select a build and copy the ID from the address bar as shown in the image: ![alt text](<screenshot.webp>).
- **`uup_language`**: The language you want for your image. You can see your region tag on [Microsoft Learn](https://learn.microsoft.com/en-us/windows-hardware/manufacture/desktop/available-language-packs-for-windows?view=windows-11). It should follow a format like: en-US (English - United States), es-ES (Spanish - Spain), es-MX (Spanish - Mexico), etc.
- **`build_type`**: Defines the level of ISO modification:
  - *Without any modifications*: Official Windows build.
  - *Tiny11*: Applies Tiny11.
  - *Tiny11 Virtual Machine*: Applies Tiny11 Core. Recommended **ONLY** for testing virtual machines. This version does not include Windows Defender, updates, and may have issues with some programs.
- **`esd_compression`**: Compresses to `.esd`. The size will be smaller but it will take more time. We recommend not selecting it only if you want to customize your Windows image with NTLite or similar programs.
- **`bypass_reqs`**: Bypasses Windows 11 installation requirements (works for both original and modified builds).
- **Windows Editions (`edition_home`, `edition_pro`, `edition_homen`, `edition_pron`)**: Select the editions you want to include in your ISO. If you apply Tiny11, you can only include one edition. Regarding the Home N/Pro N editions, they do not include Windows Media Player/Media Player and other media playback components. We do not recommend using them to avoid compatibility issues with some programs.

## Inject your own files into your ISO (or include an `autounattend.xml`)

If you want to further customize your installation or create an identical image to install on multiple computers, you can place files in the `ISOFILES` folder.

Any file or folder you place there will be compressed into the same ISO. Each file cannot exceed 25 MB (via Git it supports up to 100 MB).

*Note: There is a file called [Add files.md](./ISOFILES/Add%20files.md) inside. We recommend you review it; this file will not be included in your final ISO.*

## How to get started

1. Fork this repository and navigate to it.
2. (Optional) Upload the files you want to include in ISOFILES.
3. Go to the **Actions** tab.
4. Select **Build Windows 11 Image** from the left menu.
5. Click on **Run workflow**.
6. Configure as desired.
7. Click the green **Run workflow** button. Creation can take anywhere from a few minutes to a few hours.

Once the process is finished, you have 90 days to download the ISO from GitHub Actions Artifacts. You can also find the ISOs in the **Releases** tab divided into parts. If you create a Tiny11 version, you will have both the original and the version modified by Tiny11.

Part of the code to get versions through the UUP API was thanks to [marcinmajsc/uup-dump-build-and-get-windows-iso](https://github.com/marcinmajsc/uup-dump-build-and-get-windows-iso).