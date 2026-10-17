import 'package:flutter/material.dart';
import '../models/renewal_model.dart';
import '../core/constants/app_colors.dart';
import '../core/utils/currency_formatter.dart';

class RenewalCard extends StatelessWidget {
  final RenewalModel renewal;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleRenewed;

  const RenewalCard({
    super.key,
    required this.renewal,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleRenewed,
  });

  @override
  Widget build(BuildContext context) {
    final catColor = RenewalModel.getCategoryColor(renewal.category);
    final isExpired = renewal.daysRemaining < 0;
    final isExpiringSoon = renewal.daysRemaining >= 0 && renewal.daysRemaining <= 5;

    Color badgeColor;
    String badgeText;
    if (renewal.isRenewed) {
      badgeColor = AppColors.success;
      badgeText = '✓ Renewed';
    } else if (isExpired) {
      badgeColor = AppColors.error;
      badgeText = 'Expired (${renewal.daysRemaining.abs()}d ago)';
    } else if (isExpiringSoon) {
      badgeColor = Colors.deepOrange;
      badgeText = renewal.daysRemaining == 0
          ? 'Expires Today!'
          : '⚡ ${renewal.daysRemaining} days left';
    } else {
      badgeColor = AppColors.primary;
      badgeText = '${renewal.daysRemaining} days left';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Category Icon + Title + Menu
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: catColor.withAlpha(35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    RenewalModel.getCategoryIcon(renewal.category),
                    color: catColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        renewal.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: renewal.isRenewed ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: catColor.withAlpha(20),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              renewal.category,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: catColor),
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (renewal.amount != null)
                            Text(
                              CurrencyFormatter.format(renewal.amount!, currency: 'INR'),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, size: 20, color: Colors.grey),
                  onSelected: (val) {
                    if (val == 'edit') onEdit();
                    if (val == 'delete') onDelete();
                    if (val == 'renew') onToggleRenewed();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'renew',
                      child: Row(
                        children: [
                          Icon(
                            renewal.isRenewed ? Icons.undo_rounded : Icons.check_circle_outline,
                            size: 18,
                            color: AppColors.success,
                          ),
                          const SizedBox(width: 8),
                          Text(renewal.isRenewed ? 'Mark as Pending' : 'Mark as Renewed'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: AppColors.error)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Expiry Date & Days Remaining Badge Row
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white.withAlpha(10)
                    : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.event_outlined, size: 16, color: Colors.grey),
                      const SizedBox(width: 6),
                      Text(
                        'Expiry: ${renewal.expiryDate}',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: badgeColor.withAlpha(25),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: badgeColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Optional Purchase Date / Notes / Alert info
            if (renewal.purchaseDate != null || (renewal.notes != null && renewal.notes!.isNotEmpty))
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Row(
                  children: [
                    if (renewal.purchaseDate != null)
                      Text(
                        'Purchased: ${renewal.purchaseDate}',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                      ),
                    if (renewal.purchaseDate != null && renewal.notes != null)
                      const Text(' • ', style: TextStyle(color: Colors.grey)),
                    if (renewal.notes != null && renewal.notes!.isNotEmpty)
                      Expanded(
                        child: Text(
                          renewal.notes!,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),

            // Alert Notification Badge (5, 3, 1 days)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Row(
                children: [
                  const Icon(Icons.notifications_active_outlined, size: 13, color: Colors.deepOrange),
                  const SizedBox(width: 4),
                  Text(
                    'Alerts scheduled: ${renewal.remindBeforeDays} days before',
                    style: const TextStyle(fontSize: 11, color: Colors.deepOrange, fontWeight: FontWeight.w500),
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

