import 'package:json_annotation/json_annotation.dart';

part 'confluence_page.g.dart';

@JsonSerializable()
class ConfluencePage {
  final String id;
  final String title;
  final String url;
  final int version;
  final String spaceKey;
  final ConfluencePageContent? content;
  final ConfluencePageAncestors? ancestors;

  const ConfluencePage({
    required this.id,
    required this.title,
    required this.url,
    required this.version,
    required this.spaceKey,
    this.content,
    this.ancestors,
  });

  factory ConfluencePage.fromJson(Map<String, dynamic> json) => 
      _$ConfluencePageFromJson(json);
  
  Map<String, dynamic> toJson() => _$ConfluencePageToJson(this);

  /// Creates a copy with updated fields
  ConfluencePage copyWith({
    String? id,
    String? title,
    String? url,
    int? version,
    String? spaceKey,
    ConfluencePageContent? content,
    ConfluencePageAncestors? ancestors,
  }) {
    return ConfluencePage(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      version: version ?? this.version,
      spaceKey: spaceKey ?? this.spaceKey,
      content: content ?? this.content,
      ancestors: ancestors ?? this.ancestors,
    );
  }

  /// Extracts page ID from Confluence URL
  static String? extractPageIdFromUrl(String url) {
    // Pattern: https://domain.atlassian.net/wiki/spaces/SPACE/pages/123456/Page+Title
    final pageIdRegex = RegExp(r'/pages/(\d+)(?:/|$)');
    final match = pageIdRegex.firstMatch(url);
    return match?.group(1);
  }

  /// Validates if the URL is a valid Confluence page URL
  static bool isValidConfluencePageUrl(String url) {
    return extractPageIdFromUrl(url) != null;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConfluencePage &&
        other.id == id &&
        other.title == title &&
        other.url == url &&
        other.version == version &&
        other.spaceKey == spaceKey &&
        other.content == content &&
        other.ancestors == ancestors;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      title,
      url,
      version,
      spaceKey,
      content,
      ancestors,
    );
  }

  @override
  String toString() {
    return 'ConfluencePage(id: $id, title: $title, url: $url, '
           'version: $version, spaceKey: $spaceKey)';
  }
}

@JsonSerializable()
class ConfluencePageContent {
  final String value;
  final String representation;

  const ConfluencePageContent({
    required this.value,
    required this.representation,
  });

  factory ConfluencePageContent.fromJson(Map<String, dynamic> json) => 
      _$ConfluencePageContentFromJson(json);
  
  Map<String, dynamic> toJson() => _$ConfluencePageContentToJson(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConfluencePageContent &&
        other.value == value &&
        other.representation == representation;
  }

  @override
  int get hashCode => Object.hash(value, representation);

  @override
  String toString() {
    return 'ConfluencePageContent(representation: $representation, '
           'value: ${value.length > 100 ? '${value.substring(0, 100)}...' : value})';
  }
}

@JsonSerializable()
class ConfluencePageAncestors {
  final List<ConfluencePageAncestor> results;

  const ConfluencePageAncestors({
    required this.results,
  });

  factory ConfluencePageAncestors.fromJson(Map<String, dynamic> json) => 
      _$ConfluencePageAncestorsFromJson(json);
  
  Map<String, dynamic> toJson() => _$ConfluencePageAncestorsToJson(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConfluencePageAncestors &&
        other.results == results;
  }

  @override
  int get hashCode => results.hashCode;
}

@JsonSerializable()
class ConfluencePageAncestor {
  final String id;
  final String title;

  const ConfluencePageAncestor({
    required this.id,
    required this.title,
  });

  factory ConfluencePageAncestor.fromJson(Map<String, dynamic> json) => 
      _$ConfluencePageAncestorFromJson(json);
  
  Map<String, dynamic> toJson() => _$ConfluencePageAncestorToJson(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConfluencePageAncestor &&
        other.id == id &&
        other.title == title;
  }

  @override
  int get hashCode => Object.hash(id, title);

  @override
  String toString() {
    return 'ConfluencePageAncestor(id: $id, title: $title)';
  }
}