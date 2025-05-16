import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:languagetool_textfield/src/domain/ai_suggestion_service.dart';
import 'package:languagetool_textfield/src/domain/mistake.dart';

/// An implementation that uses OpenAI's API to get context-aware suggestions
/// specifically optimized for Arabic text.
class OpenAiSuggestionService implements AiSuggestionService {
  final String apiKey;
  final String model;
  static const _baseUrl = 'https://api.openai.com/v1/chat/completions';

  OpenAiSuggestionService({
    required this.apiKey,
    this.model =
        'gpt-4', // Using GPT-4 for better Arabic language understanding
  });

  @override
  Future<List<String>> getSuggestions({
    required String fullText,
    required Mistake mistake,
    int contextWindowSize = 100,
  }) async {
    try {
      // Get text context around the mistake
      final start =
          (mistake.offset - contextWindowSize).clamp(0, fullText.length);
      final end =
          (mistake.endOffset + contextWindowSize).clamp(0, fullText.length);
      final context = fullText.substring(start, end);
      final mistakenWord =
          fullText.substring(mistake.offset, mistake.endOffset);

      // Prepare the prompt for ChatGPT
      final messages = <Map<String, String>>[
        {
          'role': 'system',
          'content': 'You are an expert Arabic language consultant specialized in MSA (Modern Standard Arabic). '
              'Your task is to analyze the context and suggest corrections for Arabic text. '
              'Consider grammar rules (قواعد النحو), word patterns (أوزان), and proper usage. '
              'Pay special attention to:\n'
              '1. Proper Hamza placement (ء، أ، إ، ئ، ؤ)\n'
              '2. Diacritical marks (تشكيل) when relevant\n'
              '3. Grammatical case (إعراب)\n'
              '4. Conjugation and agreement\n'
              'Return only a JSON array of strings.'
        },
        {
          'role': 'user',
          'content': 'Context: $context\n'
              'Word: $mistakenWord\n'
              'Type: ${mistake.type}\n'
              'Current suggestions: ${mistake.replacements.join(", ")}\n\n'
              'Provide a JSON array of contextually appropriate corrections, '
              'considering grammatical rules and formal Arabic usage.'
        }
      ];

      // Make API request to OpenAI
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': messages,
          'temperature':
              0.3, // Lower temperature for more consistent suggestions
          'max_tokens': 150,
          'presence_penalty': 0.1, // Slightly encourage new suggestions
          'frequency_penalty':
              0.1, // Slightly discourage repetitive suggestions
        }),
      );

      if (response.statusCode == 200) {
        final jsonResponse = jsonDecode(response.body);
        final content =
            jsonResponse['choices'][0]['message']['content'] as String;

        try {
          // Try to parse the JSON response
          final dynamic parsed = jsonDecode(content);
          if (parsed is List) {
            return List<String>.from(parsed);
          } else if (parsed is Map) {
            final suggestions = parsed['suggestions'] ?? parsed['corrections'];
            if (suggestions is List) {
              return List<String>.from(suggestions);
            }
          }

          // If structured parsing fails, try regex
          print('Unexpected JSON format from OpenAI, trying regex: $content');
          final matches = RegExp(r'"([^"]+)"').allMatches(content);
          if (matches.isNotEmpty) {
            return matches.map((m) => m.group(1)!).toList();
          }
          return [];
        } catch (e) {
          print('Error parsing OpenAI response: $e');
          return [];
        }
      } else {
        print('OpenAI API error: ${response.statusCode} - ${response.body}');
        return [];
      }
    } catch (e) {
      print('Error getting OpenAI suggestions: $e');
      return [];
    }
  }
}
