import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/app_settings.dart';
import 'billing_screen.dart';
import 'products_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppSettings settings;
  final VoidCallback onSettingsChanged;

  const HomeScreen({
    super.key,
    required this.settings,
    required this.onSettingsChanged,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double _todaySales = 0;
  int _todayBillCount = 0;
  int _totalProducts = 0;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() => _loading = true);
    final db = DatabaseService.instance;
    final results = await Future.wait([
      db.getTodaySalesTotal(),
      db.getTodayBillCount(),
      db.getProductCount(),
    ]);
    setState(() {
      _todaySales = results[0] as double;
      _todayBillCount = results[1] as int;
      _totalProducts = results[2] as int;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.settings.currency;
    final today = DateFormat('EEEE, d MMMM yyyy').format(DateTime.now());

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Shop header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1B5E20), Color(0xFF2E7D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.settings.shopName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.settings.shopAddress,
                    style: TextStyle(color: Colors.green[100], fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    today,
                    style: TextStyle(color: Colors.green[200], fontSize: 12),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Today's Sales — BIG card (the hero)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'আজকের বিক্রি',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            "Today's Sales",
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                        ],
                      ),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.trending_up,
                            color: Color(0xFF2E7D32), size: 26),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_loading)
                    const CircularProgressIndicator(color: Color(0xFF2E7D32))
                  else
                    Text(
                      '$currency${_todaySales.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontSize: 42,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1B5E20),
                        letterSpacing: -1,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _miniStat('${_todayBillCount}টি বিল', 'আজ'),
                      Container(width: 1, height: 30, color: Colors.grey[200]),
                      _miniStat('${_totalProducts}টি পণ্য', 'মোট'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Quick Actions
            Text(
              'দ্রুত কাজ',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    context,
                    icon: Icons.receipt_long,
                    label: 'নতুন বিল',
                    sublabel: 'Start Billing',
                    color: const Color(0xFF2E7D32),
                    textColor: Colors.white,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => BillingScreen(settings: widget.settings),
                        ),
                      );
                      _loadStats();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionButton(
                    context,
                    icon: Icons.inventory_2_outlined,
                    label: 'পণ্য',
                    sublabel: 'Manage Products',
                    color: Colors.white,
                    textColor: Colors.grey[800]!,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ProductsScreen(),
                        ),
                      );
                      _loadStats();
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            _actionButton(
              context,
              icon: Icons.settings_outlined,
              label: 'সেটিংস',
              sublabel: 'Shop Info & PDF Taglines',
              color: Colors.white,
              textColor: Colors.grey[800]!,
              onTap: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SettingsScreen(
                      settings: widget.settings,
                      onSaved: widget.onSettingsChanged,
                    ),
                  ),
                );
              },
              fullWidth: true,
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(String value, String label) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2E7D32))),
          Text(label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      );

  Widget _actionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String sublabel,
    required Color color,
    required Color textColor,
    required VoidCallback onTap,
    bool fullWidth = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(18),
          border: color == Colors.white
              ? Border.all(color: Colors.grey.shade200)
              : null,
          boxShadow: color != Colors.white
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color == Colors.white
                    ? const Color(0xFFE8F5E9)
                    : Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: color == Colors.white
                      ? const Color(0xFF2E7D32)
                      : Colors.white,
                  size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 14)),
                  Text(sublabel,
                      style: TextStyle(
                          color: textColor.withOpacity(0.6),
                          fontSize: 11)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios,
                color: textColor.withOpacity(0.4), size: 14),
          ],
        ),
      ),
    );
  }
}
