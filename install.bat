<# : Begin batch

@ECHO OFF

net session > NUL 2>&1
IF %ERRORLEVEL% NEQ 0 (
  ECHO Not Administrator
  ECHO Win-R cmd Ctrl-Shift-Enter
  EXIT /B
)

SETLOCAL ENABLEDELAYEDEXPANSION

SET IMGCP=imgcp.exe
SET IMGDEDUP=imgdedup.exe

FOR %%A IN (imgcp.exe imgdedup.exe) DO (
  IF NOT EXIST "%%A" (
      ECHO Run make first to get the executables
      EXIT /B 1
  )
  
  ECHO Copy %%A to %WINDIR%
  COPY /Y %%A %WINDIR% 1>NUL
)

ECHO Select folder for images

FOR /f "delims=" %%I in ('powershell -noprofile "iex (${%~f0} | out-string)"') DO (
    SET FOLDER=%%~I
)

IF DEFINED FOLDER (
  SET FOLDER=%FOLDER:\=\\%
  ECHO Using %FOLDER% for dumping images
) ELSE (
  ECHO Missing Target Folder
  EXIT /B 1
)

(
  ECHO Windows Registry Editor Version 5.00
  ECHO [HKEY_CLASSES_ROOT\Drive\shell\Copy Images\command]
  ECHO @="%%WINDIR%%\\imgcp.exe -source %%1 -target %FOLDER% -auto -ex ind,inp,bin,bdm,cpi,dat,mpl,thm,pod,xml,bnp,int"
)1>imgcp.reg

(
  ECHO Windows Registry Editor Version 5.00
  ECHO [HKEY_LOCAL_MACHINE\SOFTWARE\Classes\Folder\shell\Dedup Images\command]
  ECHO @="%%WINDIR%%\\imgdedup.exe -target %%1"
)1>imgdedup.reg

REGEDIT /S imgcp.reg
REGEDIT /S imgdedup.reg

ENDLOCAL

GOTO :EOF

: end Batch portion / begin PowerShell hybrid chimera #>

Add-Type -AssemblyName System.Windows.Forms
$f = new-object Windows.Forms.FolderBrowserDialog
$f.SelectedPath = "C:\"
$f.Filter = "Private Key File (*.ppk)|*.ppk|All Files (*.*)|*.*"
$f.ShowNewFolderButton = $true
$f.ShowHelp = $false
[void]$f.ShowDialog()
$f.SelectedPath
