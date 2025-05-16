import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:languagetool_textfield/src/client/language_tool_client.dart';
import 'package:languagetool_textfield/src/core/enums/delay_type.dart';
import 'package:languagetool_textfield/src/core/enums/mistake_type.dart';
import 'package:languagetool_textfield/src/domain/highlight_style.dart';
import 'package:languagetool_textfield/src/domain/language_check_service.dart';
import 'package:languagetool_textfield/src/domain/mistake.dart';
import 'package:languagetool_textfield/src/implementations/debounce_lang_tool_service.dart';
import 'package:languagetool_textfield/src/implementations/lang_tool_service.dart';
import 'package:languagetool_textfield/src/implementations/throttling_lang_tool_service.dart';
import 'package:languagetool_textfield/src/utils/closed_range.dart';
import 'package:languagetool_textfield/src/utils/keep_latest_response_service.dart';
import 'package:languagetool_textfield/src/utils/mistake_popup.dart';

// Remove the following import if present anywhere in this file:
// import 'package:languagetool_textfield/src/domain/ai_suggestion_service.dart';
// Instead, ensure you import the correct one:
import 'package:languagetool_textfield/src/services/ai_suggestion_service.dart';

import '../../implementations/ai_suggestion_factory.dart';

/// A TextEditingController with overrides buildTextSpan for building
/// marked TextSpans with tap recognizer
class LanguageToolController extends TextEditingController {
  final HighlightStyle highlightStyle;
  final DelayType delayType;
  final Duration delay;
  final _languageToolClient = LanguageToolClient();
  final _latestResponseService = KeepLatestResponseService();
  final List<TapGestureRecognizer> _recognizers = [];
  LanguageCheckService? _languageCheckService;
  FocusNode? focusNode;
  List<Mistake> _mistakes = [];
  MistakePopup? popupWidget;
  double? scrollOffset;
  Object? _fetchError;

  String get language => _languageToolClient.language;

  set language(String language) {
    _languageToolClient.language = language;
    print('LanguageToolController: Language set to $language'); // Debug log
  }

  Object? get fetchError => _fetchError;

  @override
  set value(TextEditingValue newValue) {
    print(
        'LanguageToolController: Setting value to "${newValue.text}"'); // Debug log
    _handleTextChange(newValue.text);
    super.value = newValue;
  }

  LanguageToolController({
    String? text,
    this.highlightStyle = const HighlightStyle(),
    this.delay = Duration.zero,
    this.delayType = DelayType.debouncing,
  }) : super(text: text) {
    _languageCheckService = _getLanguageCheckService();
  }
  LanguageCheckService _getLanguageCheckService() {
    // Create base service with OpenAI integration
    final aiService = AiSuggestionFactory.createService(
        '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');
    // Since aiService is already nullable (AiSuggestionService?), we can pass it directly
    final languageToolService = LangToolService(
      _languageToolClient,
      aiSuggestionService: aiService,
    );

    if (delay == Duration.zero) return languageToolService;

    switch (delayType) {
      case DelayType.debouncing:
        return DebounceLangToolService(languageToolService, delay);
      case DelayType.throttling:
        return ThrottlingLangToolService(languageToolService, delay);
    }
  }

  void _closePopup() => popupWidget?.popupRenderer.dismiss();

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final formattedTextSpans = _generateSpans(
      context,
      style: style,
    );

    return TextSpan(
      children: formattedTextSpans.toList(),
    );
  }

  @override
  void dispose() {
    _languageCheckService?.dispose();
    super.dispose();
  }

  void replaceMistake(Mistake mistake, String replacement) {
    final mistakes = List<Mistake>.from(_mistakes);
    mistakes.remove(mistake);
    _mistakes = mistakes;
    text = text.replaceRange(mistake.offset, mistake.endOffset, replacement);
    focusNode?.requestFocus();
    Future.microtask.call(() {
      final newOffset = mistake.offset + replacement.length;
      selection = TextSelection.fromPosition(TextPosition(offset: newOffset));
    });
  }

  Future<void> _handleTextChange(String newText) async {
    if (newText == text || newText.isEmpty) {
      print(
          'LanguageToolController: Skipping text change (unchanged or empty)'); // Debug log
      return;
    }

    print(
        'LanguageToolController: Handling text change for "$newText"'); // Debug log

    final filteredMistakes = _filterMistakesOnChanged(newText);
    _mistakes = filteredMistakes.toList();

    _closePopup();

    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();

    try {
      print(
          'LanguageToolController: Fetching mistakes for language: $language'); // Debug log
      final mistakesWrapper =
          await _latestResponseService.processLatestOperation(
        () =>
            _languageCheckService?.findMistakes(newText) ?? Future(() => null),
      );
      if (mistakesWrapper == null || !mistakesWrapper.hasResult) {
        print('LanguageToolController: No result from API'); // Debug log
        return;
      }

      final mistakes = mistakesWrapper.result();
      _fetchError = mistakesWrapper.error;

      if (_fetchError != null) {
        print(
            'LanguageToolController: Fetch error - $_fetchError'); // Debug log
      } else {
        print(
            'LanguageToolController: Found ${mistakes.length} mistakes'); // Debug log
        for (var mistake in mistakes) {
          print(
              'Mistake: ${mistake.message}, Offset: ${mistake.offset}-${mistake.endOffset}'); // Debug log
        }
      }

      _mistakes = mistakes;
      notifyListeners();
    } catch (e) {
      print(
          'LanguageToolController: Error fetching mistakes - $e'); // Debug log
      _fetchError = e;
      notifyListeners();
    }
  }

  Iterable<TextSpan> _generateSpans(
    BuildContext context, {
    TextStyle? style,
  }) sync* {
    int currentOffset = 0;
    _mistakes.sort((a, b) => a.offset.compareTo(b.offset));

    for (final Mistake mistake in _mistakes) {
      final mistakeEndOffset = min(mistake.endOffset, text.length);
      if (mistake.offset > mistakeEndOffset) continue;

      // Yield text before the mistake
      if (mistake.offset > currentOffset) {
        yield TextSpan(
          text: text.substring(currentOffset, mistake.offset),
          style: style,
        );
      }
      final _onTap = TapGestureRecognizer()
        ..onTapDown = (details) {
          popupWidget?.show(
            context,
            mistake: mistake,
            popupPosition: details.globalPosition,
            controller: this,
            onClose: (details) => _setCursorOnMistake(
              context,
              globalPosition: details.globalPosition,
              style: style,
            ),
          );

          // Set the cursor position on the mistake
          _setCursorOnMistake(
            context,
            globalPosition: details.globalPosition,
            style: style,
          );
        };
      final Color mistakeColor = _getMistakeColor(mistake.type);
      // Create tap recognizer for the mistake
      final recognizer = TapGestureRecognizer()
        ..onTapDown = (details) => _handleMistakeTap(
              context,
              mistake,
              details,
              style,
            );
      _recognizers.add(recognizer);

      // Yield the mistake text with appropriate styling
      yield TextSpan(
        children: [
          TextSpan(
            text: text.substring(
              mistake.offset,
              min(mistake.endOffset, text.length),
            ),
            mouseCursor: WidgetStateMouseCursor.textable,
            style: style?.copyWith(
              backgroundColor: mistakeColor.withOpacity(
                highlightStyle.backgroundOpacity,
              ),
              decoration: highlightStyle.decoration,
              decorationColor: mistakeColor,
              decorationThickness: highlightStyle.mistakeLineThickness,
            ),
            recognizer: _onTap,
          ),
        ],
      );

      currentOffset = min(mistake.endOffset, text.length);
    }

    // Yield any remaining text
    if (currentOffset < text.length) {
      yield TextSpan(
        text: text.substring(currentOffset),
        style: style,
      );
    }
  }

  Iterable<Mistake> _filterMistakesOnChanged(String newText) sync* {
    final isSelectionRangeEmpty = selection.end == selection.start;
    final lengthDiscrepancy = newText.length - text.length;

    for (final mistake in _mistakes) {
      Mistake? newMistake;

      newMistake = isSelectionRangeEmpty
          ? _adjustMistakeOffsetWithCaretCursor(
              mistake: mistake,
              lengthDiscrepancy: lengthDiscrepancy,
            )
          : _adjustMistakeOffsetWithSelectionRange(
              mistake: mistake,
              lengthDiscrepancy: lengthDiscrepancy,
            );

      if (newMistake != null) yield newMistake;
    }
  }

  Mistake? _adjustMistakeOffsetWithCaretCursor({
    required Mistake mistake,
    required int lengthDiscrepancy,
  }) {
    final mistakeRange = ClosedRange(mistake.offset, mistake.endOffset);
    final caretLocation = selection.base.offset;

    final isCaretOnMistake = mistakeRange.contains(caretLocation);
    if (isCaretOnMistake) return null;

    final shouldAdjustOffset = mistakeRange.isBeforeOrAt(caretLocation);
    if (!shouldAdjustOffset) return mistake;

    final newOffset = mistake.offset + lengthDiscrepancy;

    return mistake.copyWith(offset: newOffset);
  }

  Mistake? _adjustMistakeOffsetWithSelectionRange({
    required Mistake mistake,
    required int lengthDiscrepancy,
  }) {
    final selectionRange = ClosedRange(selection.start, selection.end);
    final mistakeRange = ClosedRange(mistake.offset, mistake.endOffset);

    final hasSelectedTextChanged = selectionRange.overlapsWith(mistakeRange);
    if (hasSelectedTextChanged) return null;

    final shouldAdjustOffset = selectionRange.isAfterOrAt(mistake.offset);
    if (!shouldAdjustOffset) return mistake;

    final newOffset = mistake.offset + lengthDiscrepancy;

    return mistake.copyWith(offset: newOffset);
  }

  Color _getMistakeColor(MistakeType type) {
    switch (type) {
      case MistakeType.misspelling:
        return highlightStyle.misspellingMistakeColor;
      case MistakeType.typographical:
        return highlightStyle.typographicalMistakeColor;
      case MistakeType.grammar:
        return highlightStyle.grammarMistakeColor;
      case MistakeType.uncategorized:
        return highlightStyle.uncategorizedMistakeColor;
      case MistakeType.nonConformance:
        return highlightStyle.nonConformanceMistakeColor;
      case MistakeType.style:
        return highlightStyle.styleMistakeColor;
      case MistakeType.other:
        return highlightStyle.otherMistakeColor;
    }
  }

  void _setCursorOnMistake(
    BuildContext context, {
    required Offset globalPosition,
    TextStyle? style,
  }) {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final localPosition = renderBox.globalToLocal(globalPosition);

    // Get the TextPainter to calculate text positions
    final TextPainter textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    textPainter.layout();

    // Find the closest text position to the tap
    final offset = textPainter.getPositionForOffset(localPosition).offset;

    // Ensure we don't exceed text bounds
    final safeOffset = offset.clamp(0, text.length);

    selection = TextSelection.fromPosition(TextPosition(offset: safeOffset));
    focusNode?.requestFocus();
  }

  void _handleMistakeTap(
    BuildContext context,
    Mistake mistake,
    TapDownDetails details,
    TextStyle? style,
  ) {
    print(
        'LanguageToolController: Handling mistake tap at offset ${mistake.offset}');
    popupWidget?.show(
      context,
      mistake: mistake,
      popupPosition: details.globalPosition,
      controller: this,
      onClose: (_) => _setCursorOnMistake(
        context,
        globalPosition: details.globalPosition,
        style: style,
      ),
    );
  }

  void onClosePopup() {
    final offset = selection.base.offset;
    focusNode?.requestFocus();

    Future.microtask(
      () => selection = TextSelection.collapsed(offset: offset),
    );
  }
}
