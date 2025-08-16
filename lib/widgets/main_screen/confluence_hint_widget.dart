import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/config_service.dart';

/// Widget that displays Confluence integration hints to users
/// 
/// Shows informational text about Confluence link usage when:
/// - Confluence is properly configured and enabled
/// - Connection is valid and active
/// 
/// The hint appears under the Raw Requirements field to guide users
/// on how to include Confluence article links in their requirements.
class ConfluenceHintWidget extends StatelessWidget {
  const ConfluenceHintWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ConfigService>(
      builder: (context, configService, child) {
        // Check if Confluence is enabled and properly configured
        if (!configService.isConfluenceEnabled()) {
          return const SizedBox.shrink(); // Hide widget when not enabled
        }

        return Semantics(
          label: 'Confluence integration hint',
          hint: 'Information about using Confluence links in requirements',
          child: Tooltip(
            message: 'Paste Confluence article URLs directly into your requirements. The content will be automatically processed.',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              margin: const EdgeInsets.only(top: 4, bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.blue.shade200,
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.shade100.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.blue.shade600,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You can specify links to Confluence articles with information to consider in requirements',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                        height: 1.3,
                      ),
                    ),
                  ),
                  Icon(
                    Icons.link,
                    size: 16,
                    color: Colors.blue.shade500,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}