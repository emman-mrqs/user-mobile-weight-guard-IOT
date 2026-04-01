import 'package:flutter/material.dart';
import '../services/mobile_notification_service.dart';

class AppNavbar extends StatelessWidget {
  static bool _isSheetOpen = false;
  static bool _hasPrimedUnreadCount = false;

  final String title;
  final String subtitle;
  final int notificationCount;
  final VoidCallback? onNotificationTap;

  const AppNavbar({
    super.key,
    required this.title,
    required this.subtitle,
    this.notificationCount = -1,
    this.onNotificationTap,
  });

  Future<void> _primeUnreadCount() async {
    if (_hasPrimedUnreadCount) {
      return;
    }

    _hasPrimedUnreadCount = true;
    try {
      await MobileNotificationService.fetchInbox();
    } catch (_) {
      // Keep the badge stable when offline.
    }
  }

  String _relativeTime(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Unknown time';
    }

    final Duration difference = DateTime.now().difference(dateTime);
    if (difference.inMinutes < 1) return 'Just now';
    if (difference.inHours < 1) return '${difference.inMinutes}m ago';
    if (difference.inDays < 1) return '${difference.inHours}h ago';
    return '${difference.inDays}d ago';
  }

  Color _priorityColor(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'critical') return const Color(0xFFEF4444);
    if (normalized == 'high') return const Color(0xFFF59E0B);
    return const Color(0xFF4ADE80);
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) {
      return 'Unknown';
    }

    final twoDigits = (int value) => value.toString().padLeft(2, '0');
    final local = dateTime.toLocal();
    return '${local.year}-${twoDigits(local.month)}-${twoDigits(local.day)} ${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }

  String _audienceLabel(String? targetAudience) {
    final normalized = (targetAudience ?? '').trim().toLowerCase();
    if (normalized == 'all') return 'All Staff and Drivers';
    if (normalized == 'staff') return 'All Staff';
    if (normalized == 'incident_staff') return 'Incident Staff';
    if (normalized == 'dispatch_staff') return 'Dispatch Staff';
    if (normalized == 'super_admin') return 'Super Admin';
    if (normalized == 'drivers') return 'Drivers';
    return normalized.isEmpty ? 'Unknown' : normalized;
  }

  String _priorityHint(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'critical') return 'Immediate attention is recommended for this notification.';
    if (normalized == 'high') return 'Action soon is recommended based on this update.';
    return 'Informational update for your awareness.';
  }

  String _typeHint(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'alert') return 'Alert type indicates a potentially urgent operational event.';
    if (normalized == 'warning') return 'Warning type indicates a risk or condition to monitor.';
    return 'Announcement type indicates a general operational notice.';
  }

  IconData _typeIcon(String value) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'alert') return Icons.warning_amber_rounded;
    if (normalized == 'warning') return Icons.report_problem_rounded;
    return Icons.campaign_rounded;
  }

  Future<void> _showNotificationDetailsSheet(BuildContext context, MobileNotificationItem item) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        final priorityColor = _priorityColor(item.priority);
        final readStatus = item.isRead ? 'Read' : 'Unread';
        final deliveredTo = _audienceLabel(item.targetAudience);
        final typeLabel = item.type.trim().isEmpty ? 'announcement' : item.type;
        final notificationRef = item.notificationId > 0 ? '#${item.notificationId}' : '-';
        final inboxRef = item.recipientId > 0 ? '#${item.recipientId}' : '-';

        return FractionallySizedBox(
          heightFactor: 0.88,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            decoration: const BoxDecoration(
              color: Color(0xFF081F17),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Row(
                    children: <Widget>[
                      Icon(_typeIcon(typeLabel), color: priorityColor, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          item.title,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: priorityColor.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: priorityColor.withValues(alpha: 0.30)),
                        ),
                        child: Text(
                          item.priority.toUpperCase(),
                          style: TextStyle(color: priorityColor, fontSize: 10, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              _DetailPill(label: 'Type', value: typeLabel.toUpperCase()),
                              _DetailPill(label: 'Status', value: readStatus),
                              _DetailPill(label: 'Audience', value: deliveredTo),
                              _DetailPill(label: 'From', value: item.senderName),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _DetailSectionCard(
                            title: 'Summary',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _priorityHint(item.priority),
                                  style: const TextStyle(color: Colors.white70, fontSize: 12.5, height: 1.35),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _typeHint(typeLabel),
                                  style: const TextStyle(color: Colors.white54, fontSize: 11.8, height: 1.35),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          _DetailSectionCard(
                            title: 'Notification Message',
                            child: Text(
                              item.message.isEmpty ? 'No message content.' : item.message,
                              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
                            ),
                          ),
                          const SizedBox(height: 10),
                          _DetailSectionCard(
                            title: 'Delivery Details',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _DetailLine(label: 'Sender', value: item.senderName),
                                _DetailLine(label: 'Target Audience', value: deliveredTo),
                                _DetailLine(label: 'Priority', value: item.priority.toUpperCase()),
                                _DetailLine(label: 'Type', value: typeLabel.toUpperCase()),
                                _DetailLine(label: 'Read Status', value: readStatus),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),
                          _DetailSectionCard(
                            title: 'Timeline & Reference',
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                _DetailLine(label: 'Created At', value: _formatDateTime(item.createdAt)),
                                _DetailLine(label: 'Read At', value: item.readAt == null ? 'Not yet read' : _formatDateTime(item.readAt)),
                                _DetailLine(label: 'Notification ID', value: notificationRef),
                                _DetailLine(label: 'Inbox Recipient ID', value: inboxRef),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.18)),
                        foregroundColor: Colors.white70,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Close Details'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _showNotificationsSheet(BuildContext context) async {
    if (_isSheetOpen) {
      return;
    }

    _isSheetOpen = true;

    MobileNotificationInbox? inbox;
    String? loadError;

    try {
      inbox = await MobileNotificationService.fetchInbox(forceRefresh: true);
    } catch (error) {
      loadError = error.toString().replaceFirst('Exception: ', '');
    }

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            Future<void> refreshInbox() async {
              try {
                final fresh = await MobileNotificationService.fetchInbox(forceRefresh: true);
                setSheetState(() {
                  inbox = fresh;
                  loadError = null;
                });
              } catch (error) {
                setSheetState(() {
                  loadError = error.toString().replaceFirst('Exception: ', '');
                });
              }
            }

            Future<void> markAllAsRead() async {
              try {
                await MobileNotificationService.markAllAsRead();
                await refreshInbox();
              } catch (error) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(error.toString().replaceFirst('Exception: ', '')),
                    backgroundColor: const Color(0xFF7F1D1D),
                  ),
                );
              }
            }

            final items = inbox?.items ?? <MobileNotificationItem>[];
            final unread = inbox?.unreadCount ?? 0;

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              decoration: const BoxDecoration(
                color: Color(0xFF081F17),
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Container(
                      width: 42,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        const Text(
                          'Notifications',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Row(
                          children: <Widget>[
                            if (unread > 0)
                              TextButton(
                                onPressed: markAllAsRead,
                                child: const Text(
                                  'Mark all read',
                                  style: TextStyle(
                                    color: Color(0xFF4ADE80),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
                              onPressed: refreshInbox,
                              tooltip: 'Refresh',
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (loadError != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF7F1D1D).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          loadError!,
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      )
                    else if (items.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0C2B22),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: const Text(
                          'No notifications yet. You are all caught up.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: items.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = items[index];
                            return _NotificationTile(
                              title: item.title,
                              subtitle: item.message,
                              time: _relativeTime(item.createdAt),
                              sender: item.senderName,
                              priority: item.priority,
                              isUnread: !item.isRead,
                              priorityColor: _priorityColor(item.priority),
                              onTap: () => _showNotificationDetailsSheet(context, item),
                            );
                          },
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    _isSheetOpen = false;
  }

  @override
  Widget build(BuildContext context) {
    _primeUnreadCount();

    final bool useLiveCount = notificationCount < 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 14, color: Colors.white70),
            ),
          ],
        ),
        GestureDetector(
          onTap: onNotificationTap ?? () async => _showNotificationsSheet(context),
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFF0C2B22),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white12),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: <Widget>[
                const Center(
                  child: Icon(
                    Icons.notifications_none_rounded,
                    color: Color(0xFF4ADE80),
                    size: 22,
                  ),
                ),
                if (useLiveCount)
                  ValueListenableBuilder<int>(
                    valueListenable: MobileNotificationService.unreadCountNotifier,
                    builder: (context, unreadCount, child) {
                      if (unreadCount <= 0) {
                        return const SizedBox.shrink();
                      }

                      return Positioned(
                        right: -2,
                        top: -2,
                        child: Container(
                          width: 18,
                          height: 18,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A7B51),
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            unreadCount > 9 ? '9+' : '$unreadCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      );
                    },
                  )
                else if (notificationCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      width: 18,
                      height: 18,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1A7B51),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        notificationCount > 9 ? '9+' : '$notificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String time;
  final String sender;
  final String priority;
  final bool isUnread;
  final Color priorityColor;
  final VoidCallback? onTap;

  const _NotificationTile({
    required this.title,
    required this.subtitle,
    required this.time,
    required this.sender,
    required this.priority,
    required this.isUnread,
    required this.priorityColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0C2B22),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: priorityColor.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_active_outlined,
              color: priorityColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: isUnread ? FontWeight.w700 : FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isUnread)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4ADE80),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'From: $sender • ${priority.toUpperCase()}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            time,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
            ),
          ),
        ],
        ),
      ),
    );
  }
}

  class _DetailPill extends StatelessWidget {
    final String label;
    final String value;

    const _DetailPill({required this.label, required this.value});

    @override
    Widget build(BuildContext context) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF0C2B22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 11.5),
            children: <InlineSpan>[
              TextSpan(text: '$label: ', style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w600)),
              TextSpan(text: value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      );
    }
  }

  class _DetailSectionCard extends StatelessWidget {
    final String title;
    final Widget child;

    const _DetailSectionCard({required this.title, required this.child});

    @override
    Widget build(BuildContext context) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF0C2B22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      );
    }
  }

  class _DetailLine extends StatelessWidget {
    final String label;
    final String value;

    const _DetailLine({required this.label, required this.value});

    @override
    Widget build(BuildContext context) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: 12),
            children: <InlineSpan>[
              TextSpan(
                text: '$label: ',
                style: const TextStyle(color: Colors.white54, fontWeight: FontWeight.w600),
              ),
              TextSpan(
                text: value,
                style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }
  }