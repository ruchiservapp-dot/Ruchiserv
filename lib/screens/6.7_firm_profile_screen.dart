import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../services/geo_fence_service.dart';

class FirmProfileScreen extends StatefulWidget {
  const FirmProfileScreen({super.key});

  @override
  State<FirmProfileScreen> createState() => _FirmProfileScreenState();
}

class _FirmProfileScreenState extends State<FirmProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _nameController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _capacityController = TextEditingController(text: '500');
  final _addressController = TextEditingController();
  final _gstController = TextEditingController();
  final _websiteController = TextEditingController();
  final _otMultiplierController = TextEditingController(text: '1.5');
  final _clientUpiIdController = TextEditingController(); // UPI Subscription
  
  bool _isLoading = true;
  bool _isSaving = false;
  String? _firmId;
  
  // GPS Kitchen Location
  double? _kitchenLatitude;
  double? _kitchenLongitude;
  int _geoFenceRadius = 100; // meters
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _contactPersonController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _capacityController.dispose();
    _addressController.dispose();
    _gstController.dispose();
    _websiteController.dispose();
    _otMultiplierController.dispose();
    _clientUpiIdController.dispose();
    super.dispose();
  }


  Future<void> _loadData() async {
    final sp = await SharedPreferences.getInstance();
    final fid = sp.getString('last_firm');
    
    if (fid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No firm ID found. Please login again.')),
        );
        Navigator.pop(context);
      }
      return;
    }
    
    _firmId = fid;
    final data = await DatabaseHelper().getFirmDetails(fid);
    
    if (mounted) {
      if (data != null) {
        _nameController.text = data['firmName']?.toString() ?? '';
        _contactPersonController.text = data['contactPerson']?.toString() ?? '';
        _mobileController.text = data['primaryMobile']?.toString() ?? '';
        _emailController.text = data['primaryEmail']?.toString() ?? ''; // Usually email
        
        // New columns
        _capacityController.text = (data['capacity'] ?? 500).toString();
        _addressController.text = data['address']?.toString() ?? '';
        // ownerName -> contactPerson? Or separate? 
        // User asked for "all feild required to store for sjolf be ther iclsinf capapcuty"
        // I'll map 'ownerName' to 'Contact Person' or separate field?
        // Schema has 'contactPerson' (old) and 'ownerName' (new).
        // I'll show both or one? contactPerson is usually manager. Owner is owner.
        // I'll show Owner separately if needed. Or just reuse contactPerson for Owner.
        // I'll stick to 'contactPerson' as Owner for now or just add Owner field.
        // Let's add Owner Name field mapped to 'ownerName'.
        final owner = data['ownerName']?.toString() ?? '';
        if (owner.isNotEmpty) {
           // If ownerName exists, use it.
           // What about contactPerson?
        }
        
        _gstController.text = data['gstNumber']?.toString() ?? '';
        _websiteController.text = data['website']?.toString() ?? '';
        
        // GPS Kitchen Location
        if (data['kitchenLatitude'] != null) {
          _kitchenLatitude = (data['kitchenLatitude'] as num).toDouble();
        }
        if (data['kitchenLongitude'] != null) {
          _kitchenLongitude = (data['kitchenLongitude'] as num).toDouble();
        }
        _geoFenceRadius = (data['geoFenceRadius'] as int?) ?? 100;
        _otMultiplierController.text = ((data['otMultiplier'] as num?) ?? 1.5).toString();
        
        // UPI Subscription
        _clientUpiIdController.text = data['client_upi_id']?.toString() ?? '';
      }
      setState(() => _isLoading = false);
    }
  }

  /// Capture current device location as kitchen location
  Future<void> _getKitchenLocation() async {
    setState(() => _isGettingLocation = true);
    
    try {
      final geoService = GeoFenceService.instance;
      final status = await geoService.checkLocationStatus();
      
      if (status != LocationStatus.ready) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(geoService.getStatusMessage(status)),
              action: status == LocationStatus.permissionDeniedForever
                  ? SnackBarAction(label: 'Settings', onPressed: () {})
                  : null,
            ),
          );
        }
        return;
      }
      
      final position = await geoService.getCurrentPosition();
      
      if (position != null && mounted) {
        setState(() {
          _kitchenLatitude = position.latitude;
          _kitchenLongitude = position.longitude;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kitchen location captured!'),
            backgroundColor: Colors.green,
          ),
        );
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not get location. Please try again.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }


  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isSaving = true);
    
    try {
      final data = {
        'firmName': _nameController.text.trim(),
        'contactPerson': _contactPersonController.text.trim(),
        'primaryMobile': _mobileController.text.trim(),
        'primaryEmail': _emailController.text.trim(),
        'capacity': int.tryParse(_capacityController.text.trim()) ?? 500,
        'address': _addressController.text.trim(),
        'ownerName': _contactPersonController.text.trim(),
        'gstNumber': _gstController.text.trim(),
        'website': _websiteController.text.trim(),
        // GPS Kitchen Location
        'kitchenLatitude': _kitchenLatitude,
        'kitchenLongitude': _kitchenLongitude,
        'geoFenceRadius': _geoFenceRadius,
        'otMultiplier': double.tryParse(_otMultiplierController.text) ?? 1.5,
        // UPI Subscription
        'client_upi_id': _clientUpiIdController.text.trim(),
      };
      
      await DatabaseHelper().updateFirmDetails(_firmId!, data);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firm Profile')),
      body: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Firm Info
                    const Text('Basic Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Firm Name', border: OutlineInputBorder()),
                      validator: (v) => v?.isEmpty == true ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _contactPersonController,
                      decoration: const InputDecoration(labelText: 'Contact Person / Owner', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _mobileController,
                            decoration: const InputDecoration(labelText: 'Mobile', border: OutlineInputBorder()),
                            keyboardType: TextInputType.phone,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _capacityController,
                            decoration: const InputDecoration(labelText: 'Max Capacity (Pax)', border: OutlineInputBorder()),
                            keyboardType: TextInputType.number,
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n <= 0) return 'Invalid';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    const Text('Additional Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      decoration: const InputDecoration(labelText: 'Address', border: OutlineInputBorder()),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _gstController,
                            decoration: const InputDecoration(labelText: 'GST Number', border: OutlineInputBorder()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _websiteController,
                            decoration: const InputDecoration(labelText: 'Website', border: OutlineInputBorder()),
                          ),
                        ),
                      ],
                    ),
                    
                    // UPI Subscription Section
                    const SizedBox(height: 24),
                    const Text('Subscription Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Your UPI ID is used for subscription payment verification.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _clientUpiIdController,
                      decoration: const InputDecoration(
                        labelText: 'Your UPI ID',
                        hintText: 'e.g., yourname@upi',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.account_balance_wallet),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (v) {
                        if (v == null || v.isEmpty) return null; // Optional
                        // Basic UPI ID format: xxx@yyy
                        if (!v.contains('@')) {
                          return 'Invalid UPI ID format (should be like name@bank)';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),
                    
                    // ===== GPS Kitchen Location Section =====
                    const Text('Kitchen Location & Staff Settings', 
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Set your kitchen location for GPS-based staff attendance geo-fencing.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    
                    // GPS Capture Card
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _kitchenLatitude != null ? Icons.check_circle : Icons.location_off,
                                  color: _kitchenLatitude != null ? Colors.green : Colors.grey,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _kitchenLatitude != null
                                        ? 'Location set: ${_kitchenLatitude!.toStringAsFixed(6)}, ${_kitchenLongitude!.toStringAsFixed(6)}'
                                        : 'Kitchen location not set',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      color: _kitchenLatitude != null ? Colors.black87 : Colors.grey,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _isGettingLocation ? null : _getKitchenLocation,
                                icon: _isGettingLocation 
                                    ? const SizedBox(
                                        width: 16, 
                                        height: 16, 
                                        child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.my_location),
                                label: Text(_isGettingLocation 
                                    ? 'Getting Location...' 
                                    : 'Capture Current Location'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                            if (_kitchenLatitude != null) ...[
                              const SizedBox(height: 8),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _kitchenLatitude = null;
                                    _kitchenLongitude = null;
                                  });
                                },
                                icon: const Icon(Icons.clear, size: 18),
                                label: const Text('Clear Location'),
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Geo-fence Radius Slider
                    Row(
                      children: [
                        const Text('Geo-fence Radius: ', style: TextStyle(fontWeight: FontWeight.w500)),
                        Text('$_geoFenceRadius m', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                      ],
                    ),
                    Slider(
                      value: _geoFenceRadius.toDouble(),
                      min: 25,
                      max: 500,
                      divisions: 19,
                      label: '$_geoFenceRadius m',
                      onChanged: (value) {
                        setState(() => _geoFenceRadius = value.round());
                      },
                    ),
                    const Text(
                      'Staff must punch-in within this radius of kitchen location.',
                      style: TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // OT Multiplier
                    TextFormField(
                      controller: _otMultiplierController,
                      decoration: const InputDecoration(
                        labelText: 'Overtime Multiplier',
                        border: OutlineInputBorder(),
                        helperText: 'e.g., 1.5 means 1.5x hourly rate for OT hours',
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        final n = double.tryParse(v ?? '');
                        if (n == null || n < 1) return 'Must be >= 1';
                        return null;
                      },
                    ),

                    const SizedBox(height: 32),
                    SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving 
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text('SAVE PROFILE', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
