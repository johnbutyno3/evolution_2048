param(
    [Parameter(Mandatory = $true)]
    [string]$ExportPath,
    [Parameter(Mandatory = $true)]
    [string]$MappingPath,
    [switch]$Execute
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $ExportPath -PathType Leaf)) { throw "Export file not found: $ExportPath" }
if (-not (Test-Path -LiteralPath $MappingPath -PathType Leaf)) { throw "Identity mapping CSV not found: $MappingPath" }
if ([string]::IsNullOrWhiteSpace($env:SUPABASE_URL)) { throw 'Set SUPABASE_URL before running this script.' }
if ([string]::IsNullOrWhiteSpace($env:SUPABASE_ACCESS_TOKEN)) { throw 'Set SUPABASE_ACCESS_TOKEN to an authenticated Supabase admin access token.' }
if ([string]::IsNullOrWhiteSpace($env:SUPABASE_PUBLISHABLE_KEY)) { throw 'Set SUPABASE_PUBLISHABLE_KEY to the project publishable key.' }

$export = Get-Content -LiteralPath $ExportPath -Raw | ConvertFrom-Json
if ($export.format -ne 'rebirth2048-firebase-account-export-v1') { throw 'Unsupported Firebase export format.' }
$mappingRows = @(Import-Csv -LiteralPath $MappingPath)
if ($mappingRows.Count -eq 0) { throw 'The identity mapping CSV is empty.' }

$accountByUid = @{}
foreach ($account in $export.accounts) {
    if ([string]::IsNullOrWhiteSpace($account.legacyUid) -or $accountByUid.ContainsKey([string]$account.legacyUid)) {
        throw 'The export contains an empty or duplicate Firebase UID.'
    }
    $accountByUid[[string]$account.legacyUid] = $account
}

$seenLegacy = @{}
$seenSupabase = @{}
$prepared = @()
foreach ($row in $mappingRows) {
    $legacyUid = ([string]$row.legacyUid).Trim()
    $userId = ([string]$row.userId).Trim()
    $method = ([string]$row.verificationMethod).Trim()

    if ([string]::IsNullOrWhiteSpace($legacyUid) -or
        $userId -notmatch '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-8][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$' -or
        $method -notin @('dual_account_proof', 'support_verified', 'operator_verified')) {
        throw "Invalid mapping row for Firebase UID '$legacyUid'."
    }
    if ($seenLegacy.ContainsKey($legacyUid) -or $seenSupabase.ContainsKey($userId)) {
        throw 'Mapping CSV contains duplicate Firebase UID or Supabase user UUID.'
    }
    if (-not $accountByUid.ContainsKey($legacyUid)) { throw "Firebase UID '$legacyUid' is not present in the export." }

    $account = $accountByUid[$legacyUid]
    if (@($account.validationErrors).Count -gt 0) {
        throw "Account '$legacyUid' has validation errors: $(@($account.validationErrors) -join ', ')"
    }
    if ($account.sourceSha256 -notmatch '^[a-f0-9]{64}$') { throw "Account '$legacyUid' has an invalid source checksum." }

    $seenLegacy[$legacyUid] = $true
    $seenSupabase[$userId] = $true
    $prepared += [pscustomobject]@{
        LegacyUid = $legacyUid
        UserId = $userId
        VerificationMethod = $method
        Account = $account
    }
}

Write-Host "Export accounts: $($accountByUid.Count)"
Write-Host "Verified mappings supplied: $($prepared.Count)"
Write-Host "Accounts with validation errors: $(@($export.accounts | Where-Object { @($_.validationErrors).Count -gt 0 }).Count)"
if (-not $Execute) {
    Write-Host 'DRY RUN ONLY. No Supabase requests were sent.'
    Write-Host 'Review the mapping CSV and verification evidence. Add -Execute only when ready.'
    exit 0
}

$baseUrl = $env:SUPABASE_URL.TrimEnd('/')
$headers = @{
    Authorization = "Bearer $($env:SUPABASE_ACCESS_TOKEN)"
    apikey = $env:SUPABASE_PUBLISHABLE_KEY
}
$completed = 0

foreach ($item in $prepared) {
    $linkBody = @{
        legacyUid = $item.LegacyUid
        userId = $item.UserId
        verificationMethod = $item.VerificationMethod
    } | ConvertTo-Json -Depth 10 -Compress

    $linkResponse = Invoke-RestMethod -Method Post -Uri "$baseUrl/functions/v1/register-legacy-identity-link" -Headers $headers -ContentType 'application/json' -Body $linkBody

    $importBody = @{
        legacyUid = $item.LegacyUid
        sourceSha256 = $item.Account.sourceSha256
        payload = $item.Account.importPayload
    } | ConvertTo-Json -Depth 100 -Compress

    $result = Invoke-RestMethod -Method Post -Uri "$baseUrl/functions/v1/import-legacy-account" -Headers $headers -ContentType 'application/json' -Body $importBody

    if ($result.imported -ne $true -and $result.duplicate -ne $true) {
        throw "Import did not confirm success for Firebase UID '$($item.LegacyUid)'."
    }
    $completed += 1
    $status = if ($result.imported -eq $true) { 'imported' } else { 'already imported' }
    Write-Host "Processed $completed/$($prepared.Count): $($item.LegacyUid) -> $status"
}

Write-Host "Finished. Confirmed imports or safe duplicates: $completed"
Write-Host 'Reconcile Supabase account snapshots against the frozen export before cutover.'
