import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/direct_chat/data/models/dm_conversation_model.dart';
import 'package:nexora/features/direct_chat/presentation/widgets/dm_avatar.dart';
import 'package:flutter/material.dart';

/// Bottom sheet listing the org's staff, over `GET /direct-chat/directory`.
///
/// Pops with the chosen [DmDirectoryEntry], or null when dismissed. The
/// caller resolves that entry to a thread — reusing the existing one
/// when the inbox already has it, otherwise `POST /conversations` —
/// which is why this widget stays free of any repository dependency.
class StaffPickerSheet extends StatelessWidget {
  final List<DmDirectoryEntry> directory;

  const StaffPickerSheet({super.key, required this.directory});

  /// Convenience launcher so call sites don't repeat the sheet config.
  static Future<DmDirectoryEntry?> show(
    BuildContext context, {
    required List<DmDirectoryEntry> directory,
  }) {
    return showModalBottomSheet<DmDirectoryEntry>(
      context: context,
      backgroundColor: AppColors.white,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(Screen.getSize(20)),
        ),
      ),
      builder: (_) => StaffPickerSheet(directory: directory),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        // Never let a long faculty list swallow the whole screen — the
        // learner should always see they can dismiss the sheet.
        constraints: BoxConstraints(maxHeight: Screen.height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: Screen.getVerticalSize(10)),
            Container(
              width: Screen.getHorizontalSize(40),
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.grey300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: Screen.getPadding(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Start a conversation',
                      style: AppTypography.h5SemiBold.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (directory.isEmpty)
              Padding(
                padding: Screen.getPadding(horizontal: 24, vertical: 32),
                child: Text(
                  'No faculty are available to message right now.',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyTextLargeMedium.copyWith(
                    color: AppColors.mutedTextPrimary,
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  padding: Screen.getPadding(bottom: 12),
                  itemCount: directory.length,
                  separatorBuilder: (_, __) => Divider(
                    height: 1,
                    thickness: 0.5,
                    color: AppColors.grey200,
                    indent: Screen.getHorizontalSize(25),
                    endIndent: Screen.getHorizontalSize(25),
                  ),
                  itemBuilder: (_, index) {
                    final entry = directory[index];
                    return InkWell(
                      onTap: () => Navigator.of(context).pop(entry),
                      child: Padding(
                        padding: Screen.getPadding(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        child: Row(
                          children: [
                            DmAvatar(
                              initials: entry.initials,
                              imageUrl: entry.userAvatarUrl,
                              size: Screen.getSize(44),
                            ),
                            SizedBox(width: Screen.getHorizontalSize(12)),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    entry.userName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.bodyTextLargeSemiBold
                                        .copyWith(
                                          color: AppColors.textPrimary,
                                          fontWeight: FontWeight.w500,
                                          fontSize: Screen.getFontSize(15),
                                        ),
                                  ),
                                  if (entry.userSubtitle.isNotEmpty)
                                    Text(
                                      entry.userSubtitle,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: AppTypography.bodyTextSmallMedium
                                          .copyWith(
                                            color: AppColors.grey400,
                                            fontSize: Screen.getFontSize(12),
                                          ),
                                    ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.chevron_right_rounded,
                              color: AppColors.grey400,
                              size: Screen.getSize(22),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
