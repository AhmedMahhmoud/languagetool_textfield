import 'package:flutter/material.dart';
import 'package:languagetool_textfield/src/core/controllers/language_tool_controller.dart';
import 'package:languagetool_textfield/src/utils/mistake_popup.dart';
import 'package:languagetool_textfield/src/utils/popup_overlay_renderer.dart';

class LanguageToolTextField extends StatefulWidget {
  final String? title;
  final String hintText;
  final TextEditingController? controller;
  final TextStyle? style;
  final InputDecoration? decoration;
  final MistakePopup? mistakePopup;
  final int? maxLines;
  final int? maxLength;
  final int? minLines;
  final bool expands;
  final TextAlign textAlign;
  final TextDirection? textDirection;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final TapRegionCallback? onTapOutside;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final Color? cursorColor;
  final bool autoFocus;
  final FocusNode? focusNode;
  final Brightness? keyboardAppearance;
  final bool autocorrect;
  final bool readOnly;
  final MouseCursor? mouseCursor;
  final bool alignCenter;
  final String? initialValue;
  final Widget? suffixIcon;
  final bool enableValidation;
  final String? Function(String?)? customValidator;
  final BorderSide? borderSide;

  const LanguageToolTextField({
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
  TextEditingController? _externalController;

  @override
  void initState() {
    super.initState();

    _languageToolController = LanguageToolController(
      text: widget.initialValue ?? widget.controller?.text ?? '',
    );

    // Set language and handle Arabic support
    _languageToolController.language = 'ar';
    // if (widget.language.startsWith('ar') &&
    //     _languageToolController.fetchError != null) {
    //   print('Falling back to auto language due to Arabic fetch error');
    //   _languageToolController.language = 'auto';
    // }

    _externalController = widget.controller;
    if (_externalController != null) {
      _externalController!.text = _languageToolController.text;
      _externalController!.addListener(() {
        if (_languageToolController.text != _externalController!.text) {
          _languageToolController.text = _externalController!.text;
        }
      });
      _languageToolController.addListener(() {
        if (_externalController!.text != _languageToolController.text) {
          _externalController!.text = _languageToolController.text;
          if (widget.onChanged != null) {
            widget.onChanged!(_languageToolController.text);
          }
        }
        _textControllerListener();
      });
    } else {
      _languageToolController.addListener(() {
        if (widget.onChanged != null) {
          widget.onChanged!(_languageToolController.text);
        }
        _textControllerListener();
      });
    }

    _focusNode = widget.focusNode ?? FocusNode();
    _languageToolController.focusNode = _focusNode;
    final defaultPopup = MistakePopup(popupRenderer: PopupOverlayRenderer());
    _languageToolController.popupWidget = widget.mistakePopup ?? defaultPopup;
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
              controller: _languageToolController,
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
              onTapOutside: (_) => FocusScope.of(context).unfocus(),
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
      _languageToolController.dispose();
    }
    _scrollController.dispose();
    super.dispose();
  }
}
