import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/courses/data/models/live_class_models.dart';
import 'package:nexora/features/courses/presentation/bloc/live_class_cubit.dart';

/// In-page chat panel for a live class. Newest message on top (reverse
/// list); scrolling to the bottom pages older history. Respects chat
/// mode + the student's own `chatBlocked` flag (input disabled + server
/// rejection surfaced as a transient notice by the cubit).
class LiveClassChatPanel extends StatefulWidget {
  final int? myId;

  const LiveClassChatPanel({super.key, required this.myId});

  @override
  State<LiveClassChatPanel> createState() => _LiveClassChatPanelState();
}

class _LiveClassChatPanelState extends State<LiveClassChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // Nothing to page yet (list shorter than the viewport) — bail so we
    // don't fire loadMoreChat on open / on every short-list rebuild.
    if (pos.maxScrollExtent <= 0) return;
    // Reverse list: reaching max extent = the oldest visible message →
    // page backwards for older history.
    if (pos.pixels >= pos.maxScrollExtent - 80) {
      context.read<LiveClassCubit>().loadMoreChat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<LiveClassCubit>().sendChat(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.white,
      child: Column(
        children: [
          _header(),
          _connectionBanner(),
          Expanded(
            child: BlocBuilder<LiveClassCubit, LiveClassState>(
              buildWhen: (p, c) =>
                  p.messages != c.messages ||
                  p.chatLoadingMore != c.chatLoadingMore ||
                  p.chatMode != c.chatMode,
              builder: (context, state) {
                if (state.messages.isEmpty) {
                  return Center(
                    child: Text(
                      'No messages yet.',
                      style: AppTypography.bodyTextMedium.copyWith(
                        color: AppColors.mutedTextPrimary,
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: EdgeInsets.all(AppSizes.paddingM),
                  itemCount:
                      state.messages.length + (state.chatLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= state.messages.length) {
                      return const Padding(
                        padding: EdgeInsets.all(AppSizes.paddingM),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }
                    final msg = state.messages[index];
                    return _bubble(msg, msg.senderId == widget.myId);
                  },
                );
              },
            ),
          ),
          _inputBar(),
        ],
      ),
    );
  }

  /// Amber strip shown while the SignalR hub isn't connected — makes the
  /// "messages/hand-raise won't reach the host" condition visible instead
  /// of failing silently.
  Widget _connectionBanner() {
    return BlocBuilder<LiveClassCubit, LiveClassState>(
      buildWhen: (p, c) => p.hubConnected != c.hubConnected,
      builder: (context, state) {
        if (state.hubConnected) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: Colors.amber.shade100,
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.paddingM,
            vertical: AppSizes.paddingS,
          ),
          child: Row(
            children: [
              Icon(Icons.cloud_off, size: AppSizes.iconS, color: Colors.orange.shade800),
              SizedBox(width: Screen.getHorizontalSize(8)),
              Expanded(
                child: Text(
                  'Connecting to live chat…',
                  style: AppTypography.labelSmall.copyWith(
                    color: Colors.orange.shade900,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _header() {
    return BlocBuilder<LiveClassCubit, LiveClassState>(
      buildWhen: (p, c) => p.chatMode != c.chatMode,
      builder: (context, state) {
        final isPrivate = state.chatMode == ChatMode.private;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.paddingM,
            vertical: AppSizes.paddingS,
          ),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: AppColors.grey200,
                width: 1,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isPrivate ? Icons.lock_outline : Icons.chat_bubble_outline,
                size: AppSizes.iconS,
                color: AppColors.mutedTextPrimary,
              ),
              SizedBox(width: Screen.getHorizontalSize(8)),
              Text(
                isPrivate ? 'Private chat with host' : 'Live chat',
                style: AppTypography.bodyTextSemiBold,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _inputBar() {
    return BlocBuilder<LiveClassCubit, LiveClassState>(
      buildWhen: (p, c) => p.flags.chatBlocked != c.flags.chatBlocked,
      builder: (context, state) {
        final blocked = state.flags.chatBlocked;
        return SafeArea(
          top: false,
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: AppSizes.paddingM,
              vertical: AppSizes.paddingS,
            ),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.grey200, width: 1),
              ),
            ),
            child: blocked
                ? Row(
                    children: [
                      Icon(
                        Icons.block,
                        size: AppSizes.iconS,
                        color: AppColors.mutedTextPrimary,
                      ),
                      SizedBox(width: Screen.getHorizontalSize(8)),
                      Text(
                        'Chat disabled by host.',
                        style: AppTypography.bodyTextMedium.copyWith(
                          color: AppColors.mutedTextPrimary,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          maxLength: 1000,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _send(),
                          inputFormatters: [
                            LengthLimitingTextInputFormatter(1000),
                          ],
                          decoration: InputDecoration(
                            hintText: 'Message…',
                            counterText: '',
                            isDense: true,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: AppSizes.paddingM,
                              vertical: AppSizes.paddingS,
                            ),
                            border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(AppSizes.radiusL),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: Screen.getHorizontalSize(8)),
                      IconButton(
                        onPressed: _send,
                        icon: Icon(Icons.send, color: AppColors.primary),
                      ),
                    ],
                  ),
          ),
        );
      },
    );
  }

  Widget _bubble(LiveChatMessage msg, bool isMine) {
    final isEducator = msg.isEducator;
    // My own messages sit on the right; everyone else — other students
    // AND the educator — sits on the left.
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    // Educator bubbles are visually distinct from students': a stronger
    // primary tint + a left accent strip + an "Educator" tag, so the
    // teacher's replies stand out from the student chatter.
    final Color bubbleColor;
    if (isMine) {
      bubbleColor = AppColors.primary.withValues(alpha: 0.12);
    } else if (isEducator) {
      bubbleColor = AppColors.primary.withValues(alpha: 0.14);
    } else {
      bubbleColor = AppColors.grey100;
    }

    final maxBubbleWidth = MediaQuery.of(context).size.width * 0.78;

    return Padding(
      padding: EdgeInsets.only(bottom: Screen.getVerticalSize(8)),
      child: Column(
        crossAxisAlignment: align,
        children: [
          // Sender line: name + (educator tag) + timestamp.
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  isMine ? 'You' : msg.senderName,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.labelSmall.copyWith(
                    color: isEducator
                        ? AppColors.primary
                        : AppColors.mutedTextPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (isEducator) ...[
                SizedBox(width: Screen.getHorizontalSize(4)),
                _educatorTag(),
              ],
              SizedBox(width: Screen.getHorizontalSize(6)),
              Text(
                DateFormat('h:mm a').format(msg.createdAt),
                style: AppTypography.labelSmall.copyWith(
                  color: AppColors.mutedTextPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: Screen.getVerticalSize(2)),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppSizes.paddingM,
                vertical: AppSizes.paddingS,
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: BorderRadius.circular(AppSizes.radiusL),
                // Accent strip + outline only on the educator's bubble.
                border: isEducator
                    ? Border(
                        left: BorderSide(color: AppColors.primary, width: 3),
                      )
                    : null,
              ),
              child: Text(msg.body, style: AppTypography.bodyTextMedium),
            ),
          ),
        ],
      ),
    );
  }

  /// Small "Educator" pill shown next to the teacher's name so their
  /// messages are unmistakable among the students'.
  Widget _educatorTag() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(AppSizes.radiusS),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.verified, size: 10, color: AppColors.alwaysWhite),
          const SizedBox(width: 3),
          Text(
            'Educator',
            style: AppTypography.labelSmall.copyWith(
              color: AppColors.alwaysWhite,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
