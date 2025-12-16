import 'package:flutter/material.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../db/seed_ledger_data.dart';
import 'ledger_detail_screen.dart';

class LedgerScreen extends StatefulWidget {
  const LedgerScreen({super.key});

  @override
  State<LedgerScreen> createState() => _LedgerScreenState();
}

class _LedgerScreenState extends State<LedgerScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _firmId = 'DEFAULT';
  bool _isLoadingFirm = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingFirm) {
       return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.ledgers),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Seed Test Data',
            onPressed: () async {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Seeding data...")));
              await LedgerSeeder.seedData();
              setState(() {}); // Trigger rebuild to refresh lists
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Data seeded!")));
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          tabs: [
            Tab(text: AppLocalizations.of(context)!.suppliers),
            Tab(text: AppLocalizations.of(context)!.staff),
            Tab(text: AppLocalizations.of(context)!.customers),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildEntityList('Supplier'),
          _buildEntityList('Staff'),
          _buildEntityList('Customer'),
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
        
        final list = snapshot.data ?? [];
        if (list.isEmpty) {
           // Allow adding new entity if list is empty? Maybe later.
          return Center(child: Text("No ${type}s found"));
        }

        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (ctx, i) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final item = list[index];
            final name = item['name'] ?? 'Unknown';
            final contact = item['mobile'] ?? item['phone'] ?? item['email'] ?? '';
            final id = item['id'];

            return ListTile(
              leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?')),
              title: Text(name),
              subtitle: contact.isNotEmpty ? Text(contact) : null,
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                 await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LedgerDetailScreen(
                      entityName: name,
                      entityType: type.toUpperCase(), // Ensure uppercase for DB matching
                      entityId: id,
                    ),
                  ),
                );
                // Refresh list on return? Not expected to change list, but maybe balance if we showed it.
              },
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchData(String type) async {
    final db = DatabaseHelper();
    if (type == 'Supplier') {
      return await db.getAllSuppliers(_firmId);
    } else if (type == 'Staff') {
      return await db.getAllStaff();
    } else if (type == 'Customer') {
      return await db.getAllCustomers(_firmId);
    }
    return [];
  }
}
