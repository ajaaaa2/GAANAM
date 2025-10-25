class Song {
  final String id;
  final String title;
  final String artist;
  final String audioUrl;
  final String imageUrl;
  final String? album;
  final int? duration; // Duration in seconds
  final DateTime? addedAt;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioUrl,
    required this.imageUrl,
    this.album,
    this.duration,
    this.addedAt,
  });

  factory Song.fromMap(Map<String, dynamic> map, {String? docId}) {
    return Song(
      id: docId ?? map['id'] ?? '',
      title: map['title'] ?? 'Unknown Title',
      artist: map['artist'] ?? 'Unknown Artist',
      audioUrl: map['audioUrl'] ?? '',
      imageUrl: map['imageUrl'] ?? '',
      album: map['album'],
      duration: map['duration'] as int?,
      addedAt: map['addedAt'] != null
          ? (map['addedAt'] is String
                ? DateTime.tryParse(map['addedAt'] as String)
                : null)
          : null,
    );
  }

  /// Convert Song object to a Map (useful for Firestore updates)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'artist': artist,
      'audioUrl': audioUrl,
      'imageUrl': imageUrl,
      'album': album ?? '',
      'duration': duration,
      'addedAt': addedAt?.toIso8601String(),
    };
  }

  /// Create a copy of this Song with modified fields
  Song copyWith({
    String? id,
    String? title,
    String? artist,
    String? audioUrl,
    String? imageUrl,
    String? album,
    int? duration,
    DateTime? addedAt,
  }) {
    return Song(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      audioUrl: audioUrl ?? this.audioUrl,
      imageUrl: imageUrl ?? this.imageUrl,
      album: album ?? this.album,
      duration: duration ?? this.duration,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Song && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
