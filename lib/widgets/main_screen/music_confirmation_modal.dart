import 'package:flutter/material.dart';

class MusicConfirmationModal extends StatelessWidget {
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const MusicConfirmationModal({
    super.key,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.music_note, color: Colors.purple),
          SizedBox(width: 8),
          Text('Музицировать требования?'),
        ],
      ),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Данное действие носит исключительно юмористический характер и вряд ли потребуется в работе, но при этом расходует деньги!',
            style: TextStyle(fontSize: 16),
          ),
          SizedBox(height: 16),
          Text(
            'Уверен, что хочешь затрекать требования?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
        ],
      ),
      actions: [
        IconButton(
          onPressed: onCancel,
          icon: const Icon(Icons.close, color: Colors.red),
          tooltip: 'Отмена',
          style: IconButton.styleFrom(
            backgroundColor: Colors.red.withOpacity(0.1),
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onConfirm,
          icon: const Icon(Icons.check, color: Colors.green),
          tooltip: 'Подтвердить',
          style: IconButton.styleFrom(
            backgroundColor: Colors.green.withOpacity(0.1),
          ),
        ),
      ],
    );
  }

  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => MusicConfirmationModal(
        onConfirm: () => Navigator.of(context).pop(true),
        onCancel: () => Navigator.of(context).pop(false),
      ),
    );
  }
}