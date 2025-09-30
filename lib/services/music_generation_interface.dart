import '../models/gen_api_models.dart';

abstract class IMusicGenerationService {
  Future<GenApiUserInfo> getUserInfo();
  Future<GenApiResponse> generateMusic({
    required String title,
    required String tags,
    required String prompt,
    String? model,
    bool? translateInput,
  });
  Future<GenApiResponse> getRequestStatus(String requestId);
  Future<List<String>> downloadMusicFiles({
    required List<String> audioUrls,
    required String sessionId,
  });
  String generateSessionId(String requirements);
  String generateRequirementsHash(String requirements);
  void dispose();
}