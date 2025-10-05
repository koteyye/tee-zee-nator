import 'package:flutter/material.dart';
import '../../../theme/ide_theme.dart';

/// Тип изменения в diff
enum DiffType {
  unchanged,
  added,
  removed,
}

/// Строка diff с типом изменения
class DiffLine {
  final String content;
  final DiffType type;
  final int? originalLineNumber;
  final int? modifiedLineNumber;

  DiffLine({
    required this.content,
    required this.type,
    this.originalLineNumber,
    this.modifiedLineNumber,
  });
}

/// Виджет для отображения различий между версиями файла
class DiffViewer extends StatelessWidget {
  final String original;
  final String modified;

  const DiffViewer({
    super.key,
    required this.original,
    required this.modified,
  });

  @override
  Widget build(BuildContext context) {
    final diffs = _computeDiff(original, modified);

    return Container(
      color: IDETheme.editorBackground,
      child: ListView.builder(
        itemCount: diffs.length,
        itemBuilder: (context, index) {
          final diff = diffs[index];
          return _buildDiffLine(context, diff);
        },
      ),
    );
  }

  /// Вычислить построчный diff
  List<DiffLine> _computeDiff(String original, String modified) {
    final originalLines = original.split('\n');
    final modifiedLines = modified.split('\n');
    final result = <DiffLine>[];

    // Простой построчный алгоритм diff
    int origIndex = 0;
    int modIndex = 0;

    while (origIndex < originalLines.length || modIndex < modifiedLines.length) {
      if (origIndex >= originalLines.length) {
        // Только добавления остались
        result.add(DiffLine(
          content: modifiedLines[modIndex],
          type: DiffType.added,
          modifiedLineNumber: modIndex + 1,
        ));
        modIndex++;
      } else if (modIndex >= modifiedLines.length) {
        // Только удаления остались
        result.add(DiffLine(
          content: originalLines[origIndex],
          type: DiffType.removed,
          originalLineNumber: origIndex + 1,
        ));
        origIndex++;
      } else if (originalLines[origIndex] == modifiedLines[modIndex]) {
        // Строки одинаковые
        result.add(DiffLine(
          content: originalLines[origIndex],
          type: DiffType.unchanged,
          originalLineNumber: origIndex + 1,
          modifiedLineNumber: modIndex + 1,
        ));
        origIndex++;
        modIndex++;
      } else {
        // Строки различаются - проверяем следующие строки
        final nextOrigInMod = _findInList(
          originalLines[origIndex],
          modifiedLines,
          modIndex,
        );
        final nextModInOrig = _findInList(
          modifiedLines[modIndex],
          originalLines,
          origIndex,
        );

        if (nextOrigInMod != -1 && (nextModInOrig == -1 || nextOrigInMod < nextModInOrig)) {
          // Найдена текущая оригинальная строка позже в modified - значит были добавления
          while (modIndex < nextOrigInMod) {
            result.add(DiffLine(
              content: modifiedLines[modIndex],
              type: DiffType.added,
              modifiedLineNumber: modIndex + 1,
            ));
            modIndex++;
          }
        } else if (nextModInOrig != -1) {
          // Найдена текущая modified строка позже в original - значит были удаления
          while (origIndex < nextModInOrig) {
            result.add(DiffLine(
              content: originalLines[origIndex],
              type: DiffType.removed,
              originalLineNumber: origIndex + 1,
            ));
            origIndex++;
          }
        } else {
          // Не найдено совпадений - считаем замененными строками
          result.add(DiffLine(
            content: originalLines[origIndex],
            type: DiffType.removed,
            originalLineNumber: origIndex + 1,
          ));
          result.add(DiffLine(
            content: modifiedLines[modIndex],
            type: DiffType.added,
            modifiedLineNumber: modIndex + 1,
          ));
          origIndex++;
          modIndex++;
        }
      }
    }

    return result;
  }

  /// Найти строку в списке начиная с индекса
  int _findInList(String str, List<String> list, int startIndex) {
    for (int i = startIndex; i < list.length && i < startIndex + 5; i++) {
      if (list[i] == str) return i;
    }
    return -1;
  }

  /// Построить строку diff
  Widget _buildDiffLine(BuildContext context, DiffLine diff) {
    Color? backgroundColor;
    Color? borderColor;

    switch (diff.type) {
      case DiffType.added:
        backgroundColor = IDETheme.diffAddedBackground;
        borderColor = IDETheme.diffAddedBorder;
        break;
      case DiffType.removed:
        backgroundColor = IDETheme.diffRemovedBackground;
        borderColor = IDETheme.diffRemovedBorder;
        break;
      case DiffType.unchanged:
        backgroundColor = null;
        borderColor = null;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: borderColor != null
            ? Border(left: BorderSide(color: borderColor, width: 3))
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Номера строк
          _buildLineNumbers(diff),
          // Содержимое строки
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: SelectableText(
                diff.content.isEmpty ? ' ' : diff.content,
                style: IDETheme.codeStyle.copyWith(
                  color: diff.type == DiffType.removed
                      ? IDETheme.textSecondary
                      : IDETheme.textPrimary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Построить номера строк
  Widget _buildLineNumbers(DiffLine diff) {
    return Container(
      width: 80,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: IDETheme.surfaceColor.withOpacity(0.5),
        border: Border(
          right: BorderSide(color: IDETheme.borderColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Номер оригинальной строки
          SizedBox(
            width: 30,
            child: Text(
              diff.originalLineNumber?.toString() ?? '',
              textAlign: TextAlign.right,
              style: IDETheme.bodySmallStyle.copyWith(
                color: IDETheme.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ),
          // Номер измененной строки
          SizedBox(
            width: 30,
            child: Text(
              diff.modifiedLineNumber?.toString() ?? '',
              textAlign: TextAlign.right,
              style: IDETheme.bodySmallStyle.copyWith(
                color: IDETheme.textSecondary,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
