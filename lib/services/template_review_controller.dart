import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';

enum TemplateReviewPhase { idle, reviewing, reviewCompleted, fixing, fixCompleted, error }
enum TemplateReviewSeverity { ok, minor, critical }

class TemplateReviewController extends ChangeNotifier {
  TemplateReviewPhase phase = TemplateReviewPhase.idle;
  TemplateReviewSeverity severity = TemplateReviewSeverity.ok;
  String reviewText = '';
  String? fixBuffer;
  String? errorMessage;
  String originalContentSnapshot = '';
  bool ignoreCritical = false;
  DateTime? lastReviewedAt;

  StreamSubscription<String>? _subscription;

  bool get canSave => severity != TemplateReviewSeverity.critical || ignoreCritical;

  // Legacy tag constants kept only for potential fallback display if model emits them inside text
  static const criticalTag = '[КРИТИЧЕСКОЕ ЗАМЕЧАНИЕ]';
  static const minorTag = '[НЕЗНАЧИТЕЛЬНОЕ ЗАМЕЧАНИЕ]';
  static const legacyCritical = '[CRITICAL_ALERT]';

  void startReview({required Stream<String> stream, required String currentContent}) {
    cancel();
    originalContentSnapshot = currentContent;
    phase = TemplateReviewPhase.reviewing;
    severity = TemplateReviewSeverity.ok;
    reviewText = '';
    errorMessage = null;
    notifyListeners();
  _subscription = stream.listen(_onLine, onError: (e) {
      errorMessage = '$e';
      phase = TemplateReviewPhase.error;
      notifyListeners();
    }, onDone: () {
      if (phase != TemplateReviewPhase.error) {
        phase = TemplateReviewPhase.reviewCompleted;
        lastReviewedAt = DateTime.now();
        notifyListeners();
      }
    });
  }

  void _onLine(String line) {
    // Try parse NDJSON line(s). Chunks may contain multiple lines or partial.
    // We still append raw for display after extracting deltas.
    // If it's valid JSON with event field we handle specially.
    final segments = line.split(RegExp(r'\r?\n'));
    for (final seg in segments) {
      if (seg.trim().isEmpty) continue;
      final parsed = _tryParseJson(seg.trim());
      if (parsed != null && parsed is Map && parsed['event'] == 'meta') {
        final isCritical = parsed['isCritical'] == true;
        final isMinor = parsed['isMinor'] == true;
        if (isCritical) {
          severity = TemplateReviewSeverity.critical;
        } else if (isMinor) {
          severity = TemplateReviewSeverity.minor;
        } else {
          severity = TemplateReviewSeverity.ok;
        }
      } else if (parsed != null && parsed is Map && parsed['event'] == 'text') {
        final delta = parsed['delta'];
        if (delta is String) {
          reviewText += delta + '\n';
        }
      } else {
        // Fallback: treat as raw text (legacy models w/o NDJSON compliance)
        reviewText += seg;
      }
    }
    notifyListeners();
  }

  dynamic _tryParseJson(String s) {
    try {
      if (!(s.startsWith('{') && s.endsWith('}'))) return null;
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  // ---- FIX MODE ----
  void startFix({required Stream<String> stream, required String currentContent}) {
    if (phase != TemplateReviewPhase.reviewCompleted) return; // allow only after review
    cancel();
    originalContentSnapshot = currentContent; // snapshot for potential diff / revert
    fixBuffer = '';
    phase = TemplateReviewPhase.fixing;
    errorMessage = null;
    notifyListeners();
    _subscription = stream.listen((chunk) {
      fixBuffer = (fixBuffer ?? '') + chunk;
      notifyListeners();
    }, onError: (e) {
      errorMessage = '$e';
      phase = TemplateReviewPhase.error;
      notifyListeners();
    }, onDone: () {
      if (phase != TemplateReviewPhase.error) {
        phase = TemplateReviewPhase.fixCompleted;
        notifyListeners();
      }
    });
  }

  String? acceptFix() {
    if (phase != TemplateReviewPhase.fixCompleted || fixBuffer == null) return null;
    final result = fixBuffer!;
    // Reset state for a fresh cycle; severity сбрасываем в ok, ревью нужно заново при желании
    reset();
    return result;
  }

  void rejectFix() {
    if (phase != TemplateReviewPhase.fixCompleted) return;
    // Возвращаемся к результату ревью (со старыми замечаниями)
    cancel();
    phase = TemplateReviewPhase.reviewCompleted;
    notifyListeners();
  }

  void setIgnoreCritical(bool value) {
    ignoreCritical = value;
    notifyListeners();
  }

  void reset() {
    cancel();
    phase = TemplateReviewPhase.idle;
    severity = TemplateReviewSeverity.ok;
    reviewText = '';
    fixBuffer = null;
    errorMessage = null;
    ignoreCritical = false;
    notifyListeners();
  }

  void cancel() {
    _subscription?.cancel();
    _subscription = null;
  }

  @override
  void dispose() {
    cancel();
    super.dispose();
  }
}
