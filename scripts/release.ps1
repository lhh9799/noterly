# Builds the release APK and signs it with the release key, in one go:
#   .\scripts\release.ps1
#
# Android Gradle refuses a project path with non-ASCII characters, so the build runs from a drive letter mapped to
# the repository with subst (created here if it is missing). Signing uses scripts\sign-release.ps1, which asks for the
# keystore password unless it was saved once with: .\scripts\sign-release.ps1 -SavePassword
param(
    [string]$Flavor = 'dev',
    [string]$Drive = 'X:',
    [string]$JavaHome = 'C:\Program Files\Java\jdk-17'
)

$ErrorActionPreference = 'Stop'

$repo = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$mappedScript = "$Drive\scripts\release.ps1"

if (-not (Test-Path "$Drive\")) {
    subst $Drive $repo
    if ($LASTEXITCODE -ne 0) { throw "subst $Drive failed ($LASTEXITCODE)" }
}
# The drive letter must point at this repository, not another folder
if (-not (Test-Path $mappedScript) -or (Get-FileHash $mappedScript).Hash -ne (Get-FileHash $PSCommandPath).Hash) {
    throw "$Drive is already used for another folder; pass a free drive letter with -Drive"
}

$env:JAVA_HOME = $JavaHome

Push-Location "$Drive\noterly"
try {
    flutter build apk --release --flavor $Flavor
    if ($LASTEXITCODE -ne 0) { throw "flutter build failed ($LASTEXITCODE)" }
} finally {
    Pop-Location
}

& "$Drive\scripts\sign-release.ps1" -Flavor $Flavor
