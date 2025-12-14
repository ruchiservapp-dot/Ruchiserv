// MODULE: INVENTORY HUB
// Last Updated: 2025-12-14 | Features: Navigation tiles for Inventory sub-modules (6 modules)
import 'package:flutter/material.dart';
import '4.1_ingredients_screen.dart';
import '4.2_bom_screen.dart';
import '4.0_mrp_hub_screen.dart';
import '4.6_supplier_screen.dart';
import '4.7_subcontractor_screen.dart';
import '3.4_utensils_screen.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate tile height based on available space
          final availableHeight = constraints.maxHeight - 48; // minus padding
          final tileHeight = (availableHeight / 3) - 8; // 3 rows with spacing
          
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Row 1: Ingredients & BOM
                SizedBox(
                  height: tileHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTile(
                          context,
                          title: AppLocalizations.of(context)!.ingredients,
                          subtitle: AppLocalizations.of(context)!.masterList,
                          icon: Icons.restaurant_menu,
                          color: Colors.green,
                          onTap: () => Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(builder: (_) => const IngredientsScreen(), fullscreenDialog: true),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTile(
                          context,
                          title: AppLocalizations.of(context)!.bom,
                          subtitle: AppLocalizations.of(context)!.recipeMapping,
                          icon: Icons.receipt_long,
                          color: Colors.blue,
                          onTap: () => Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(builder: (_) => const BomScreen(), fullscreenDialog: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Row 2: MRP Planning (Hub) & Suppliers
                SizedBox(
                  height: tileHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTile(
                          context,
                          title: 'MRP Planning',
                          subtitle: 'Run, Output, Allotment, POs',
                          icon: Icons.analytics,
                          color: Colors.orange,
                          onTap: () => Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(builder: (_) => const MrpHubScreen(), fullscreenDialog: true),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTile(
                          context,
                          title: AppLocalizations.of(context)!.suppliers,
                          subtitle: AppLocalizations.of(context)!.vendors,
                          icon: Icons.local_shipping,
                          color: Colors.teal,
                          onTap: () => Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(builder: (_) => const SupplierScreen(), fullscreenDialog: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                
                // Row 3: Subcontractors & Utensils
                SizedBox(
                  height: tileHeight,
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildTile(
                          context,
                          title: AppLocalizations.of(context)!.subcontractors,
                          subtitle: AppLocalizations.of(context)!.kitchens,
                          icon: Icons.handshake,
                          color: Colors.indigo,
                          onTap: () => Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(builder: (_) => const SubcontractorScreen(), fullscreenDialog: true),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildTile(
                          context,
                          title: AppLocalizations.of(context)!.utensils,
                          subtitle: AppLocalizations.of(context)!.utensilMaster,
                          icon: Icons.inventory_2,
                          color: Colors.purple,
                          onTap: () => Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(builder: (_) => const UtensilsScreen(), fullscreenDialog: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTile(
    BuildContext context, {
    required String title,
    String? subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      elevation: 2,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 24, color: color),
              ),
              const SizedBox(height: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
                textAlign: TextAlign.center,
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
