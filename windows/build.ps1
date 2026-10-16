# build.ps1 - Compile MouseSave for Windows (Fluent Win11 UI)
$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$binDir = Join-Path $scriptDir "bin"
$srcDir = Join-Path $scriptDir "src"
$outExe = Join-Path $binDir "MouseSave.exe"

$csc = "C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe"
if (!(Test-Path $csc)) {
    $csc = "C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe"
}
if (!(Test-Path $csc)) {
    Write-Error "C# compiler (csc.exe) not found."
}

if (!(Test-Path $binDir)) {
    New-Item -ItemType Directory -Path $binDir -Force | Out-Null
}

Write-Host "Compiling MouseSave for Windows using $csc..."

$sources = @(
    (Join-Path $srcDir "Settings.cs"),
    (Join-Path $srcDir "Localization.cs"),
    (Join-Path $srcDir "StartupHelper.cs"),
    (Join-Path $srcDir "Theme.cs"),
    (Join-Path $srcDir "Controls\ToggleSwitch.cs"),
    (Join-Path $srcDir "Controls\FluentSlider.cs"),
    (Join-Path $srcDir "Controls\FluentButton.cs"),
    (Join-Path $srcDir "Controls\FluentCard.cs"),
    (Join-Path $srcDir "Controls\MouseVisualizer.cs"),
    (Join-Path $srcDir "Controls\ScrollPreviewBox.cs"),
    (Join-Path $srcDir "Controls\ExclusionListView.cs"),
    (Join-Path $srcDir "Controls\FluentMenuRenderer.cs"),
    (Join-Path $srcDir "MouseHook.cs"),
    (Join-Path $srcDir "SettingsForm.cs"),
    (Join-Path $srcDir "Program.cs")
)

$manifest = Join-Path $srcDir "app.manifest"

$args = @(
    "/target:winexe",
    "/optimize+",
    "/platform:anycpu",
    "/r:System.dll",
    "/r:System.Drawing.dll",
    "/r:System.Windows.Forms.dll",
    "/win32manifest:$manifest",
    "/out:$outExe"
) + $sources

& $csc $args

if ($LASTEXITCODE -eq 0 -and (Test-Path $outExe)) {
    Write-Host "Build Successful!" -ForegroundColor Green
    Write-Host "Executable generated: $outExe"
    Get-Item $outExe | Select-Object Name, Length, LastWriteTime
} else {
    Write-Error "Build failed with exit code $LASTEXITCODE"
}
