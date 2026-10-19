import 'package:flutter/material.dart';
import 'package:noterly/extensions/date_time_extensions.dart';
import 'package:noterly/l10n/localisations_util.dart';
import 'package:noterly/managers/app_manager.dart';
import 'package:noterly/models/navigation_screen.dart';
import 'package:noterly/models/notification_item.dart';

import 'package:noterly/widgets/empty_state.dart';
import 'package:noterly/widgets/expressive.dart';

import '../edit_notification_page.dart';

class ArchivedNotificationsPage extends NavigationScreen {
  final ScrollController scrollController;
  final List<NotificationItem> items;

  const ArchivedNotificationsPage({
    super.key,
    required this.items,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return EmptyState(icon: Icons.history, text: Strings.of(context).page_archivedNotifications_empty);
    }

    items.sort((a, b) => b.archivedDateTime!.compareTo(a.archivedDateTime!));

    return ListView.builder(
      controller: scrollController,
      itemCount: items.length + (items.length > 1 ? 1 : 0),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96), // Allow space for the FAB.
      itemBuilder: (context, index) {
        if (index == items.length) {
          // button to delete all archived notifications
          return Padding(
            padding: const EdgeInsets.only(top: 24),
            child: FilledButton.tonalIcon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              icon: const Icon(Icons.delete_sweep),
              label: Text(Strings.of(context).page_archivedNotifications_button_deleteAll),
              onPressed: () {
                AppManager.instance.deleteAllArchivedItems();

                ScaffoldMessenger.of(context).clearSnackBars(); // Clear any existing snackbars
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    persist: false, // Snack bars with an action stay until swiped away by default
                    content: Text(Strings.of(context).snackbar_allArchivedNotificationsDeleted),
                    action: SnackBarAction(
                      label: Strings.of(context).general_undo,
                      onPressed: () {
                        AppManager.instance.restoreLastDeletedItems();
                      },
                    ),
                  ),
                );
              },
            ),
          );
        }

        final item = items[index];

        return ExpressiveListItem(
          index: index,
          count: items.length,
          child: Dismissible(
            key: ValueKey(item.id),
            background: const ExpressiveDismissBackground(icon: Icons.delete),
            secondaryBackground: const ExpressiveDismissBackground(icon: Icons.delete, isSecondary: true),
            onDismissed: (direction) {
              AppManager.instance.deleteItem(item.id);
              ScaffoldMessenger.of(context).clearSnackBars(); // Clear any existing snackbars to prevent buildup
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  persist: false, // Snack bars with an action stay until swiped away by default
                  content: Text(Strings.of(context).snackbar_notificationDeleted(item.title)),
                  action: SnackBarAction(
                    label: Strings.of(context).general_undo,
                    onPressed: () {
                      AppManager.instance.restoreLastDeletedItems();
                    },
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
          ),
        );
      },
    );
  }

  Widget _getSubtitle(BuildContext context, NotificationItem item) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (item.body.isNotEmpty) Text(item.body),
          Row(
            children: [
              const Icon(Icons.history, size: 16),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  Strings.of(context).page_archivedNotifications_item_archived(item.archivedDateTime!.toRelativeDateTimeString()),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
            ],
          ),
        ],
      );

  void _onItemTap(BuildContext context, NotificationItem item) => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EditNotificationPage(
            item: item,
          ),
        ),
      );
}
