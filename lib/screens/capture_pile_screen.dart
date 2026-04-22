import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../state/analysis_provider.dart';
import '../theme.dart';
import '../widgets/lego_loader.dart';
import '../widgets/scanner_corners.dart';
import 'result_screen.dart';
import 'tap_identify_screen.dart';

class CapturePileScreen extends ConsumerStatefulWidget {
  const CapturePileScreen({super.key});

  @override
  ConsumerState<CapturePileScreen> createState() => _CapturePileScreenState();
}

class _CapturePileScreenState extends ConsumerState<CapturePileScreen> {
  File? _picked;
  final _picker = ImagePicker();
  _Mode _mode = _Mode.auto;

  Future<void> _pick(ImageSource src) async {
    final x = await _picker.pickImage(source: src, imageQuality: 92);
    if (x == null) return;
    setState(() => _picked = File(x.path));
  }

  Future<void> _analyze() async {
    final f = _picked;
    if (f == null) return;
    if (_mode == _Mode.tap) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => TapIdentifyScreen(pileImage: f),
      ));
      return;
    }
    await ref.read(analysisProvider.notifier).analyzePile(f);
    if (!mounted) return;
    final st = ref.read(analysisProvider);
    if (st.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(st.error!)));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ResultScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final st = ref.watch(analysisProvider);
    final busy = st.busy;
    return Scaffold(
      appBar: AppBar(title: const Text('Шаг 3 — Куча деталей')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hint(
                  icon: Icons.tips_and_updates_outlined,
                  text:
                      'Сфотографируй кучу сверху. Хорошее освещение, детали не должны сильно перекрывать друг друга.',
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ScannerCorners(
                    active: _picked != null && !busy,
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceElev,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      clipBehavior: Clip.antiAlias,
                      child: _picked == null
                          ? const _EmptyPreview(
                              icon: Icons.grid_view_rounded,
                              label: 'Фото не выбрано',
                            )
                          : Image.file(_picked!, fit: BoxFit.contain),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Камера'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: busy ? null : () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('Галерея'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const SizedBox(height: 4),
                _ModeSelector(
                  mode: _mode,
                  onChanged: (m) => setState(() => _mode = m),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: (_picked == null || busy) ? null : _analyze,
                    icon: Icon(_mode == _Mode.auto
                        ? Icons.center_focus_strong_rounded
                        : Icons.touch_app_rounded),
                    label: Text(_mode == _Mode.auto
                        ? 'Найти детали автоматически'
                        : 'Перейти в тап-режим'),
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            Positioned.fill(
              child: LegoLoader(
                thumbnail: _picked,
                progressDone: st.progressDone,
                progressTotal: st.progressTotal,
                progressLabel: st.progressLabel,
              ),
            ),
        ],
      ),
    );
  }
}

enum _Mode { auto, tap }

class _ModeSelector extends StatelessWidget {
  final _Mode mode;
  final ValueChanged<_Mode> onChanged;
  const _ModeSelector({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceElev,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ModeChip(
              label: 'Авто (AI)',
              icon: Icons.auto_awesome_rounded,
              selected: mode == _Mode.auto,
              onTap: () => onChanged(_Mode.auto),
            ),
          ),
          Expanded(
            child: _ModeChip(
              label: 'Тап-режим',
              icon: Icons.touch_app_rounded,
              selected: mode == _Mode.tap,
              onTap: () => onChanged(_Mode.tap),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.amber : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 16,
                color: selected ? Colors.black : Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.black : Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Hint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceElev,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.amber, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPreview extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EmptyPreview({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 64, color: Colors.white24),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 13)),
      ],
    );
  }
}
