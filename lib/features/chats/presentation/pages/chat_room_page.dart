import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_network_image.dart';
import 'package:nexora/features/chats/data/models/chat_message_model.dart';
import 'package:nexora/features/chats/data/services/signalr_chat_service.dart';
import 'package:nexora/features/chats/domain/repositories/chat_group_repository.dart';
import 'package:nexora/features/chats/presentation/bloc/chat_room_cubit.dart';
import 'package:nexora/features/chats/presentation/widgets/chat_input.dart';
import 'package:nexora/features/chats/presentation/widgets/message_bubble.dart';
import 'package:nexora/features/chats/presentation/widgets/reply_banner.dart';
import 'package:nexora/features/chats/presentation/widgets/swipe_to_reply.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Soft pink/cream wash used for the whole chat surface (page + AppBar
/// + composer). Lives at file scope so every chat widget can pick the
/// same shade without re-deriving it; if the design system grows a
/// dedicated `chatSurface` token, swap this for that.
Color get kChatSurface => AppColors.isDark
    // Deliberately the page backdrop, NOT the card surface: incoming
    // bubbles use the card tone, and painting the page the same colour
    // made them disappear into it.
    ? AppColors.scaffoldLight
    : const Color(0xFFFAF1F1);

/// Chat room screen — one cubit per [groupId]. Owns its own
/// [ChatRoomCubit] (factory) so the join/leave + history lifecycle
/// runs cleanly on push and pop.
///
/// The hosting [BlocProvider] is rebuilt with the cubit's `..open()`
/// kicked off in `create`; the page renders loading / error / loaded
/// off `state.maybeWhen` like every other screen in the app.
class ChatRoomPage extends StatelessWidget {
  final String groupId;
  final String groupName;
  final String? groupImageUrl;

  /// `false` for announcement / read-only groups — the composer
  /// renders disabled with placeholder copy explaining why.
  final bool canReply;

  const ChatRoomPage({
    super.key,
    required this.groupId,
    required this.groupName,
    this.groupImageUrl,
    this.canReply = true,
  });

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    return BlocProvider<ChatRoomCubit>(
      create: (_) => ChatRoomCubit(
        repository: sl<ChatGroupRepository>(),
        signalr: sl<SignalRChatService>(),
        groupId: groupId,
      )..open(),
      child: Scaffold(
        backgroundColor: kChatSurface,
        appBar: _ChatAppBar(groupName: groupName, groupImageUrl: groupImageUrl),
        body: _ChatRoomBody(canReply: canReply),
      ),
    );
  }
}

/// Tappable AppBar with avatar + group name. Title spacing is tightened
/// so the name sits close to the avatar after the back button.
class _ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String groupName;
  final String? groupImageUrl;

  const _ChatAppBar({required this.groupName, required this.groupImageUrl});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    return CustomAppBar(
      centerTitle: false,
      titleSpacing: 0,
      // Same wash as the body so the AppBar reads as part of the chat
      // surface rather than a separate chrome strip.
      backgroundColor: kChatSurface,
      titleWidget: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: rh.isLargeScreen ? 56 : Screen.getSize(46),
              height: rh.isLargeScreen ? 56 : Screen.getSize(46),
              child: CustomNetworkImage(
                url: groupImageUrl,
                fit: BoxFit.cover,
                errorWidget: Container(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.groups_rounded,
                    color: AppColors.primary,
                    size: Screen.getSize(18),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(width: Screen.getHorizontalSize(10)),
          Expanded(
            child: Text(
              groupName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.h5SemiBold.copyWith(
                color: AppColors.textPrimary,
                fontSize: rh.cappedFontSize(18),
              ),
            ),
          ),
        ],
      ),
      actions: const [
        // Group-actions overflow menu — no items wired yet. Commented
        // out per request; restore once mute / search-in-chat / view
        // members ship.
        // IconButton(
        //   tooltip: 'More',
        //   icon: Icon(
        //     Icons.more_vert_rounded,
        //     color: AppColors.textPrimary,
        //     size: Screen.getSize(22),
        //   ),
        //   onPressed: () {},
        // ),
      ],
    );
  }
}

class _ChatRoomBody extends StatelessWidget {
  final bool canReply;

  const _ChatRoomBody({required this.canReply});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ChatRoomCubit, ChatRoomState>(
      builder: (context, state) {
        return state.maybeWhen(
          initial: () => const Center(child: CircularProgressIndicator()),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (message) => _ErrorBlock(
            message: message,
            onRetry: () => context.read<ChatRoomCubit>().open(),
          ),
          loaded: (messages, hasMore, currentPage, isLoadingMore, typing) {
            final cubit = context.read<ChatRoomCubit>();
            return Column(
              children: [
                Expanded(
                  child: messages.isEmpty
                      ? _EmptyConversation(canReply: canReply)
                      : _MessageList(
                          messages: messages,
                          hasMore: hasMore,
                          isLoadingMore: isLoadingMore,
                        ),
                ),
                if (typing.isNotEmpty) _TypingHint(names: typing),
                // Reply banner — only renders when the cubit's
                // `replyingTo` is non-null, animating in/out via
                // AnimatedSwitcher inside the banner.
                if (canReply)
                  ReplyBanner(
                    replyingTo: cubit.replyingTo,
                    onCancel: cubit.cancelReply,
                  ),
                ChatInput(
                  enabled: canReply,
                  hint: canReply
                      ? 'Type a message…'
                      : 'You can\'t reply in this group',
                  onSend: cubit.sendText,
                  onTypingChanged: cubit.notifyTyping,
                ),
              ],
            );
          },
          orElse: () => const SizedBox.shrink(),
        );
      },
    );
  }
}

/// Reverse-scrolled list of bubbles. The cubit stores messages
/// newest-first (index 0 == latest), and `reverse: true` puts index 0
/// at the bottom so new messages land at the visible bottom edge.
class _MessageList extends StatefulWidget {
  final List<ChatMessage> messages;
  final bool hasMore;
  final bool isLoadingMore;

  const _MessageList({
    required this.messages,
    required this.hasMore,
    required this.isLoadingMore,
  });

  @override
  State<_MessageList> createState() => _MessageListState();
}

class _MessageListState extends State<_MessageList> {
  final ScrollController _controller = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  /// Reverse list — "scrolled to the top" (earlier messages) means
  /// hitting `maxScrollExtent`. Use that to trigger a paged load.
  void _onScroll() {
    if (!_controller.hasClients) return;
    final pos = _controller.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      if (widget.hasMore && !widget.isLoadingMore) {
        context.read<ChatRoomCubit>().loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // +1 slot when paging is in flight so the spinner can sit above
    // the oldest message visible.
    final itemCount = widget.messages.length + (widget.isLoadingMore ? 1 : 0);
    return ListView.separated(
      controller: _controller,
      reverse: true,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: Screen.getPadding(horizontal: 12, vertical: 12),
      itemCount: itemCount,
      // WhatsApp-style spacing — tight 2 px gap inside a run of
      // same-sender messages, comfortable 8 px gap between senders
      // (and around the load-more spinner slot at the top of the list).
      separatorBuilder: (_, index) {
        final older = index + 1 < widget.messages.length
            ? widget.messages[index + 1]
            : null;
        final current = index < widget.messages.length
            ? widget.messages[index]
            : null;
        final sameSender =
            older != null &&
            current != null &&
            older.senderId == current.senderId;
        return SizedBox(height: Screen.getVerticalSize(sameSender ? 2 : 8));
      },
      itemBuilder: (context, index) {
        if (widget.isLoadingMore && index == widget.messages.length) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        final message = widget.messages[index];
        // Two bubbles in a row from the same sender (next-in-reading-
        // order, which is `index + 1` here because the list is
        // reversed). Suppress the sender label on the lower one.
        final prevIndex = index + 1;
        final sameAsPrev =
            prevIndex < widget.messages.length &&
            widget.messages[prevIndex].senderId == message.senderId;
        // Date header — appears above the FIRST message of each day in
        // reading order. The list is `reverse: true` and stored
        // newest-first, so "first message of the day" is the one whose
        // older neighbour (index + 1) sits on a different date.
        final prev = prevIndex < widget.messages.length
            ? widget.messages[prevIndex]
            : null;
        final showDateHeader =
            prev == null || !_isSameDay(prev.createdAt, message.createdAt);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header renders ABOVE the bubble. `reverse: true` only
            // flips the order of items in the scroll view — it does
            // not flip the internal widget order of each item — so the
            // header has to come first in the Column to sit above the
            // first bubble of its day visually.
            if (showDateHeader)
              Padding(
                padding: EdgeInsets.only(
                  top: Screen.getVerticalSize(12),
                  bottom: Screen.getVerticalSize(8),
                ),
                child: _DateHeader(date: message.createdAt),
              ),
            SwipeToReply(
              isMe: message.isFromCurrentStudent,
              onReply: () => context.read<ChatRoomCubit>().startReply(message),
              child: MessageBubble(
                message: message,
                sameSenderAsPrev: sameAsPrev,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Y/M/D comparison ignoring time-of-day. Local-time so the header
  /// flips at the user's midnight rather than UTC's.
  static bool _isSameDay(DateTime a, DateTime b) {
    final aL = a.toLocal();
    final bL = b.toLocal();
    return aL.year == bL.year && aL.month == bL.month && aL.day == bL.day;
  }
}

/// Centred "31 Mar, 2026" / "Today" / "Yesterday" pill sitting above
/// the first message of each day. Renders with no chrome — just a
/// muted text label — so it reads as a quiet divider, not a card.
class _DateHeader extends StatelessWidget {
  final DateTime date;

  const _DateHeader({required this.date});

  String _label() {
    final now = DateTime.now();
    final d = date.toLocal();
    final today = DateTime(now.year, now.month, now.day);
    final that = DateTime(d.year, d.month, d.day);
    final diff = today.difference(that).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat('d MMM, y').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: Screen.getHorizontalSize(12),
          vertical: Screen.getVerticalSize(4),
        ),
        decoration: BoxDecoration(
          // The 8 % indigo wash that reads as a soft pill on a cream
          // page is barely there against near-black, so the chip needs
          // more body — and indigo-on-indigo is hard to read at 10.5px,
          // so the label goes neutral in the dark.
          color: AppColors.primary.withValues(
            alpha: AppColors.isDark ? 0.20 : 0.08,
          ),
          borderRadius: BorderRadius.circular(Screen.getSize(12)),
        ),
        child: Text(
          _label().toUpperCase(),
          style: AppTypography.bodyTextMedium.copyWith(
            color: AppColors.isDark
                ? AppColors.textSecondary
                : AppColors.primary,
            fontWeight: FontWeight.w700,
            fontSize: Screen.getFontSize(10.5),
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}

class _TypingHint extends StatelessWidget {
  final List<String> names;

  const _TypingHint({required this.names});

  @override
  Widget build(BuildContext context) {
    final label = names.length == 1
        ? '${names.first} is typing…'
        : '${names.length} people are typing…';
    return Padding(
      padding: Screen.getPadding(horizontal: 18, vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: AppTypography.bodyTextMedium.copyWith(
              color: AppColors.mutedTextPrimary,
              fontStyle: FontStyle.italic,
              fontSize: Screen.getFontSize(12),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  final bool canReply;

  const _EmptyConversation({required this.canReply});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Screen.getPadding(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: AppColors.grey300),
            SizedBox(height: Screen.getVerticalSize(12)),
            Text(
              'No messages yet',
              style: AppTypography.h5SemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(8)),
            Text(
              canReply
                  ? 'Start the conversation by sending a message.'
                  : 'Messages from your educator will appear here.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBlock({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Screen.getPadding(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: AppColors.error),
            SizedBox(height: Screen.getVerticalSize(12)),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(16)),
            TextButton(
              onPressed: onRetry,
              child: Text(
                'Retry',
                style: AppTypography.bodyTextSemiBold.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Builds a [ChatRoomPage] from go_router query params. Lives here so
/// app_router.dart stays declarative.
///
/// Accepts both `canUserReply`/`canReply` and `imageUrl`/`groupImageUrl`
/// spellings so the route is tolerant of either naming convention at
/// the call site (the ChatGroupTile push uses `canUserReply` +
/// `imageUrl`, mirroring the backend's chat-group payload).
ChatRoomPage chatRoomPageFromQuery(Map<String, String> params) {
  final groupId = params['groupId'] ?? '';
  final groupName = params['groupName'] ?? 'Chat';
  final imageUrlRaw = params['imageUrl'] ?? params['groupImageUrl'];
  final imageUrl = (imageUrlRaw != null && imageUrlRaw.isNotEmpty)
      ? imageUrlRaw
      : null;
  final canReplyRaw = (params['canUserReply'] ?? params['canReply'])
      ?.toLowerCase();
  final canReply = canReplyRaw == null ? true : canReplyRaw != 'false';
  return ChatRoomPage(
    groupId: groupId,
    groupName: groupName,
    groupImageUrl: imageUrl,
    canReply: canReply,
  );
}
