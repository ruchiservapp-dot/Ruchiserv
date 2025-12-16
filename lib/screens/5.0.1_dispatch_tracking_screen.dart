// lib/screens/5.0.1_dispatch_tracking_screen.dart
// GPS Tracking Screen for Admin/Staff to view driver location and share tracking link
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../services/location_service.dart';
import '../db/database_helper.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class DispatchTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> dispatch;
  const DispatchTrackingScreen({super.key, required this.dispatch});

  @override
  State<DispatchTrackingScreen> createState() => _DispatchTrackingScreenState();
}

class _DispatchTrackingScreenState extends State<DispatchTrackingScreen> {
  Map<String, dynamic>? _locationData;
  bool _isLoading = true;
  Timer? _refreshTimer;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadLocation();
    // Auto-refresh every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadLocation());
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadLocation() async {
    try {
      final dispatchId = widget.dispatch['id'] as int;
      
      // Try to get location from local DB first
      final localLocation = await LocationService.getLastLocation(dispatchId);
      
      if (localLocation != null && localLocation['driverLat'] != null) {
        setState(() {
          _locationData = localLocation;
          _isLoading = false;
          _errorMessage = null;
        });
      } else {
        // Try AWS if local is empty
        final awsLocation = await LocationService.getAwsLocation(dispatchId);
        if (awsLocation != null) {
          setState(() {
            _locationData = awsLocation;
            _isLoading = false;
            _errorMessage = null;
          });
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Location not available yet. Driver may not have started tracking.';
          });
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading location: $e';
      });
    }
  }

  String get _trackingUrl {
    final dispatchId = widget.dispatch['id'];
    return 'https://ruchiserv.in/track/$dispatchId';
  }

  Future<void> _openGoogleMaps() async {
    final lat = _locationData?['driverLat'] ?? _locationData?['lat'];
    final lng = _locationData?['driverLng'] ?? _locationData?['lng'];
    
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available'), backgroundColor: Colors.orange),
      );
      return;
    }

    // Universal Google Maps URL - works on app or web browser
    final mapUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    final uri = Uri.parse(mapUrl);
    
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open maps'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _shareTrackingLink() async {
    final customerName = widget.dispatch['customerName'] ?? 'Order';
    final message = '''🚚 Track Your Delivery

Order: $customerName
Track your order in real-time: $_trackingUrl

Powered by RuchiServ''';

    await Share.share(message, subject: 'Track Your Order - RuchiServ');
  }

  Future<void> _callDriver() async {
    final driverMobile = widget.dispatch['driverMobile']?.toString();
    if (driverMobile == null || driverMobile.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Driver mobile not available'), backgroundColor: Colors.orange),
      );
      return;
    }

    final uri = Uri.parse('tel:$driverMobile');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dispatch = widget.dispatch;
    final status = dispatch['dispatchStatus'] ?? 'DISPATCHED';
    final isDelivered = status == 'DELIVERED';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Track Dispatch'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadLocation,
            tooltip: 'Refresh Location',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadLocation,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Banner
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDelivered 
                        ? [Colors.green.shade400, Colors.green.shade600]
                        : [Colors.blue.shade400, Colors.blue.shade600],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      isDelivered ? Icons.check_circle : Icons.local_shipping,
                      color: Colors.white,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isDelivered ? 'Delivered' : 'On The Way',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            isDelivered 
                                ? 'Order has been delivered successfully'
                                : 'Order is being delivered',
                            style: const TextStyle(color: Colors.white70),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Order Info Card
              _buildCard(
                title: 'Order Details',
                icon: Icons.receipt_long,
                children: [
                  _buildInfoRow('Customer', dispatch['customerName'] ?? 'N/A'),
                  _buildInfoRow('Location', dispatch['location'] ?? 'N/A'),
                  _buildInfoRow('Date', dispatch['date'] ?? 'N/A'),
                  _buildInfoRow('Time', dispatch['time'] ?? 'N/A'),
                  _buildInfoRow('Pax', '${dispatch['totalPax'] ?? 'N/A'}'),
                ],
              ),

              const SizedBox(height: 12),

              // Driver Info Card
              _buildCard(
                title: 'Driver Details',
                icon: Icons.person,
                children: [
                  _buildInfoRow('Driver', dispatch['driverName'] ?? 'N/A'),
                  _buildInfoRow('Vehicle', '${dispatch['vehicleNo'] ?? 'N/A'} ${dispatch['vehicleType'] != null ? '[${dispatch['vehicleType']}]' : ''}'),
                  _buildInfoRow('Mobile', dispatch['driverMobile'] ?? 'N/A', isPhone: true),
                ],
              ),

              const SizedBox(height: 12),

              // GPS Location Card
              _buildCard(
                title: 'GPS Location',
                icon: Icons.location_on,
                children: [
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline, color: Colors.orange),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMessage!, style: const TextStyle(color: Colors.orange)),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _buildInfoRow(
                      'Coordinates',
                      '${_locationData?['driverLat'] ?? _locationData?['lat']}, ${_locationData?['driverLng'] ?? _locationData?['lng']}',
                    ),
                    if (_locationData?['lastLocationUpdate'] != null || _locationData?['timestamp'] != null)
                      _buildInfoRow(
                        'Last Updated',
                        _formatTimestamp(_locationData?['lastLocationUpdate'] ?? _locationData?['timestamp']),
                      ),
                  ],
                ],
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _locationData != null ? _openGoogleMaps : null,
                      icon: const Icon(Icons.map),
                      label: const Text('View on Map'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _callDriver,
                      icon: const Icon(Icons.phone),
                      label: const Text('Call Driver'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Share Tracking Link
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _shareTrackingLink,
                  icon: const Icon(Icons.share),
                  label: const Text('Share Tracking Link with Customer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Tracking Link Preview
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.link, color: Colors.indigo),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _trackingUrl,
                        style: TextStyle(
                          color: Colors.indigo.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),
              Text(
                'Auto-refreshes every 30 seconds',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(icon, color: Colors.indigo, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isPhone = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(
            child: isPhone && value != 'N/A'
                ? GestureDetector(
                    onTap: () => launchUrl(Uri.parse('tel:$value')),
                    child: Text(
                      value,
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.blue,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                : Text(value, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return 'N/A';
    try {
      final dt = DateTime.parse(timestamp);
      return DateFormat('dd MMM, hh:mm a').format(dt);
    } catch (_) {
      return timestamp;
    }
  }
}
