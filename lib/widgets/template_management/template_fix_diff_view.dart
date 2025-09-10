import 'package:flutter/material.dart';
import '../../utils/line_diff.dart';

class TemplateFixDiffView extends StatelessWidget {
  final String original;
  final String fixed;
  const TemplateFixDiffView({super.key, required this.original, required this.fixed});

  @override
  Widget build(BuildContext context) {
    final diff = computeLineDiff(original, fixed);
    return Container(
      constraints: const BoxConstraints(maxHeight: 260),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Scrollbar(
        thumbVisibility: true,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
            itemCount: diff.length,
            itemBuilder: (context, index) {
              final seg = diff[index];
              Color? bg;
              Color? fg;
              String prefix;
              switch (seg.op) {
                case DiffOp.equal:
                  prefix = '  ';
                  fg = Theme.of(context).textTheme.bodyMedium?.color;
                  break;
                case DiffOp.add:
                  prefix = '+ ';
                  bg = Colors.green.withOpacity(0.12);
                  fg = Colors.green[800];
                  break;
                case DiffOp.remove:
                  prefix = '- ';
                  bg = Colors.red.withOpacity(0.12);
                  fg = Colors.red[800];
                  break;
              }
              return Container(
                color: bg,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                child: Text(
                  '$prefix${seg.line}',
                  style: TextStyle(fontFamily: 'monospace', fontSize: 13, color: fg),
                ),
              );
            }),
      ),
    );
  }
}
