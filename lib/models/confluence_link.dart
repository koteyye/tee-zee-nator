import 'package:json_annotation/json_annotation.dart';

part 'confluence_link.g.dart';

@JsonSerializable()
class ConfluenceLink {
  final String originalUrl;
  final String pageId;
  final String extractedContent;
  final DateTime processedAt;
  final bool isValid;
  final String? errorMessage;

  const ConfluenceLink({
    required this.originalUrl,
    required this.pageId,
    required this.extractedContent,
    required this.processedAt,
    this.isValid = true,
    this.errorMessage,
  });

  factory ConfluenceLink.fromJson(Map<String, dynamic> json) => 
      _$ConfluenceLinkFromJson(json);
  
  Map<String, dynamic> toJson() => _$ConfluenceLinkToJson(this);

  /// Creates a failed link with error information
  factory ConfluenceLink.failed({
    required String originalUrl,
    required String pageId,
    required String errorMessage,
  }) {
    return ConfluenceLink(
      originalUrl: originalUrl,
      pageId: pageId,
      extractedContent: '',
      processedAt: DateTime.now(),
      isValid: false,
      errorMessage: errorMessage,
    );
  }

  /// Creates a successful link with extracted content
  factory ConfluenceLink.success({
    required String originalUrl,
    required String pageId,
    required String extractedContent,
  }) {
    return ConfluenceLink(
      originalUrl: originalUrl,
      pageId: pageId,
      extractedContent: extractedContent,
      processedAt: DateTime.now(),
      isValid: true,
    );
  }

  /// Creates a copy with updated fields
  ConfluenceLink copyWith({
    String? originalUrl,
    String? pageId,
    String? extractedContent,
    DateTime? processedAt,
    bool? isValid,
    String? errorMessage,
  }) {
    return ConfluenceLink(
      originalUrl: originalUrl ?? this.originalUrl,
      pageId: pageId ?? this.pageId,
      extractedContent: extractedContent ?? this.extractedContent,
      processedAt: processedAt ?? this.processedAt,
      isValid: isValid ?? this.isValid,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// Checks if the link processing is still fresh (within cache TTL)
  bool isFresh({Duration ttl = const Duration(minutes: 30)}) {
    return DateTime.now().difference(processedAt) < ttl;
  }

  /// Returns the content marker format for LLM processing
  String get contentMarker {
    if (!isValid || extractedContent.isEmpty) {
      return originalUrl; // Return original URL if processing failed
    }
    return '@conf-cnt $extractedContent@';
  }

  /// Extracts page ID from the original URL
  static String? extractPageIdFromUrl(String url) {
    // Try /pages/{id}
    final pagesIdRegex = RegExp(r'/pages/(\d+)(?:/|$)');
    final m1 = pagesIdRegex.firstMatch(url);
    if (m1 != null) return m1.group(1);

    // Try query param pageId=123456 (viewpage.action?pageId=123456)
    try {
      final uri = Uri.parse(url);
      final qpId = uri.queryParameters['pageId'];
      if (qpId != null && RegExp(r'^\d+$').hasMatch(qpId)) {
        return qpId;
      }
    } catch (_) {}

    // No ID detected
    return null;
  }

  /// Validates if the URL matches the expected Confluence pattern
  static bool isValidConfluenceUrl(String url, String baseUrl) {
    try {
      final uri = Uri.parse(url);
      final baseUri = Uri.parse(baseUrl);

      // Host must match configured Confluence host
      if (uri.host != baseUri.host) {
        return false;
      }

      // Accept typical Confluence paths, including self-hosted/DC and tiny links
      final path = uri.path.toLowerCase();
      final looksConfluencePath = path.contains('/wiki/') ||
          path.contains('/pages/') ||
          path.contains('/display/') ||
          path.startsWith('/x/') ||
          path.contains('viewpage.action');

      // Consider valid if it looks like a Confluence path and either already has pageId,
      // or we can try to resolve it later (tiny link). Here we only filter obvious non-Confluence URLs.
      if (!looksConfluencePath) return false;

      // If pageId can be extracted now, even better
      final id = extractPageIdFromUrl(url);
      return id != null || path.startsWith('/x/');
    } catch (_) {
      return false;
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConfluenceLink &&
        other.originalUrl == originalUrl &&
        other.pageId == pageId &&
        other.extractedContent == extractedContent &&
        other.processedAt == processedAt &&
        other.isValid == isValid &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode {
    return Object.hash(
      originalUrl,
      pageId,
      extractedContent,
      processedAt,
      isValid,
      errorMessage,
    );
  }

  @override
  String toString() {
    return 'ConfluenceLink(originalUrl: $originalUrl, pageId: $pageId, '
           'isValid: $isValid, processedAt: $processedAt, '
           'contentLength: ${extractedContent.length})';
  }
}