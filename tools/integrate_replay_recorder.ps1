$ErrorActionPreference = 'Stop'

$path = Join-Path (Get-Location) 'lib\game\services\game_engine.dart'
if (-not (Test-Path $path)) { throw "Missing $path" }

$text = Get-Content -Raw -Encoding UTF8 $path

function Replace-Exact([string]$old, [string]$new, [string]$label) {
  if ($script:text.IndexOf($old, [System.StringComparison]::Ordinal) -lt 0) {
    throw "Expected source block not found: $label"
  }
  $script:text = $script:text.Replace($old, $new)
}

function Replace-Regex([string]$pattern, [string]$replacement, [string]$label) {
  $updated = [System.Text.RegularExpressions.Regex]::Replace(
    $script:text,
    $pattern,
    $replacement,
    [System.Text.RegularExpressions.RegexOptions]::Singleline
  )
  if ($updated -eq $script:text) {
    throw "Expected source block not found: $label"
  }
  $script:text = $updated
}

Replace-Exact "import 'tool_manager.dart';" "import 'tool_manager.dart';\nimport 'replay_recorder.dart';" 'imports'

Replace-Exact "    _initializeTools();\n    reset();" "    _initializeTools();\n    _replayRecorder = ReplayRecorder(chapter: _chapter.name);\n    reset();" 'recorder initialization'

Replace-Exact "  late GameBoard _board;\n  late ToolManager _toolManager;" "  late GameBoard _board;\n  late ToolManager _toolManager;\n  late final ReplayRecorder _replayRecorder;" 'recorder field'

Replace-Exact "      'gameTimerStartedAt': _gameTimerStartedAt?.millisecondsSinceEpoch,\n    };" "      'gameTimerStartedAt': _gameTimerStartedAt?.millisecondsSinceEpoch,\n      'replayLog': _replayRecorder.log?.toJson(),\n    };" 'save replay log'

Replace-Exact "    _updateBestScore();\n\n    return true;\n  }\n\n  int _highestStageFromBoard()" "    _replayRecorder.restoreFromSave(data, _board);\n\n    _updateBestScore();\n\n    return true;\n  }\n\n  int _highestStageFromBoard()" 'restore replay log'

Replace-Exact "    if (_board.tiles.every((tile) => tile == null)) {\n      _spawnTile();\n    }\n\n    _saveLocal();" "    var spawnIndex = -1;\n    var spawnValue = -1;\n\n    if (_board.tiles.every((tile) => tile == null)) {\n      final spawned = _spawnTile();\n      if (spawned != null) {\n        spawnIndex = spawned.$1;\n        spawnValue = spawned.$2;\n      }\n    }\n\n    _replayRecorder.recordRevive(\n      row: row,\n      column: column,\n      spawnIndex: spawnIndex >= 0 ? spawnIndex : null,\n      spawnValue: spawnValue >= 0 ? spawnValue : null,\n    );\n\n    _saveLocal();" 'revive recording'

Replace-Regex "(Future<bool> useTimeRewind\(\) async \{[\\s\\S]*?_newEvolutionValuesThisMove\.clear\(\);)\\s*_saveLocal\(\);" '${1}\n\n    _replayRecorder.recordTimeRewind();\n\n    _saveLocal();' 'rewind recording'

Replace-Regex "(Future<bool> usePositionSwap\([\\s\\S]*?_newEvolutionValuesThisMove\.clear\(\);)\\s*_saveLocal\(\);" '${1}\n\n    _replayRecorder.recordPositionSwap(\n      firstRow: firstRow,\n      firstColumn: firstColumn,\n      secondRow: secondRow,\n      secondColumn: secondColumn,\n    );\n\n    _saveLocal();' 'swap recording'

Replace-Exact "    _recordHighestEvolutionValue(source.value);\n\n    _saveLocal();" "    _recordHighestEvolutionValue(source.value);\n\n    _replayRecorder.recordDuplicate(\n      sourceRow: sourceRow,\n      sourceColumn: sourceColumn,\n      targetRow: targetRow,\n      targetColumn: targetColumn,\n    );\n\n    _saveLocal();" 'duplicate recording'

Replace-Exact "  bool moveUp() => _move(_board.moveUp);\n  bool moveDown() => _move(_board.moveDown);\n  bool moveLeft() => _move(_board.moveLeft);\n  bool moveRight() => _move(_board.moveRight);\n\n  bool _move(bool Function() move) {" "  bool moveUp() => _move('up', _board.moveUp);\n  bool moveDown() => _move('down', _board.moveDown);\n  bool moveLeft() => _move('left', _board.moveLeft);\n  bool moveRight() => _move('right', _board.moveRight);\n\n  bool _move(String direction, bool Function() move) {" 'move signatures'

Replace-Exact "      _stopGameTimer();\n\n      _updateBestScore();\n      _saveLocal();\n      return true;\n    }\n\n    if (!_board.isFull) {\n      _spawnTile();\n    }" "      _stopGameTimer();\n\n      _replayRecorder.recordMove(\n        direction: direction,\n        spawnIndex: -1,\n        spawnValue: -1,\n      );\n\n      _updateBestScore();\n      _saveLocal();\n      return true;\n    }\n\n    var spawnIndex = -1;\n    var spawnValue = -1;\n\n    if (!_board.isFull) {\n      final spawned = _spawnTile();\n      if (spawned != null) {\n        spawnIndex = spawned.$1;\n        spawnValue = spawned.$2;\n      }\n    }\n\n    _replayRecorder.recordMove(\n      direction: direction,\n      spawnIndex: spawnIndex,\n      spawnValue: spawnValue,\n    );" 'move recording'

Replace-Exact "  void _spawnTile() {\n    final empty = _board.emptyPositions;\n\n    if (empty.isEmpty) {\n      return;\n    }\n\n    final position = empty[_random.nextInt(empty.length)];\n\n    final value = _random.nextInt(10) == 0 ? 4 : 2;\n\n    _board.setTile(\n      position.row,\n      position.column,\n      GameTile(value: value, chapter: _chapter),\n    );\n\n    _recordHighestEvolutionValue(value);\n  }" "  (int index, int value)? _spawnTile() {\n    final empty = _board.emptyPositions;\n\n    if (empty.isEmpty) {\n      return null;\n    }\n\n    final position = empty[_random.nextInt(empty.length)];\n\n    final value = _random.nextInt(10) == 0 ? 4 : 2;\n\n    _board.setTile(\n      position.row,\n      position.column,\n      GameTile(value: value, chapter: _chapter),\n    );\n\n    _recordHighestEvolutionValue(value);\n\n    return (position.row * boardSize + position.column, value);\n  }" 'spawn return data'

Replace-Exact "    _spawnTile();\n    _spawnTile();\n\n    _saveLocal();" "    _spawnTile();\n    _spawnTile();\n\n    _replayRecorder.start(_board);\n\n    _saveLocal();" 'fresh replay start'

Set-Content -Path $path -Value $text -Encoding UTF8 -NoNewline
Write-Host 'ReplayRecorder integration applied to game_engine.dart.'
Write-Host 'Next: run flutter analyze, then inspect the diff before committing.'
