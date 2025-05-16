import 'package:flutter/material.dart';
import 'package:languagetool_textfield/src/domain/ai_suggestion_service.dart';
import 'package:languagetool_textfield/src/implementations/openai_suggestion_service.dart';
import 'package:languagetool_textfield/src/implementations/arabic_ai_suggestion_service.dart';

/// Factory for creating appropriate AI suggestion services based on configuration
class AiSuggestionFactory {
  /// Creates an AI suggestion service that uses OpenAI to enhance suggestions
  /// If openAiKey is provided, it will use OpenAI's GPT for enhanced Arabic suggestions
  /// Returns null if neither OpenAI nor basic service can be initialized
  static AiSuggestionService? createService(String openAiKey) {
    try {
      if (openAiKey.isNotEmpty) {
        debugPrint('Making request with aikey $openAiKey');
        return OpenAiSuggestionService(apiKey: openAiKey);
      }
      // Fallback to basic service if no OpenAI key is provided
      return ArabicAiSuggestionService();
    } catch (e) {
      print('Error creating AI service: $e');
      return null;
    }
  }
}
