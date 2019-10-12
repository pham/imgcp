# Media Files Organizer

I needed a simple program that finds all the images/videos on a memory card and organizes them in folders according to their creation date on my local HD, so I can go back and deal with them later. Nothing was available, so I made one; the result is `imgcp.exe`. After my day of shooting, I would stuff the SD card in the reader and issue the command:

```
imgcp -source E: -target C:\tmp
```

I end up with this directory structure:
```
C:\tmp
|
+-- 20011002-angola-fields (previously copied and tagged)
|
+-- 20011002               (just copied, more/dup Angola fields images)
|   |
|   +-- IMG_0023.JPG
|   +-- VID_202.AVI
|   +-- ...
+-- 20011003               (next day stuff)
```

I ran into the problem of having duplicate images (especially having more than one camera), so I wrote a companion program `imgdedup.exe` to fix this.

```
imgdedup -target C:\tmp
```

# Usage
## imgcp
`imgcp.exe` organizes media files from memory card to HD into `YYYYMMDD` directories based on the files' creation dates.
I made this program to simplify the process of find media files nested somewhere on a memory card and copy them to a *staging* folder according to their creation date on my local HD so that I can process them later.

```
imgcp -source <drive> -target <dir> [-auto] [-test] [-ex <extension-list>]
```

| Switches | Meaning | Example
| --- | --- | ---
| -source | Source drive (e.g. memory card) | `D:`
| -target | Destination folder              | `C:\tmp`
| -ex     | Extensions to ignore            | `-ex xml,html,bin`
| -auto   | Start copying immediately       | 
| -test   | Don't copy anything just report |

## imgdedup
`imgdedup.exe` is a cleanup utility that removes files that have the same names but reside in different subdirectories.
This program is useful if you have large projects where you've copied and organized files on your local drive into their subdirectories then take more pictures but can't remember if you've removed the copied files from the card.

```
imgdedup -target <dir> [-test]
```

## Context-Menu
To enable right-click on an external drive and copy its contents to a designated folder, you need to edit your registry.
Execute the provided `install.bat` (provided that you already downloaded the executables); it copies the `*.exe` to your Windows directory and adds the registry entries for you.

Alternatively you can manually edit the registry by launching `regedit` and add the following values at these locations:

### imgcp
```
[HKEY_CLASSES_ROOT\Drive\shell\Copy Images\command]
%%WINDIR%%\\imgcp.exe -source %%1 -target C:\\tmp -auto -ex ind,inp,bin,bdm,cpi,dat,mpl,thm,pod,xml,bnp,int
```

### imgdedup
```
[HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Folder\shell\Dedup Images\command]
%%WINDIR%%\\imgdedup.exe -target %%1
```

# Building Executables

## Requirements
`imgcp.exe` and `imgdedup.exe` are built using ActiveState [ActivePerl].
These source files have been built and tested using:

* ActivePerl v5.16 (64-bit)
* ActiveState PDK v9.5.1 (64-bit)

Use the Perl Package Manager (PPM) to download these packages:
`Tk`, `Tk-Button`, `Tk-Photo`, `Tk-ProgressBar`, `Tk-Toplevel`, `Tk-Frame`, `Tk-Label`,
`File-Copy`, `File-Path`, `Win32-DriveInfo`.
There might be some I'm missing, but `PerlApp` gives more details when you build.

## Use PerlApp (from PDK)
Inside `perlapp` folder are build files for `PerlApp`. Open these up and hit `Make Executable`.

## Use `make.bat`
The `make.bat` file takes 2 arguments:

```
make imgcp 1.7
make imgdedup 1.2
```

# Making Icons
You can also change icons for the executables by making SVG files.
See `icons` folder, for example.
Building the icons locally, you need the tools detailed below.
Alternatively, you can find online resources to help make the `*.ico` files.

## Requirements
You'll need these tools to make icons:

* [ImageMagick] to convert PNGs to multiple sizes ICO files (and GIF for app icon)
* [Inkscape] to convert SVG to PNG
* [OpenSSL] to encode GIF to Base64

## Build
To make the `imgcp.ico` files use:
```
svg2ico.bat imgcp.svg
```

`makeb64.bat` creates a Base64 string of a 32x32 pixel GIF image for the Windows app icon.
To use this program, create a file similar to `logo.svg` and run the command:
```
makeb64 logo.svg
```
A file called `logo.b64`  is created. Copy this string and edit `lib/BasicWindow.pm` replace the content from `11` to the line with a `.` by itself.

[ActivePerl]: https://www.activestate.com/Products/activeperl
[ImageMagick]: https://imagemagick.org/script/download.php
[Inkscape]: https://inkscape.org/
[OpenSSL]: http://gnuwin32.sourceforge.net/packages/openssl.htm
