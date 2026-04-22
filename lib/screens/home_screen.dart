import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../state/analysis_provider.dart';
import '../theme.dart';
import '../widgets/lego_brick.dart';
import 'capture_inventory_screen.dart';
import 'history_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // Subtle radial glow.
            const Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -0.5),
                    radius: 1.1,
                    colors: [Color(0x33FFB300), Color(0xFF121212)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 24,
                        decoration: BoxDecoration(
                          color: AppColors.amber,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'TWINK · SCANNER',
                        style: TextStyle(
                          color: AppColors.amber,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2.0,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) => const HistoryScreen(),
                          ));
                        },
                        icon: const Icon(Icons.history, color: Colors.white70),
                        tooltip: 'История',
                      ),
                    ],
                  ),
                  const Spacer(flex: 2),
                  const Center(child: AnimatedLegoBrick(size: 180)),
                  const Spacer(),
                  const Text(
                    'TwinkLegoFinder',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Сфотографируй список деталей и кучу — найдём\nкаждую детальку в вашей куче.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  _StepsRow(),
                  const Spacer(flex: 2),
                  SizedBox(
                    height: 56,
                    child: FilledButton.icon(
                      onPressed: () {
                        ref.read(analysisProvider.notifier).reset();
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const CaptureInventoryScreen(),
                        ));
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 26),
                      label: const Text('Начать анализ'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'powered by Gemini 2.5 Flash via kie.ai',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white30, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        _StepChip(n: '1', icon: Icons.photo_camera_outlined, label: 'Инвентарь'),
        SizedBox(width: 8),
        _StepChip(n: '2', icon: Icons.edit_note_rounded, label: 'Проверка'),
        SizedBox(width: 8),
        _StepChip(n: '3', icon: Icons.center_focus_strong_rounded, label: 'Куча'),
      ],
    );
  }
}

class _StepChip extends StatelessWidget {
  final String n;
  final IconData icon;
  final String label;
  const _StepChip({required this.n, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceElev,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10, width: 1),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: AppColors.amber,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    n,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(icon, size: 18, color: Colors.white70),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
