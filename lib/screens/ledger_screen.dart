import 'package:ruchiserv/repositories/finance_repository.dart';
import 'package:ruchiserv/repositories/operation_repository.dart';
import 'package:ruchiserv/repositories/order_repository.dart';
import 'package:flutter/material.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/seed_ledger_data.dart';
import 'ledger_detail_screen.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _firmId = 'DEFAULT';
  bool _isLoadingFirm = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _loadFirmId();
  }

  Future<void> _loadFirmId() async {
    final sp = await SharedPreferences.getInstance();
    setState(() {
      _firmId = sp.getString('last_firm') ?? 'DEFAULT';
      _isLoadingFirm = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingFirm) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context).ledgers),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Seed Test Data',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Seeding data...")));
              await LedgerSeeder.seedData();
              setState(() {}); // Trigger rebuild to refresh lists
              if (!mounted) return;
              ScaffoldMessenger.of(context)
                  .showSnackBar(const SnackBar(content: Text("Data seeded!")));
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(100),
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search ledger...',
                    prefixIcon: const Icon(Icons.search, color: Colors.white70),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.1),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    hintStyle: const TextStyle(color: Colors.white70),
                  ),
                  style: const TextStyle(color: Colors.white),
                  onChanged: (val) {
                    setState(() {
                      _searchQuery = val;
                    });
                  },
                ),
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                indicatorColor: Colors.white,
                tabs: [
                  Tab(text: AppLocalizations.of(context).suppliers),
                  Tab(text: AppLocalizations.of(context).subcontractors),
                  Tab(text: AppLocalizations.of(context).staff),
                  Tab(text: AppLocalizations.of(context).customers),
                  const Tab(text: 'Drivers'),
                ],
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEntityList('Supplier'),
          _buildEntityList('Subcontractor'),
          _buildEntityList('Staff'),
          _buildEntityList('Customer'),
          _buildEntityList('Driver'),
        ],
      ),
    );
  }

  Widget _buildEntityList(String type) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchData(type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        var list = snapshot.data ?? [];

        // Apply Search Filtering
        if (_searchQuery.isNotEmpty) {
          list = list.where((item) {
            final name = (item['name'] ?? '').toString().toLowerCase();
            final mobile = (item['mobile'] ?? '').toString().toLowerCase();
            return name.contains(_searchQuery.toLowerCase()) ||
                mobile.contains(_searchQuery.toLowerCase());
          }).toList();
        }

        if (list.isEmpty) {
          return Center(
              child: Text(_searchQuery.isEmpty
                  ? "No ${type}s found"
                  : "No matches found"));
        }

        return Column(
          children: [
            // Summary Bar for the category
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              color: Colors.grey.shade50,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Total Balance',
                          style: TextStyle(
                              fontSize: 10, color: Colors.grey.shade600)),
                      Text('Calculated in details',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.indigo.shade800)),
                    ],
                  ),
                  // We could potentially sum up balances here if we added a balance column to the query
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                itemCount: list.length,
                separatorBuilder: (ctx, i) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = list[index];
                  final name = item['name'] ?? 'Unknown';
                  final contact =
                      item['mobile'] ?? item['phone'] ?? item['email'] ?? '';
                  final id = item['id'];

                  return ListTile(
                    leading: CircleAvatar(
                        child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?')),
                    title: Text(name),
                    subtitle: contact.isNotEmpty ? Text(contact) : null,
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LedgerDetailScreen(
                            entityName: name,
                            entityType: type
                                .toUpperCase(), // Ensure uppercase for DB matching
                            entityId: id,
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchData(String type) async {
    if (type == 'Supplier') {
      return await FinanceRepository().getAllSuppliers(_firmId);
    } else if (type == 'Subcontractor') {
      return await FinanceRepository().getAllSubcontractors(_firmId);
    } else if (type == 'Staff') {
      return await OperationRepository().getAllStaff();
    } else if (type == 'Customer') {
      return await OrderRepository().getAllCustomers(_firmId);
    } else if (type == 'Driver') {
      return await OperationRepository().getDrivers(_firmId);
    }
    return [];
  }
}
