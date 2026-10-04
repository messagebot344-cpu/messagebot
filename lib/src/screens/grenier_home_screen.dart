import 'package:flutter/material.dart';

import '../theme/grenier_tokens.dart';

class GrenierHomeScreen extends StatelessWidget {
  const GrenierHomeScreen({super.key, required this.onStartConversation});

  final VoidCallback onStartConversation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = GrenierBreakpoints.isMobile(constraints.maxWidth);
        if (mobile) {
          return Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [GrenierPalette.navy, Color(0xFF142A4B), GrenierPalette.lightCanvas],
                stops: [0, 0.62, 0.62],
              ),
            ),
            child: SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 54, 24, 28),
                children: [
                  const Icon(Icons.menu_book_rounded, size: 72, color: Colors.white),
                  const SizedBox(height: 20),
                  const Text(GrenierBrand.name, textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 29, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text(GrenierBrand.versionLabel, textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 18),
                  const Text(
                    'Toute Sa Parole.\nToujours avec vous.\nHors ligne.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, fontSize: 20, height: 1.35, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 30),
                  FilledButton.icon(
                    onPressed: onStartConversation,
                    icon: const Icon(Icons.search_rounded),
                    label: const Text('Commencer une recherche'),
                  ),
                  const SizedBox(height: 16),
                  const Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HomeTrustChip(icon: Icons.cloud_off_rounded, label: GrenierBrand.offlineLabel),
                      _HomeTrustChip(icon: Icons.shield_outlined, label: GrenierBrand.noAiLabel),
                      _HomeTrustChip(icon: Icons.verified_outlined, label: GrenierBrand.canonicalOnlyLabel),
                    ],
                  ),
                  const SizedBox(height: 74),
                  Text(
                    'Recherche documentaire déterministe dans le corpus canonique, sans reformulation générative.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          );
        }

        return Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 42, vertical: 46),
                  child: Column(
                    children: [
                      const Icon(Icons.menu_book_rounded, size: 78, color: GrenierPalette.actionBlue),
                      const SizedBox(height: 18),
                      Text(GrenierBrand.name, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 6),
                      Text(GrenierBrand.versionLabel, style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Text(GrenierBrand.tagline, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 24),
                      FilledButton.icon(onPressed: onStartConversation, icon: const Icon(Icons.search_rounded), label: const Text('Commencer une recherche')),
                      const SizedBox(height: 20),
                      const Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Chip(avatar: Icon(Icons.cloud_off_outlined, size: 18), label: Text(GrenierBrand.offlineLabel)),
                          Chip(avatar: Icon(Icons.shield_outlined, size: 18), label: Text(GrenierBrand.noAiLabel)),
                          Chip(avatar: Icon(Icons.verified_outlined, size: 18), label: Text(GrenierBrand.canonicalOnlyLabel)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HomeTrustChip extends StatelessWidget {
  const _HomeTrustChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(99)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: Colors.white, size: 15),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}
