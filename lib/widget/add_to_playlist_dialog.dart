import 'package:flutter/material.dart';

import 'package:musicapp/models/song.dart';
import 'package:musicapp/providers/music_provider.dart';
import 'package:provider/provider.dart';

class AddToPlaylistDialog extends StatefulWidget {
  final Song song;
  const AddToPlaylistDialog({super.key, required this.song});

  @override
  State<AddToPlaylistDialog> createState() => _AddToPlaylistDialogState();
}

class _AddToPlaylistDialogState extends State<AddToPlaylistDialog> {
  final TextEditingController _playlistNameController = TextEditingController();
  bool _isCreating = false;

  @override
  void dispose() {
    _playlistNameController.dispose();
    super.dispose();
  }

  /// Shows the inner dialog for creating a new playlist.
  void _showCreatePlaylistDialog(BuildContext context, MusicProvider provider) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.grey[900],
              title: const Text(
                'New Playlist',
                style: TextStyle(color: Colors.white),
              ),
              content: TextField(
                controller: _playlistNameController,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: "Playlist Name",
                  hintStyle: TextStyle(color: Colors.white54),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white38),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.white),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isCreating
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                        },
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: _isCreating
                      ? null
                      : () async {
                          final playlistName = _playlistNameController.text
                              .trim();
                          if (playlistName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please enter a playlist name'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return;
                          }

                          setDialogState(() => _isCreating = true);

                          try {
                            await provider.createNewPlaylist(
                              playlistName,
                              widget.song,
                            );
                            _playlistNameController.clear();

                            if (dialogContext.mounted) {
                              Navigator.pop(
                                dialogContext,
                              ); // Close create dialog
                            }
                            if (context.mounted) {
                              Navigator.pop(context); // Close main dialog
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Song added to "$playlistName"',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Failed to create playlist: $e',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) {
                              setDialogState(() => _isCreating = false);
                            }
                          }
                        },
                  child: _isCreating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<MusicProvider>(context, listen: false);

    return AlertDialog(
      backgroundColor: Colors.grey[900],
      title: const Text(
        'Add to Playlist',
        style: TextStyle(color: Colors.white),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Consumer<MusicProvider>(
          builder: (context, providerData, child) {
            if (providerData.playlistState == NotifierState.loading) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(20.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }

            if (providerData.playlistState == NotifierState.error) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Could not load playlists.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => providerData.fetchPlaylists(),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final playlists = providerData.playlists;

            return ListView.builder(
              shrinkWrap: true,
              itemCount: playlists.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: const Icon(Icons.add, color: Colors.white),
                    title: const Text(
                      'Create new playlist',
                      style: TextStyle(color: Colors.white),
                    ),
                    onTap: () => _showCreatePlaylistDialog(context, provider),
                  );
                }

                final playlist = playlists[index - 1];
                return ListTile(
                  leading: const Icon(Icons.queue_music, color: Colors.white70),
                  title: Text(
                    playlist.title,
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '${playlist.songs.length} songs',
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  onTap: () async {
                    try {
                      await provider.addSongToPlaylist(
                        playlist.id,
                        widget.song,
                      );

                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Added to "${playlist.title}"'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to add song: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                );
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
