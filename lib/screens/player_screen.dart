import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:musicapp/models/song.dart';
import 'package:musicapp/providers/music_provider.dart';
import 'package:provider/provider.dart';
import 'package:just_audio/just_audio.dart';

class PlayerScreen extends StatefulWidget {
  final Song song;
  final List<Song> albumSongs;

  const PlayerScreen({super.key, required this.song, required this.albumSongs});

  static const routeName = '/player';

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late MusicProvider _musicProvider;
  late List<Song> _playlist;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  StreamSubscription<Duration>? _positionSubscription;
  StreamSubscription<Duration?>? _durationSubscription;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  @override
  void initState() {
    super.initState();
    _musicProvider = Provider.of<MusicProvider>(context, listen: false);
    _playlist = widget.albumSongs.isNotEmpty
        ? widget.albumSongs
        : _musicProvider.songs;

    // Listen to position changes
    _positionSubscription = _musicProvider.positionStream.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    // Listen to duration changes
    _durationSubscription = _musicProvider.durationStream.listen((dur) {
      if (mounted) setState(() => _duration = dur ?? Duration.zero);
    });

    // Listen for song completion to auto-play next (with safety check)
    _playerStateSubscription = _musicProvider.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        // Only auto-play if there's a next song
        if (_musicProvider.player.hasNext) {
          _musicProvider.playNext();
        }
      }
    });
  }

  @override
  void dispose() {
    // Cancel all stream subscriptions to prevent memory leaks
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerStateSubscription?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    return '${minutes}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1214),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'Now Playing',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: 30,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Consumer<MusicProvider>(
        builder: (context, provider, child) {
          // Always get the most up-to-date song from the provider
          final currentSong = provider.currentSong ?? widget.song;
          final isPlaying = provider.isPlaying;

          return Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // 🔹 Album Art
              Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color.fromARGB(
                        255,
                        40,
                        40,
                        41,
                      ).withOpacity(0.5),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: CachedNetworkImage(
                    imageUrl: currentSong.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[800],
                      child: const Center(child: CircularProgressIndicator()),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[800],
                      child: const Icon(
                        Icons.music_note,
                        size: 80,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              // 🔹 Song Info
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    Text(
                      currentSong.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      currentSong.artist,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // 🔹 Seek Bar (with safety checks)
              Column(
                children: [
                  Slider(
                    value: _duration.inSeconds > 0
                        ? _position.inSeconds
                            .toDouble()
                            .clamp(0.0, _duration.inSeconds.toDouble())
                        : 0.0,
                    min: 0,
                    max: _duration.inSeconds > 0
                        ? _duration.inSeconds.toDouble()
                        : 1.0,
                    activeColor: Colors.white,
                    inactiveColor: Colors.white24,
                    onChanged: _duration.inSeconds > 0
                        ? (value) {
                            provider.seek(
                              Duration(seconds: value.toInt()),
                            );
                          }
                        : null,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _formatDuration(_position),
                          style: const TextStyle(color: Colors.white54),
                        ),
                        Text(
                          _formatDuration(_duration),
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // 🔹 Controls
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.skip_previous_rounded,
                      color: provider.player.hasPrevious
                          ? Colors.white
                          : Colors.white38,
                      size: 40,
                    ),
                    onPressed: provider.player.hasPrevious
                        ? provider.playPrevious
                        : null,
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () {
                      if (isPlaying) {
                        provider.pause();
                      } else {
                        provider.resume();
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: const Color.fromARGB(
                              255,
                              20,
                              19,
                              21,
                            ).withOpacity(0.5),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Icon(
                        isPlaying
                            ? Icons.pause_rounded
                            : Icons.play_arrow_rounded,
                        color: const Color(0xFF1A000D),
                        size: 40,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: Icon(
                      Icons.skip_next_rounded,
                      color: provider.player.hasNext
                          ? Colors.white
                          : Colors.white38,
                      size: 40,
                    ),
                    onPressed: provider.player.hasNext
                        ? provider.playNext
                        : null,
                  ),
                ],
              ),

              // 🔹 Bottom Options
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const _BottomButton(icon: Icons.high_quality, label: "HQ"),
                    _BottomButton(
                      icon: Icons.shuffle,
                      label: "Shuffle",
                      isActive: provider.isShuffleEnabled,
                      onTap: provider.toggleShuffle,
                    ),
                    _BottomButton(
                      icon: Icons.repeat,
                      label: provider.loopMode == LoopMode.off
                          ? "Repeat"
                          : provider.loopMode == LoopMode.all
                          ? "Repeat All"
                          : "Repeat 1",
                      isActive: provider.loopMode != LoopMode.off,
                      onTap: provider.cycleLoopMode,
                    ),
                    const _BottomButton(
                      icon: Icons.queue_music,
                      label: "Playlist",
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _BottomButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback? onTap;

  const _BottomButton({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: isActive ? Colors.white : Colors.white70),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isActive ? Colors.white : Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}