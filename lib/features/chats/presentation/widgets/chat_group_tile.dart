import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_decorations.dart';
import 'package:nexora/core/theme/app_images.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/features/chats/data/models/chat_group_model.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Row tile for a single chat group — avatar + name + description, with
/// a lock badge on announcement-only groups.
class ChatGroupTile extends StatelessWidget {
  final ChatGroupModel group;

  const ChatGroupTile({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    final imageUrl = group.groupImageUrl;
    // A raised card, matching the section cards on Profile.
    return PremiumSurface(
      margin: Screen.getPadding(horizontal: 16),
      // A soft drop shadow lifts the tile instead of an outline: no border,
      // no coloured edge lines.
      borderColor: Colors.transparent,
      showTopEdge: false,
      shadows: [
        BoxShadow(
          color: AppColors.isDark
              ? AppColors.black.withValues(alpha: 0.55)
              : const Color(0xFF64748B).withValues(alpha: 0.20),
          blurRadius: 18,
          offset: const Offset(0, 6),
        ),
      ],
      child: Stack(
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                // Push the dedicated chat-room route. Prefer the SignalR room
                // id (`firebaseGroupId`) and fall back to the numeric groupId
                // so older payloads still route. Group name, image and reply
                // permission travel as query params so the room can render
                // its AppBar / composer without a second round-trip.
                final roomId = group.firebaseGroupId.isNotEmpty
                    ? group.firebaseGroupId
                    : group.groupId.toString();
                final imageQuery = (imageUrl != null && imageUrl.isNotEmpty)
                    ? '&groupImageUrl=${Uri.encodeComponent(imageUrl)}'
                    : '';
                context.push(
                  '${AppRoutes.chatRoom}'
                  '?groupId=${Uri.encodeComponent(roomId)}'
                  '&groupName=${Uri.encodeComponent(group.groupName)}'
                  '$imageQuery'
                  '&canReply=${group.canUserReply}',
                );
              },
              child: Container(
                padding: Screen.getPadding(horizontal: 12, vertical: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Avatar — falls back to a course-book icon when the group has
                    // no image set.
                    _RingedAvatar(
                      size: rh.isLargeScreen ? 100 : Screen.getSize(56),
                      child: CustomNetworkImage(
                        url: imageUrl,
                        fit: BoxFit.cover,
                        errorWidget: _placeholderAvatar(rh),
                      ),
                    ),
                    SizedBox(width: Screen.getHorizontalSize(10)),

                    // Title + description
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.groupName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyTextLargeSemiBold.copyWith(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.w500,
                              fontSize: Screen.getFontSize(16),
                            ),
                          ),
                          Text(
                            group.groupDescription,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.bodyTextSmallMedium.copyWith(
                              color: AppColors.grey400,
                              fontWeight: FontWeight.w400,
                              fontSize: Screen.getFontSize(12),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Read-only badge for announcement-type groups
                    if (!group.canUserReply) ...[
                      SizedBox(width: Screen.getHorizontalSize(8)),
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 18,
                        color: AppColors.grey400,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderAvatar(ResponsiveHelper rh) {
    return CircleAvatar(
      radius: rh.isLargeScreen ? 50 : Screen.getSize(28),
      backgroundColor: AppColors.grey300,
      child: Padding(
        padding: Screen.getPadding(all: rh.isLargeScreen ? 12 : 8),
        child: Image.asset(AppImages.bookImg),
      ),
    );
  }
}

/// Avatar inside a thin ring, like the profile picture: the edge keeps a
/// pale or white group image from bleeding into the card.
class _RingedAvatar extends StatelessWidget {
  final double size;
  final Widget child;

  const _RingedAvatar({required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size + 10,
      height: size + 10,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.45),
          width: 2,
        ),
      ),
      child: ClipOval(child: child),
    );
  }
}
