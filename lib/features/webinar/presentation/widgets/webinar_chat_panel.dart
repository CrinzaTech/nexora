import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';

import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_sizes.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/features/courses/data/models/live_class_models.dart';
import 'package:nexora/features/webinar/presentation/bloc/webinar_room_cubit.dart';

/// Webinar chat — newest message on top (reverse list); scrolling to the
/// bottom pages older history backwards through `beforeId`.
///
/// Chat is a **transcript**, not media: it keeps working before the host
/// starts and after the class ends, which is why this panel is mounted in
/// every phase rather than only alongside the player.
class WebinarChatPanel extends StatefulWidget {
  /// This learner's own `app_users.id`, for aligning their bubbles right.
  final int? myId;

  const WebinarChatPanel({super.key, required this.myId});

  @override
  State<WebinarChatPanel> createState() => _WebinarChatPanelState();
}

class _WebinarChatPanelState extends State<WebinarChatPanel> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    // Nothing to page yet (list shorter than the viewport) — bail so a
    // short list doesn't fire loadMoreChat on every rebuild.
    if (pos.maxScrollExtent <= 0) return;
    // Reverse list: the far end is the *oldest* message, so that is
    // where paging backwards belongs.
    if (pos.pixels >= pos.maxScrollExtent - 80) {
      context.read<WebinarRoomCubit>().loadMoreChat();
    }
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    context.read<WebinarRoomCubit>().sendChat(text);
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
            child: BlocBuilder<WebinarRoomCubit, WebinarRoomState>(
              buildWhen: (p, c) =>
                  p.messages != c.messages ||
                  p.isLoadingMoreChat != c.isLoadingMoreChat,
              builder: (context, state) {
                if (state.messages.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: Screen.getPadding(horizontal: 24),
                      child: Text(
                        'No messages yet. Say hello!',
                        textAlign: TextAlign.center,
                        style: AppTypography.bodyTextMedium.copyWith(
                          color: AppColors.mutedTextPrimary,
                        ),
                      ),
                    ),
                  );
                }
                return ListView.builder(
                  controller: _scrollController,
                  reverse: true,
                  padding: EdgeInsets.all(AppSizes.paddingM),
                  itemCount:
                      state.messages.length + (state.isLoadingMoreChat ? 1 : 0),
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

  Widget _header() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: AppSizes.paddingM,
        vertical: AppSizes.paddingS,
      ),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.grey200, width: 1)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: AppSizes.iconS,
            color: AppColors.mutedTextPrimary,
          ),
          SizedBox(width: Screen.getHorizontalSize(8)),
          Text('Live chat', style: AppTypography.bodyTextSemiBold),
        ],
      ),
    );
  }

  /// Amber strip while the socket is down. The transcript still reads
  /// over REST, so the honest statement is "you can read but not send" —
  /// silently swallowing what someone types would be worse.
  Widget _connectionBanner() {
    return BlocBuilder<WebinarRoomCubit, WebinarRoomState>(
      buildWhen: (p, c) => p.chatConnected != c.chatConnected,
      builder: (context, state) {
        if (state.chatConnected) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: Colors.amber.shade100,
          padding: EdgeInsets.symmetric(
            horizontal: AppSizes.paddingM,
            vertical: AppSizes.paddingS,
          ),
          child: Row(
            children: [
              Icon(
                Icons.cloud_off,
                size: AppSizes.iconS,
                color: Colors.orange.shade800,
              ),
              SizedBox(width: Screen.getHorizontalSize(8)),
              Expanded(
                child: Text(
                  'Chat is read-only — reconnecting…',
                  style: AppTypography.bodyTextSmallMedium.copyWith(
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

  Widget _inputBar() {
    return BlocBuilder<WebinarRoomCubit, WebinarRoomState>(
      buildWhen: (p, c) => p.chatConnected != c.chatConnected,
      builder: (context, state) {
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
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: state.chatConnected,
                    maxLength: 1000,
                    minLines: 1,
                    maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    inputFormatters: [LengthLimitingTextInputFormatter(1000)],
                    decoration: InputDecoration(
                      hintText: state.chatConnected
                          ? 'Message…'
                          : 'Connecting to chat…',
                      counterText: '',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: AppSizes.paddingM,
                        vertical: AppSizes.paddingS,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppSizes.radiusL),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: Screen.getHorizontalSize(8)),
                IconButton(
                  onPressed: state.chatConnected ? _send : null,
                  icon: Icon(
                    Icons.send,
                    color: state.chatConnected
                        ? AppColors.primary
                        : AppColors.grey400,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _bubble(LiveChatMessage msg, bool isMine) {
    // Measured against the panel, not the window. Sizing off
    // `MediaQuery.size.width` is right on a phone, where the panel *is*
    // the screen — but on the web the chat is a 380 px column beside the
    // stage, and 78% of a 2000 px window is a bubble four times wider
    // than the panel holding it, so long messages ran off the edge.
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxBubbleWidth = constraints.maxWidth * 0.86;
        return _buildBubble(context, msg, isMine, maxBubbleWidth);
      },
    );
  }

  Widget _buildBubble(
    BuildContext context,
    LiveChatMessage msg,
    bool isMine,
    double maxBubbleWidth,
  ) {
    final isEducator = msg.isEducator;
    final align = isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start;

    final Color bubbleColor;
    if (isMine) {
      bubbleColor = AppColors.primary.withValues(alpha: 0.12);
    } else if (isEducator) {
      bubbleColor = AppColors.primary.withValues(alpha: 0.14);
    } else {
      bubbleColor = AppColors.grey100;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: Screen.getVerticalSize(8)),
      child: Column(
        crossAxisAlignment: align,
        children: [
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
                _hostTag(),
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

  /// "Host" rather than "Educator" — a webinar's speaker may not be one
  /// of the learner's course teachers, and the wire role is the same
  /// non-student value either way.
  Widget _hostTag() {
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
            'Host',
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
