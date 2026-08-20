import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/chats/data/models/chat_message_model.dart';
import 'package:nexora/features/chats/data/services/signalr_chat_service.dart';
import 'package:nexora/features/chats/domain/repositories/chat_group_repository.dart';
import 'package:nexora/features/chats/presentation/pages/chat_room_page.dart' show kChatSurface;
import 'package:nexora/features/chats/presentation/widgets/chat_input.dart';
import 'package:nexora/features/chats/presentation/widgets/message_bubble.dart';
import 'package:nexora/features/chats/presentation/widgets/reply_banner.dart';
import 'package:nexora/features/chats/presentation/widgets/swipe_to_reply.dart';
import 'package:nexora/features/direct_chat/data/models/dm_conversation_model.dart';
import 'package:nexora/features/direct_chat/domain/repositories/direct_chat_repository.dart';
import 'package:nexora/features/direct_chat/presentation/bloc/direct_chat_room_cubit.dart';
import 'package:nexora/features/direct_chat/presentation/bloc/direct_inbox_cubit.dart';
import 'package:nexora/features/direct_chat/presentation/widgets/chat_confirm_dialog.dart';
import 'package:nexora/features/direct_chat/presentation/widgets/dm_avatar.dart';
import 'package:nexora/features/direct_chat/presentation/widgets/message_actions_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

/// Personal-chat room — a private 1-to-1 thread between the learner and
/// a member of staff.
///
/// Visually and structurally a twin of [ChatRoomPage], reusing its
/// bubbles, composer and swipe-to-reply verbatim; only the transport
/// underneath differs (conversation keys and `*Direct*` hub methods
/// instead of group ids).
class DirectChatRoomPage extends StatelessWidget {
  final String conversationKey;
  final String otherUserName;
  final String? otherUserAvatarUrl;

  /// Blocked as known at open time. Staff can flip this mid-session, so
  /// the live value comes off the cubit state — this only seeds it.
  final bool isBlocked;

  const DirectChatRoomPage({
    super.key,
    required this.conversationKey,
    required this.otherUserName,
    this.otherUserAvatarUrl,
    this.isBlocked = false,
  });

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    return BlocProvider<DirectChatRoomCubit>(
      create: (_) => DirectChatRoomCubit(
        repository: sl<DirectChatRepository>(),
        chatGroupRepository: sl<ChatGroupRepository>(),
        signalr: sl<SignalRChatService>(),
        inbox: sl<DirectInboxCubit>(),
        conversationKey: conversationKey,
        initiallyBlocked: isBlocked,
      )..open(),
      child: Scaffold(
        backgroundColor: kChatSurface,
        appBar: _DirectChatAppBar(
          otherUserName: otherUserName,
          otherUserAvatarUrl: otherUserAvatarUrl,
        ),
        body: _DirectChatRoomBody(otherUserName: otherUserName),
      ),
    );
  }
}

class _DirectChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String otherUserName;
  final String? otherUserAvatarUrl;

  const _DirectChatAppBar({
    required this.otherUserName,
    required this.otherUserAvatarUrl,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    final rh = ResponsiveHelper.of(context);
    return CustomAppBar(
      centerTitle: false,
      titleSpacing: 0,
      backgroundColor: kChatSurface,
      titleWidget: Row(
        children: [
          DmAvatar(
            initials: initialsOf(otherUserName),
            imageUrl: otherUserAvatarUrl,
            size: rh.isLargeScreen ? 56 : Screen.getSize(46),
          ),
          SizedBox(width: Screen.getHorizontalSize(10)),
          Expanded(
            child: BlocBuilder<DirectChatRoomCubit, DirectChatRoomState>(
              builder: (context, state) {
                final blocked = state.maybeWhen(
                  loaded: (_, __, ___, ____, isBlocked, _____) => isBlocked,
                  orElse: () => false,
                );
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      otherUserName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.h5SemiBold.copyWith(
                        color: AppColors.textPrimary,
                        fontSize: rh.cappedFontSize(18),
                      ),
                    ),
                    // Only surfaced while blocked — a permanent status
                    // line under every name would be noise.
                    if (blocked)
                      Text(
                        'Conversation closed',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodyTextSmallMedium.copyWith(
                          color: AppColors.mutedTextPrimary,
                          fontSize: Screen.getFontSize(11),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        // Thread-level overflow. Clear is the only item today; it lives
        // here rather than in the per-message menu precisely because it
        // is a *thread* operation and must not be mistaken for delete.
        PopupMenuButton<_ThreadAction>(
          tooltip: 'More',
          color: AppColors.white,
          icon: Icon(
            Icons.more_vert_rounded,
            color: AppColors.textPrimary,
            size: Screen.getSize(22),
          ),
          onSelected: (action) async {
            if (action != _ThreadAction.clearHistory) return;
            final cubit = context.read<DirectChatRoomCubit>();
            final confirmed = await ChatConfirmDialog.clearHistory(
              context,
              otherUserName: otherUserName,
            );
            if (confirmed != true) return;
            await cubit.clearHistory();
          },
          itemBuilder: (_) => [
            PopupMenuItem<_ThreadAction>(
              value: _ThreadAction.clearHistory,
              child: Text(
                'Clear my chat history',
                style: AppTypography.bodyTextLargeMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontSize: Screen.getFontSize(14),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

enum _ThreadAction { clearHistory }

/// Stateful purely to own the `sendError` listener — a server refusal
/// (most often a send into a blocked thread) arrives on a hub `Error`
/// event, not as an exception, so a snackbar is the only way the
/// learner finds out their message didn't land.
class _DirectChatRoomBody extends StatefulWidget {
  final String otherUserName;

  const _DirectChatRoomBody({required this.otherUserName});

  @override
  State<_DirectChatRoomBody> createState() => _DirectChatRoomBodyState();
}

class _DirectChatRoomBodyState extends State<_DirectChatRoomBody> {
  late final DirectChatRoomCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<DirectChatRoomCubit>();
    _cubit.sendError.addListener(_onSendError);
    _cubit.actionNotice.addListener(_onActionNotice);
  }

  @override
  void dispose() {
    _cubit.sendError.removeListener(_onSendError);
    _cubit.actionNotice.removeListener(_onActionNotice);
    super.dispose();
  }

  void _onSendError() {
    final message = _cubit.sendError.value;
    if (message == null || message.isEmpty || !mounted) return;
    CustomSnackbar.error(
      context,
      title: 'Not sent',
      message: message,
    );
    // Consume it so a rebuild can't replay the same snackbar.
    _cubit.sendError.value = null;
  }

  void _onActionNotice() {
    final message = _cubit.actionNotice.value;
    if (message == null || message.isEmpty || !mounted) return;
    CustomSnackbar.success(context, title: 'Done', message: message);
    _cubit.actionNotice.value = null;
  }

  /// Long-press handler. The menu is rebuilt on every press so the
  /// edit / delete windows are evaluated against the clock *now* — a
  /// menu cached on render would still offer Edit long after the
  /// 2-minute window shut.
  Future<void> _onLongPressMessage(ChatMessage message, bool canReply) async {
    final action = await MessageActionsSheet.show(
      context,
      message: message,
      canReply: canReply,
    );
    if (action == null || !mounted) return;
    switch (action) {
      case MessageAction.reply:
        _cubit.startReply(message);
      case MessageAction.edit:
        _cubit.startEdit(message);
      case MessageAction.delete:
        final confirmed = await ChatConfirmDialog.deleteMessage(
          context,
          otherUserName: widget.otherUserName,
        );
        if (confirmed != true) return;
        await _cubit.deleteMessage(message.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DirectChatRoomCubit, DirectChatRoomState>(
      builder: (context, state) {
        return state.maybeWhen(
          initial: () => const Center(child: CircularProgressIndicator()),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (message) => _ErrorBlock(
            message: message,
            onRetry: () => context.read<DirectChatRoomCubit>().open(),
          ),
          loaded:
              (
                messages,
                hasMore,
                currentPage,
                isLoadingMore,
                isBlocked,
                typing,
              ) {
                final cubit = context.read<DirectChatRoomCubit>();
                return Column(
                  children: [
                    Expanded(
                      child: messages.isEmpty
                          ? _EmptyConversation(isBlocked: isBlocked)
                          : _MessageList(
                              messages: messages,
                              hasMore: hasMore,
                              isLoadingMore: isLoadingMore,
                              canReply: !isBlocked,
                              onLongPressMessage: _onLongPressMessage,
                            ),
                    ),
                    if (typing.isNotEmpty) _TypingHint(names: typing),
                    if (isBlocked)
                      const _BlockedNotice()
                    else ...[
                      ReplyBanner(
                        replyingTo: cubit.replyingTo,
                        onCancel: cubit.cancelReply,
                      ),
                      ReplyBanner(
                        replyingTo: cubit.editingMessage,
                        onCancel: cubit.cancelEdit,
                        labelBuilder: (_) => 'Editing message',
                      ),
                    ],
                    // Rebuilt against `editingMessage` so entering edit
                    // mode swaps in a composer seeded with the original
                    // text. The ValueKey is what forces a fresh State —
                    // ChatInput reads `initialText` once, in initState.
                    ValueListenableBuilder<ChatMessage?>(
                      valueListenable: cubit.editingMessage,
                      builder: (_, editing, __) {
                        return ChatInput(
                          key: ValueKey(
                            editing == null ? 'compose' : 'edit-${editing.id}',
                          ),
                          // Same mechanism read-only groups use — the
                          // composer disables and explains itself
                          // rather than letting the send fail silently.
                          enabled: !isBlocked,
                          hint: isBlocked
                              ? 'This conversation has been closed'
                              : (editing == null
                                    ? 'Type a message…'
                                    : 'Edit your message…'),
                          initialText: editing?.message,
                          // In edit mode an empty field must still be
                          // submittable, so the refusal is explained
                          // rather than silently swallowed by a dead
                          // send button.
                          allowEmptySubmit: editing != null,
                          onSend: editing == null
                              ? cubit.sendText
                              : cubit.saveEdit,
                          // No typing pings while editing — the other
                          // side isn't waiting on a new message.
                          onTypingChanged: editing == null
                              ? cubit.notifyTyping
                              : null,
                        );
                      },
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

  /// False on a blocked thread — suppresses reply and edit in the
  /// long-press menu, since both end in a send the server will refuse.
  final bool canReply;

  final void Function(ChatMessage message, bool canReply) onLongPressMessage;

  const _MessageList({
    required this.messages,
    required this.hasMore,
    required this.isLoadingMore,
    required this.canReply,
    required this.onLongPressMessage,
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
        context.read<DirectChatRoomCubit>().loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final itemCount = widget.messages.length + (widget.isLoadingMore ? 1 : 0);
    return ListView.separated(
      controller: _controller,
      reverse: true,
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      padding: Screen.getPadding(horizontal: 12, vertical: 12),
      itemCount: itemCount,
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
        final prevIndex = index + 1;
        final sameAsPrev =
            prevIndex < widget.messages.length &&
            widget.messages[prevIndex].senderId == message.senderId;
        final prev = prevIndex < widget.messages.length
            ? widget.messages[prevIndex]
            : null;
        final showDateHeader =
            prev == null || !_isSameDay(prev.createdAt, message.createdAt);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header renders ABOVE the bubble. `reverse: true` only
            // flips the order of items in the scroll view — not the
            // internal widget order of each item — so the header has to
            // come first in the Column.
            if (showDateHeader)
              Padding(
                padding: EdgeInsets.only(
                  top: Screen.getVerticalSize(12),
                  bottom: Screen.getVerticalSize(8),
                ),
                child: _DateHeader(date: message.createdAt),
              ),
            SwipeToReply(
              // `isFromCurrentStudent` is a role check, not a user-id
              // check — which is exactly right here, because this app
              // is always the learner side of a student↔staff thread.
              isMe: message.isFromCurrentStudent,
              onReply: () =>
                  context.read<DirectChatRoomCubit>().startReply(message),
              // Long-press opens Reply / Edit / Delete. Wrapping
              // outside SwipeToReply keeps the horizontal drag gesture
              // and the long-press from competing in the same detector.
              child: GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                onLongPress: () =>
                    widget.onLongPressMessage(message, widget.canReply),
                child: MessageBubble(
                  message: message,
                  sameSenderAsPrev: sameAsPrev,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static bool _isSameDay(DateTime a, DateTime b) {
    final aL = a.toLocal();
    final bL = b.toLocal();
    return aL.year == bL.year && aL.month == bL.month && aL.day == bL.day;
  }
}

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
    // A DM has exactly one other party, so the plural branch group chat
    // needs can't happen here.
    final label = '${names.first} is typing…';
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

/// Sits where the reply banner would, directly above the disabled
/// composer, so the reason the input is dead is adjacent to the input.
class _BlockedNotice extends StatelessWidget {
  const _BlockedNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: Screen.getPadding(horizontal: 18, vertical: 10),
      color: AppColors.grey200.withValues(alpha: 0.6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.lock_outline_rounded,
            size: Screen.getSize(16),
            color: AppColors.mutedTextPrimary,
          ),
          SizedBox(width: Screen.getHorizontalSize(8)),
          Flexible(
            child: Text(
              'This conversation has been closed.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextSmallMedium.copyWith(
                color: AppColors.mutedTextPrimary,
                fontSize: Screen.getFontSize(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversation extends StatelessWidget {
  final bool isBlocked;

  const _EmptyConversation({required this.isBlocked});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Screen.getPadding(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 64,
              color: AppColors.grey300,
            ),
            SizedBox(height: Screen.getVerticalSize(12)),
            Text(
              'No messages yet',
              style: AppTypography.h5SemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(8)),
            Text(
              isBlocked
                  ? 'This conversation has been closed.'
                  : 'Say hello — your message goes straight to them.',
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

/// Builds a [DirectChatRoomPage] from go_router query params. Lives
/// here so app_router.dart stays declarative.
DirectChatRoomPage directChatRoomPageFromQuery(Map<String, String> params) {
  final conversationKey = params['conversationKey'] ?? '';
  final otherUserName = params['otherUserName'] ?? 'Chat';
  final avatarRaw = params['otherUserAvatarUrl'];
  final avatar = (avatarRaw != null && avatarRaw.isNotEmpty) ? avatarRaw : null;
  final blockedRaw = params['isBlocked']?.toLowerCase();
  return DirectChatRoomPage(
    conversationKey: conversationKey,
    otherUserName: otherUserName,
    otherUserAvatarUrl: avatar,
    isBlocked: blockedRaw == 'true',
  );
}
