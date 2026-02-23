// RESPONSIVE UTILS — Central breakpoint helpers for all screens
// Breakpoints: Mobile < 600, Tablet 600–1100, Desktop > 1100

import 'package:flutter/material.dart';

class Responsive {
  // ── Breakpoint checks ──────────────────────────────────────────────────────

  static bool isPhone(BuildContext context) =>
      MediaQuery.of(context).size.width < 600;

  static bool isTablet(BuildContext context) {
    final w = MediaQuery.of(context).size.width;
    return w >= 600 && w < 1100;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 1100;

  static bool isTabletOrDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 600;

  // ── Value picker ───────────────────────────────────────────────────────────

  /// Returns the value matching the current breakpoint.
  /// Falls back: desktop → tablet → phone if a value is null.
  static T value<T>(
    BuildContext context, {
    required T phone,
    T? tablet,
    T? desktop,
  }) {
    final w = MediaQuery.of(context).size.width;
    if (w >= 1100) return desktop ?? tablet ?? phone;
    if (w >= 600) return tablet ?? phone;
    return phone;
  }

  // ── Common layout helpers ──────────────────────────────────────────────────

  /// Standard horizontal padding for content areas.
  static EdgeInsets padding(BuildContext context) => EdgeInsets.symmetric(
        horizontal: value(context, phone: 12.0, tablet: 24.0, desktop: 40.0),
        vertical: 12,
      );

  /// Number of grid columns for card/tile grids.
  static int columns(BuildContext context, {int phone = 1, int tablet = 2, int desktop = 3}) =>
      value(context, phone: phone, tablet: tablet, desktop: desktop);

  /// Max content width for centred layouts (forms, detail pages).
  static double maxContentWidth(BuildContext context) =>
      value(context, phone: double.infinity, tablet: 720, desktop: 960);

  /// Font scale factor — slightly larger on desktop.
  static double fontScale(BuildContext context) =>
      value(context, phone: 1.0, tablet: 1.05, desktop: 1.1);

  // ── Navigation helpers ─────────────────────────────────────────────────────

  /// True when the app should show a side NavigationRail instead of BottomNav.
  static bool useSideNav(BuildContext context) => isDesktop(context);
}

// ── Responsive wrapper widget ──────────────────────────────────────────────

/// Wraps a child in a centred, max-width constrained box for detail/form pages.
class ResponsiveCenter extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;

  const ResponsiveCenter({super.key, required this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: Responsive.maxContentWidth(context)),
        child: Padding(
          padding: padding ?? Responsive.padding(context),
          child: child,
        ),
      ),
    );
  }
}

/// A grid that automatically picks the right column count per breakpoint.
class ResponsiveGrid extends StatelessWidget {
  final List<Widget> children;
  final int phoneColumns;
  final int tabletColumns;
  final int desktopColumns;
  final double spacing;
  final double runSpacing;

  const ResponsiveGrid({
    super.key,
    required this.children,
    this.phoneColumns = 1,
    this.tabletColumns = 2,
    this.desktopColumns = 3,
    this.spacing = 12,
    this.runSpacing = 12,
  });

  @override
  Widget build(BuildContext context) {
    final cols = Responsive.columns(
      context,
      phone: phoneColumns,
      tablet: tabletColumns,
      desktop: desktopColumns,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final itemWidth = (constraints.maxWidth - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children
              .map((child) => SizedBox(width: itemWidth, child: child))
              .toList(),
        );
      },
    );
  }
}
