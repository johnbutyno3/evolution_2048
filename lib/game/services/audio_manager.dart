import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import '../models/game_tile.dart';
import '../models/tools/game_tool.dart';

enum GameSfx {
  buttonClick,
  buttonCancel,
  menuOpen,
  menuClose,
  tileMove,
  tileMerge,
  toolSelect,
  gameOver,
  chapterUnlock,
}

class AudioManager {
  AudioManager._();

  static final AudioManager instance = AudioManager._();

  // ============================================================
  // Players
  // ============================================================

  final AudioPlayer _bgmPlayer = AudioPlayer();

  static const Map<GameSfx, int> _sfxPlayerCounts = {
    GameSfx.tileMove: 4,
    GameSfx.tileMerge: 4,
  };

  final Map<GameSfx, List<AudioPlayer>> _sfxPlayers = {
    for (final sfx in GameSfx.values.where(
      (sfx) => _sfxPlayerCounts.containsKey(sfx),
    ))
      sfx: List<AudioPlayer>.generate(
        _sfxPlayerCounts[sfx]!,
        (_) => AudioPlayer(),
      ),
  };
  final Map<GameSfx, AudioPlayer> _singleSfxPlayers = {
    for (final sfx in GameSfx.values.where(
      (sfx) => !_sfxPlayerCounts.containsKey(sfx),
    ))
      sfx: AudioPlayer(),
  };
  final Map<GameSfx, int> _nextSfxPlayer = <GameSfx, int>{};

  // ============================================================
  // Volume / state
  // ============================================================

  double _musicVolume = 0.35;
  double _sfxVolume = 0.55;

  bool _musicEnabled = true;
  bool _sfxEnabled = true;
  bool _initialized = false;
  Future<void>? _initializationFuture;

  GameChapter? _currentChapter;

  double get musicVolume => _musicVolume;
  double get sfxVolume => _sfxVolume;

  bool get musicEnabled => _musicEnabled;
  bool get sfxEnabled => _sfxEnabled;

  // ============================================================
  // Assets
  // ============================================================

  static const Map<GameChapter, String> _chapterMusic = {
    GameChapter.ocean: 'audio/chapter/chapter_01_ocean.mp3',
    GameChapter.land: 'audio/chapter/chapter_02_land.mp3',
    GameChapter.sky: 'audio/chapter/chapter_03_sky.mp3',
    GameChapter.history: 'audio/chapter/chapter_04_history.mp3',
    GameChapter.tech: 'audio/chapter/chapter_05_technology.mp3',
    GameChapter.universe: 'audio/chapter/chapter_06_universe.mp3',
  };

  static const Map<GameSfx, String> _sfxAssets = {
    GameSfx.buttonClick: 'audio/ui/button_click.mp3',
    GameSfx.buttonCancel: 'audio/ui/button_cancel.mp3',
    GameSfx.menuOpen: 'audio/ui/menu_open.mp3',
    GameSfx.menuClose: 'audio/ui/menu_close.mp3',
    GameSfx.tileMove: 'audio/gameplay/tile_move.mp3',
    GameSfx.tileMerge: 'audio/gameplay/tile_merge.mp3',
    GameSfx.toolSelect: 'audio/tools/tool_select.mp3',
    GameSfx.gameOver: 'audio/system/game_over.mp3',
    GameSfx.chapterUnlock: 'audio/chapter/chapter_unlock.mp3',
  };

  // ============================================================
  // Android / cross-platform audio contexts
  // ============================================================

  AudioContext get _musicAudioContext {
    return AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: false,
        contentType: AndroidContentType.music,
        usageType: AndroidUsageType.media,
        audioFocus: AndroidAudioFocus.gain,
      ),
      iOS: AudioContextIOS(category: AVAudioSessionCategory.playback),
    );
  }

  AudioContext get _sfxAudioContext {
    return AudioContext(
      android: const AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: false,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.game,
        audioFocus: AndroidAudioFocus.gainTransientMayDuck,
      ),
      iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
    );
  }

  // ============================================================
  // Initialization
  // ============================================================

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    final existingInitialization = _initializationFuture;
    if (existingInitialization != null) {
      return existingInitialization;
    }

    final initialization = _initializePlayers();
    _initializationFuture = initialization;
    await initialization;
  }

  Future<void> _initializePlayers() async {
    try {
      // ----------------------------------------------------------
      // BGM
      // ----------------------------------------------------------

      await _bgmPlayer.setPlayerMode(PlayerMode.mediaPlayer);
      await _bgmPlayer.setAudioContext(_musicAudioContext);
      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(_musicVolume);

      // ----------------------------------------------------------
      // SFX
      //
      // Keep one stable player per sound effect.
      // No AudioPool and no lowLatency mode are used.
      // This avoids keeping a large number of Android native
      // audio players alive during long gameplay sessions.
      // ----------------------------------------------------------

      final sfxPlayers = [
        ..._sfxPlayers.values.expand((players) => players),
        ..._singleSfxPlayers.values,
      ];

      for (final player in sfxPlayers) {
        await player.setPlayerMode(PlayerMode.mediaPlayer);
        await player.setAudioContext(_sfxAudioContext);
        await player.setReleaseMode(ReleaseMode.release);
        await player.setVolume(_sfxVolume);
      }

      _initialized = true;

      debugPrint('AudioManager: initialized successfully');
    } catch (e, stackTrace) {
      debugPrint('AudioManager initialize error: $e');
      debugPrint('$stackTrace');
    }
  }

  // ============================================================
  // Chapter BGM
  // ============================================================

  Future<void> playChapterMusic(GameChapter chapter) async {
    if (!_musicEnabled) {
      return;
    }

    await initialize();

    final asset = _chapterMusic[chapter];

    if (asset == null) {
      debugPrint('AudioManager: no BGM asset for $chapter');
      return;
    }

    if (_currentChapter == chapter && _bgmPlayer.state == PlayerState.playing) {
      return;
    }

    try {
      await _bgmPlayer.stop();

      await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
      await _bgmPlayer.setVolume(_musicVolume);

      await _bgmPlayer.play(AssetSource(asset), mode: PlayerMode.mediaPlayer);

      _currentChapter = chapter;

      debugPrint('AudioManager: playing BGM $asset');
    } catch (e, stackTrace) {
      debugPrint('AudioManager BGM error [$asset]: $e');
      debugPrint('$stackTrace');
    }
  }

  Future<void> stopMusic() async {
    try {
      await _bgmPlayer.stop();
      _currentChapter = null;
    } catch (e) {
      debugPrint('AudioManager stopMusic error: $e');
    }
  }

  Future<void> pauseMusic() async {
    try {
      if (_bgmPlayer.state == PlayerState.playing) {
        await _bgmPlayer.pause();
      }
    } catch (e) {
      debugPrint('AudioManager pauseMusic error: $e');
    }
  }

  Future<void> resumeMusic() async {
    if (!_musicEnabled) {
      return;
    }

    try {
      if (_bgmPlayer.state == PlayerState.paused) {
        await _bgmPlayer.resume();
      }
    } catch (e) {
      debugPrint('AudioManager resumeMusic error: $e');
    }
  }

  // ============================================================
  // SFX
  // ============================================================

  Future<void> playSfx(GameSfx sfx) {
    if (!_sfxEnabled) {
      return Future<void>.value();
    }

    if (!_initialized) {
      unawaited(initialize());
    }

    final asset = _sfxAssets[sfx];

    if (asset == null) {
      debugPrint('AudioManager: no SFX asset for $sfx');
      return Future<void>.value();
    }

    final players = _sfxPlayers[sfx];
    final singlePlayer = _singleSfxPlayers[sfx];

    if (players == null && singlePlayer == null) {
      return Future<void>.value();
    }

    try {
      final player = _nextAvailableSfxPlayer(sfx);
      if (player == null) {
        return Future<void>.value();
      }

      unawaited(player.play(AssetSource(asset), mode: PlayerMode.mediaPlayer));

      debugPrint('AudioManager: playing SFX $asset');
    } catch (e, stackTrace) {
      debugPrint('AudioManager SFX error [$asset]: $e');
      debugPrint('$stackTrace');
    }

    return Future<void>.value();
  }

  // ============================================================
  // SFX that must finish before continuing
  // ============================================================

  Future<void> playSfxAndWait(GameSfx sfx) async {
    if (!_sfxEnabled) {
      return;
    }

    await initialize();

    final asset = _sfxAssets[sfx];
    final player = _singleSfxPlayers[sfx] ?? _sfxPlayers[sfx]?.first;

    if (asset == null || player == null) {
      return;
    }

    try {
      await player.stop();

      final completion = player.onPlayerComplete.first;

      await player.play(AssetSource(asset), mode: PlayerMode.mediaPlayer);

      await completion;

      debugPrint('AudioManager: completed SFX $asset');
    } catch (e, stackTrace) {
      debugPrint('AudioManager SFX error [$asset]: $e');
      debugPrint('$stackTrace');
    }
  }

  AudioPlayer? _nextAvailableSfxPlayer(GameSfx sfx) {
    final players = _sfxPlayers[sfx];
    if (players == null) {
      return _singleSfxPlayers[sfx];
    }

    final start = _nextSfxPlayer[sfx] ?? 0;
    for (var offset = 0; offset < players.length; offset++) {
      final index = (start + offset) % players.length;
      final player = players[index];
      if (player.state != PlayerState.playing &&
          player.state != PlayerState.paused) {
        _nextSfxPlayer[sfx] = (index + 1) % players.length;
        return player;
      }
    }

    final player = players[start % players.length];
    _nextSfxPlayer[sfx] = (start + 1) % players.length;
    return player;
  }

  // ============================================================
  // Volume
  // ============================================================

  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume.clamp(0.0, 1.0);

    try {
      await _bgmPlayer.setVolume(_musicVolume);
    } catch (e) {
      debugPrint('AudioManager setMusicVolume error: $e');
    }
  }

  Future<void> setSfxVolume(double volume) async {
    _sfxVolume = volume.clamp(0.0, 1.0);

    try {
      final sfxPlayers = [
        ..._sfxPlayers.values.expand((players) => players),
        ..._singleSfxPlayers.values,
      ];
      for (final player in sfxPlayers) {
        await player.setVolume(_sfxVolume);
      }
    } catch (e) {
      debugPrint('AudioManager setSfxVolume error: $e');
    }
  }

  // ============================================================
  // Enable / disable
  // ============================================================

  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;

    if (!enabled) {
      await _bgmPlayer.stop();
      return;
    }

    final chapter = _currentChapter;

    if (chapter != null) {
      _currentChapter = null;
      await playChapterMusic(chapter);
    }
  }

  Future<void> setSfxEnabled(bool enabled) async {
    _sfxEnabled = enabled;
  }

  // ============================================================
  // Tools
  // ============================================================

  Future<void> playToolButton(GameToolType type) async {
    await playSfx(GameSfx.toolSelect);
  }

  // ============================================================
  // Dispose
  // ============================================================

  Future<void> dispose() async {
    try {
      await _bgmPlayer.dispose();

      final sfxPlayers = [
        ..._sfxPlayers.values.expand((players) => players),
        ..._singleSfxPlayers.values,
      ];
      for (final player in sfxPlayers) {
        await player.dispose();
      }

      _initialized = false;
      _currentChapter = null;
    } catch (e) {
      debugPrint('AudioManager dispose error: $e');
    }
  }
}
