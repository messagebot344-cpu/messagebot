import 'package:flutter/material.dart';

import '../theme/grenier_tokens.dart';

class GrenierTopBanner extends StatelessWidget {
  const GrenierTopBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 104,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF172033), GrenierPalette.navy, Color(0xFF071426)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final showEditorial = constraints.maxWidth >= 820;
          final showCanonical = constraints.maxWidth >= 680;
          return Row(
            children: [
              if (showEditorial)
                const SizedBox(
                  width: 230,
                  child: Row(
                    children: [
                      Icon(Icons.auto_stories_rounded, color: Color(0xFFD7A94B), size: 42),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Une Parole. Des vies.\nPour toujours.',
                          style: TextStyle(color: Colors.white70, height: 1.25),
                        ),
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      GrenierBrand.name,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: Colors.white,
                            fontFamily: 'serif',
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      GrenierBrand.tagline,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      border: Border.all(color: GrenierPalette.offlineGreen, width: 1.3),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.wifi_off_rounded, color: GrenierPalette.offlineGreen, size: 19),
                        SizedBox(width: 8),
                        Text(GrenierBrand.offlineLabel, style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 5),
                  const Text(GrenierBrand.noAiLabel, style: TextStyle(color: Colors.white70, fontSize: 12)),
                  if (showCanonical)
                    const Text(GrenierBrand.canonicalOnlyLabel, style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
