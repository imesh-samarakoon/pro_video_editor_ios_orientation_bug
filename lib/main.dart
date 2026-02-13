// lib/main.dart
// Minimal toy app to test pro_video_editor orientation behavior on iOS
//
// Flow: Pick video → Trim → Export → Play result

import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  runApp(const ToyApp());
}

class ToyApp extends StatelessWidget {
  const ToyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pro Video Editor Test',
      theme: ThemeData.dark(),
      home: const HomeScreen(),
    );
  }
}

// =============================================================================
// HOME SCREEN - Pick a video
// =============================================================================

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _pickVideo(BuildContext context) async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);

    if (picked == null || !context.mounted) return;

    // Get video metadata for duration
    final metadata = await ProVideoEditor.instance.getMetadata(
      EditorVideo.file(File(picked.path)),
    );

    if (metadata?.duration == null || !context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read video metadata')),
      );
      return;
    }

    // Navigate to trim screen
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TrimScreen(
          videoFile: File(picked.path),
          videoDuration: metadata!.duration!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Orientation Test')),
      body: Center(
        child: ElevatedButton.icon(
          onPressed: () => _pickVideo(context),
          icon: const Icon(Icons.video_library),
          label: const Text('Pick Video'),
        ),
      ),
    );
  }
}

// =============================================================================
// TRIM SCREEN - Preview + trim sliders + export
// =============================================================================

class TrimScreen extends StatefulWidget {
  final File videoFile;
  final Duration videoDuration;

  const TrimScreen({
    super.key,
    required this.videoFile,
    required this.videoDuration,
  });

  @override
  State<TrimScreen> createState() => _TrimScreenState();
}

class _TrimScreenState extends State<TrimScreen> {
  late Player _player;
  late VideoController _controller;

  Duration _startTime = Duration.zero;
  late Duration _endTime;

  bool _isExporting = false;
  double _exportProgress = 0.0;

  @override
  void initState() {
    super.initState();
    _endTime = widget.videoDuration;
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    _player = Player();
    _controller = VideoController(_player);
    await _player.open(Media(widget.videoFile.path));
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    setState(() {
      _isExporting = true;
      _exportProgress = 0.0;
    });

    try {
      final dir = await getTemporaryDirectory();
      final outputPath = '${dir.path}/trimmed_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final renderModel = VideoRenderData(
        video: EditorVideo.file(widget.videoFile),
        startTime: _startTime,
        endTime: _endTime,
        enableAudio: true,
        outputFormat: VideoOutputFormat.mp4,
      );

      // Listen to progress
      final subscription = ProVideoEditor.instance
          .progressStreamById(renderModel.id)
          .listen((p) {
        if (mounted) setState(() => _exportProgress = p.progress);
      });

      await ProVideoEditor.instance.renderVideoToFile(outputPath, renderModel);
      await subscription.cancel();

      if (!mounted) return;

      // Navigate to result screen
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ResultScreen(videoPath: outputPath),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isExporting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    }
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final totalMs = widget.videoDuration.inMilliseconds.toDouble();

    return Scaffold(
      appBar: AppBar(title: const Text('Trim Video')),
      body: _isExporting
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(value: _exportProgress),
                  const SizedBox(height: 16),
                  Text('Exporting... ${(_exportProgress * 100).toInt()}%'),
                ],
              ),
            )
          : Column(
              children: [
                // Video preview
                Expanded(
                  child: Video(controller: _controller),
                ),

                // Export button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _export,
                      child: const Text('Export & Play Result'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

// =============================================================================
// RESULT SCREEN - Play the exported video
// =============================================================================

class ResultScreen extends StatefulWidget {
  final String videoPath;

  const ResultScreen({super.key, required this.videoPath});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late Player _player;
  late VideoController _controller;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _controller = VideoController(_player);
    _player.open(Media(widget.videoPath));
    _player.setPlaylistMode(PlaylistMode.loop);
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Result'),
        actions: [
          IconButton(
            icon: const Icon(Icons.home),
            onPressed: () {
              Navigator.of(context).popUntil((route) => route.isFirst);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Video(controller: _controller),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Check if orientation is correct!\nPath: ${widget.videoPath}',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}