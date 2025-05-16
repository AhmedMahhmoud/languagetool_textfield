import 'package:languagetool_textfield/src/client/language_tool_client.dart';
import 'package:languagetool_textfield/src/domain/ai_suggestion_service.dart';
import 'package:languagetool_textfield/src/domain/language_check_service.dart';
import 'package:languagetool_textfield/src/domain/mistake.dart';
import 'package:languagetool_textfield/src/domain/writing_mistake.dart';
import 'package:languagetool_textfield/src/services/ai_suggestion_service.dart';
import 'package:languagetool_textfield/src/utils/result.dart';

/// An implementation of language check service with language tool service.
class LangToolService extends LanguageCheckService {
  /// An instance of this class that is used to interact with LanguageTool API.
  final LanguageToolClient languageTool;

  /// Optional AI suggestion service for context-aware corrections
  final AiSuggestionService? aiSuggestionService;

  /// Creates a new instance of the [LangToolService].
  LangToolService(this.languageTool, {this.aiSuggestionService});

  @override
  Future<Result<List<Mistake>>> findMistakes(String text) async {
    try {
      final result = await languageTool.check(text);
      final enhancedMistakes = <Mistake>[];

      for (var m in result) {
        var replacements = List<String>.from(m.replacements);

        // If AI service is available, enhance with context-aware suggestions
        if (aiSuggestionService != null) {
          try {
            final mistake = Mistake(
              message: m.message,
              type: m.issueType,
              offset: m.offset,
              length: m.length,
              replacements: replacements,
            );

            final aiSuggestions = await aiSuggestionService!.getSuggestions(
              fullText: text,
              contextWindowSize: 100,
              mistake: mistake,
            );

            // Add AI suggestions at the beginning of the list
            replacements = [
              ...aiSuggestions,
              ...replacements,
            ].toSet().toList(); // Remove duplicates
          } catch (e) {
            print('AI suggestion error: $e');
            // Continue with base suggestions if AI fails
          }
        }

        enhancedMistakes.add(Mistake(
          message: m.message,
          type: m.issueType,
          offset: m.offset,
          length: m.length,
          replacements: replacements,
        ));
      }

      return Result.success(enhancedMistakes);
    } catch (e) {
      return Result.error(e);
    }
  }
}
