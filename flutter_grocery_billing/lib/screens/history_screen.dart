import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/bill.dart';
import '../models/app_settings.dart';
import '../services/database_service.dart';
import '../services/pdf_service.dart';

class HistoryScreen extends StatefulWidget {
  final AppSettings settings;
  const HistoryScreen({super.key, required this.settings});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Bill> _bills = [];
  bool _loading = true;
  int? _expandedId;
  int? _generatingPdfId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final bills = await DatabaseService.instance.getAllBills();
    setState(() {
      _bills = bills;
      _loading = false;
    });
  }

  Future<void> _handlePdf(Bill bill, String action) async {
    setState(() => _generatingPdfId = bill.id);
    try {
      final bytes = await PdfService.generateBillPdf(bill, widget.settings);
      if (action == 'share') {
        await PdfService.sharePdf(
            bytes, bill.billNumber, widget.settings.shopName);
      } else {
        await PdfService.printPdf(bytes);
      }
    } finally {
      if (mounted) setState(() => _generatingPdfId = null);
    }
  }

  Future<void> _deleteBill(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('বিল মুছবেন?'),
        content: const Text('এই বিল স্থায়ীভাবে মুছে যাবে।'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('বাতিল')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child:
                  const Text('মুছুন', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await DatabaseService.instance.deleteBill(id);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currency;

    return RefreshIndicator(
      onRefresh: _load,
      child: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF2E7D32)))
          : _bills.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long,
                          size: 64, color: Colors.grey[300]),
                      const SizedBox(height: 12),
                      Text('কোনো বিল নেই',
                          style: TextStyle(
                              color: Colors.grey[400], fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _bills.length,
                  itemBuilder: (_, i) {
                    final bill = _bills[i];
                    final isExpanded = _expandedId == bill.id;
                    final dateStr = DateFormat('dd MMM yyyy, hh:mm a')
                        .format(bill.createdAt);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                      color: Colors.white,
                      child: Column(
                        children: [
                          // Header row
                          ListTile(
                            onTap: () => setState(() {
                              _expandedId =
                                  isExpanded ? null : bill.id;
                            }),
                            leading: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.receipt,
                                  color: Color(0xFF2E7D32), size: 22),
                            ),
                            title: Row(
                              children: [
                                Text(bill.billNumber,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F8F1),
                                    borderRadius:
                                        BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    bill.paymentMode.label.split('/').first.trim(),
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF2E7D32)),
                                  ),
                                ),
                              ],
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(dateStr,
                                    style: TextStyle(
                                        color: Colors.grey[500],
                                        fontSize: 11)),
                                if (bill.customerName != null)
                                  Text(bill.customerName!,
                                      style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 11)),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  '$currency${bill.total.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: Color(0xFF2E7D32),
                                  ),
                                ),
                                Text('${bill.items.length}টি পণ্য',
                                    style: TextStyle(
                                        color: Colors.grey[400],
                                        fontSize: 11)),
                                Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: Colors.grey[400],
                                  size: 18,
                                ),
                              ],
                            ),
                          ),

                          // Expanded content
                          if (isExpanded) ...[
                            const Divider(height: 1),
                            // Items
                            Padding(
                              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                              child: Column(
                                children: bill.items
                                    .map((item) => Padding(
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 3),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  '${item.nameBn ?? item.name} × ${item.quantity} ${item.unit}',
                                                  style: const TextStyle(
                                                      fontSize: 12),
                                                ),
                                              ),
                                              Text(
                                                '$currency${item.total.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                        ))
                                    .toList(),
                              ),
                            ),

                            // Summary
                            Container(
                              margin: const EdgeInsets.symmetric(horizontal: 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF5F5F5),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                children: [
                                  if (bill.discount > 0)
                                    _row('Discount',
                                        '-$currency${bill.discount.toStringAsFixed(2)}'),
                                  if (bill.tax > 0)
                                    _row('Tax',
                                        '$currency${bill.tax.toStringAsFixed(2)}'),
                                  _row(
                                    'Total',
                                    '$currency${bill.total.toStringAsFixed(2)}',
                                    bold: true,
                                  ),
                                ],
                              ),
                            ),

                            // Action buttons
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _generatingPdfId == bill.id
                                          ? null
                                          : () => _handlePdf(bill, 'share'),
                                      icon: const Icon(Icons.share, size: 16),
                                      label: const Text('শেয়ার'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            const Color(0xFF2E7D32),
                                        side: const BorderSide(
                                            color: Color(0xFF2E7D32)),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: _generatingPdfId == bill.id
                                          ? null
                                          : () => _handlePdf(bill, 'print'),
                                      icon: const Icon(
                                          Icons.picture_as_pdf, size: 16),
                                      label: const Text('PDF'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.blue,
                                        side: const BorderSide(color: Colors.blue),
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton(
                                    onPressed: () => _deleteBill(bill.id!),
                                    icon: const Icon(Icons.delete_outline,
                                        color: Colors.red, size: 20),
                                    style: IconButton.styleFrom(
                                      backgroundColor:
                                          Colors.red.withOpacity(0.1),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight:
                        bold ? FontWeight.bold : FontWeight.normal)),
            Text(value,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    color: bold ? const Color(0xFF2E7D32) : null)),
          ],
        ),
      );
}
