param(
    [string]$KeystorePath = (Join-Path $env:USERPROFILE '.android\mealmate-offline-release.p12'),
    [string]$KeyAlias = 'mealmate-offline'
)
$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
if (-not (Test-Path -LiteralPath $KeystorePath -PathType Leaf)) {
    throw 'Create your private PKCS12 keystore interactively first. See ANDROID_RELEASE.md.'
}
$signingNames = @('MEALMATE_OFFLINE_KEYSTORE','MEALMATE_OFFLINE_KEY_ALIAS','MEALMATE_OFFLINE_STORE_PASSWORD','MEALMATE_OFFLINE_KEY_PASSWORD','GRADLE_OPTS')
$previous = @{}
foreach ($entry in $signingNames) { $previous[$entry] = [Environment]::GetEnvironmentVariable($entry, 'Process') }
$secret = Read-Host 'Keystore password (hidden; never send it in chat)' -AsSecureString
try {
    [Environment]::SetEnvironmentVariable('MEALMATE_OFFLINE_KEYSTORE', (Resolve-Path -LiteralPath $KeystorePath).Path, 'Process')
    [Environment]::SetEnvironmentVariable('MEALMATE_OFFLINE_KEY_ALIAS', $KeyAlias, 'Process')
    [Environment]::SetEnvironmentVariable('MEALMATE_OFFLINE_STORE_PASSWORD', [System.Net.NetworkCredential]::new('', $secret).Password, 'Process')
    [Environment]::SetEnvironmentVariable('MEALMATE_OFFLINE_KEY_PASSWORD', $env:MEALMATE_OFFLINE_STORE_PASSWORD, 'Process')
    $env:GRADLE_OPTS = ($previous['GRADLE_OPTS'] + ' -Dorg.gradle.daemon=false -Dorg.gradle.configuration-cache=false -Dorg.gradle.project.kotlin.incremental=false -Dorg.gradle.project.kotlin.compiler.execution.strategy=in-process').Trim()
    Push-Location -LiteralPath $projectRoot
    try {
        & flutter build apk --release --flavor offline --target lib/main_offline.dart
        if ($LASTEXITCODE -ne 0) { throw 'Offline release build failed. No APK was installed.' }
        $apk = Join-Path $projectRoot 'build\app\outputs\flutter-apk\app-offline-release.apk'
        Get-Item -LiteralPath $apk | Select-Object FullName, Length, LastWriteTime
    } finally { Pop-Location }
} finally {
    foreach ($entry in $signingNames) { [Environment]::SetEnvironmentVariable($entry, $previous[$entry], 'Process') }
    $secret.Dispose()
}
