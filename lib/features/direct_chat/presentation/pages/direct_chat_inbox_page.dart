import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/router/app_routes.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/core/widgets/custom_appbar_widget.dart';
import 'package:nexora/core/widgets/custom_snackbar.dart';
import 'package:nexora/features/chats/presentation/widgets/chats_list_shimmer.dart';
import 'package:nexora/features/chats/presentation/widgets/error_state.dart';
import 'package:nexora/features/direct_chat/data/models/dm_conversation_model.dart';
import 'package:nexora/features/direct_chat/presentation/bloc/direct_inbox_cubit.dart';
import 'package:nexora/features/direct_chat/presentation/widgets/dm_conversation_tile.dart';
import 'package:nexora/features/direct_chat/presentation/widgets/staff_picker_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

/// Personal-chat inbox — the learner's private 1-to-1 threads with the
/// org's staff.
///
/// Reached from the "Personal Chat" tile on the Profile screen. When the
/// org has exactly one staff member the list is pure friction, so the
/// page resolves that single thread and replaces itself with the room —
/// see [_maybeAutoOpen].
class DirectChatInboxPage extends StatelessWidget {
  const DirectChatInboxPage({super.key});

  @override
  Widget build(BuildContext context) {
    Screen().adaptDeviceScreenSize(context);
    // `.value`, not a plain BlocProvider: DirectInboxCubit is a lazy
    // singleton that stays subscribed to `DirectInboxUpdated` for the
    // app's lifetime. A plain provider would close it on pop and every
    // later `sl<DirectInboxCubit>()` would return a dead cubit.
    return BlocProvider<DirectInboxCubit>.value(
      value: sl<DirectInboxCubit>()..load(),
      child: const _DirectChatInboxView(),
    );
  }
}

class _DirectChatInboxView extends StatefulWidget {
  const _DirectChatInboxView();

  @override
  State<_DirectChatInboxView> createState() => _DirectChatInboxViewState();
}

class _DirectChatInboxViewState extends State<_DirectChatInboxView> {
  /// The auto-open decision is made once per page mount. Without this
  /// the learner could never get back — popping the room would rebuild
  /// the inbox, which would immediately push the room again.
  bool _autoOpenResolved = false;

  /// Covers the screen while a thread is being resolved (a
  /// `POST /conversations` round-trip), so a tap can't be double-fired
  /// and the auto-open path never flashes an inbox the user won't keep.
  bool _isResolving = false;

  /// Single-staff orgs skip the list entirely. The rule is deliberately
  /// narrow: exactly one person the learner could possibly talk to, and
  /// no second thread already in the inbox. Anything else earns a list.
  ///
  /// The builder consults this too — it has to hold the shimmer for the
  /// same states the listener is about to navigate away from, so the
  /// two must never disagree.
  static bool _shouldAutoOpen(
    List<DmConversation> conversations,
    List<DmDirectoryEntry> directory,
  ) => directory.length == 1 && conversations.length <= 1;

  Future<void> _maybeAutoOpen(
    List<DmConversation> conversations,
    List<DmDirectoryEntry> directory,
  ) async {
    if (_autoOpenResolved) return;
    if (!_shouldAutoOpen(conversations, directory)) return;
    _autoOpenResolved = true;
    await _openEntry(directory.first, replace: true);
  }

  /// Resolve a directory entry to a thread and navigate into it.
  ///
  /// [replace] swaps this page out of the stack instead of stacking on
  /// top — used by the auto-open path so "back" from the room returns
  /// to Profile rather than to an inbox the learner never chose to see.
  Future<void> _openEntry(
    DmDirectoryEntry entry, {
    bool replace = false,
  }) async {
    setState(() => _isResolving = true);
    final result = await context.read<DirectInboxCubit>().openWith(entry);
    if (!mounted) return;
    setState(() => _isResolving = false);
    result.fold(
      (failure) {
        // A single-staff org whose one entry can't be opened would
        // otherwise sit on a blank screen forever — let the retry come
        // from a visible inbox instead.
        _autoOpenResolved = true;
        CustomSnackbar.error(
          context,
          title: 'Unable to open chat',
          message: failure.message,
        );
      },
      (conversation) => _pushRoom(conversation, replace: replace),
    );
  }

  void _pushRoom(DmConversation conversation, {bool replace = false}) {
    final avatar = conversation.otherUserAvatarUrl;
    final avatarQuery = (avatar != null && avatar.isNotEmpty)
        ? '&otherUserAvatarUrl=${Uri.encodeComponent(avatar)}'
        : '';
    final location =
        '${AppRoutes.directChatRoom}'
        '?conversationKey=${Uri.encodeComponent(conversation.conversationKey)}'
        '&otherUserName=${Uri.encodeComponent(conversation.otherUserName)}'
        '$avatarQuery'
        '&isBlocked=${conversation.isBlocked}';
    if (replace) {
      context.pushReplacement(location);
    } else {
      context.push(location);
    }
  }

  Future<void> _openStaffPicker(List<DmDirectoryEntry> directory) async {
    final entry = await StaffPickerSheet.show(context, directory: directory);
    if (entry == null || !mounted) return;
    await _openEntry(entry);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.white,
      appBar: const CustomAppBar(title: 'Personal Chat', centerTitle: false),
      body: BlocConsumer<DirectInboxCubit, DirectInboxState>(
        listener: (context, state) {
          state.maybeWhen(
            loaded: (conversations, directory) {
              _maybeAutoOpen(conversations, directory);
            },
            orElse: () {},
          );
        },
        builder: (context, state) {
          return state.maybeWhen(
            loading: () => const ChatsListShimmer(),
            error: (message) => ErrorState(
              message: message,
              onRetry: () => context.read<DirectInboxCubit>().load(),
            ),
            loaded: (conversations, directory) {
              // Hold the shimmer through the auto-open round-trip so a
              // single-staff org never sees a one-row list flash past.
              // This build runs before the listener that navigates, so
              // the first pass has to predict the same decision.
              if (_isResolving ||
                  (!_autoOpenResolved &&
                      _shouldAutoOpen(conversations, directory))) {
                return const ChatsListShimmer();
              }
              if (conversations.isEmpty) {
                return _EmptyInbox(
                  canStart: directory.isNotEmpty,
                  onStart: () => _openStaffPicker(directory),
                );
              }
              return RefreshIndicator(
                color: AppColors.primary,
                onRefresh: context.read<DirectInboxCubit>().refresh,
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: Screen.getPadding(vertical: 8),
                  itemCount: conversations.length + 1,
                  separatorBuilder: (_, index) =>
                      index == conversations.length - 1
                      ? const SizedBox.shrink()
                      : Divider(
                          height: 1,
                          thickness: 0.5,
                          color: AppColors.grey200,
                          indent: Screen.getHorizontalSize(25),
                          endIndent: Screen.getHorizontalSize(25),
                        ),
                  itemBuilder: (_, index) {
                    if (index == conversations.length) {
                      return Utils.defaultBottomSpace();
                    }
                    final conversation = conversations[index];
                    return DmConversationTile(
                      conversation: conversation,
                      onTap: () => _pushRoom(conversation),
                    );
                  },
                ),
              );
            },
            orElse: () => const ChatsListShimmer(),
          );
        },
      ),
      // Only offered when there is actually someone new to talk to —
      // with a single staff member the learner is already in that
      // thread, so the button would be a dead end.
      floatingActionButton:
          BlocBuilder<DirectInboxCubit, DirectInboxState>(
            builder: (context, state) {
              final directory = state.maybeWhen(
                loaded: (_, directory) => directory,
                orElse: () => const <DmDirectoryEntry>[],
              );
              if (directory.length < 2 || _isResolving) {
                return const SizedBox.shrink();
              }
              return FloatingActionButton(
                onPressed: () => _openStaffPicker(directory),
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.alwaysWhite,
                tooltip: 'New chat',
                child: const Icon(Icons.edit_outlined),
              );
            },
          ),
    );
  }
}

class _EmptyInbox extends StatelessWidget {
  final bool canStart;
  final VoidCallback onStart;

  const _EmptyInbox({required this.canStart, required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: Screen.getPadding(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.forum_outlined,
              size: 80,
              color: AppColors.grey300,
            ),
            SizedBox(height: Screen.getVerticalSize(12)),
            Text(
              'No conversations yet',
              style: AppTypography.h5SemiBold.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: Screen.getVerticalSize(8)),
            Text(
              canStart
                  ? 'Message a faculty member directly. They\'ll reply here.'
                  : 'No faculty are available to message right now.',
              textAlign: TextAlign.center,
              style: AppTypography.bodyTextLargeMedium.copyWith(
                color: AppColors.mutedTextPrimary,
              ),
            ),
            if (canStart) ...[
              SizedBox(height: Screen.getVerticalSize(16)),
              TextButton(
                onPressed: onStart,
                child: Text(
                  'Start a conversation',
                  style: AppTypography.bodyTextSemiBold.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
