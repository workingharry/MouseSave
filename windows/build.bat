@echo off
setlocal
set "BIN_DIR=%~dp0bin"
set "SRC_DIR=%~dp0src"
set "OUT_EXE=%BIN_DIR%\MouseSave.exe"
set "CSC=%SystemRoot%\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if not exist "%CSC%" set "CSC=%SystemRoot%\Microsoft.NET\Framework\v4.0.30319\csc.exe"
if not exist "%BIN_DIR%" mkdir "%BIN_DIR%"
echo Compiling MouseSave for Windows...
"%CSC%" /target:winexe /optimize+ /platform:anycpu /r:System.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll /out:"%OUT_EXE%" "%SRC_DIR%\Settings.cs" "%SRC_DIR%\Localization.cs" "%SRC_DIR%\StartupHelper.cs" "%SRC_DIR%\MouseHook.cs" "%SRC_DIR%\SettingsForm.cs" "%SRC_DIR%\Program.cs"
if %ERRORLEVEL% equ 0 (
    echo [SUCCESS] MouseSave.exe created at %OUT_EXE%
) else (
    echo [FAILED] Compilation failed with error %ERRORLEVEL%
)