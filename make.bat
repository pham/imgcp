@echo off

IF (%1) == () GOTO PRODUCT
IF (%2) == () GOTO VERSION

FOR /F "tokens=4 delims=/ " %%i IN ("%date%") DO SET "year=%%i"

SET PRODUCT=%1
SET VERSION=%2
SET ICON=--icon icons\%PRODUCT%.ico
SET TRIM=--trim JSON::PP58::;File\Spec\Unix\Unix.dll
SET SWITCHES=--lib lib --norunlib --warnings --force -gui

ECHO.Making %PRODUCT% v%VERSION%...

perlapp %CLEAN% %TRIM% %ICON% %SWITCHES% --info "CompanyName=Aquaron;LegalCopyright=%YEAR%;ProductName=%PRODUCT%;ProductVersion=%VERSION%" --exe %PRODUCT%.exe %PRODUCT%.pl

EXIT /B

:PRODUCT
ECHO.%~0 product version
EXIT /B

:VERSION
ECHO.version needed
EXIT /B

