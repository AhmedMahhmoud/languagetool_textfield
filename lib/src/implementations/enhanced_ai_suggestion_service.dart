import 'package:languagetool_textfield/src/domain/ai_suggestion_service.dart';
import 'package:languagetool_textfield/src/domain/mistake.dart';

/// OpenAI-powered suggestion service with enhanced Arabic language support
class EnhancedAiSuggestionService implements AiSuggestionService {
  /// OpenAI API key for generating suggestions
  final String apiKey;

  /// Creates a new instance of EnhancedAiSuggestionService
  const EnhancedAiSuggestionService({required this.apiKey});

  @override
  Future<List<String>> getSuggestions({
    required String fullText,
    required Mistake mistake,
    int contextWindowSize = 100,
  }) async {
    try {
      // Extract the surrounding context
      final startContext = mistake.offset - contextWindowSize;
      final endContext = mistake.offset + mistake.length + contextWindowSize;
      final context = fullText.substring(
        startContext.clamp(0, fullText.length),
        endContext.clamp(0, fullText.length),
      );

      // Build a prompt focused on Arabic language and context
      final mistakeWord = fullText.substring(mistake.offset, mistake.offset + mistake.length);
      final prompt = '''
        للنص التالي، قم بتصحيح الكلمة "$mistakeWord" مع مراعاة السياق:
        السياق: $context
        ''';

      // TODO: Make API call to OpenAI to get suggestions
      // For now return placeholder suggestions
      return ['اقتراح 1', 'اقتراح 2', 'اقتراح 3'];
    } catch (e) {
      print('Error getting AI suggestions: $e');
      return [];
    }
  }
}