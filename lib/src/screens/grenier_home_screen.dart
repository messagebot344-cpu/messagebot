import 'package:flutter/material.dart';

import '../theme/grenier_tokens.dart';

class GrenierHomeScreen extends StatelessWidget {
  const GrenierHomeScreen({
    super.key,
    required this.onStartConversation,
  });

  final VoidCallback onStartConversation;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mobile = GrenierBreakpoints.isMobile(constraints.maxWidth);
        return DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: mobile
                  ? const [Color(0xFF071426), GrenierPalette.navy, Color(0xFF0D2546)]
                  : [
                      Theme.of(context).scaffoldBackgroundColor,
                      Theme.of(context).colorScheme.surface,
                    ],
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: mobile ? 24 : 48,
                vertical: mobile ? 36 : 48,
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: mobile ? 116 : 104,
                      height: mobile ? 116 : 104,
                      decoration: BoxDecoration(
                        color: mobile
                            ? Colors.white.withValues(alpha: 0.08)
                            : GrenierPalette.navy.withValues(alpha: 0.07),
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.auto_stories_rounded,
                        size: mobile ? 72 : 64,
                        color: mobile
                            ? const Color(0xFFD7A94B)
                            : GrenierPalette.navy,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      GrenierBrand.name,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            color: mobile ? Colors.white : null,
                            fontFamily: 'serif',
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      GrenierBrand.versionLabel,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: mobile
                                ? Colors.white70
                                : GrenierPalette.actionBlue,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      mobile
                          ? 'Toute Sa Parole.\nToujours avec vous.\nHors ligne.'
                          : GrenierBrand.tagline,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: mobile ? Colors.white70 : null,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 30),
                    ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 250),
                      child: FilledButton.icon(
                        onPressed: onStartConversation,
                        icon: const Icon(Icons.search_rounded),
                        label: const Padding(
                          padding: EdgeInsets.symmetric(vertical: 4),
                          child: Text('Commencer une recherche'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (mobile)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: const [
                          _TrustChip(
                            icon: Icons.wifi_off_rounded,
                            label: GrenierBrand.offlineLabel,
                            mobile: true,
                            positive: true,
                          ),
                          SizedBox(height: 8),
                          _TrustChip(
                            icon: Icons.psychology_alt_outlined,
                            label: GrenierBrand.noAiLabel,
                            mobile: true,
                          ),
                          SizedBox(height: 8),
                          _TrustChip(
                            icon: Icons.verified_outlined,
                            label: GrenierBrand.canonicalOnlyLabel,
                            mobile: true,
                          ),
                        ],
                      )
                    else
                      const Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _TrustChip(
                            icon: Icons.wifi_off_rounded,
                            label: GrenierBrand.offlineLabel,
                            mobile: false,
                            positive: true,
                          ),
                          _TrustChip(
                            icon: Icons.psychology_alt_outlined,
                            label: GrenierBrand.noAiLabel,
                            mobile: false,
                          ),
                          _TrustChip(
                            icon: Icons.verified_outlined,
                            label: GrenierBrand.canonicalOnlyLabel,
                            mobile: false,
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TrustChip extends StatelessWidget {
  const _TrustChip({
    required this.icon,
    required this.label,
    required this.mobile,
    this.positive = false,
  });

  final IconData icon;
  final String label;
  final bool mobile;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    final foreground = positive
        ? GrenierPalette.offlineGreen
        : (mobile ? Colors.white70 : Theme.of(context).colorScheme.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: mobile ? Colors.white.withValues(alpha: 0.06) : Colors.transparent,
        border: Border.all(
          color: positive
              ? GrenierPalette.offlineGreen
              : (mobile ? Colors.white24 : Theme.of(context).colorScheme.outlineVariant),
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisSize: mobile ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: mobile ? MainAxisAlignment.center : MainAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: foreground),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: foreground, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
