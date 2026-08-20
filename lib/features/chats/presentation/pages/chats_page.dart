import 'package:nexora/core/config/di/dependency_injection.dart';
import 'package:nexora/core/theme/app_colors.dart';
import 'package:nexora/core/theme/app_images.dart';
import 'package:nexora/core/theme/app_typography.dart';
import 'package:nexora/core/theme/responsive_helper.dart';
import 'package:nexora/core/theme/screen.dart';
import 'package:nexora/core/utils/utils.dart';
import 'package:nexora/core/widgets/scrolling_title.dart';
import 'package:nexora/features/chats/data/models/chat_group_model.dart';
import 'package:nexora/features/chats/presentation/bloc/chat_groups_cubit.dart';
import 'package:nexora/features/chats/presentation/widgets/chat_group_tile.dart';
import 'package:nexora/features/chats/presentation/widgets/chats_list_shimmer.dart';
import 'package:nexora/features/chats/presentation/widgets/chats_search_field.dart';
import 'package:nexora/features/chats/presentation/widgets/empty_state.dart';
import 'package:nexora/features/chats/presentation/widgets/error_state.dart';
import 'package:nexora/features/chats/presentation/widgets/no_search_results.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Chats Screen — lists course chat groups available to the current user.
///
/// Powered by `GET /api/v1/chat-group`. The list only renders when the
/// backend returns paid-user groups; if the user has no purchased courses
/// the API returns an empty array and we show an empty state.
class ChatsPage extends StatefulWidget {
  const ChatsPage({super.key});

  @override
  State<ChatsPage> createState() => _ChatsPageState();
}

class _ChatsPageState extends State<ChatsPage>
    with AutomaticKeepAliveClientMixin {
  /// Whether the local search field is currently displayed in place of
  /// the AppBar title. Toggled by the search icon action.
  bool _isSearching = false;

  /// Backing controller for the local search field. We listen to it and
  /// re-filter the loaded list on every keystroke — entirely client-side.
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  /// Mirror of `_searchController.text.trim().toLowerCase()` so the build
  /// doesn't re-run `toLowerCase` on every paint.
  String _query = '';

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onQueryChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onQueryChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onQueryChanged() {
    final next = _searchController.text.trim().toLowerCase();
    if (next != _query) {
      setState(() => _query = next);
    }
  }

  void _toggleSearch() {
    setState(() {
      _isSearching = !_isSearching;
      if (!_isSearching) {
        _searchController.clear();
        _query = '';
      } else {
        _searchFocusNode.requestFocus();
      }
    });
  }

  /// Local filter — matches against the group name and description so the
  /// user can find a group by either. Case-insensitive.
  List<ChatGroupModel> _filter(List<ChatGroupModel> groups) {
    if (_query.isEmpty) return groups;
    return groups.where((g) {
      final name = g.groupName.toLowerCase();
      final desc = g.groupDescription.toLowerCase();
      return name.contains(_query) || desc.contains(_query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    Screen().adaptDeviceScreenSize(context);

    return BlocProvider(
      create: (_) => sl<ChatGroupsCubit>()..load(),
      child: Scaffold(
        backgroundColor: AppColors.white,
        extendBody: true,
        body: SafeArea(
          child: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) {
              return [
                SliverAppBar(
                  backgroundColor: AppColors.white,
                  surfaceTintColor: AppColors.white,
                  elevation: 0,
                  pinned: true,
                  floating: true,
                  centerTitle: false,
                  automaticallyImplyLeading: false,
                  titleSpacing: Screen.getHorizontalSize(20),
                  title: ScrollingTitle(
                    text: 'All Chats',
                    style: AppTypography.h5SemiBold.copyWith(
                      color: AppColors.textPrimary,
                    ),
                  ),
                  actions: [
                    IconButton(
                      tooltip: _isSearching ? 'Close search' : 'Search chats',
                      icon: _isSearching
                          ? Icon(Icons.close, color: AppColors.textPrimary)
                          : Image.asset(
                              AppImages.searchIcon,
                              width: Screen.getSize(18),
                              color: AppColors.textPrimary,
                            ),
                      onPressed: _toggleSearch,
                    ),
                    SizedBox(width: Screen.getHorizontalSize(8)),
                  ],
                  bottom: PreferredSize(
                    preferredSize: Size.fromHeight(_isSearching ? Screen.getVerticalSize(66) : 0),
                    child: Container(
                      color: AppColors.white,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isSearching)
                            Padding(
                              padding: Screen.getPadding(horizontal: 20, top: 12, bottom: 8),
                              child: ChatsSearchField(
                                controller: _searchController,
                                focusNode: _searchFocusNode,
                                hintText: 'Search chats',
                                onChanged: (_) => _onQueryChanged(),
                                onClear: () {
                                  _searchController.clear();
                                  _onQueryChanged();
                                },
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: BlocBuilder<ChatGroupsCubit, ChatGroupsState>(
          builder: (context, state) {
            return state.maybeWhen(
              loading: () => const ChatsListShimmer(),
              loaded: (groups) {
                final filtered = _filter(groups);
                if (groups.isEmpty) return const EmptyState();
                if (filtered.isEmpty) {
                  return NoSearchResults(query: _query);
                }
                final rh = ResponsiveHelper.of(context);
                return RefreshIndicator(
                  color: AppColors.primary,
                  onRefresh: context.read<ChatGroupsCubit>().refresh,
                  child: Center(
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(
                        parent: BouncingScrollPhysics(),
                      ),
                      padding: Screen.getPadding(vertical: 8),
                      itemCount: filtered.length + 1,
                      separatorBuilder: (_, index) => index == filtered.length - 1
                          ? const SizedBox.shrink()
                          : Divider(
                              height: 1,
                              thickness: 0.5,
                              color: AppColors.grey200,
                              indent: Screen.getHorizontalSize(25),
                              endIndent: Screen.getHorizontalSize(25),
                            ),
                      itemBuilder: (_, index) {
                        if (index == filtered.length) {
                          return Utils.defaultBottomSpace();
                        }
                        return ChatGroupTile(group: filtered[index]);
                      },
                    ),
                  ),
            );
          },
          error: (message) => ErrorState(
            message: message,
            onRetry: () => context.read<ChatGroupsCubit>().load(),
          ),
          orElse: () => const ChatsListShimmer(),
        );
      },
    ),
          ),
        ),
      ),
    );
  }
}
