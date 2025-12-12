// WIDGET: STAFF ASSIGNMENT PICKER
// Reusable widget for selecting staff to assign to orders
import 'package:flutter/material.dart';
import '../db/database_helper.dart';

class StaffAssignmentPicker extends StatefulWidget {
  final int orderId;
  final String orderDate;
  final bool readOnly;
  final Function(List<Map<String, dynamic>>)? onChanged;
  
  const StaffAssignmentPicker({
    super.key,
    required this.orderId,
    required this.orderDate,
    this.readOnly = false,
    this.onChanged,
  });

  @override
  State<StaffAssignmentPicker> createState() => _StaffAssignmentPickerState();
}

class _StaffAssignmentPickerState extends State<StaffAssignmentPicker> {
  List<Map<String, dynamic>> _allStaff = [];
  List<Map<String, dynamic>> _assignedStaff = [];
  bool _isLoading = true;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final db = DatabaseHelper();
    
    // Load all active staff
    final staff = await db.getAllStaff();
    _allStaff = staff.where((s) => s['isActive'] == 1).toList();
    
    // Load already assigned staff for this order
    if (widget.orderId > 0) {
      _assignedStaff = await db.getOrderStaffAssignments(widget.orderId);
    }
    
    setState(() => _isLoading = false);
  }

  Future<void> _assignStaff(int staffId, String staffName) async {
    // Show role selection dialog
    final role = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Assign $staffName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Select assignment role:'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                _roleChip('Head Cook', Icons.restaurant),
                _roleChip('Helper', Icons.person),
                _roleChip('Server', Icons.room_service),
                _roleChip('Driver', Icons.delivery_dining),
                _roleChip('Cleaner', Icons.cleaning_services),
                _roleChip('Supervisor', Icons.supervisor_account),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    
    if (role != null && widget.orderId > 0) {
      await DatabaseHelper().assignStaffToOrder(widget.orderId, staffId, role);
      await _loadData();
      widget.onChanged?.call(_assignedStaff);
    }
  }

  Widget _roleChip(String role, IconData icon) {
    return ActionChip(
      avatar: Icon(icon, size: 18),
      label: Text(role),
      onPressed: () => Navigator.pop(context, role),
    );
  }

  Future<void> _removeAssignment(int assignmentId) async {
    await DatabaseHelper().removeStaffAssignment(assignmentId);
    await _loadData();
    widget.onChanged?.call(_assignedStaff);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Card(
      margin: const EdgeInsets.all(8),
      child: Column(
        children: [
          // Header
          ListTile(
            leading: const Icon(Icons.people),
            title: Text('Staff Assigned (${_assignedStaff.length})'),
            trailing: widget.readOnly 
                ? null 
                : IconButton(
                    icon: Icon(_isExpanded ? Icons.expand_less : Icons.expand_more),
                    onPressed: () => setState(() => _isExpanded = !_isExpanded),
                  ),
            onTap: widget.readOnly ? null : () => setState(() => _isExpanded = !_isExpanded),
          ),
          
          // Assigned Staff List
          if (_assignedStaff.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _assignedStaff.map((assignment) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: _getRoleColor(assignment['role']),
                      child: Text(
                        (assignment['name'] ?? 'S')[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                    ),
                    label: Text('${assignment['name']} (${assignment['role']})'),
                    deleteIcon: widget.readOnly ? null : const Icon(Icons.close, size: 18),
                    onDeleted: widget.readOnly ? null : () => _removeAssignment(assignment['id']),
                  );
                }).toList(),
              ),
            ),
          
          // Staff Picker (Expanded)
          if (_isExpanded && !widget.readOnly)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _allStaff.length,
                itemBuilder: (context, index) {
                  final staff = _allStaff[index];
                  final isAssigned = _assignedStaff.any((a) => a['staffId'] == staff['id']);
                  
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isAssigned ? Colors.green : Colors.grey.shade300,
                      child: Icon(
                        isAssigned ? Icons.check : Icons.person,
                        color: Colors.white,
                      ),
                    ),
                    title: Text(staff['name'] ?? 'Unknown'),
                    subtitle: Text(staff['role'] ?? 'Staff'),
                    trailing: isAssigned
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : TextButton(
                            onPressed: () => _assignStaff(staff['id'], staff['name'] ?? 'Staff'),
                            child: const Text('Assign'),
                          ),
                    enabled: !isAssigned,
                  );
                },
              ),
            ),
          
          // Empty state
          if (_assignedStaff.isEmpty && !_isExpanded)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                widget.readOnly ? 'No staff assigned' : 'Tap to assign staff',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'Head Cook': return Colors.orange;
      case 'Helper': return Colors.blue;
      case 'Server': return Colors.purple;
      case 'Driver': return Colors.green;
      case 'Cleaner': return Colors.teal;
      case 'Supervisor': return Colors.red;
      default: return Colors.grey;
    }
  }
}
