import 'package:flutter/material.dart';
import 'package:noterly/extensions/date_time_extensions.dart';
import 'package:noterly/l10n/localisations_util.dart';
import 'package:noterly/managers/app_manager.dart';
import 'package:noterly/models/navigation_screen.dart';
import 'package:noterly/models/notification_item.dart';
import 'package:noterly/pages/edit_notification_page.dart';
import 'package:noterly/widgets/empty_state.dart';
import 'package:noterly/widgets/expressive.dart';

class ActiveNotificationsPage extends NavigationScreen {
  final ScrollController scrollController;
  final List<NotificationItem> items;

  const ActiveNotificationsPage({
    super.key,
    required this.items,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(icon: Icons.notifications_none, text: Strings.of(context).page_activeNotifications_empty);
    }

    items.sort((a, b) {
      if (a.dateTime == null && b.dateTime == null) {
        return a.title.compareTo(b.title);
      } else if (a.dateTime == null) {
        return -1;
      } else if (b.dateTime == null) {
        return 1;
      } else {
        return a.dateTime!.compareTo(b.dateTime!);
      }
    });

    var immediateItems = items.where((element) => element.dateTime == null && !element.isRepeating).toList();
    var scheduledItems = items.where((element) => element.dateTime != null && !element.isRepeating).toList();
    var repeatingItems = items.where((element) => element.isRepeating).toList();

    var immediateWidgets = immediateItems.isEmpty
        ? []
        : [
            _getListHeader(context, Strings.of(context).page_activeNotifications_header_immediate),
            _getCard(context, immediateItems),
          ];

    var scheduledWidgets = scheduledItems.isEmpty
        ? []
        : [
            _getListHeader(context, Strings.of(context).page_activeNotifications_header_scheduled),
            _getCard(context, scheduledItems),
          ];

    var repeatingWidgets = repeatingItems.isEmpty
        ? []
        : [
            _getListHeader(context, Strings.of(context).page_activeNotifications_header_repeating),
            _getCard(context, repeatingItems),
          ];

    var emptyWidgets = [
      SliverToBoxAdapter(
        child: Center(
          child: Text(Strings.of(context).page_activeNotifications_empty),
        ),
      ),
    ];

    bool isEmpty = immediateWidgets.isEmpty && scheduledWidgets.isEmpty && repeatingWidgets.isEmpty;

    var widgets = isEmpty
        ? emptyWidgets
        : [
            ...immediateWidgets,
            ...scheduledWidgets,
            ...repeatingWidgets,
          ];

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        ...widgets,
        const SliverToBoxAdapter(child: SizedBox(height: 96)), // Add some padding at the bottom so the FAB doesn't overlap with the last item
      ],
    );
  }

  Widget _getListHeader(BuildContext context, String title) => SliverToBoxAdapter(
        child: ExpressiveSectionHeader(title),
      );

  Widget _getCard(BuildContext context, List<NotificationItem> items) => SliverToBoxAdapter(
        child: ExpressiveListGroup(
          children: [for (var item in items) _getItem(context, item)],
        ),
      );

  Widget _getItem(BuildContext context, NotificationItem item) => Dismissible(
        key: ValueKey(item.id),
        background: const ExpressiveDismissBackground(icon: Icons.archive),
        secondaryBackground: const ExpressiveDismissBackground(icon: Icons.archive, isSecondary: true),
        onDismissed: (direction) {
          AppManager.instance.archiveItem(item.id);
          ScaffoldMessenger.of(context).clearSnackBars(); // Prevents multiple snackbars from building up
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              persist: false, // Snack bars with an action stay until swiped away by default
              content: Text(Strings.of(context).snackbar_notificationArchived(item.title)),
              action: SnackBarAction(
                label: Strings.of(context).general_undo,
                onPressed: () => AppManager.instance.restoreArchivedItem(item.id),
              ),
            ),
          );
        },
        child: ListTile(
          title: Text(item.title),
          subtitle: _getSubtitle(context, item),
          minVerticalPadding: 14,
          leading: ExpressiveColourBadge(colour: item.colour),
          onTap: () => _onItemTap(context, item),
        ),
      );

  Widget? _getSubtitle(BuildContext context, NotificationItem item) {
    // Contains a list of conditions, each one of which returns true if it should NOT be shown
    var subtitleCheck = [
      item.body.isEmpty,
      item.isImmediate,
      item.isNotRepeating,
      (item.isNotSnoozed || item.isSnoozedPast),
    ];

    if (subtitleCheck.every((condition) => condition)) {
      return null; // No subtitle
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (item.body.isNotEmpty) Text(item.body),
        if ((item.dateTime != null || item.isRepeating)) const SizedBox(height: 4),
        if (item.dateTime != null)
          Row(
            children: [
              const Icon(Icons.access_time, size: 16),
              const SizedBox(width: 8),
              Flexible(child: Text(item.dateTime!.toRelativeDateTimeString(), style: Theme.of(context).textTheme.labelLarge)),
            ],
          ),
        if (item.isRepeating)
          Row(
            children: [
              const Icon(Icons.repeat, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  Strings.of(context).page_activeNotifications_item_repeats(item.repetitionData!.toReadableString()),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
        if (item.isSnoozed && !item.isSnoozedPast)
          Row(
            children: [
              const Icon(Icons.snooze, size: 16),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  Strings.of(context).page_activeNotifications_item_snoozed(item.snoozeDateTime!.toSnoozedUntilDateTimeString()),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
      ],
    );
  }

  void _onItemTap(BuildContext context, NotificationItem item) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EditNotificationPage(
            item: item,
          ),
        ),
      );
}
