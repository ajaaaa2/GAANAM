import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:musicapp/providers/music_provider.dart';
import 'package:provider/provider.dart';
import '../models/song.dart';
import '../service/api_service.dart';

class AddSongScreen extends StatefulWidget {
  const AddSongScreen({super.key});
  static const routeName = '/add-song';

  @override
  State<AddSongScreen> createState() => _AddSongScreenState();
}

class _AddSongScreenState extends State<AddSongScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController songNameController = TextEditingController();
  final TextEditingController artistNameController = TextEditingController();
  final TextEditingController playListNameController = TextEditingController();

  File? _audioFile;
  File? _imageFile;
  bool _isLoading = false;
  double _uploadProgress = 0.0;

  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    songNameController.dispose();
    artistNameController.dispose();
    playListNameController.dispose();
    super.dispose();
  }

  Future<void> _pickAudio() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final fileSizeInMB = file.lengthSync() / (1024 * 1024);

        if (fileSizeInMB > 50) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Audio file too large. Maximum size is 50MB.'),
              ),
            );
          }
          return;
        }
        setState(() => _audioFile = file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking audio: $e')));
      }
    }
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
      );
      if (pickedFile != null) {
        final file = File(pickedFile.path);
        final fileSizeInMB = file.lengthSync() / (1024 * 1024);

        if (fileSizeInMB > 10) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image file too large. Maximum size is 10MB.'),
              ),
            );
          }
          return;
        }
        setState(() => _imageFile = file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error picking image: $e')));
      }
    }
  }

  Future<String> _uploadFile(File file, String folder) async {
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
    final ref = FirebaseStorage.instance.ref('$folder/$fileName');

    final uploadTask = ref.putFile(file);

    // Track progress
    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      if (mounted) {
        setState(() {
          _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
        });
      }
    });

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Future<String> _uploadFileWithRetry(File file, String folder) async {
    const int maxRetries = 3;
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await _uploadFile(file, folder);
      } catch (e) {
        if (i == maxRetries - 1) rethrow;
        await Future.delayed(Duration(seconds: 2 * (i + 1)));
      }
    }
    throw Exception('Upload failed after $maxRetries attempts');
  }

  Future<void> _submitSong() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_audioFile == null ||
        _imageFile == null ||
        songNameController.text.trim().isEmpty ||
        artistNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill all fields and select both an audio and image file.',
          ),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
    });

    try {
      final audioUrl = await _uploadFileWithRetry(_audioFile!, 'songs');
      final imageUrl = await _uploadFileWithRetry(_imageFile!, 'album_art');

      Song newSong = Song(
        id: '',
        title: songNameController.text.trim(),
        artist: artistNameController.text.trim(),
        audioUrl: audioUrl,
        imageUrl: imageUrl,
        album: playListNameController.text.trim().isEmpty
            ? null
            : playListNameController.text.trim(),
      );

      await _apiService.addSong(
        title: newSong.title,
        artist: newSong.artist,
        audioUrl: newSong.audioUrl,
        imageUrl: newSong.imageUrl,
        album: newSong.album,
      );

      // Try to refresh music list, but don't fail if it doesn't work
      try {
        await Provider.of<MusicProvider>(context, listen: false).fetchMusic();
      } catch (e) {
        debugPrint('Warning: Could not refresh music list: $e');
        // Continue anyway - the song was added successfully
      }

      if (mounted) {
        // Clear form
        songNameController.clear();
        artistNameController.clear();
        playListNameController.clear();
        setState(() {
          _audioFile = null;
          _imageFile = null;
        });

        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text("Success!"),
            content: const Text("The song has been added to your library."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  Navigator.of(context).pop(); // Return to previous screen
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      debugPrint('ERROR SUBMITTING SONG: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(
          SnackBar(
            content: Text('Failed to add song: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final inputDecoration = InputDecoration(
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      filled: true,
      fillColor: Colors.white.withOpacity(0.05),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Add a New Song'), centerTitle: true),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Audio Picker
                OutlinedButton.icon(
                  icon: const Icon(Icons.music_note_outlined, size: 28),
                  label: Text(
                    _audioFile == null
                        ? 'Select Audio File'
                        : 'Audio File Selected!',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _audioFile == null
                        ? Colors.white
                        : colorScheme.primary,
                    side: BorderSide(
                      color: colorScheme.primary.withOpacity(0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _pickAudio,
                ),
                if (_audioFile != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'File: ${_audioFile!.path.split('/').last}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                  ),
                const SizedBox(height: 16),

                // Image Picker
                OutlinedButton.icon(
                  icon: const Icon(Icons.image_outlined, size: 28),
                  label: Text(
                    _imageFile == null
                        ? 'Select Album Art'
                        : 'Album Art Selected!',
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _imageFile == null
                        ? Colors.white
                        : colorScheme.primary,
                    side: BorderSide(
                      color: colorScheme.primary.withOpacity(0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _pickImage,
                ),
                if (_imageFile != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      'File: ${_imageFile!.path.split('/').last}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white.withOpacity(0.7)),
                    ),
                  ),
                const SizedBox(height: 32),

                // Upload Progress Indicator
                if (_isLoading)
                  Column(
                    children: [
                      LinearProgressIndicator(value: _uploadProgress),
                      const SizedBox(height: 8),
                      Text(
                        'Uploading... ${(_uploadProgress * 100).toInt()}%',
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),

                // Song Name
                const Text(
                  'Song Name',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: songNameController,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter song name';
                    }
                    return null;
                  },
                  decoration: inputDecoration.copyWith(
                    hintText: 'Enter the song title',
                  ),
                ),
                const SizedBox(height: 24),

                // Artist Name
                const Text(
                  'Artist Name',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: artistNameController,
                  enabled: !_isLoading,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter artist name';
                    }
                    return null;
                  },
                  decoration: inputDecoration.copyWith(
                    hintText: 'Enter the artist\'s name',
                  ),
                ),
                const SizedBox(height: 24),

                // Album Name (Optional)
                const Text(
                  'Album (Optional)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: playListNameController,
                  enabled: !_isLoading,
                  decoration: inputDecoration.copyWith(
                    hintText: 'Enter album name',
                  ),
                ),

                const SizedBox(height: 48),

                // Submit Button
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: _isLoading ? null : _submitSong,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            color: Colors.black,
                          ),
                        )
                      : const Text(
                          'Add to Library',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}