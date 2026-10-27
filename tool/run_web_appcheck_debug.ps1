# Runs the local Flutter Web app with a registered Firebase App Check debug token.
# The token is entered privately, injected into web/index.html only while Flutter runs,
# and never written to Git. The original index.html bytes are restored on exit.

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent $PSScriptRoot)

$indexPath = Join-Path (Get-Location) 'web/index.html'
if (-not (Test-Path -LiteralPath $indexPath)) {
    throw "Cannot find web/index.html. Run this script from the project repository."
}

$originalBytes = [System.IO.File]::ReadAllBytes($indexPath)
$originalText = [System.IO.File]::ReadAllText($indexPath)
$pattern = 'self\.FIREBASE_APPCHECK_DEBUG_TOKEN\s*=\s*true\s*;'
if (-not [regex]::IsMatch($originalText, $pattern)) {
    throw 'Expected the standard App Check debug-token assignment in web/index.html; no file was changed.'
}

$secureToken = Read-Host 'Paste the Firebase App Check debug token (input hidden)' -AsSecureString
$tokenPointer = [IntPtr]::Zero
$token = $null
try {
    $tokenPointer = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureToken)
    $token = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($tokenPointer)
    if ($token -notmatch '^[0-9a-fA-F]{8}-(?:[0-9a-fA-F]{4}-){3}[0-9a-fA-F]{12}$') {
        throw 'Token format is not a UUID. No source file was changed.'
    }

    $replacement = 'self.FIREBASE_APPCHECK_DEBUG_TOKEN = "' + $token + '";'
    $runtimeText = [regex]::Replace($originalText, $pattern, $replacement, 1)
    [System.IO.File]::WriteAllText($indexPath, $runtimeText, [System.Text.UTF8Encoding]::new($false))

    Write-Host 'Starting Flutter Web with the registered token injected before Flutter bootstrap.'
    Write-Host 'Do not commit web/index.html while the app is running. The original file is restored when you stop Flutter.'
    flutter run -d chrome
}
finally {
    [System.IO.File]::WriteAllBytes($indexPath, $originalBytes)
    if ($tokenPointer -ne [IntPtr]::Zero) {
        [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($tokenPointer)
    }
    $token = $null
    if ($secureToken) { $secureToken.Dispose() }
    Write-Host 'Restored the original web/index.html.'
}
