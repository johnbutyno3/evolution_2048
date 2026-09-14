$ErrorActionPreference = 'Stop'

$path = Join-Path $PSScriptRoot '..\lib\game\services\save_manager.dart'
$text = Get-Content -Raw -Encoding UTF8 $path

if ($text -match 'static Future<void> saveToolProgress\(') {
  Write-Host 'saveToolProgress already exists; nothing to do.'
  exit 0
}

$marker = @'
  static Future<void> clear() async {
'@

$method = @'
  /// Persists developer-only global tool progress in the local save root.
  ///
  /// Production tool inventory remains server-authoritative. This helper is
  /// intentionally used only by ToolManager when developer mode is enabled.
  static Future<void> saveToolProgress({
    required Map<String, int> toolUses,
    required List<String> rewardsClaimed,
  }) async {
    if (!kDebugMode) return;
    if (!developerMode) return;

    _preferences ??= await SharedPreferences.getInstance();

    final root = _cachedSave == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(_cachedSave!);

    root['version'] = 1;
    root['savedAt'] = DateTime.now().millisecondsSinceEpoch;
    root['toolUses'] = <String, int>{...toolUses};
    root['toolRewardsClaimed'] = List<String>.from(rewardsClaimed);

    _cachedSave = root;
    await _preferences!.setString(_saveKey, jsonEncode(root));
  }

'@

if (-not $text.Contains($marker)) {
  throw 'Expected SaveManager.clear marker was not found.'
}

$text = $text.Replace($marker, $method + $marker)
Set-Content -Path $path -Value $text -Encoding UTF8 -NoNewline
Write-Host 'SaveManager.saveToolProgress added.'
