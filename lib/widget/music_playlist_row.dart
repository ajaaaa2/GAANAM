import 'package:flutter/material.dart';
import 'package:musicapp/providers/music_provider.dart';
import 'package:musicapp/screens/player_screen.dart';
import 'package:provider/provider.dart';

class MusicPlaylistRow extends StatefulWidget {
  const MusicPlaylistRow({super.key});

  @override
  State<MusicPlaylistRow> createState() => _MusicPlaylistRowState();
}

class _MusicPlaylistRowState extends State<MusicPlaylistRow> {
  bool _isNavigating = false;

  Future<void> _navigateToPlayer(
    BuildContext context,
    MusicProvider provider,
    int index,
  ) async {
    // Prevent double navigation
    if (_isNavigating) return;

    setState(() => _isNavigating = true);

    final playlist = provider.playlists[index];

    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            song: playlist.songs.first,
            albumSongs: playlist.songs,
          ),
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
        if (provider.playlistState == NotifierState.loading) {
          return const SizedBox(
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (provider.playlistState == NotifierState.error) {
          return const SizedBox(
            height: 120,
            child: Center(
              child: Text(
                'Failed to load playlists',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        final playlists = provider.playlists;
        if (playlists.isEmpty) {
          return const SizedBox(
            height: 120,
            child: Center(
              child: Text(
                'No playlists available',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          );
        }

        return SizedBox(
          height: 120,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            physics: const BouncingScrollPhysics(),
            itemCount: playlists.length,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final playlist = playlists[index];
              return GestureDetector(
                onTap: () {
                  if (playlist.songs.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('This playlist is empty')),
                    );
                    return;
                  }

                  if (!_isNavigating) {
                    provider.playPlaylist(playlist.songs);
                    _navigateToPlayer(context, provider, index);
                  }
                },
                child: Container(
                  width: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (playlist.imageUrl != null)
                          Image.network(
                            playlist.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                  color: Colors.grey[800],
                                  child: const Icon(
                                    Icons.queue_music,
                                    size: 40,
                                    color: Colors.white54,
                                  ),
                                ),
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                color: Colors.grey[800],
                                child: Center(
                                  child: CircularProgressIndicator(
                                    value:
                                        loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              loadingProgress
                                                  .expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                          )
                        else
                          Container(
                            color: Colors.grey[800],
                            child: const Icon(
                              Icons.queue_music,
                              size: 40,
                              color: Colors.white54,
                            ),
                          ),
                        Align(
                          alignment: Alignment.bottomLeft,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8.0),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withOpacity(0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  playlist.title,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${playlist.songs.length} songs',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
