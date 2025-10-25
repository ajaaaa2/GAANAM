import 'song.dart';

/// Playlist model
class Playlist {
  final String id;
  final String title;
  final String? imageUrl;
  final List<Song> songs;

  Playlist({
    required this.id,
    required this.title,
    this.imageUrl,
    required this.songs,
  });

  factory Playlist.fromMap(Map<String, dynamic> map, String id) {
    try {
      final songsList = map['songs'] as List<dynamic>? ?? [];
      final List<Song> songs = [];

      for (int index = 0; index < songsList.length; index++) {
        try {
          final songData = songsList[index];
          
          // Validate that songData is a Map
          if (songData is! Map<String, dynamic>) {
            print('Warning: Invalid song data at index $index in playlist $id');
            continue;
          }

          // Generate unique ID if missing - use playlist ID + index as fallback
          final songId = songData['id'] ?? '${id}_song_$index';
          songs.add(Song.fromMap(songData, docId: songId));
        } catch (e) {
          print('Error parsing song at index $index in playlist $id: $e');
          // Skip this song but continue processing others
          continue;
        }
      }

      return Playlist(
        id: id,
        title: map['title'] ?? 'Untitled Playlist',
        imageUrl: map['imageUrl'],
        songs: songs,
      );
    } catch (e) {
      print('Error parsing playlist $id: $e');
      // Return a safe default playlist
      return Playlist(
        id: id,
        title: 'Untitled Playlist',
        imageUrl: null,
        songs: [],
      );
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'imageUrl': imageUrl,
      'songs': songs.map((s) => s.toMap()).toList(),
    };
  }

  /// Create a copy of this Playlist with modified fields
  Playlist copyWith({
    String? id,
    String? title,
    String? imageUrl,
    List<Song>? songs,
  }) {
    return Playlist(
      id: id ?? this.id,
      title: title ?? this.title,
      imageUrl: imageUrl ?? this.imageUrl,
      songs: songs ?? this.songs,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Playlist && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}