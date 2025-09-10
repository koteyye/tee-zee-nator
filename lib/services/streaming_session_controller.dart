import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/output_format.dart';
import 'streaming_llm_service.dart';

class StreamingState {
  final bool active;
  final bool finalized;
  final bool aborted; // true only if user initiated abort
  final String phase;
  final int progress;
  final String document;
  final bool hasContent;
  final String? summary;
  final String? error;

  const StreamingState({
    required this.active,
    required this.finalized,
    required this.aborted,
    required this.phase,
    required this.progress,
    required this.document,
    required this.hasContent,
    this.summary,
    this.error,
  });

  StreamingState copyWith({
    bool? active,
    bool? finalized,
    bool? aborted,
    String? phase,
    int? progress,
    String? document,
    bool? hasContent,
    String? summary,
    String? error,
  }) => StreamingState(
    active: active ?? this.active,
    finalized: finalized ?? this.finalized,
    aborted: aborted ?? this.aborted,
    phase: phase ?? this.phase,
    progress: progress ?? this.progress,
    document: document ?? this.document,
    hasContent: hasContent ?? this.hasContent,
    summary: summary ?? this.summary,
    error: error ?? this.error,
  );

  factory StreamingState.initial() => const StreamingState(
    active: false,
    finalized: false,
    aborted: false,
    phase: 'init',
    progress: 0,
    document: '',
    hasContent: false,
    summary: null,
    error: null,
  );
}

class StreamingSessionController extends ChangeNotifier {
  final StreamingLLMService _streamingService;
  StreamingState _state = StreamingState.initial();
  StreamSubscription<String>? _subscription;
  int _errorLines = 0;
  static const int _maxParseErrors = 3;
  void Function(StreamingState)? onFinalized; // optional external callback

  StreamingState get state => _state;
  String get document => _state.document;
  bool get isActive => _state.active;
  bool get isFinalized => _state.finalized;
  bool get isAborted => _state.aborted;

  StreamingSessionController(this._streamingService);

  Future<void> start({
    required String rawRequirements,
    String? changes,
    String? templateContent,
    required OutputFormat format,
  }) async {
    await abort();
  _state = StreamingState.initial().copyWith(active: true, aborted: false);
    notifyListeners();

    final stream = _streamingService.startSpecificationStream(
      rawRequirements: rawRequirements,
      changes: changes,
      templateContent: templateContent,
      format: format,
    );

    _subscription = stream.listen(_handleLine, onError: (e) {
      _state = _state.copyWith(
        error: 'Ошибка потока: $e',
        active: false,
        finalized: true,
        aborted: false,
        phase: 'finalize',
        progress: 100,
      );
      notifyListeners();
    }, onDone: () {
      if (!_state.finalized) {
  _state = _state.copyWith(active: false, finalized: true, aborted: false);
  notifyListeners();
  if (onFinalized != null) onFinalized!(_state);
      }
    });
  }

  void _handleLine(String line) {
    try {
      final Map<String, dynamic> jsonLine = jsonDecode(line) as Map<String, dynamic>;
      final type = jsonLine['stream_type'];
      switch (type) {
        case 'status':
          final phase = jsonLine['phase']?.toString() ?? _state.phase;
            final progress = (jsonLine['progress'] is int)
              ? jsonLine['progress'] as int
              : int.tryParse(jsonLine['progress'].toString()) ?? _state.progress;
          if (progress < _state.progress) {
            // Ignore regress
            return;
          }
          _state = _state.copyWith(phase: phase, progress: progress);
          break;
        case 'content':
          String document = _state.document;
          if (jsonLine.containsKey('append')) {
            final chunk = jsonLine['append']?.toString() ?? '';
            if (chunk.isNotEmpty) {
              document += chunk;
            }
          } else if (jsonLine.containsKey('full')) {
            document = jsonLine['full']?.toString() ?? document;
          }
          final hasContent = document.trim().isNotEmpty;
          _state = _state.copyWith(document: document, hasContent: hasContent);
          break;
        case 'final':
          _state = _state.copyWith(
            finalized: true,
            active: false,
            aborted: false,
            progress: 100,
            summary: jsonLine['summary']?.toString(),
          );
          if (onFinalized != null) onFinalized!(_state);
          break;
        default:
          _errorLines++;
          if (_errorLines >= _maxParseErrors) {
            _state = _state.copyWith(
              error: 'Слишком много некорректных строк потока',
              active: false,
              finalized: true,
              aborted: false,
            );
          }
      }
      notifyListeners();
    } catch (e) {
      _errorLines++;
      if (_errorLines >= _maxParseErrors) {
        _state = _state.copyWith(
          error: 'Ошибка парсинга: $e',
          active: false,
          finalized: true,
          aborted: false,
        );
        notifyListeners();
      }
    }
  }

  Future<void> abort() async {
    if (_subscription != null) {
      await _subscription!.cancel();
      _subscription = null;
    }
    // Attempt to abort provider-level stream if supported
    try {
      _streamingService.abortCurrent();
    } catch (_) {}
    if (_state.active && !_state.finalized) {
      _state = _state.copyWith(
        active: false,
        finalized: true,
        aborted: true,
        phase: 'finalize',
        summary: _state.summary ?? 'Прервано пользователем',
      );
      notifyListeners();
  if (onFinalized != null) onFinalized!(_state);
    }
  }

  void reset() {
    _state = StreamingState.initial();
    notifyListeners();
  }

  /// Loads a static (already generated) document into the controller state.
  /// Used when user selects an item from history so that UI widgets relying
  /// on streaming state can still display content (including Markdown render).
  void loadStaticDocument(String document) {
    _state = StreamingState.initial().copyWith(
      document: document,
      hasContent: document.trim().isNotEmpty,
      finalized: true,
      active: false,
      phase: 'finalize',
      progress: 100,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
