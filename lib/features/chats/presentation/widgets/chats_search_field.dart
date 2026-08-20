import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:flutter/material.dart';

class ChatsSearchField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final String hintText;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  const ChatsSearchField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.hintText,
    required this.onChanged,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: Screen.getVerticalSize(46),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(50),
        border: Border.all(
          color: AppColors.mutedTextPrimary.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(width: Screen.getHorizontalSize(16)),
          Icon(
            Icons.search,
            color: AppColors.mutedTextPrimary,
            size: Screen.getSize(20),
          ),
          SizedBox(width: Screen.getHorizontalSize(8)),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textAlignVertical: TextAlignVertical.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.textPrimary,
                fontSize: Screen.getFontSize(14),
              ),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle: AppTypography.bodyTextLargeMedium.copyWith(
                  color: AppColors.grey400,
                  fontSize: Screen.getFontSize(14),
                ),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                fillColor: Colors.transparent,
                isDense: true,
                contentPadding: EdgeInsets.zero,
                isCollapsed: true,
              ),
            ),
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return GestureDetector(
                onTap: onClear,
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: Screen.getHorizontalSize(8),
                  ),
                  child: Icon(
                    Icons.close_rounded,
                    color: AppColors.mutedTextPrimary,
                    size: Screen.getSize(18),
                  ),
                ),
              );
            },
          ),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (_, value, __) {
              if (value.text.isNotEmpty) return const SizedBox.shrink();
              return SizedBox(width: Screen.getHorizontalSize(16));
            },
          ),
        ],
      ),
    );
  }
}
