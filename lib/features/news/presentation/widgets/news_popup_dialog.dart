import 'dart:math' as math;

import 'package:nexora/core/theme/app_theme.dart';
import 'package:nexora/features/news/data/models/news_item_model.dart';
import 'package:nexora/features/news/presentation/bloc/news_home_cubit.dart';
import 'package:nexora/features/news/presentation/widgets/news_post_widgets.dart';
import 'package:flutter/material.dart';

/// The Home popup: every new post in one dialog, one page each, newest
/// first.
///
/// However it closes — ×, Later, back, a barrier tap or the action button —
/// [show] reports **all** of its ids as shown, including pages the learner
/// never swiped to. That is what stops them popping up again; they stay
/// unread (badge lit) until opened in the panel.
class NewsPopupDialog extends StatefulWidget {
  final List<NewsItem> items;
  final NewsHomeCubit cubit;

  const NewsPopupDialog({super.key, required this.items, required this.cubit});

  /// Shows the dialog over [context] and, once it has closed, runs the
  /// action the learner tapped (if any) — so a course page opens on top of
  /// Home, not underneath the dialog.
  static Future<void> show(
    BuildContext context, {
    required List<NewsItem> items,
    required NewsHomeCubit cubit,
  }) async {
    if (items.isEmpty) return;
    final tapped = await showDialog<NewsItem>(
      context: context,
      barrierDismissible: true,
      builder: (_) => NewsPopupDialog(items: items, cubit: cubit),
    );
    cubit.popupClosed([for (final n in items) n.newsId]);
    if (tapped != null && context.mounted) await runNewsAction(context, tapped);
  }

  @override
  State<NewsPopupDialog> createState() => _NewsPopupDialogState();
}

class _NewsPopupDialogState extends State<NewsPopupDialog> {
  final PageController _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onAction(NewsItem item) {
    widget.cubit.markRead(item);
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // A PageView needs a fixed height. Taller when any page has a picture,
    // and capped so it never fills a tablet.
    final anyImage = widget.items.any((n) => n.hasImage);
    final height = anyImage
        ? math.min(size.height * 0.68, 540.0)
        : math.min(size.height * 0.5, 400.0);
    final many = widget.items.length > 1;

    return Dialog(
      backgroundColor: AppColors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: height,
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _controller,
                    itemCount: widget.items.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => _PopupPage(
                      item: widget.items[i],
                      onAction: () => _onAction(widget.items[i]),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: _CloseButton(
                      onTap: () => Navigator.of(context).pop(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
              child: Row(
                children: [
                  if (many) _Dots(count: widget.items.length, active: _page),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      'Later',
                      style: AppTypography.bodyTextLargeSemiBold.copyWith(
                        color: AppColors.mutedTextPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PopupPage extends StatelessWidget {
  final NewsItem item;
  final VoidCallback onAction;

  const _PopupPage({required this.item, required this.onAction});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // The dialog's own clip rounds the picture's top corners.
        NewsPostImage(item: item),
        Expanded(
          child: SingleChildScrollView(
            // Clear of the × when there is no picture above the text.
            padding: EdgeInsets.fromLTRB(20, item.hasImage ? 16 : 20, 20, 12),
            child: Padding(
              padding: EdgeInsets.only(right: item.hasImage ? 0 : 32),
              child: NewsPostBody(item: item),
            ),
          ),
        ),
        if (item.hasAction)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
            child: NewsActionButton(item: item, onPressed: onAction),
          ),
      ],
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.all(6),
          child: Icon(
            Icons.close_rounded,
            size: 20,
            color: AppColors.alwaysWhite,
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  final int count;
  final int active;

  const _Dots({required this.count, required this.active});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(right: 6),
            width: i == active ? 18 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == active ? AppColors.primary : AppColors.grey300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}
