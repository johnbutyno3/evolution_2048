from pathlib import Path


def replace_if_needed(path: Path, old: str, new: str, marker: str) -> None:
    text = path.read_text(encoding='utf-8-sig')
    if new in text:
        print(f'{marker}: already applied')
        return
    if old not in text:
        raise SystemExit(f'{marker}: marker not found')
    path.write_text(text.replace(old, new, 1), encoding='utf-8')
    print(f'{marker}: applied')


replay = Path('lib/game/services/replay_log.dart')
replace_if_needed(
    replay,
    """  Map<String, dynamic> toJson() => <String, dynamic>{\n        'replayVersion': currentVersion,\n""",
    """  Map<String, dynamic> toJson() => <String, dynamic>{\n        'version': currentVersion,\n        'replayVersion': currentVersion,\n""",
    'ReplayLog toJson',
)
replace_if_needed(
    replay,
    """    final version = raw['replayVersion'];\n""",
    """    final version = raw['version'] ?? raw['replayVersion'];\n""",
    'ReplayLog version parser',
)

page = Path('lib/game/screens/evolution_2048_page.dart')
text = page.read_text(encoding='utf-8-sig')

if 'Future<bool> _ensureGameSession() async {' not in text:
    marker = "  Future<void> _startTool(String mode) async {\n"
    helper = """  Future<bool> _ensureGameSession() async {\n    if (_gameSessionStarting) {\n      while (_gameSessionStarting) {\n        await Future<void>.delayed(const Duration(milliseconds: 20));\n      }\n      return PlayerProgressService.instance.activeGameSessionId != null;\n    }\n\n    if (PlayerProgressService.instance.activeGameSessionId != null) {\n      return true;\n    }\n\n    _gameSessionStarting = true;\n    try {\n      return await PlayerProgressService.instance.startGameSession(\n        _chapterNumber - 1,\n      );\n    } finally {\n      _gameSessionStarting = false;\n    }\n  }\n\n"""
    if marker not in text:
        raise SystemExit('Session helper: marker not found')
    text = text.replace(marker, helper + marker, 1)
    print('Session helper: applied')
else:
    print('Session helper: already applied')

if '_gameSessionStarting' not in text:
    marker = '  Timer? _uiRefreshTimer;\n'
    replacement = '  Timer? _uiRefreshTimer;\n  bool _gameSessionStarting = false;\n'
    if marker not in text:
        raise SystemExit('Session state: marker not found')
    text = text.replace(marker, replacement, 1)
    print('Session state: applied')
else:
    print('Session state: already applied')

old = """  Future<void> _startTool(String mode) async {\n    if (!_engine.hasTools ||\n"""
new = """  Future<void> _startTool(String mode) async {\n    if (!await _ensureGameSession()) {\n      return;\n    }\n\n    if (!_engine.hasTools ||\n"""
if new not in text:
    if old not in text:
        raise SystemExit('Tool gate: marker not found')
    text = text.replace(old, new, 1)
    print('Tool gate: applied')
else:
    print('Tool gate: already applied')

required = [
    "PlayerProgressService.instance.clearGameSession();",
    "unawaited(_ensureGameSession());",
    "if (!await _ensureGameSession())",
    "final completionAccepted =",
]
for marker in required:
    if marker not in text:
        raise SystemExit(f'Required integration missing: {marker}')

page.write_text(text, encoding='utf-8')
print('Game session replay integration checks passed.')
