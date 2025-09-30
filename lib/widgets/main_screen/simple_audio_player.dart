import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'dart:io';

class SimpleAudioPlayer extends StatefulWidget {
  final String? audioFilePath;

  const SimpleAudioPlayer({
    super.key,
    required this.audioFilePath,
  });

  @override
  State<SimpleAudioPlayer> createState() => _SimpleAudioPlayerState();
}

class _SimpleAudioPlayerState extends State<SimpleAudioPlayer> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _togglePlayStop() async {
    if (widget.audioFilePath == null) return;

    final file = File(widget.audioFilePath!);
    if (!await file.exists()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Аудиофайл не найден')),
        );
      }
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (_isPlaying) {
        await _player.stop();
        setState(() {
          _isPlaying = false;
        });
      } else {
        await _player.play(DeviceFileSource(widget.audioFilePath!));
        setState(() {
          _isPlaying = true;
        });

        // Слушаем завершение воспроизведения
        _player.onPlayerComplete.listen((event) {
          if (mounted) {
            setState(() {
              _isPlaying = false;
            });
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка воспроизведения: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.audioFilePath == null) {
      return const SizedBox.shrink();
    }

    return IconButton(
      onPressed: _isLoading ? null : _togglePlayStop,
      icon: _isLoading
          ? SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
            )
          : Icon(
              _isPlaying ? Icons.stop : Icons.play_arrow,
              color: Colors.purple,
            ),
      tooltip: _isPlaying ? 'Остановить' : 'Воспроизвести',
      style: IconButton.styleFrom(
        backgroundColor: Colors.purple.withOpacity(0.1),
      ),
    );
  }
}