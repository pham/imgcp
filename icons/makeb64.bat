@echo off
SET file=%~1
SET name=%~n1

IF NOT EXIST "%file%" (
  ECHO.File %file% does't exist.
  EXIT /B 1
)

IF /I "%~x1"=="svg" (
  ECHO.File %file% must be an .SVG
  EXIT /B 1
)

CALL svg2ico.bat "%file%" 32

WHERE /q openssl

IF ERRORLEVEL 1 (
  ECHO.OpenSSL needed
  ECHO.Try convert %name%.gif to Base64 manually
  EXIT /B 1
)

openssl enc -base64 -in %name%.gif > %name%.b64 2> nul

IF EXIST "%name%.b64" (
REM  DEL %name%.gif
  ECHO.Created %name%.b64
)
