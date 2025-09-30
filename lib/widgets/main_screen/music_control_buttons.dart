import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/config_service.dart';
import '../../services/music_generation_service.dart';
import '../../services/notification_service.dart';
import '../../services/llm_service.dart';
import '../../models/music_generation_session.dart';
import 'music_confirmation_modal.dart';
import 'simple_audio_player.dart';

class MusicControlButtons extends StatefulWidget {
  final String requirements;
  final bool isGenerationActive;

  const MusicControlButtons({
    super.key,
    required this.requirements,
    required this.isGenerationActive,
  });

  @override
  State<MusicControlButtons> createState() => _MusicControlButtonsState();
}

class _MusicControlButtonsState extends State<MusicControlButtons> {
  late MusicGenerationService _musicService;

  @override
  void initState() {
    super.initState();
    _musicService = MusicGenerationService();
    _initializeMusicService();
  }

  Future<void> _initializeMusicService() async {
    final configService = Provider.of<ConfigService>(context, listen: false);
    final musicConfig = configService.config?.specMusicConfig;
    final llmService = Provider.of<LLMService>(context, listen: false);

    if (musicConfig != null) {
      _musicService.configure(musicConfig, llmService: llmService);
    }

    // Передаем контекст для показа уведомлений об ошибках
    _musicService.setContext(context);
  }

  @override
  void dispose() {
    _musicService.dispose();
    super.dispose();
  }

  bool get _canGenerateMusic {
    final configService = Provider.of<ConfigService>(context, listen: false);
    final musicConfig = configService.config?.specMusicConfig;
    return musicConfig?.enabled == true &&
           musicConfig?.isValid == true &&
           widget.requirements.trim().isNotEmpty &&
           !widget.isGenerationActive &&
           !_musicService.hasActiveSession;
  }

  Future<void> _showMusicConfirmationAndStart() async {
    if (!_canGenerateMusic) return;

    final confirmed = await MusicConfirmationModal.show(context);
    if (confirmed == true && mounted) {
      try {
        await _musicService.startMusicGeneration(widget.requirements);
      } catch (e) {
        // Ошибка уже обработана в MusicGenerationService через NotificationService
      }
    }
  }

  Future<void> _openFileInFolder() async {
    try {
      await _musicService.openFileInFolder();
    } catch (e) {
      if (mounted) {
        NotificationService.showError(
          context,
          'Не удалось открыть папку с файлом',
          technicalDetails: e.toString(),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final configService = Provider.of<ConfigService>(context);
    final musicConfig = configService.config?.specMusicConfig;

    // Если музикация не настроена, не показываем кнопки
    if (musicConfig?.enabled != true || musicConfig?.isValid != true) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: _musicService,
      builder: (context, child) {
        final session = _musicService.currentSession;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Кнопка "Музицировать" или статус генерации
            if (session == null || session.status == MusicGenerationStatus.idle)
              ElevatedButton.icon(
                onPressed: _canGenerateMusic ? _showMusicConfirmationAndStart : null,
                icon: const Icon(Icons.music_note, size: 16),
                label: const Text('Музицировать'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple,
                  foregroundColor: Colors.white,
                ),
              )
            else
              _buildGenerationStatus(session),

            // Дополнительные кнопки при завершенной генерации
            if (session?.status == MusicGenerationStatus.completed) ...[
              const SizedBox(width: 8),
              SimpleAudioPlayer(audioFilePath: session?.filePath),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _openFileInFolder,
                icon: const Icon(Icons.folder_open, size: 16),
                tooltip: 'Открыть в папке',
                style: IconButton.styleFrom(
                  backgroundColor: Colors.blue.withOpacity(0.1),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildGenerationStatus(MusicGenerationSession session) {
    Color statusColor;
    IconData statusIcon;

    switch (session.status) {
      case MusicGenerationStatus.starting:
      case MusicGenerationStatus.generating:
        statusColor = Colors.orange;
        statusIcon = Icons.auto_awesome;
        break;
      case MusicGenerationStatus.downloading:
        statusColor = Colors.blue;
        statusIcon = Icons.download;
        break;
      case MusicGenerationStatus.completed:
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case MusicGenerationStatus.failed:
        statusColor = Colors.red;
        statusIcon = Icons.error;
        break;
      case MusicGenerationStatus.insufficientFunds:
        statusColor = Colors.amber;
        statusIcon = Icons.account_balance_wallet;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (session.status == MusicGenerationStatus.starting ||
              session.status == MusicGenerationStatus.generating ||
              session.status == MusicGenerationStatus.downloading)
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(statusColor),
              ),
            )
          else
            Icon(statusIcon, size: 16, color: statusColor),
          const SizedBox(width: 6),
          Text(
            session.progressMessage ?? 'Генерация музыки',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: statusColor,
            ),
          ),
        ],
      ),
    );
  }
}