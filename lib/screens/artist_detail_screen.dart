import 'package:flutter/material.dart';
import 'package:musicapp/models/song.dart';
import 'package:musicapp/providers/music_provider.dart';
import 'package:musicapp/screens/add_song.dart';
import 'package:musicapp/screens/player_screen.dart';
import 'package:musicapp/widget/album_cart.dart' show AlbumCard;
import 'package:musicapp/widget/player_list.dart';
import 'package:musicapp/widget/music_playlist_row.dart';
import 'package:provider/provider.dart';

class ArtistDetailScreen extends StatefulWidget {
  const ArtistDetailScreen({super.key});
  static const routeName = '/artist';

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<MusicProvider>(context, listen: false).fetchMusic();
    });
  }

  Map<String, List<Song>> _groupByAlbum(List<Song> songs) {
    final Map<String, List<Song>> albums = {};
    for (var song in songs) {
      // Fix: Properly check for null or empty album
      final albumName = (song.album == null || song.album!.trim().isEmpty)
          ? 'Unknown Album'
          : song.album!;
      albums.putIfAbsent(albumName, () => []).add(song);
    }
    return albums;
  }

  Future<void> _navigateToPlayer(Song song, List<Song> albumSongs) async {
    // Prevent double navigation
    if (_isNavigating) return;
    
    setState(() => _isNavigating = true);
    
    try {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => PlayerScreen(
            song: song,
            albumSongs: albumSongs,
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('GAANAM', style: TextStyle(color: Colors.white)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 10.0),
            child: FilledButton(
              onPressed: () {
                Navigator.of(context).pushNamed(AddSongScreen.routeName);
              },
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Icon(Icons.add, color: Colors.black),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          try {
            await Provider.of<MusicProvider>(
              context,
              listen: false,
            ).fetchMusic();
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Failed to refresh: $e')));
            }
          }
        },
        child: Consumer<MusicProvider>(
          builder: (context, provider, child) {
            if (provider.state == NotifierState.loading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (provider.state == NotifierState.error) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.cloud_off,
                      size: 64,
                      color: Colors.white38,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Failed to load music',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Check your internet connection',
                      style: TextStyle(color: Colors.white54),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () {
                        provider.fetchMusic();
                      },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }

            final songs = provider.songs;

            if (songs.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.music_note, size: 80, color: Colors.white38),
                    const SizedBox(height: 16),
                    const Text(
                      'No songs available yet.',
                      style: TextStyle(color: Colors.white, fontSize: 18),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap + to add your first song',
                      style: TextStyle(color: Colors.white54, fontSize: 14),
                    ),
                  ],
                ),
              );
            }

            final albums = _groupByAlbum(songs);

            return ListView(
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              children: [
                // Dynamic Playlists Row
                const Text(
                  'Playlists',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                const MusicPlaylistRow(),
                const SizedBox(height: 24),

                // Discography
                Text(
                  'Discography',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 200,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    physics: const BouncingScrollPhysics(),
                    itemCount: albums.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final albumEntry = albums.entries.elementAt(index);
                      final albumName = albumEntry.key;
                      final albumSongs = albumEntry.value;
                      final coverImage = albumSongs.first.imageUrl;

                      return GestureDetector(
                        onTap: () {
                          if (albumSongs.isNotEmpty && !_isNavigating) {
                            Provider.of<MusicProvider>(
                              context,
                              listen: false,
                            ).playPlaylist(albumSongs);
                            _navigateToPlayer(albumSongs.first, albumSongs);
                          }
                        },
                        onDoubleTap: () {
                          Provider.of<MusicProvider>(
                            context,
                            listen: false,
                          ).pauseOrStop();
                        },
                        child: AlbumCard(
                          albumTitle: albumName,
                          albumImage: coverImage,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Popular singles / tracks
                Text(
                  'Popular singles',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 8),
                TrackList(tracks: songs),
              ],
            );
          },
        ),
      ),
    );
  }
}