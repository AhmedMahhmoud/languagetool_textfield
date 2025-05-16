import 'package:languagetool_textfield/src/domain/ai_suggestion_service.dart';
import 'package:languagetool_textfield/src/domain/mistake.dart';

/// A basic Arabic language suggestion service that provides suggestions
/// without requiring external API calls. This acts as a fallback when
/// OpenAI integration is not available.
class ArabicAiSuggestionService implements AiSuggestionService {
  // Common Arabic word replacements
  static final Map<String, List<String>> _commonReplacements = {
    // Hamza variations
    'ا': ['أ', 'إ', 'آ'],
    'اذا': ['إذا'],
    'ان': ['أن', 'إن'],
    'انت': ['أنت'],
    'انتم': ['أنتم'],
    'انا': ['أنا'],
    'اي': ['أي'],
    'اين': ['أين'],
    // Common mistakes
    'هاذا': ['هذا'],
    'هاذه': ['هذه'],
    'لاكن': ['لكن'],
    'الذى': ['الذي'],
    'الى': ['إلى'],
    'علي': ['على'],
    // Taa Marbuta variations
    'ه': ['ة'],
    'ة': ['ه'],
  };

  @override
  Future<List<String>> getSuggestions({
    required String fullText,
    required Mistake mistake,
    int contextWindowSize = 100,
  }) async {
    final mistakenWord = fullText.substring(mistake.offset, mistake.endOffset);
    final suggestions = <String>{};

    // 1. Check direct replacements
    if (_commonReplacements.containsKey(mistakenWord)) {
      suggestions.addAll(_commonReplacements[mistakenWord]!);
    }

    // 2. Check character by character replacements
    final chars = mistakenWord.split('');
    for (var i = 0; i < chars.length; i++) {
      final char = chars[i];
      if (_commonReplacements.containsKey(char)) {
        for (final replacement in _commonReplacements[char]!) {
          final newWord = List<String>.from(chars);
          newWord[i] = replacement;
          suggestions.add(newWord.join());
        }
      }
    }

    // 3. Remove duplicates and convert to list
    final result = suggestions.toList();

    // 4. Add existing suggestions if they're not already included
    for (final existing in mistake.replacements) {
      if (!result.contains(existing)) {
        result.add(existing);
      }
    }

    return result;
  }
}
