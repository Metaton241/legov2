import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../state/analysis_provider.dart';
import '../theme.dart';
import '../widgets/lego_loader.dart';
import '../widgets/scanner_corners.dart';
import 'capture_pile_screen.dart';
import 'review_inventory_screen.dart';

class CaptureInventoryScreen extends ConsumerStatefulWidget {
  const CaptureInventoryScreen({super.key});

  @override
  ConsumerState<CaptureInventoryScreen> createState() =>
      _CaptureInventoryScreenState();
}

class _CaptureInventoryScreenState
    extends ConsumerState<CaptureInventoryScreen> {
  File? _picked;
  final _picker = ImagePicker();
  final _labelCtrl = TextEditingController();

  @override
  void dispose() {
    _labelCtrl.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    final x = await _picker.pickImage(source: src, imageQuality: 92);
    if (x == null) return;
    setState(() => _picked = File(x.path));
  }

  Future<void> _analyze() async {
    final f = _picked;
    if (f == null) return;
    ref.read(analysisProvider.notifier).setLabel(_labelCtrl.text.trim());
    await ref.read(analysisProvider.notifier).parseInventory(f);
    if (!mounted) return;
    final st = ref.read(analysisProvider);
    if (st.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(st.error!)));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ReviewInventoryScreen(),
    ));
  }

  Future<void> _loadFromSetNumber() async {
    final n = _labelCtrl.text.trim();
    if (n.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Впиши номер набора в поле выше'),
      ));
      return;
    }
    await ref.read(analysisProvider.notifier).loadFromSetNumber(n);
    if (!mounted) return;
    final st = ref.read(analysisProvider);
    if (st.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(st.error!)));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ReviewInventoryScreen(),
    ));
  }

  /// Skip inventory entirely — useful when kie.ai is down. The pipeline will
  /// then return every brick Brickognize identifies (no match filtering).
  void _skipInventory() {
    ref.read(analysisProvider.notifier).updateInventory(const []);
    ref.read(analysisProvider.notifier).setLabel(_labelCtrl.text.trim());
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const CapturePileScreen(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(analysisProvider).busy;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Шаг 1 — Инвентарь'),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hint(
                  icon: Icons.lightbulb_outline,
                  text:
                      'Сфотографируй страницу инструкции со списком деталей (inventory).',
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _labelCtrl,
                  enabled: !busy,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Номер набора (напр. 75192)',
                    hintStyle: const TextStyle(color: Colors.white38),
                    prefixIcon: const Icon(Icons.sell_outlined,
                        color: Colors.white54, size: 20),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                  ),
                ),
                if (ref.watch(analysisProvider.notifier).rebrickableConfigured) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : _loadFromSetNumber,
                      icon: const Icon(Icons.cloud_download_outlined, size: 18),
                      label: const Text(
                        'Загрузить инвентарь с Rebrickable',
                        style: TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                ],
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
                              icon: Icons.article_outlined,
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
                SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: (_picked == null || busy) ? null : _analyze,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Распознать список деталей'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: busy ? null : _skipInventory,
                  icon: const Icon(Icons.skip_next_rounded,
                      color: Colors.white54),
                  label: const Text(
                    'Пропустить инвентарь — найти все детали в куче',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (busy)
            Positioned.fill(
              child: LegoLoader(thumbnail: _picked),
            ),
        ],
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
