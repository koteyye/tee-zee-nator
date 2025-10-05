import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../../services/config_service.dart';
import '../../services/music_generation_service.dart';
import '../../models/confluence_config.dart';
import '../../models/spec_music_config.dart';

class IntegrationIndicators extends StatefulWidget {
  const IntegrationIndicators({super.key});

  @override
  State<IntegrationIndicators> createState() => _IntegrationIndicatorsState();
}

class _IntegrationIndicatorsState extends State<IntegrationIndicators> {
  late MusicGenerationService _musicService;

  @override
  void initState() {
    super.initState();
    _musicService = MusicGenerationService();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeMusicService();
    });
  }

  Future<void> _initializeMusicService() async {
    final configService = Provider.of<ConfigService>(context, listen: false);
    final musicConfig = configService.config?.specMusicConfig;

    if (musicConfig != null) {
      _musicService.configure(musicConfig);
      if (musicConfig.enabled && musicConfig.isValid) {
        await _musicService.refreshBalance();
      }
    }
  }

  @override
  void dispose() {
    _musicService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ConfigService>(
      builder: (context, configService, child) {
        final confluenceConfig = configService.getConfluenceConfig();
        final musicConfig = configService.config?.specMusicConfig;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Confluence indicator
            _buildConfluenceIndicator(confluenceConfig),
            const SizedBox(width: 16),

            // Music generation indicator
            _buildMusicIndicator(musicConfig),
          ],
        );
      },
    );
  }

  Widget _buildConfluenceIndicator(ConfluenceConfig? config) {
    final isEnabled = config?.enabled ?? false;
    final isValid = config?.isValid ?? false;

    return Tooltip(
      message: isEnabled && isValid
          ? 'Confluence: активно'
          : 'Confluence: неактивно',
      child: SvgPicture.asset(
        'assets/icons/atlassian.svg',
        width: 20,
        height: 20,
        colorFilter: ColorFilter.mode(
          isEnabled && isValid
              ? const Color(0xFF4CAF50) // Зеленый для активного
              : const Color(0xFF9E9E9E), // Серый для неактивного
          BlendMode.srcIn,
        ),
      ),
    );
  }

  Widget _buildMusicIndicator(SpecMusicConfig? config) {
    final isEnabled = config?.enabled ?? false;
    final isValid = config?.isValid ?? false;

    return Tooltip(
      message: isEnabled && isValid
          ? 'Музикация: активно'
          : 'Музикация: неактивно',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icons/music.svg',
            width: 20,
            height: 20,
            colorFilter: ColorFilter.mode(
              isEnabled && isValid
                  ? const Color(0xFF9C27B0) // Фиолетовый для активного
                  : const Color(0xFF9E9E9E), // Серый для неактивного
              BlendMode.srcIn,
            ),
          ),
          if (isEnabled && isValid) ...[
            const SizedBox(width: 8),
            _buildBalanceSection(),
          ],
        ],
      ),
    );
  }

  Widget _buildBalanceSection() {
    return ListenableBuilder(
      listenable: _musicService,
      builder: (context, child) {
        final balance = _musicService.currentBalance;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (balance != null) ...[
              Text(
                '$balance₽',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF9C27B0), // Фиолетовый
                ),
              ),
              const SizedBox(width: 4),
            ],
            InkWell(
              onTap: () async {
                await _musicService.refreshBalance();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(
                  Icons.refresh,
                  size: 16,
                  color: Color(0xFF9C27B0), // Фиолетовый
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}