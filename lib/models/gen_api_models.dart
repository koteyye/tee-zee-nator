import 'package:json_annotation/json_annotation.dart';

part 'gen_api_models.g.dart';

@JsonSerializable(includeIfNull: false, explicitToJson: true)
class GenApiRequest {
  final String title;
  final String tags;
  final String prompt;
  final String? model; // версия API GenAPI (например "v5")
  @JsonKey(name: 'translate_input')
  final bool? translateInput;
  @JsonKey(name: 'callback_url')
  final String? callbackUrl;

  const GenApiRequest({
    required this.title,
    required this.tags,
    required this.prompt,
    this.model,
    this.translateInput,
    this.callbackUrl,
  });

  factory GenApiRequest.fromJson(Map<String, dynamic> json) =>
      _$GenApiRequestFromJson(json);

  Map<String, dynamic> toJson() => _$GenApiRequestToJson(this);
}

@JsonSerializable(explicitToJson: true)
class GenApiResponse {
  @JsonKey(fromJson: _idFromJson)
  final String? id;
  @JsonKey(name: 'request_id', fromJson: _requestIdFromJson)
  final String? requestId;
  final String status;
  final int? progress;
  final List<dynamic>? result;
  final String? error;
  @JsonKey(name: 'response_type')
  final String? responseType;
  final double? cost;
  final Map<String, dynamic>? input;

  const GenApiResponse({
    this.id,
    this.requestId,
    required this.status,
    this.progress,
    this.result,
    this.error,
    this.responseType,
    this.cost,
    this.input,
  });

  static String? _idFromJson(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is int) return value.toString();
    return value.toString();
  }

  static String? _requestIdFromJson(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is int) return value.toString();
    return value.toString();
  }

  factory GenApiResponse.fromJson(Map<String, dynamic> json) =>
      _$GenApiResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GenApiResponseToJson(this);

  /// Извлекает URL аудио-файлов из результата
  List<String> get audioUrls {
    if (result == null || result!.isEmpty) return [];

    final urls = <String>[];
    for (final item in result!) {
      // Элемент может быть прямой строкой с URL
      if (item is String && item.endsWith('.mp3')) {
        urls.add(item);
      }
      // Или объектом с полем 'url'
      else if (item is Map<String, dynamic>) {
        final url = item['url'];
        if (url is String && url.endsWith('.mp3')) {
          urls.add(url);
        }
      }
    }
    return urls;
  }
}

@JsonSerializable(explicitToJson: true)
class GenApiUserInfo {
  @JsonKey(fromJson: _balanceFromJson)
  final String? balance;
  final String? currency;
  final Map<String, dynamic>? limits;
  final String? status;

  const GenApiUserInfo({
    this.balance,
    this.currency,
    this.limits,
    this.status,
  });

  factory GenApiUserInfo.fromJson(Map<String, dynamic> json) =>
      _$GenApiUserInfoFromJson(json);

  Map<String, dynamic> toJson() => _$GenApiUserInfoToJson(this);

  static String? _balanceFromJson(dynamic value) {
    if (value == null) return null;
    if (value is String) return value;
    if (value is num) return value.toString();
    return value.toString();
  }
}