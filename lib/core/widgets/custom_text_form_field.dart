import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../theme/screen.dart';

class CustomTextFormField extends StatefulWidget {
  final bool? autofocus;
  final FocusNode? focusNode;
  final TextEditingController controller;
  final String? hintText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool? obscureText;
  final bool isPasswordField;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final Function(String)? onChanged;
  final String? errorText;
  final bool isNumber;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLine;

  /// Starting line count. When set alongside [maxLine] the field grows
  /// from `minLine` to `maxLine` rows as the user types, then scrolls
  /// internally beyond that. Leave null for a fixed-height field.
  final int? minLine;
  final EdgeInsetsGeometry? contentPadding;

  // ADD MISSING PROPERTIES
  final TextInputAction? textInputAction;
  final Function(String)? onFieldSubmitted;
  final Function(PointerDownEvent)? onTapOutside;

  /// When `false` the field is non-interactive and styled as read-only.
  /// Use this for values the user shouldn't be able to overwrite (e.g. a
  /// phone number that the backend already has on file).
  final bool enabled;

  /// When `true` (default) tapping anywhere outside the field — including
  /// neighbouring buttons like a send/submit affordance — dismisses the
  /// keyboard. Set to `false` for chat-style composers where the user
  /// expects the keyboard to stay open between sends (WhatsApp-style)
  /// so they don't have to refocus the field for every message.
  final bool unfocusOnTapOutside;

  const CustomTextFormField({
    super.key,
    required this.controller,
    this.hintText,
    this.prefixIcon,
    this.obscureText = false,
    this.isPasswordField = false,
    this.validator,
    this.onChanged,
    this.focusNode,
    this.errorText,
    this.keyboardType,
    this.isNumber = false,
    this.suffixIcon,
    this.inputFormatters,
    this.autofocus = false, // FIX: Default to false instead of true
    this.maxLine,
    this.minLine,
    this.contentPadding,
    // ADD MISSING PROPERTIES
    this.textInputAction,
    this.onFieldSubmitted,
    this.onTapOutside,
    this.enabled = true,
    this.unfocusOnTapOutside = true,
  });

  @override
  State<CustomTextFormField> createState() => _CustomTextFormFieldState();
}

class _CustomTextFormFieldState extends State<CustomTextFormField> {
  bool isObscure = true;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isFilled = widget.controller.text.isNotEmpty;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          autofocus: widget.autofocus ?? false, // FIX: Default to false
          focusNode: widget.focusNode,
          controller: widget.controller,
          enabled: widget.enabled,
          cursorColor: AppColors.primary,
          maxLines: widget.maxLine,
          minLines: widget.minLine,
          style: AppTypography.bodyTextLargeMedium.copyWith(
            color: widget.enabled
                ? AppColors.textPrimary
                : AppColors.mutedTextPrimary,
            fontSize: Screen.getFontSizeCapped(14),
          ),
          obscureText: widget.isPasswordField ? isObscure : false,
          keyboardType: widget.keyboardType ?? TextInputType.text,

          // ADD MISSING PROPERTIES TO TextFormField
          textInputAction: widget.textInputAction ?? TextInputAction.done,
          onFieldSubmitted: widget.onFieldSubmitted,
          onTapOutside: (event) {
            // Only dismiss the keyboard when the caller hasn't opted
            // out (e.g. chat composers want it to stay open between
            // sends). The custom callback still fires either way so
            // callers can layer their own behaviour.
            if (widget.unfocusOnTapOutside) {
              FocusScope.of(context).unfocus();
            }
            widget.onTapOutside?.call(event);
          },

          decoration: InputDecoration(
            contentPadding: widget.contentPadding ??
                const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            prefix: const SizedBox(width: 4),
            filled: true,
            fillColor: widget.enabled ? AppColors.white : AppColors.grey100,
            // fillColor: isFilled ? AppColors.grey700 : AppColors.inputBorderLight,
            hint: widget.hintText != null
                ? Text(
                    widget.hintText!,
                    style: AppTypography.bodyTextLargeMedium.copyWith(
                      color: AppColors.grey500,
                      fontSize: Screen.getFontSizeCapped(14),
                    ),
                  )
                : null,
            prefixIcon: widget.isNumber
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 6),
                      Icon(Icons.add, size: 20, color: AppColors.primary),
                      Text(
                        "91",
                        style: AppTypography.bodyTextLargeMedium.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  )
                : widget.prefixIcon,
            suffixIcon:
                widget.suffixIcon ??
                (widget.isPasswordField
                    ? IconButton(
                        icon: Icon(
                          isObscure
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: AppColors.grey400,
                        ),
                        onPressed: () {
                          setState(() {
                            isObscure = !isObscure;
                          });
                        },
                      )
                    : null),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(color: AppColors.primary),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                color: isFilled ? AppColors.primary : AppColors.grey300,
              ),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: AppColors.error),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: const BorderSide(color: AppColors.error),
            ),
          ),
          validator: widget.validator,
          onChanged: widget.onChanged,
          autocorrect: true,
          inputFormatters:
              widget.inputFormatters ??
              (widget.isNumber
                  ? [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ]
                  : null),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: widget.errorText != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 3.0, left: 12),
                  child: Text(
                    widget.errorText!,
                    style: AppTypography.bodyTextMedium.copyWith(
                      color: AppColors.error,
                      fontWeight: FontWeight.w400,
                      fontSize: Screen.getFontSizeCapped(12),
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}
