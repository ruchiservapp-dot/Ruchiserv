import 'package:flutter/material.dart';
import 'package:ruchiserv/l10n/app_localizations.dart';

class LedgerScreen extends StatelessWidget {
  const LedgerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(AppLocalizations.of(context)!.ledgers),
          bottom: TabBar(
            tabs: [
              Tab(text: AppLocalizations.of(context)!.suppliers),
              Tab(text: AppLocalizations.of(context)!.staff),
              Tab(text: AppLocalizations.of(context)!.customers),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            Center(child: Text("${AppLocalizations.of(context)!.suppliers} ${AppLocalizations.of(context)!.ledgers} - ${AppLocalizations.of(context)!.comingSoon}")),
            Center(child: Text("${AppLocalizations.of(context)!.staff} ${AppLocalizations.of(context)!.ledgers} - ${AppLocalizations.of(context)!.comingSoon}")),
            Center(child: Text("${AppLocalizations.of(context)!.customers} ${AppLocalizations.of(context)!.ledgers} - ${AppLocalizations.of(context)!.comingSoon}")),
          ],
        ),
      ),
    );
  }
}
