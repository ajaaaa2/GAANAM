import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../service/api_service.dart';

enum NotifierState { initial, loading, loaded, error }

class MusicProvider extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final AudioPlayer _player = AudioPlayer();

  // State for the main song list
  NotifierState _state = NotifierState.initial;
  NotifierState get state => _state;

  List<Song> _songs = [];
  List<Song> get songs => _songs;

  // State for playlists
  NotifierState _playlistState = NotifierState.initial;
  NotifierState get playlistState => _playlistState;

  List<Playlist> _playlists = [];
  List<Playlist> get playlists => _playlists;

  Song? _currentSong;
  Song? get currentSong => _currentSong;

  bool get isPlaying => _player.playing;

  StreamSubscription<int?>? _currentIndexSubscription;
  bool _isDisposed = false;

  // Expose streams for UI
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;

  // Expose player for direct access
  AudioPlayer get player => _player;

  // Shuffle and Loop states
  bool _isShuffleEnabled = false;
  bool get isShuffleEnabled => _isShuffleEnabled;

  LoopMode _loopMode = LoopMode.off;
  LoopMode get loopMode => _loopMode;

  /// Initialize provider, load preferences, and fetch initial data
  Future<void> initialize() async {
    await _loadPreferences();
    await fetchPlaylists();
  }

  /// Load saved preferences from SharedPreferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isShuffleEnabled = prefs.getBool('shuffle_enabled') ?? false;
      final loopModeIndex = prefs.getInt('loop_mode') ?? 0;
      _loopMode = LoopMode.values[loopModeIndex.clamp(0, 2)];

      await _player.setShuffleModeEnabled(_isShuffleEnabled);
      await _player.setLoopMode(_loopMode);
    } catch (e) {
      debugPrint('⚠️ Error loading preferences: $e');
    }
  }

  /// Save preferences to SharedPreferences
  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('shuffle_enabled', _isShuffleEnabled);
      await prefs.setInt('loop_mode', _loopMode.index);
    } catch (e) {
      debugPrint('⚠️ Error saving preferences: $e');
    }
  }

  // --- Song Management ---

  void _setState(NotifierState state) {
    if (_isDisposed) return;
    _state = state;
    notifyListeners();
  }

  /// Fetch all songs from Firestore
  Future<void> fetchMusic() async {
    _setState(NotifierState.loading);
    try {
      _songs = await _apiService.fetchSongs();
      _setState(NotifierState.loaded);
    } catch (e) {
      debugPrint('⚠️ Error fetching songs: $e');
      _setState(NotifierState.error);
    }
  }

  // --- Playlist Management ---

  void _setPlaylistState(NotifierState state) {
    if (_isDisposed) return;
    _playlistState = state;
    notifyListeners();
  }

  /// Fetch all playlists from Firestore
  Future<void> fetchPlaylists() async {
    _setPlaylistState(NotifierState.loading);
    try {
      _playlists = await _apiService.fetchPlaylists();
      _setPlaylistState(NotifierState.loaded);
    } catch (e) {
      debugPrint('⚠️ Error fetching playlists: $e');
      _setPlaylistState(NotifierState.error);
    }
  }

  /// Create a new playlist
  Future<void> createNewPlaylist(String playlistName, Song initialSong) async {
    try {
      await _apiService.createNewPlaylist(playlistName, initialSong);
      await fetchPlaylists();
    } catch (e) {
      debugPrint('⚠️ Error creating new playlist: $e');
      rethrow;
    }
  }

  /// Add a song to an existing playlist
  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    try {
      await _apiService.addSongToPlaylist(playlistId, song);
      await fetchPlaylists();
    } catch (e) {
      debugPrint('⚠️ Error adding song to playlist: $e');
      rethrow;
    }
  }

  // --- Playback Controls ---

  /// Play a single song, with optional playlist context for continuous play.
  Future<void> playSong(Song song, {List<Song>? playlist}) async {
    try {
      // Cancel existing subscription
      await _currentIndexSubscription?.cancel();
      _currentIndexSubscription = null;

      if (playlist != null && playlist.isNotEmpty) {
        // Validate playlist contains valid audio URLs
        final validSongs = playlist.where((s) => s.audioUrl.isNotEmpty).toList();
        if (validSongs.isEmpty) {
          throw Exception('No valid songs in playlist');
        }

        final audioSources = validSongs
            .map((s) => AudioSource.uri(Uri.parse(s.audioUrl)))
            .toList();
        
        final initialIndex = validSongs.indexWhere((s) => s.id == song.id);
        final startIndex = initialIndex >= 0 ? initialIndex : 0;

        await _player.setAudioSource(
          ConcatenatingAudioSource(children: audioSources),
          initialIndex: startIndex,
        );

        // Only create subscription if we have valid songs
        _currentIndexSubscription = _player.currentIndexStream.listen((index) {
          if (index != null && index >= 0 && index < validSongs.length) {
            _currentSong = validSongs[index];
            if (!_isDisposed) {
              notifyListeners();
            }
          }
        });
      } else {
        // Single song playback
        if (song.audioUrl.isEmpty) {
          throw Exception('Invalid audio URL');
        }
        await _player.setUrl(song.audioUrl);
      }

      _currentSong = song;
      await _player.play();
      
      if (!_isDisposed) {
        notifyListeners();
      }
    } on PlayerInterruptedException catch (e) {
      debugPrint("Connection interrupted: ${e.message}");
      _currentSong = null;
      if (!_isDisposed) {
        notifyListeners();
      }
    } on PlayerException catch (e) {
      debugPrint("Player error: ${e.message}");
      _currentSong = null;
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('An unexpected error occurred in playSong: $e');
      _currentSong = null;
      if (!_isDisposed) {
        notifyListeners();
      }
      rethrow;
    }
  }

  /// Play a playlist sequentially
  Future<void> playPlaylist(List<Song> playlist) async {
    if (playlist.isEmpty) return;
    await playSong(playlist.first, playlist: playlist);
  }

  Future<void> pause() async {
    try {
      await _player.pause();
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error pausing: $e');
    }
  }

  Future<void> resume() async {
    try {
      await _player.play();
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error resuming: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('Error seeking: $e');
    }
  }

  Future<void> playNext() async {
    try {
      if (_player.hasNext) {
        await _player.seekToNext();
      }
    } catch (e) {
      debugPrint('Error playing next: $e');
    }
  }

  Future<void> playPrevious() async {
    try {
      if (_player.hasPrevious) {
        await _player.seekToPrevious();
      }
    } catch (e) {
      debugPrint('Error playing previous: $e');
    }
  }

  Future<void> toggleShuffle() async {
    try {
      _isShuffleEnabled = !_isShuffleEnabled;
      await _player.setShuffleModeEnabled(_isShuffleEnabled);
      await _savePreferences();
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error toggling shuffle: $e');
    }
  }

  Future<void> cycleLoopMode() async {
    try {
      switch (_loopMode) {
        case LoopMode.off:
          _loopMode = LoopMode.all;
          break;
        case LoopMode.all:
          _loopMode = LoopMode.one;
          break;
        case LoopMode.one:
          _loopMode = LoopMode.off;
          break;
      }
      await _player.setLoopMode(_loopMode);
      await _savePreferences();
      if (!_isDisposed) {
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error cycling loop mode: $e');
    }
  }

  /// Pause or stop playback.
  Future<void> pauseOrStop() async {
    try {
      if (_player.playing) {
        await pause();
      } else if (_player.processingState != ProcessingState.idle) {
        await _player.stop();
        _currentSong = null;
        if (!_isDisposed) {
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error in pauseOrStop: $e');
    }
  }

  /// Clean up resources before app termination.
  Future<void> cleanup() async {
    debugPrint('🧹 Cleaning up MusicProvider resources...');
    try {
      await _player.stop();
      await _currentIndexSubscription?.cancel();
      _currentIndexSubscription = null;
      _currentSong = null;
    } catch (e) {
      debugPrint('Error during cleanup: $e');
    }
  }

  @override
  void dispose() {
    _isDisposed = true;
    _currentIndexSubscription?.cancel();
    _player.dispose();
    super.dispose();
  }
}