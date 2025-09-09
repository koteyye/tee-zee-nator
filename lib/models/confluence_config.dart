import 'package:hive/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import '../services/secure_token_storage.dart';
import '../services/input_sanitizer.dart';

part 'confluence_config.g.dart';

@HiveType(typeId: 12)
@JsonSerializable()
class ConfluenceConfig {
  @HiveField(0)
  final bool enabled;
  
  @HiveField(1)
  final String baseUrl;
  
  @HiveField(2)
  final String token; // Stored securely, this field contains encrypted reference
  
  @HiveField(3)
  final DateTime? lastValidated;
  
  @HiveField(4)
  final bool isValid;
  
  @HiveField(5)
  final String email; // Email address for Confluence authentication

  const ConfluenceConfig({
    required this.enabled,
    required this.baseUrl,
    required this.token,
    this.lastValidated,
    this.isValid = false,
    this.email = '',
  });

  factory ConfluenceConfig.fromJson(Map<String, dynamic> json) => 
      _$ConfluenceConfigFromJson(json);
  
  Map<String, dynamic> toJson() => _$ConfluenceConfigToJson(this);

  /// Creates a default disabled configuration
  factory ConfluenceConfig.disabled() {
    return const ConfluenceConfig(
      enabled: false,
      baseUrl: '',
      token: '',
      email: '',
      isValid: false,
    );
  }

  /// Creates a copy with updated fields
  ConfluenceConfig copyWith({
    bool? enabled,
    String? baseUrl,
    String? token,
    DateTime? lastValidated,
    bool? isValid,
    String? email,
  }) {
    return ConfluenceConfig(
      enabled: enabled ?? this.enabled,
      baseUrl: baseUrl ?? this.baseUrl,
      token: token ?? this.token,
      lastValidated: lastValidated ?? this.lastValidated,
      isValid: isValid ?? this.isValid,
      email: email ?? this.email,
    );
  }

  /// Validates the configuration completeness
  bool get isConfigurationComplete {
    return enabled && baseUrl.isNotEmpty && token.isNotEmpty && email.isNotEmpty;
  }

  /// Returns sanitized base URL (removes trailing slashes and wiki/rest/api suffix)
  String get sanitizedBaseUrl {
    String url = baseUrl.trim();
    
    // Remove trailing slashes
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    
    // Remove /wiki/rest/api suffix if present
    if (url.endsWith('/wiki/rest/api')) {
      url = url.substring(0, url.length - '/wiki/rest/api'.length);
    }
    
    return url;
  }

  /// Returns the full API base URL
  /// - Cloud: https://<host>/wiki/rest/api (unless base already contains /wiki)
  /// - DC/Server: https://<host>/rest/api (preserves context path)
  String get apiBaseUrl {
    final uri = Uri.tryParse(sanitizedBaseUrl);
    if (uri == null) return '$sanitizedBaseUrl/rest/api';

    final segments = uri.pathSegments;
    final hasWiki = segments.contains('wiki');
    final isCloud = uri.host.endsWith('.atlassian.net');
    final base = sanitizedBaseUrl;

    if (isCloud) {
      return hasWiki ? '$base/rest/api' : '$base/wiki/rest/api';
    }
    // Self-hosted/DC
    return '$base/rest/api';
  }

  /// Creates a configuration with secure token storage
  /// 
  /// [enabled] - Whether Confluence integration is enabled
  /// [baseUrl] - The Confluence base URL (will be sanitized)
  /// [email] - The email address for Confluence authentication
  /// [token] - The API token (will be stored securely)
  /// [lastValidated] - When the configuration was last validated
  /// [isValid] - Whether the configuration is valid
  static Future<ConfluenceConfig> createSecure({
    required bool enabled,
    required String baseUrl,
    required String email,
    required String token,
    DateTime? lastValidated,
    bool isValid = false,
  }) async {
    // Sanitize inputs
    final sanitizedBaseUrl = InputSanitizer.sanitizeBaseUrl(baseUrl);
    final sanitizedEmail = InputSanitizer.sanitizeEmail(email);
    final sanitizedToken = InputSanitizer.sanitizeApiToken(token);
    
    if (enabled && sanitizedBaseUrl.isEmpty) {
      throw ArgumentError('Invalid base URL provided');
    }
    
    if (enabled && sanitizedEmail.isEmpty) {
      throw ArgumentError('Invalid email provided');
    }
    
    if (enabled && sanitizedToken.isEmpty) {
      throw ArgumentError('Invalid token provided');
    }
    
    // Store token securely if provided
    String tokenReference = '';
    if (sanitizedToken.isNotEmpty) {
      final stored = await SecureTokenStorage.storeConfluenceToken(sanitizedToken);
      if (stored) {
        tokenReference = 'secure_${DateTime.now().millisecondsSinceEpoch}';
      } else {
        throw StateError('Failed to store token securely');
      }
    }
    
    return ConfluenceConfig(
      enabled: enabled,
      baseUrl: sanitizedBaseUrl,
      email: sanitizedEmail,
      token: tokenReference,
      lastValidated: lastValidated,
      isValid: isValid,
    );
  }

  /// Retrieves the actual token from secure storage
  /// 
  /// Returns the decrypted token or null if not available
  Future<String?> getSecureToken() async {
    if (token.isEmpty || !token.startsWith('secure_')) {
      return token.isEmpty ? null : token; // Fallback for legacy tokens
    }
    
    return await SecureTokenStorage.getConfluenceToken();
  }

  /// Updates the configuration with a new secure token
  /// 
  /// [newToken] - The new token to store securely
  /// Returns updated configuration
  Future<ConfluenceConfig> updateSecureToken(String newToken) async {
    final sanitizedToken = InputSanitizer.sanitizeApiToken(newToken);
    
    if (sanitizedToken.isEmpty) {
      throw ArgumentError('Invalid token provided');
    }
    
    // Store new token securely
    final stored = await SecureTokenStorage.storeConfluenceToken(sanitizedToken);
    if (!stored) {
      throw StateError('Failed to store token securely');
    }
    
    final tokenReference = 'secure_${DateTime.now().millisecondsSinceEpoch}';
    
    return copyWith(
      token: tokenReference,
      lastValidated: DateTime.now(),
      isValid: false, // Reset validation status
    );
  }

  /// Validates that the secure token is accessible
  /// 
  /// Returns true if token can be retrieved from secure storage
  Future<bool> validateSecureToken() async {
    if (token.isEmpty) return false;
    
    if (token.startsWith('secure_')) {
      return await SecureTokenStorage.validateStoredToken();
    }
    
    // Legacy token validation
    return token.isNotEmpty;
  }

  /// Clears the secure token from storage
  /// 
  /// Returns updated configuration with cleared token
  Future<ConfluenceConfig> clearSecureToken() async {
    if (token.startsWith('secure_')) {
      await SecureTokenStorage.removeConfluenceToken();
    }
    
    return copyWith(
      token: '',
      isValid: false,
      lastValidated: null,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConfluenceConfig &&
        other.enabled == enabled &&
        other.baseUrl == baseUrl &&
        other.token == token &&
        other.email == email &&
        other.lastValidated == lastValidated &&
        other.isValid == isValid;
  }

  @override
  int get hashCode {
    return Object.hash(
      enabled,
      baseUrl,
      token,
      email,
      lastValidated,
      isValid,
    );
  }

  @override
  String toString() {
    return 'ConfluenceConfig(enabled: $enabled, baseUrl: $baseUrl, '
           'token: [REDACTED], lastValidated: $lastValidated, isValid: $isValid)';
  }
}