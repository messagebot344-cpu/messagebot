import 'package:flutter/material.dart';

import '../theme/grenier_tokens.dart';

class GrenierTopBanner extends StatelessWidget {
  const GrenierTopBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      width: double.infinity,
      color: GrenierPalette.navy,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      child: Row(
        children: [
          const Icon(Icons.menu_book_rounded, size: 42, color: Colors.white),
          const SizedBox(width: 14),
          const SizedBox(
            width: 190,
            child: Text(
              'Toute Sa Parole\nà portée de recherche.',
              style: TextStyle(color: Colors.white70, height: 1.25),
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  GrenierBrand.name,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w700, fontFamily: 'serif'),
                ),
                SizedBox(height: 3),
                Text(
                  GrenierBrand.tagline,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 310),
            child: const Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                _TrustBadge(icon: Icons.cloud_off_rounded, label: GrenierBrand.offlineLabel, emphasized: true),
                _TrustBadge(icon: Icons.shield_outlined, label: GrenierBrand.noAiLabel),
                _TrustBadge(icon: Icons.verified_outlined, label: GrenierBrand.canonicalOnlyLabel),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  const _TrustBadge({required this.icon, required this.label, this.emphasized = false});

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: emphasized ? GrenierPalette.offlineGreen : Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.white),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
