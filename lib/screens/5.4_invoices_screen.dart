// MODULE: INVOICES SCREEN
// Last Updated: 2025-12-17 | Features: Invoice list, status filter, auto-generate from orders, PDF export
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../services/invoice_pdf_service.dart';

class InvoicesScreen extends StatefulWidget {
  const InvoicesScreen({super.key});

  @override
  State<InvoicesScreen> createState() => _InvoicesScreenState();
}

class _InvoicesScreenState extends State<InvoicesScreen> {
  List<Map<String, dynamic>> _invoices = [];
  bool _isLoading = true;
  String _firmId = 'DEFAULT';
  String _filterStatus = 'All'; // All, UNPAID, PARTIAL, PAID

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    _firmId = prefs.getString('last_firm') ?? 'DEFAULT';
    
    final invoices = await DatabaseHelper().getInvoices(
      _firmId,
      status: _filterStatus == 'All' ? null : _filterStatus,
    );
    
    setState(() {
      _invoices = invoices;
      _isLoading = false;
    });
  }

  Color _getStatusColor(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return Colors.green;
      case 'PARTIAL':
        return Colors.orange;
      case 'UNPAID':
        return Colors.red;
      case 'DRAFT':
        return Colors.grey;
      case 'CANCELLED':
        return Colors.grey.shade600;
      default:
        return Colors.blue;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toUpperCase()) {
      case 'PAID':
        return Icons.check_circle;
      case 'PARTIAL':
        return Icons.timelapse;
      case 'UNPAID':
        return Icons.warning;
      case 'DRAFT':
        return Icons.edit;
      default:
        return Icons.receipt;
    }
  }

  Future<void> _viewInvoice(Map<String, dynamic> invoice) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _InvoiceDetailSheet(
        invoice: invoice,
        onPaymentRecorded: _loadData,
      ),
    );
  }

  Future<void> _createInvoiceFromOrder() async {
    // Show order picker dialog
    final orders = await DatabaseHelper().getOrdersByDate(
      DateTime.now().toIso8601String().substring(0, 10),
    );
    
    if (!mounted) return;
    
    if (orders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No orders available for invoicing')),
      );
      return;
    }

    final selectedOrder = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Select Order'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: orders.length,
            itemBuilder: (context, index) {
              final order = orders[index];
              return ListTile(
                title: Text(order['customerName'] ?? 'Customer'),
                subtitle: Text('Pax: ${order['totalPax']} | ₹${order['grandTotal'] ?? order['totalAmount'] ?? 0}'),
                trailing: Text('#${order['id']}'),
                onTap: () => Navigator.pop(context, order),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (selectedOrder == null) return;

    // Check if invoice already exists for this order
    final existingInvoices = await DatabaseHelper().getInvoices(_firmId);
    final hasInvoice = existingInvoices.any((inv) => inv['orderId'] == selectedOrder['id']);
    
    if (hasInvoice) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice already exists for this order')),
      );
      return;
    }

    // Create invoice
    try {
      await DatabaseHelper().createInvoiceFromOrder(selectedOrder['id'], _firmId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invoice created successfully!')),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              setState(() => _filterStatus = value);
              _loadData();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All')),
              const PopupMenuItem(value: 'UNPAID', child: Text('Unpaid')),
              const PopupMenuItem(value: 'PARTIAL', child: Text('Partial')),
              const PopupMenuItem(value: 'PAID', child: Text('Paid')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createInvoiceFromOrder,
        icon: const Icon(Icons.add),
        label: const Text('From Order'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.receipt_long, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'No invoices found',
                        style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        onPressed: _createInvoiceFromOrder,
                        icon: const Icon(Icons.add),
                        label: const Text('Create from Order'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _invoices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final invoice = _invoices[index];
                      final status = invoice['status'] ?? 'UNPAID';
                      final totalAmount = (invoice['totalAmount'] as num?)?.toDouble() ?? 0;
                      final balanceDue = (invoice['balanceDue'] as num?)?.toDouble() ?? totalAmount;
                      
                      return Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          onTap: () => _viewInvoice(invoice),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Header
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        invoice['invoiceNumber'] ?? 'INV-0000',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(_getStatusIcon(status), size: 14, color: _getStatusColor(status)),
                                          const SizedBox(width: 4),
                                          Text(
                                            status,
                                            style: TextStyle(
                                              color: _getStatusColor(status),
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                
                                // Customer
                                Text(
                                  invoice['customerName'] ?? 'Customer',
                                  style: TextStyle(color: Colors.grey.shade700),
                                ),
                                const SizedBox(height: 4),
                                
                                // Date and Due
                                Row(
                                  children: [
                                    Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      invoice['invoiceDate'] ?? '',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                    const SizedBox(width: 16),
                                    if (invoice['dueDate'] != null) ...[
                                      Icon(Icons.schedule, size: 14, color: Colors.grey.shade500),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Due: ${invoice['dueDate']}',
                                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                                      ),
                                    ],
                                  ],
                                ),
                                
                                const Divider(height: 24),
                                
                                // Amounts
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Total', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                                        Text(
                                          '₹${totalAmount.toStringAsFixed(2)}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                      ],
                                    ),
                                    if (balanceDue > 0)
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text('Balance Due', style: TextStyle(color: Colors.red.shade400, fontSize: 12)),
                                          Text(
                                            '₹${balanceDue.toStringAsFixed(2)}',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.red.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

// Invoice Detail Bottom Sheet
class _InvoiceDetailSheet extends StatefulWidget {
  final Map<String, dynamic> invoice;
  final VoidCallback onPaymentRecorded;

  const _InvoiceDetailSheet({required this.invoice, required this.onPaymentRecorded});

  @override
  State<_InvoiceDetailSheet> createState() => _InvoiceDetailSheetState();
}

class _InvoiceDetailSheetState extends State<_InvoiceDetailSheet> {
  Map<String, dynamic>? _fullInvoice;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoiceDetails();
  }

  Future<void> _loadInvoiceDetails() async {
    final invoice = await DatabaseHelper().getInvoiceWithItems(widget.invoice['id']);
    setState(() {
      _fullInvoice = invoice;
      _isLoading = false;
    });
  }

  Future<void> _recordPayment() async {
    final balanceDue = (_fullInvoice?['balanceDue'] as num?)?.toDouble() ?? 0;
    if (balanceDue <= 0) return;

    final amountController = TextEditingController(text: balanceDue.toStringAsFixed(2));
    String paymentMode = 'UPI';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Record Payment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: paymentMode,
              decoration: const InputDecoration(labelText: 'Payment Mode'),
              items: ['Cash', 'UPI', 'Bank Transfer', 'Cheque']
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (v) => paymentMode = v ?? 'UPI',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Record'),
          ),
        ],
      ),
    );

    if (result != true) return;

    final amount = double.tryParse(amountController.text) ?? 0;
    if (amount <= 0) return;

    await DatabaseHelper().recordInvoicePayment(
      widget.invoice['id'],
      amount,
      paymentMode,
    );

    if (mounted) {
      Navigator.pop(context);
      widget.onPaymentRecorded();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payment recorded!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
    }

    final inv = _fullInvoice ?? widget.invoice;
    final items = (inv['items'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final status = inv['status'] ?? 'UNPAID';
    final balanceDue = (inv['balanceDue'] as num?)?.toDouble() ?? 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            
            // Header
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        inv['invoiceNumber'] ?? 'Invoice',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      Text(inv['customerName'] ?? 'Customer'),
                    ],
                  ),
                ),
              Chip(
                  label: Text(status),
                  backgroundColor: status == 'PAID' ? Colors.green.shade100 : Colors.orange.shade100,
                ),
              ],
            ),
            
            // PDF/Share Actions
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final success = await InvoicePdfService.previewInvoice(widget.invoice['id']);
                      if (!success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to generate PDF')),
                        );
                      }
                    },
                    icon: const Icon(Icons.picture_as_pdf, size: 18),
                    label: const Text('Preview PDF'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final file = await InvoicePdfService.shareInvoice(widget.invoice['id']);
                      if (file == null && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Failed to share invoice')),
                        );
                      }
                    },
                    icon: const Icon(Icons.share, size: 18),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            
            const Divider(height: 32),
            
            // Invoice Items
            Expanded(
              child: ListView(
                controller: scrollController,
                children: [
                  // Summary
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          _buildRow('Subtotal', inv['subtotal']),
                          _buildRow('CGST', inv['cgst']),
                          _buildRow('SGST', inv['sgst']),
                          const Divider(),
                          _buildRow('Total', inv['totalAmount'], isBold: true),
                          _buildRow('Paid', inv['amountPaid'], color: Colors.green),
                          _buildRow('Balance', inv['balanceDue'], color: Colors.red, isBold: true),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Line Items
                  if (items.isNotEmpty) ...[
                    const Text('Items', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    ...items.map((item) => Card(
                      child: ListTile(
                        title: Text(item['description'] ?? 'Item'),
                        subtitle: Text('${item['quantity']} x ₹${item['rate']}'),
                        trailing: Text('₹${item['totalAmount']?.toStringAsFixed(2) ?? '0.00'}'),
                      ),
                    )),
                  ],
                ],
              ),
            ),
            
            // Actions
            if (balanceDue > 0)
              SafeArea(
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _recordPayment,
                        icon: const Icon(Icons.payment),
                        label: Text('Record Payment (₹${balanceDue.toStringAsFixed(0)})'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, dynamic value, {bool isBold = false, Color? color}) {
    final amount = (value as num?)?.toDouble() ?? 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)),
          Text(
            '₹${amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
