# Uploads the signing keys and the saved keystore password to the GitHub Actions secrets of the repository, for
# .github/workflows/release.yml. Run it once, and again after changing a key or the password:
#   .\scripts\set-ci-secrets.ps1
#
# Needs the password saved with .\scripts\sign-release.ps1 -SavePassword and a logged-in gh. The values go straight
# from this process to gh (which encrypts them for GitHub); nothing is printed or written to disk.
param(
    [string]$Repo = 'lhh9799/noterly',
    [string]$KeyStore = (Join-Path $PSScriptRoot '..\keys\noterly-release.jks'),
    [string]$Lineage = (Join-Path $PSScriptRoot '..\keys\noterly.lineage'),
    [string]$DebugKeyStore = (Join-Path $env:USERPROFILE '.android\debug.keystore')
)

$ErrorActionPreference = 'Stop'

$passwordFile = Join-Path $env:LOCALAPPDATA 'noterly\keystore-pass.xml'
if (-not (Test-Path $passwordFile)) { throw "No saved password. Run .\scripts\sign-release.ps1 -SavePassword first." }
foreach ($path in @($KeyStore, $Lineage, $DebugKeyStore)) {
    if (-not (Test-Path $path)) { throw "Not found: $path" }
}

function Set-Secret([string]$Name, [string]$Value) {
    gh secret set $Name --repo $Repo --body $Value
    if ($LASTEXITCODE -ne 0) { throw "gh secret set $Name failed ($LASTEXITCODE)" }
}

function Get-Base64([string]$Path) { [Convert]::ToBase64String([IO.File]::ReadAllBytes((Resolve-Path $Path).Path)) }

Set-Secret NOTERLY_RELEASE_KEYSTORE (Get-Base64 $KeyStore)
Set-Secret NOTERLY_LINEAGE (Get-Base64 $Lineage)
Set-Secret NOTERLY_DEBUG_KEYSTORE (Get-Base64 $DebugKeyStore)
Set-Secret NOTERLY_KEYSTORE_PASSWORD ([System.Net.NetworkCredential]::new('', (Import-Clixml -Path $passwordFile)).Password)

Write-Host "Secrets set on $Repo. Check the setup with: gh workflow run release.yml --repo $Repo -f dry_run=true"
