import 'package:flutter/material.dart';
import 'package:languagetool_textfield/src/core/controllers/language_tool_controller.dart';
import 'package:languagetool_textfield/src/utils/mistake_popup.dart';
import 'package:languagetool_textfield/src/utils/popup_overlay_renderer.dart';

/// A TextFormField widget that checks grammar using the given
/// [LanguageToolController]
class LanguageToolTextField extends StatefulWidget {
  /// A title to display above the text field.
  final String? title;

  /// Hint text to display when the field is empty.
  final String hintText;

  /// Optional external controller to sync with internal logic.
  final TextEditingController? controller;

  /// A style to use for the text being edited.
  final TextStyle? style;

  /// A decoration of this [TextFormField].
  final InputDecoration? decoration;

  /// Mistake popup window.
  final MistakePopup? mistakePopup;

  /// The maximum number of lines to show at one time, wrapping if necessary.
  final int? maxLines;

  /// The maximum number of characters to allow.
  final int? maxLength;

  /// The minimum number of lines to occupy when the content spans fewer lines.
  final int? minLines;

  /// Whether this widget's height will be sized to fill its parent.
  final bool expands;

  /// A language code like en-US, de-DE, fr, or auto to guess
  /// the language automatically.
  final String language;

  /// Determine text alignment.
  final TextAlign textAlign;

  /// Determine text direction.
  final TextDirection? textDirection;

  /// Called when the text changes.
  final ValueChanged<String>? onChanged;

  /// Called when the user submits the text (e.g., presses enter).
  final ValueChanged<String>? onSubmitted;

  /// Called when the text field is tapped.
  final VoidCallback? onTap;

  /// Called when the text field is tapped outside.
  final TapRegionCallback? onTapOutside;

  /// The action to suggest when the user submits the text.
  final TextInputAction? textInputAction;

  /// The type of keyboard to use.
  final TextInputType? keyboardType;

  /// The color of the cursor.
  final Color? cursorColor;

  /// Whether to autofocus the field.
  final bool autoFocus;

  /// The focus node to use.
  final FocusNode? focusNode;

  /// The appearance of the keyboard.
  final Brightness? keyboardAppearance;

  /// Whether to enable autocorrect.
  final bool autocorrect;

  /// Whether the field is read-only.
  final bool readOnly;

  /// The mouse cursor to display.
  final MouseCursor? mouseCursor;

  /// Whether to center the text field.
  final bool alignCenter;

  /// Initial value of the text field.
  final String? initialValue;

  /// Widget to display at the end of the text field.
  final Widget? suffixIcon;

  /// Whether to enable form validation.
  final bool enableValidation;

  /// Custom validation function.
  final String? Function(String?)? customValidator;

  /// Border side for the enabled state.
  final BorderSide? borderSide;

  /// Creates a widget that checks grammar errors.
  const LanguageToolTextField({
    required this.language,
    this.title,
    this.hintText = '',
    this.initialValue,
    this.controller,
    this.style,
    this.decoration,
    this.mistakePopup,
    this.maxLines = 1,
    this.maxLength,
    this.minLines,
    this.expands = false,
    this.textAlign = TextAlign.start,
    this.textDirection,
    this.cursorColor,
    this.autocorrect = true,
    this.autoFocus = false,
    this.readOnly = false,
    this.textInputAction,
    this.keyboardType,
    this.focusNode,
    this.keyboardAppearance,
    this.mouseCursor,
    this.onTap,
    this.onTapOutside,
    this.onChanged,
    this.onSubmitted,
    this.alignCenter = true,
    this.suffixIcon,
    this.enableValidation = true,
    this.customValidator,
    this.borderSide,
    super.key,
  });

  @override
  State<LanguageToolTextField> createState() => _LanguageToolTextFieldState();
}

class _LanguageToolTextFieldState extends State<LanguageToolTextField> {
  FocusNode? _focusNode;
  final _scrollController = ScrollController();
  late LanguageToolController _languageToolController;
  late TextEditingController _internalController;

  @override
  void initState() {
    super.initState();

    // Initialize controllers
    _internalController = widget.controller ??
        TextEditingController(text: widget.initialValue ?? '');
    _languageToolController = LanguageToolController(
      text: _internalController.text,
    );

    _focusNode = widget.focusNode ?? FocusNode();
    _languageToolController.focusNode = _focusNode;
    final defaultPopup = MistakePopup(popupRenderer: PopupOverlayRenderer());
    _languageToolController.popupWidget = widget.mistakePopup ?? defaultPopup;

    // Sync controllers
    _internalController.addListener(() {
      if (_languageToolController.text != _internalController.text) {
        _languageToolController.text = _internalController.text;
      }
    });
    _languageToolController.addListener(() {
      if (_internalController.text != _languageToolController.text) {
        _internalController.text = _languageToolController.text;
        if (widget.onChanged != null) {
          widget.onChanged!(_languageToolController.text);
        }
      }
      _textControllerListener();
    });
  }

  @override
  Widget build(BuildContext context) {
    final decoration = widget.decoration ??
        InputDecoration(
          suffixIcon: widget.suffixIcon != null
              ? Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: IconTheme(
                    data: const IconThemeData(size: 11),
                    child: widget.suffixIcon!,
                  ),
                )
              : null,
          fillColor: Colors.white,
          filled: true,
          hintText: widget.hintText,
          hintStyle:
              TextStyle(fontSize: 13, color: Colors.black.withOpacity(0.40)),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: widget.borderSide ?? BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(color: Colors.pink, width: 1),
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.title != null) ...[
          Text(
            widget.title!,
            style: const TextStyle(fontSize: 16),
          ),
          const SizedBox(height: 8),
        ],
        ListenableBuilder(
          listenable: _languageToolController,
          builder: (_, __) {
            final fetchError = _languageToolController.fetchError;

            final inputDecoration = decoration.copyWith(
              suffix: fetchError != null
                  ? Text(
                      '$fetchError',
                      style: TextStyle(
                        color: _languageToolController
                            .highlightStyle.misspellingMistakeColor,
                      ),
                    )
                  : null,
            );

            Widget childWidget = TextFormField(
              textAlign: widget.textAlign,
              textDirection: widget.textDirection ?? TextDirection.rtl,
              focusNode: _focusNode,
              controller: _internalController,
              scrollController: _scrollController,
              decoration: inputDecoration,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              maxLength: widget.maxLength,
              expands: widget.expands,
              style: widget.style,
              cursorColor: widget.cursorColor,
              autocorrect: widget.autocorrect,
              textInputAction: widget.textInputAction,
              keyboardAppearance: widget.keyboardAppearance,
              keyboardType: widget.keyboardType,
              autofocus: widget.autoFocus,
              readOnly: widget.readOnly,
              mouseCursor: widget.mouseCursor,
              onChanged: widget.onChanged,
              onFieldSubmitted: widget.onSubmitted,
              validator: widget.enableValidation
                  ? (value) {
                      if (widget.customValidator != null) {
                        return widget.customValidator!(value);
                      }
                      if (value == null || value.isEmpty) {
                        return 'مطلوب';
                      }
                      return null;
                    }
                  : null,
              onTap: widget.onTap,
              onTapOutside: widget.onTapOutside,
            );

            if (widget.alignCenter) {
              childWidget = Center(child: childWidget);
            }

            return childWidget;
          },
        ),
      ],
    );
  }

  void _textControllerListener() =>
      _languageToolController.scrollOffset = _scrollController.offset;

  @override
  void dispose() {
    if (widget.focusNode == null) {
      _focusNode?.dispose();
    }
    if (widget.controller == null) {
      _internalController.dispose();
    }
    _scrollController.dispose();
    _languageToolController.dispose();
    super.dispose();
  }
}
