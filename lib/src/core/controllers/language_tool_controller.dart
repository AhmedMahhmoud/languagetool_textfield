import 'package:collection/collection.dart';
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
  }

  Object? get fetchError => _fetchError;

  @override
  set value(TextEditingValue newValue) {
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
    final languageToolService = LangToolService(_languageToolClient);

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
    if (newText == text || newText.isEmpty) return;

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
      final mistakeEndOffset =
          (mistake.endOffset < text.length) ? mistake.endOffset : text.length;
      if (mistake.offset > mistakeEndOffset) continue;

      yield TextSpan(
        text: text.substring(
          currentOffset,
          (mistake.offset < text.length) ? mistake.offset : text.length,
        ),
        style: style,
      );

      final Color mistakeColor = _getMistakeColor(mistake.type);

      final _onTap = TapGestureRecognizer()
        ..onTapDown = (details) {
          print(
              'LanguageToolController: Tapped on mistake: ${mistake.message}'); // Debug log
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

          _setCursorOnMistake(
            context,
            globalPosition: details.globalPosition,
            style: style,
          );
        };

      _recognizers.add(_onTap);

      yield TextSpan(
        children: [
          TextSpan(
            text: text.substring(
              mistake.offset,
              (mistake.endOffset < text.length)
                  ? mistake.endOffset
                  : text.length,
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

      currentOffset =
          (mistake.endOffset < text.length) ? mistake.endOffset : text.length;
    }

    final textAfterMistake = text.substring(currentOffset);

    yield TextSpan(
      text: textAfterMistake,
      style: style,
    );
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
    final offset = _getValidTextOffset(
      context,
      globalPosition: globalPosition,
      style: style,
    );

    if (offset == null) return;

    focusNode?.requestFocus();
    Future.microtask(() => selection = TextSelection.collapsed(offset: offset));

    final mistake = _mistakes.firstWhereOrNull(
      (e) => e.offset <= offset && offset < e.endOffset,
    );

    if (mistake == null) return;

    _closePopup();

    popupWidget?.show(
      context,
      mistake: mistake,
      popupPosition: globalPosition,
      controller: this,
      onClose: (details) => _setCursorOnMistake(
        context,
        globalPosition: details.globalPosition,
        style: style,
      ),
    );
  }

  int? _getValidTextOffset(
    BuildContext context, {
    required Offset globalPosition,
    TextStyle? style,
  }) {
    final textFieldRenderBox = context.findRenderObject() as RenderBox?;
    final localOffset = textFieldRenderBox?.globalToLocal(globalPosition);

    if (localOffset == null) return null;

    final textBoxHeight = textFieldRenderBox?.size.height ?? 0;

    final isOffsetOutsideTextBox =
        localOffset.dy < 0 || textBoxHeight < localOffset.dy;
    if (isOffsetOutsideTextBox) return null;

    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    );
    final textFieldWidth = textFieldRenderBox?.size.width ?? 0;
    final scrollOffset = this.scrollOffset ?? 0;

    double maxWidth = double.infinity;
    if (scrollOffset == 0) maxWidth = textFieldWidth;

    textPainter.layout(minWidth: textFieldWidth, maxWidth: maxWidth);

    final adjustedOffset =
        Offset(localOffset.dx + scrollOffset, localOffset.dy);

    return textPainter.getPositionForOffset(adjustedOffset).offset;
  }

  void onClosePopup() {
    final offset = selection.base.offset;
    focusNode?.requestFocus();

    Future.microtask(
      () => selection = TextSelection.collapsed(offset: offset),
    );
  }
}
