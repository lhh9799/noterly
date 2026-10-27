# Re-signs a release APK with the Noterly release key and its rotation lineage (debug key -> release key), so the APK
# installs over builds signed with the old debug key and keeps their data.
#
# Build first:  flutter build apk --release --flavor dev   (in the noterly directory)
# Then run:     .\scripts\sign-release.ps1
#
# The keystore password is asked for on each run, unless it was saved once with -SavePassword:
#   .\scripts\sign-release.ps1 -SavePassword
# That stores it outside the repository, in %LOCALAPPDATA%\noterly\keystore-pass.xml, encrypted with Windows DPAPI so
# only the current Windows user on this PC can read it. Delete that file to go back to being asked.
# The password is only passed to apksigner through an environment variable of this process, so it is never written in
# plain text to a file or the shell history.
param(
    [string]$Flavor = 'dev',
    [string]$KeyStore = (Join-Path $PSScriptRoot '..\keys\noterly-release.jks'),
    [string]$Lineage = (Join-Path $PSScriptRoot '..\keys\noterly.lineage'),
    [string]$Alias = 'noterly',
    [string]$DebugKeyStore = (Join-Path $env:USERPROFILE '.android\debug.keystore'),
    [switch]$SavePassword
)

$ErrorActionPreference = 'Stop'

$passwordFile = Join-Path $env:LOCALAPPDATA 'noterly\keystore-pass.xml'

if ($SavePassword) {
    $secure = Read-Host "Password for $KeyStore (saved for this Windows user)" -AsSecureString
    New-Item -ItemType Directory -Force (Split-Path $passwordFile) | Out-Null
    $secure | Export-Clixml -Path $passwordFile
    Write-Host "Password saved to $passwordFile (DPAPI, this Windows user only)"
    return
}

$apkDir = Join-Path $PSScriptRoot "..\noterly\build\app\outputs\flutter-apk"
$unsigned = Join-Path $apkDir "app-$Flavor-release.apk"
$signed = Join-Path $apkDir "app-$Flavor-release-signed.apk"

foreach ($path in @($unsigned, $KeyStore, $Lineage, $DebugKeyStore)) {
    if (-not (Test-Path $path)) { throw "Not found: $path" }
}

$buildTools = Get-ChildItem "$env:LOCALAPPDATA\Android\Sdk\build-tools" | Sort-Object { [version]$_.Name } | Select-Object -Last 1
$apksigner = Join-Path $buildTools.FullName 'apksigner.bat'

if (Test-Path $passwordFile) {
    $secure = Import-Clixml -Path $passwordFile
} else {
    $secure = Read-Host "Password for $KeyStore" -AsSecureString
}
$env:NOTERLY_KS_PASS = [System.Net.NetworkCredential]::new('', $secure).Password
try {
    # Signers in lineage order, oldest first, as apksigner expects when signing with a rotation lineage
    & $apksigner sign `
        --ks $DebugKeyStore --ks-key-alias androiddebugkey --ks-pass pass:android --key-pass pass:android `
        --next-signer --ks $KeyStore --ks-key-alias $Alias --ks-pass env:NOTERLY_KS_PASS `
        --lineage $Lineage --out $signed $unsigned
    if ($LASTEXITCODE -ne 0) { throw "apksigner sign failed ($LASTEXITCODE)" }
} finally {
    Remove-Item Env:NOTERLY_KS_PASS -ErrorAction SilentlyContinue
}

& $apksigner verify --print-certs --verbose $signed
if ($LASTEXITCODE -ne 0) { throw "apksigner verify failed ($LASTEXITCODE)" }

Write-Host "Signed APK: $signed"
