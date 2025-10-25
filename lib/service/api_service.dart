import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:musicapp/models/playlist.dart';
import '../models/song.dart';

class ApiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Cache for songs
  static final Map<String, List<Song>> _cache = {};
  static DateTime? _lastFetch;
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  /// Fetch all songs from Firestore with timeout and error handling
  Future<List<Song>> fetchSongs() async {
    try {
      final snapshot = await _firestore
          .collection('songs')
          .orderBy('addedAt', descending: true)
          .get()
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () => throw TimeoutException('Request timed out'),
          );

      return snapshot.docs
          .map((doc) => Song.fromMap(doc.data(), docId: doc.id))
          .toList();
    } on FirebaseException catch (e) {
      debugPrint('Firebase error: ${e.code} - ${e.message}');
      throw Exception('Failed to fetch songs: ${e.message}');
    } on TimeoutException {
      throw Exception('Connection timeout. Please check your internet.');
    } catch (e) {
      debugPrint('Unexpected error: $e');
      rethrow;
    }
  }

  /// Fetch songs with caching
  Future<List<Song>> fetchSongsWithCache() async {
    if (_cache.containsKey('all_songs') &&
        _lastFetch != null &&
        DateTime.now().difference(_lastFetch!) < _cacheValidDuration) {
      return _cache['all_songs']!;
    }

    final songs = await fetchSongs();
    _cache['all_songs'] = songs;
    _lastFetch = DateTime.now();
    return songs;
  }

  /// Fetch songs with pagination
  Future<List<Song>> fetchSongsPaginated({
    int limit = 20,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query query = _firestore
          .collection('songs')
          .orderBy('addedAt', descending: true)
          .limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();
      return snapshot.docs
          .map(
            (doc) =>
                Song.fromMap(doc.data() as Map<String, dynamic>, docId: doc.id),
          )
          .toList();
    } catch (e) {
      debugPrint('Error fetching paginated songs: $e');
      rethrow;
    }
  }

  /// Search songs by title
  Future<List<Song>> searchSongs(String query) async {
    try {
      final snapshot = await _firestore
          .collection('songs')
          .where('title', isGreaterThanOrEqualTo: query)
          .where('title', isLessThanOrEqualTo: '$query\uf8ff')
          .get();

      return snapshot.docs
          .map((doc) => Song.fromMap(doc.data(), docId: doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error searching songs: $e');
      return [];
    }
  }

  /// Fetch songs by album
  Future<List<Song>> fetchSongsByAlbum(String album) async {
    try {
      final snapshot = await _firestore
          .collection('songs')
          .where('album', isEqualTo: album)
          .get();

      return snapshot.docs
          .map((doc) => Song.fromMap(doc.data(), docId: doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching album songs: $e');
      return [];
    }
  }

  /// Fetch songs by artist
  Future<List<Song>> fetchSongsByArtist(String artist) async {
    try {
      final snapshot = await _firestore
          .collection('songs')
          .where('artist', isEqualTo: artist)
          .get();

      return snapshot.docs
          .map((doc) => Song.fromMap(doc.data(), docId: doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching artist songs: $e');
      return [];
    }
  }
  // In lib/service/api_service.dart

  /// Fetch all playlists from Firestore
  Future<List<Playlist>> fetchPlaylists() async {
    try {
      final snapshot = await _firestore.collection('playlists').get();
      return snapshot.docs
          .map((doc) => Playlist.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      debugPrint('Error fetching playlists: $e');
      return [];
    }
  }

  /// Create a new playlist with an initial song
  Future<void> createNewPlaylist(String playlistName, Song initialSong) async {
    try {
      await _firestore.collection('playlists').add({
        'title': playlistName,
        'imageUrl': initialSong.imageUrl, // Use first song's image as default
        'songs': [initialSong.toMap()], // Add the first song
      });
    } catch (e) {
      debugPrint('Error creating new playlist: $e');
      rethrow;
    }
  }

  /// Add a song to an existing playlist
  Future<void> addSongToPlaylist(String playlistId, Song song) async {
    try {
      final playlistRef = _firestore.collection('playlists').doc(playlistId);
      await playlistRef.update({
        'songs': FieldValue.arrayUnion([song.toMap()]),
      });
    } catch (e) {
      debugPrint('Error adding song to playlist: $e');
      rethrow;
    }
  }

  /// Add a new song to Firestore
  Future<void> addSong({
    required String title,
    required String artist,
    required String imageUrl,
    required String audioUrl,
    String? album,
    int? duration,
  }) async {
    try {
      await _firestore.collection('songs').add({
        'title': title,
        'artist': artist,
        'imageUrl': imageUrl,
        'audioUrl': audioUrl,
        'album': album ?? '',
        'duration': duration,
        'timestamp': FieldValue.serverTimestamp(),
        'addedAt': DateTime.now().toIso8601String(),
      });
      clearCache(); // Clear cache after adding
    } catch (e) {
      debugPrint('Error adding song: $e');
      rethrow;
    }
  }

  /// Update existing song
  Future<void> updateSong(String docId, Song song) async {
    try {
      await _firestore.collection('songs').doc(docId).update(song.toMap());
      clearCache(); // Clear cache after update
    } catch (e) {
      debugPrint('Error updating song: $e');
      rethrow;
    }
  }

  /// Delete a song
  Future<void> deleteSong(String docId) async {
    try {
      await _firestore.collection('songs').doc(docId).delete();
      clearCache(); // Clear cache after deletion
    } catch (e) {
      debugPrint('Error deleting song: $e');
      rethrow;
    }
  }

  /// Add multiple songs in batch
  Future<void> addSongsBatch(List<Song> songs) async {
    try {
      final batch = _firestore.batch();
      for (var song in songs) {
        final docRef = _firestore.collection('songs').doc();
        batch.set(docRef, song.toMap());
      }
      await batch.commit();
      clearCache(); // Clear cache after batch add
    } catch (e) {
      debugPrint('Error adding songs in batch: $e');
      rethrow;
    }
  }

  /// Clear the cache
  static void clearCache() {
    _cache.clear();
    _lastFetch = null;
  }
}
