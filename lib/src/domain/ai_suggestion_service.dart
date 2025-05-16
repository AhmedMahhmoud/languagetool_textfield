import 'package:languagetool_textfield/src/domain/mistake.dart';

/// Interface for AI-powered suggestion services
abstract class AiSuggestionService {
  /// Get AI-powered suggestions for a mistake, taking into account the full context
  Future<List<String>> getSuggestions({
    required String fullText,
    required Mistake mistake,
    int contextWindowSize = 100,
  });
}
