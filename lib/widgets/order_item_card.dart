import 'package:flutter/material.dart';
import '../models/order_item.dart';

class OrderItemCard extends StatelessWidget {
  final OrderItem item;
  final int index;
  final Function(OrderItem updatedItem)? onEdit;

  const OrderItemCard({
    super.key,
    required this.item,
    required this.index,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: item.platform == 'Meesho'
                        ? Colors.purple.shade50
                        : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: item.platform == 'Meesho'
                          ? Colors.purple.shade300
                          : Colors.blue.shade300,
                    ),
                  ),
                  child: Text(
                    item.platform,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: item.platform == 'Meesho'
                          ? Colors.purple.shade800
                          : Colors.blue.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item.orderNo,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (item.qty > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade400),
                    ),
                    child: Text(
                      "QTY: ${item.qty}",
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.red.shade900,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              item.sku,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                _buildBadge(Icons.straighten, item.size, Colors.blue.shade700),
                const SizedBox(width: 8),
                _buildBadge(Icons.palette, item.color, Colors.teal.shade700),
                const SizedBox(width: 8),
                _buildBadge(Icons.local_shipping, item.courierPartner, Colors.deepOrange.shade700),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
