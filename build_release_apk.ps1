param(
    [string]$FlutterPath = ""
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $projectRoot

function Resolve-FlutterCommand {
    param([string]$ProvidedPath)

    if ($ProvidedPath) {
        if (Test-Path $ProvidedPath) {
            return (Resolve-Path $ProvidedPath).Path
        }
    }

    $command = Get-Command flutter -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    $candidates = @(
        $env:FLUTTER_ROOT,
        $env:FLUTTER_HOME,
        "C:\flutter\bin\flutter.bat",
        "C:\src\flutter\bin\flutter.bat",
        "$env:USERPROFILE\flutter\bin\flutter.bat",
        "$env:USERPROFILE\Desktop\flutter\bin\flutter.bat",
        "$env:USERPROFILE\fvm\default\bin\flutter.bat"
    ) | Where-Object { $_ -and $_.Trim() -ne "" }

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return (Resolve-Path $candidate).Path
        }
    }

    return $null
}

$flutter = Resolve-FlutterCommand -ProvidedPath $FlutterPath
if (-not $flutter) {
    Write-Host "Flutter SDK not found." -ForegroundColor Red
    Write-Host "Install Flutter or pass the full path like:" -ForegroundColor Yellow
    Write-Host "powershell -ExecutionPolicy Bypass -File .\build_release_apk.ps1 -FlutterPath C:\flutter\bin\flutter.bat"
    exit 1
}

Write-Host "Using Flutter: $flutter" -ForegroundColor Cyan
& $flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "flutter pub get failed." -ForegroundColor Red
    exit $LASTEXITCODE
}

& $flutter build apk --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "APK build failed." -ForegroundColor Red
    exit $LASTEXITCODE
}

$apkPath = Join-Path $projectRoot "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkPath) {
    Write-Host "APK created successfully:" -ForegroundColor Green
    Write-Host $apkPath
} else {
    Write-Host "Build finished but APK file was not found at the expected path." -ForegroundColor Yellow
    exit 1
}
