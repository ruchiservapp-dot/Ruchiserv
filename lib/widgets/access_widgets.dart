// Access Control Widgets
// Reusable widgets for permission gating, rate hiding, and feature badges
import 'package:flutter/material.dart';
import '../services/permission_service.dart';
import '../services/feature_gate_service.dart';

/// Wraps content that should only be visible if user can view rates/costs
class RateProtected extends StatefulWidget {
  final Widget child;
  final Widget? placeholder;
  final bool hideCompletely;

  const RateProtected({
    super.key,
    required this.child,
    this.placeholder,
    this.hideCompletely = false,
  });

  @override
  State<RateProtected> createState() => _RateProtectedState();
}

class _RateProtectedState extends State<RateProtected> {
  bool _canView = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final canView = await PermissionService.instance.canViewRates();
    if (mounted) {
      setState(() {
        _canView = canView;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    
    if (_canView) return widget.child;
    
    if (widget.hideCompletely) return const SizedBox.shrink();
    
    return widget.placeholder ?? 
      const Text('****', style: TextStyle(color: Colors.grey));
  }
}

/// Wraps navigation or content that requires module access
class PermissionGate extends StatefulWidget {
  final String module;
  final Widget child;
  final Widget? deniedWidget;
  final VoidCallback? onDenied;

  const PermissionGate({
    super.key,
    required this.module,
    required this.child,
    this.deniedWidget,
    this.onDenied,
  });

  @override
  State<PermissionGate> createState() => _PermissionGateState();
}

class _PermissionGateState extends State<PermissionGate> {
  bool _hasAccess = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkAccess();
  }

  Future<void> _checkAccess() async {
    final hasAccess = await PermissionService.instance.canAccess(widget.module);
    if (mounted) {
      setState(() {
        _hasAccess = hasAccess;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();
    
    if (_hasAccess) return widget.child;
    
    if (widget.deniedWidget != null) return widget.deniedWidget!;
    
    return _buildAccessDenied();
  }

  Widget _buildAccessDenied() {
    return Card(
      color: Colors.grey.shade100,
      child: InkWell(
        onTap: widget.onDenied ?? () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Access denied. Contact your administrator.'),
              backgroundColor: Colors.orange,
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.lock, color: Colors.grey.shade400),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Access Restricted',
                  style: TextStyle(color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Shows a badge for Pro/Enterprise features
class FeatureBadge extends StatefulWidget {
  final String feature;
  final Widget child;
  final bool showLockOverlay;

  const FeatureBadge({
    super.key,
    required this.feature,
    required this.child,
    this.showLockOverlay = false,
  });

  @override
  State<FeatureBadge> createState() => _FeatureBadgeState();
}

class _FeatureBadgeState extends State<FeatureBadge> {
  bool _isEnabled = true;
  String _requiredTier = 'BASIC';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkFeature();
  }

  Future<void> _checkFeature() async {
    final isEnabled = await FeatureGateService.instance.isFeatureEnabled(widget.feature);
    final requiredTier = FeatureGateService.getRequiredTier(widget.feature);
    if (mounted) {
      setState(() {
        _isEnabled = isEnabled;
        _requiredTier = requiredTier;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return widget.child;
    
    if (_isEnabled) return widget.child;
    
    return Stack(
      children: [
        widget.child,
        if (widget.showLockOverlay)
          Positioned.fill(
            child: Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Icon(Icons.lock, color: Colors.white.withOpacity(0.7), size: 32),
              ),
            ),
          ),
        Positioned(
          top: 4,
          right: 4,
          child: _buildBadge(),
        ),
      ],
    );
  }

  Widget _buildBadge() {
    final color = _requiredTier == 'ENTERPRISE' ? Colors.purple : Colors.orange;
    final label = _requiredTier == 'ENTERPRISE' ? 'ENT' : 'PRO';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Upgrade prompt dialog
class UpgradePrompt extends StatelessWidget {
  final String feature;
  final String requiredTier;

  const UpgradePrompt({
    super.key,
    required this.feature,
    required this.requiredTier,
  });

  static Future<void> show(BuildContext context, String feature) async {
    final requiredTier = FeatureGateService.getRequiredTier(feature);
    final featureName = FeatureGateService.featureNames[feature] ?? feature;
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.lock, color: Colors.orange.shade700),
            const SizedBox(width: 8),
            const Text('Upgrade Required'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$featureName requires a $requiredTier subscription.'),
            const SizedBox(height: 16),
            Text(
              FeatureGateService.getTierDisplayName(requiredTier),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Navigate to subscription screen
              Navigator.pushNamed(ctx, '/subscription');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Upgrade Now'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => show(context, feature),
      icon: const Icon(Icons.upgrade),
      label: const Text('Upgrade'),
    );
  }
}

/// Access denied screen for unauthorized navigation
class AccessDeniedScreen extends StatelessWidget {
  final String module;

  const AccessDeniedScreen({super.key, required this.module});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Access Denied')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'You don\'t have access to this module',
              style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Contact your administrator for access.',
              style: TextStyle(color: Colors.grey.shade500),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
