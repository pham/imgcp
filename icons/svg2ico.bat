@echo off
SET file=%~1
SET name=%~n1
SET width=%~2

IF NOT DEFINED file GOTO FILE
IF NOT DEFINED width SET width=300

WHERE /q inkscape
IF ERRORLEVEL 1 (
  SET inkscape=C:\Program Files\Inkscape\inkscape.exe
  IF NOT EXIST "%inkscape%" SET inkscape=D:\Program Files\Inkscape\inkscape.exe
  IF NOT EXIST "%inkscape%" GOTO INKSCAPE
)

SET inkscape=inkscape.exe

WHERE /q magick
IF ERRORLEVEL 1 (
  ECHO.ImageMagick needed
  EXIT /B 1
)

"%inkscape%" -z -e %name%.png -w %width% %file%

IF "%width%" == "32" (
  magick "%name%.png" -thumbnail 32x32 -strip -quiet %name%.gif 2> nul
) ELSE (
  magick "%name%.png" -define icon:auto-resize="128,64,48,32,16" -strip -quiet "%name%.ico" 2> nul
)

DEL %name%.png


EXIT /B 0

:FILE
ECHO.%~0 image.svg [size]
EXIT /B 1

:INKSCAPE
ECHO.Inkscape needed
EXIT /B 1
