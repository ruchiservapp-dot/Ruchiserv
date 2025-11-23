import 'package:flutter/material.dart';
import '2.0_orders_calendar_screen.dart';
import '3.0_operations_screen.dart';
import '4.0_inventory_screen.dart';
import '5.0_reports_screen.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _menuItems = [
    {'icon': Icons.receipt_long, 'label': 'Orders'},
    {'icon': Icons.settings_suggest, 'label': 'Operations'},
    {'icon': Icons.inventory_2, 'label': 'Inventory'},
    {'icon': Icons.bar_chart_rounded, 'label': 'Reports'},
  ];

  final List<Widget> _screens = const [
    OrderCalendarScreen(),
    OperationsScreen(),
    InventoryScreen(),
    ReportsScreen(),
  ];

  void _onMenuTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          "RuchiServ",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onSelected: (value) {
              if (value == 'Settings') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Settings - Coming Soon')),
                );
              } else if (value == 'Logout') {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Logout - Coming Soon')),
                );
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'Settings', child: Text('Settings')),
              const PopupMenuItem(value: 'Logout', child: Text('Logout')),
            ],
          ),
        ],
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        child: _screens[_selectedIndex],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(_menuItems.length, (index) {
            final isSelected = _selectedIndex == index;
            final item = _menuItems[index];
            return GestureDetector(
              onTap: () => _onMenuTap(index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue.shade50
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      item['icon'],
                      color: isSelected
                          ? Colors.blue.shade800
                          : Colors.grey.shade600,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item['label'],
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected
                            ? Colors.blue.shade800
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
