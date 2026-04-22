import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/analysis_snapshot.dart';
import '../models/lego_part.dart';
import '../state/analysis_provider.dart';
import '../theme.dart';
import 'capture_pile_screen.dart';
import 'result_screen.dart';

class ReviewInventoryScreen extends ConsumerStatefulWidget {
  const ReviewInventoryScreen({super.key});

  @override
  ConsumerState<ReviewInventoryScreen> createState() =>
      _ReviewInventoryScreenState();
}

class _ReviewInventoryScreenState extends ConsumerState<ReviewInventoryScreen> {
  late List<LegoPart> _parts;

  @override
  void initState() {
    super.initState();
    _parts = List.of(ref.read(analysisProvider).inventory);
  }

  void _save() {
    ref.read(analysisProvider.notifier).updateInventory(_parts);
  }

  Future<void> _editRow(int i) async {
    final p = _parts[i];
    final result = await showDialog<LegoPart>(
      context: context,
      builder: (_) => _PartEditor(initial: p),
    );
    if (result != null) setState(() => _parts[i] = result);
  }

  Future<void> _addRow() async {
    final result = await showDialog<LegoPart>(
      context: context,
      builder: (_) => const _PartEditor(
        initial: LegoPart(partId: '', name: '', color: '', qty: 1),
      ),
    );
    if (result != null) setState(() => _parts.add(result));
  }

  @override
  Widget build(BuildContext context) {
    final past = ref.watch(analysisProvider).pastRuns;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Шаг 2 — Проверь список'),
        actions: [
          IconButton(onPressed: _addRow, icon: const Icon(Icons.add)),
        ],
      ),
      body: Column(
        children: [
          if (past.isNotEmpty) _PastRunsBanner(past: past),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceElev,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                children: const [
                  Icon(Icons.info_outline, color: AppColors.amber, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Проверь номера и количество — это сильно влияет на точность.',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: _parts.isEmpty
                ? const Center(
                    child: Text('Список пуст. Добавь детали вручную.',
                        style: TextStyle(color: Colors.white54)),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: _parts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final p = _parts[i];
                      return Dismissible(
                        key: ValueKey('${p.partId}-$i-${p.color}'),
                        background: Container(
                          decoration: BoxDecoration(
                            color: AppColors.bad,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child:
                              const Icon(Icons.delete, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) => setState(() => _parts.removeAt(i)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _editRow(i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceElev,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                _ColorSwatch(color: p.color),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        p.name.isEmpty ? '—' : p.name,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '${p.color.isEmpty ? 'no color' : p.color} · #${p.partId}',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.amber.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                        color: AppColors.amber
                                            .withValues(alpha: 0.3)),
                                  ),
                                  child: Text(
                                    '×${p.qty}',
                                    style: const TextStyle(
                                      color: AppColors.amber,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton.icon(
                onPressed: _parts.isEmpty
                    ? null
                    : () {
                        _save();
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => const CapturePileScreen(),
                        ));
                      },
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Далее — фото кучи'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PastRunsBanner extends ConsumerWidget {
  final List<AnalysisSnapshot> past;
  const _PastRunsBanner({required this.past});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = past.first;
    final found = last.foundCount;
    final needed = last.neededCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          ref.read(analysisProvider.notifier).loadSnapshot(last);
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const ResultScreen(),
          ));
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.amber.withValues(alpha: 0.18),
                AppColors.amber.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: AppColors.amber.withValues(alpha: 0.45), width: 1),
          ),
          child: Row(
            children: [
              const Icon(Icons.bookmark_rounded,
                  color: AppColors.amber, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      past.length == 1
                          ? 'Этот набор уже сканировали 1 раз'
                          : 'Этот набор уже сканировали ${past.length} раз',
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Последний: $found / $needed · ${_fmtDate(last.createdAt)}',
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }

  String _fmtDate(DateTime dt) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(dt.day)}.${two(dt.month)}.${dt.year}';
  }
}

class _ColorSwatch extends StatelessWidget {
  final String color;
  const _ColorSwatch({required this.color});

  @override
  Widget build(BuildContext context) {
    final c = _parse(color);
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white24, width: 1),
        boxShadow: [
          BoxShadow(
            color: c.withValues(alpha: 0.3),
            blurRadius: 8,
            spreadRadius: -2,
          ),
        ],
      ),
    );
  }

  Color _parse(String raw) {
    final n = raw.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    const m = {
      'red': Color(0xFFC91A09),
      'blue': Color(0xFF0055BF),
      'yellow': Color(0xFFF2CD37),
      'black': Color(0xFF05131D),
      'white': Color(0xFFF4F4F4),
      'tan': Color(0xFFE4CD9E),
      'lightbluishgray': Color(0xFFAFB5C7),
      'darkbluishgray': Color(0xFF6C6E68),
      'gray': Color(0xFF6C6E68),
      'grey': Color(0xFF6C6E68),
      'orange': Color(0xFFFE8A18),
      'green': Color(0xFF237841),
      'lime': Color(0xFFA5CA18),
      'brown': Color(0xFF583927),
      'darkbrown': Color(0xFF352100),
      'reddishbrown': Color(0xFF582A12),
      'darkred': Color(0xFF720E0F),
      'darkgray': Color(0xFF505050),
      'lightgray': Color(0xFFC0C0C0),
      'pink': Color(0xFFFC97AC),
      'magenta': Color(0xFF923978),
      'purple': Color(0xFF81007B),
      'darkpurple': Color(0xFF3F3691),
      'darkblue': Color(0xFF0A3463),
      'mediumblue': Color(0xFF5A93DB),
      'skyblue': Color(0xFF7DBFDD),
      'darktan': Color(0xFF958A73),
      'darkgreen': Color(0xFF184632),
      'sand': Color(0xFFA0BCAC),
      'silver': Color(0xFF898788),
      'gold': Color(0xFFDBAC34),
    };
    return m[n] ?? const Color(0xFF3A3A3A);
  }
}

class _PartEditor extends StatefulWidget {
  final LegoPart initial;
  const _PartEditor({required this.initial});

  @override
  State<_PartEditor> createState() => _PartEditorState();
}

class _PartEditorState extends State<_PartEditor> {
  late final TextEditingController _pid;
  late final TextEditingController _name;
  late final TextEditingController _color;
  late final TextEditingController _qty;

  @override
  void initState() {
    super.initState();
    _pid = TextEditingController(text: widget.initial.partId);
    _name = TextEditingController(text: widget.initial.name);
    _color = TextEditingController(text: widget.initial.color);
    _qty = TextEditingController(text: widget.initial.qty.toString());
  }

  @override
  void dispose() {
    _pid.dispose();
    _name.dispose();
    _color.dispose();
    _qty.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Деталь'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
              controller: _pid,
              decoration: const InputDecoration(labelText: 'part_id')),
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'name')),
          TextField(
              controller: _color,
              decoration: const InputDecoration(labelText: 'color')),
          TextField(
              controller: _qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'qty')),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена')),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            LegoPart(
              partId: _pid.text.trim(),
              name: _name.text.trim(),
              color: _color.text.trim(),
              qty: int.tryParse(_qty.text.trim()) ?? 1,
            ),
          ),
          child: const Text('OK'),
        ),
      ],
    );
  }
}
