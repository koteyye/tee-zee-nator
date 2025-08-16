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
    // Pattern: https://domain.atlassian.net/wiki/spaces/SPACE/pages/123456/Page+Title
    final pageIdRegex = RegExp(r'/pages/(\d+)(?:/|$)');
    final match = pageIdRegex.firstMatch(url);
    return match?.group(1);
  }

  /// Validates if the URL matches the expected Confluence pattern
  static bool isValidConfluenceUrl(String url, String baseUrl) {
    try {
      final uri = Uri.parse(url);
      final baseUri = Uri.parse(baseUrl);
      
      // Check if the domain matches
      if (uri.host != baseUri.host) {
        return false;
      }
      
      // Check if it's a wiki page URL
      return uri.path.contains('/wiki/') && extractPageIdFromUrl(url) != null;
    } catch (e) {
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