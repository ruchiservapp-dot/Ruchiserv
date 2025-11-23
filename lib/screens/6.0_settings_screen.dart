import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        centerTitle: true,
        title: const Text(
          "Settings",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF0D47A1), Color(0xFF42A5F5)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            leading: const Icon(Icons.business_rounded, color: Colors.indigo),
            title: const Text("Firm Profile"),
            subtitle: const Text("View or update your firm details"),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Firm Profile - Coming Soon")),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person_rounded, color: Colors.indigo),
            title: const Text("User Profile"),
            subtitle: const Text("Manage your login and preferences"),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("User Profile - Coming Soon")),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.palette_rounded, color: Colors.indigo),
            title: const Text("Theme Mode"),
            subtitle: const Text("Light / Dark mode switch"),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Theme toggle - Coming Soon")),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.info_outline_rounded, color: Colors.indigo),
            title: const Text("About RuchiServ"),
            onTap: () {
              Navigator.pushNamed(context, '/about');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: Colors.redAccent),
            title: const Text("Logout"),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Logout - Coming Soon")),
              );
            },
          ),
        ],
      ),
    );
  }
}
