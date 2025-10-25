import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:musicapp/models/song.dart';
import 'package:musicapp/providers/music_provider.dart';
import 'package:musicapp/screens/player_screen.dart';
import 'package:musicapp/widget/add_to_playlist_dialog.dart';
import 'package:provider/provider.dart';

class TrackList extends StatefulWidget {
  final List<Song> tracks;

  const TrackList({super.key, required this.tracks});

  @override
  State<TrackList> createState() => _TrackListState();
}

class _TrackListState extends State<TrackList> {
  bool _isNavigating = false;

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  void _showSongOptions(BuildContext context, Song song) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.playlist_add, color: Colors.white),
            title: const Text(
              'Add to Playlist',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              showDialog(
                context: context,
                builder: (_) => AddToPlaylistDialog(song: song),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.share, color: Colors.white),
            title: const Text('Share', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              // TODO: Implement share
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Share feature coming soon')),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info, color: Colors.white),
            title: const Text(
              'Song Info',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () {
              Navigator.pop(context);
              _showSongInfo(context, song);
            },
          ),
        ],
      ),
    );
  }

  void _showSongInfo(BuildContext context, Song song) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(song.title, style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Artist', song.artist),
            if (song.album != null && song.album!.isNotEmpty)
              _buildInfoRow('Album', song.album!),
            if (song.duration != null)
              _buildInfoRow(
                'Duration',
                _formatDuration(Duration(seconds: song.duration!)),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: const TextStyle(
              color: Colors.white70,
              fontWeight: FontWeight.bold,
            ),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<void> _navigateToPlayer(Song song, List<Song> tracks) async {
    // Prevent double navigation
    if (_isNavigating) return;
    
    setState(() => _isNavigating = true);
    
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PlayerScreen(song: song, albumSongs: tracks),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isNavigating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<MusicProvider>(
      builder: (context, provider, child) {
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.tracks.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final song = widget.tracks[index];
            final isCurrentSong = provider.currentSong?.id == song.id;
            final isPlaying = isCurrentSong && provider.isPlaying;

            return ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              leading: InkWell(
                onTap: () {
                  if (!_isNavigating) {
                    provider.playSong(song, playlist: widget.tracks);
                    _navigateToPlayer(song, widget.tracks);
                  }
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: song.imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey[800],
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 50,
                      height: 50,
                      color: Colors.grey,
                      child: const Icon(Icons.music_note, color: Colors.white),
                    ),
                  ),
                ),
              ),
              title: Text(
                song.title,
                style: TextStyle(
                  color: isCurrentSong ? Colors.greenAccent : Colors.white,
                  fontWeight: isCurrentSong
                      ? FontWeight.bold
                      : FontWeight.normal,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                song.artist,
                style: const TextStyle(color: Colors.white70),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (song.duration != null)
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: Text(
                        _formatDuration(Duration(seconds: song.duration!)),
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  IconButton(
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_circle_filled
                          : Icons.play_circle_fill,
                      color: isCurrentSong ? Colors.greenAccent : Colors.white,
                      size: 32,
                    ),
                    onPressed: () {
                      if (!isCurrentSong) {
                        // Play the new song and navigate
                        if (!_isNavigating) {
                          provider.playSong(song, playlist: widget.tracks);
                          _navigateToPlayer(song, widget.tracks);
                        }
                      } else if (isPlaying) {
                        provider.pause();
                      } else {
                        provider.resume();
                      }
                    },
                  ),
                ],
              ),
              tileColor: isCurrentSong ? Colors.white12 : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              onLongPress: () => _showSongOptions(context, song),
            );
          },
        );
      },
    );
  }
}