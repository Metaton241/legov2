import 'package:flutter/material.dart';

import '../models/lego_part.dart';
import '../theme.dart';

class PartsSheet extends StatelessWidget {
  final List<LegoPart> inventory;
  final Map<String, int> foundCounts;

  const PartsSheet({
    super.key,
    required this.inventory,
    required this.foundCounts,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.38,
      minChildSize: 0.12,
      maxChildSize: 0.9,
      builder: (ctx, scroll) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surfaceElev,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          boxShadow: [
            BoxShadow(color: Colors.black54, blurRadius: 20, spreadRadius: -4),
          ],
        ),
        child: Column(
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white30,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            _LegendHeader(
              inventory: inventory,
              foundCounts: foundCounts,
            ),
            const Divider(height: 1, color: Colors.white10),
            Expanded(
              child: ListView.separated(
                controller: scroll,
                padding: const EdgeInsets.symmetric(vertical: 4),
                itemCount: inventory.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: Colors.white10),
                itemBuilder: (_, i) {
                  final p = inventory[i];
                  final found = foundCounts[p.partId] ?? 0;
                  final ok = found >= p.qty && p.qty > 0;
                  return ListTile(
                    dense: true,
                    leading: Container(
                      width: 32,
                      height: 32,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: ok
                            ? AppColors.good.withValues(alpha: 0.15)
                            : Colors.white10,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        ok ? Icons.check_rounded : Icons.radio_button_unchecked,
                        color: ok ? AppColors.good : Colors.white38,
                        size: 18,
                      ),
                    ),
                    title: Text(
                      p.name.isEmpty ? '—' : p.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${p.color} · #${p.partId}',
                      style: const TextStyle(color: Colors.white54),
                    ),
                    trailing: Text(
                      '$found / ${p.qty}',
                      style: TextStyle(
                        color: ok ? AppColors.good : AppColors.warn,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendHeader extends StatelessWidget {
  final List<LegoPart> inventory;
  final Map<String, int> foundCounts;
  const _LegendHeader({required this.inventory, required this.foundCounts});

  @override
  Widget build(BuildContext context) {
    int found = 0;
    int missing = 0;
    int neededTotal = 0;
    for (final p in inventory) {
      neededTotal += p.qty;
      final f = foundCounts[p.partId] ?? 0;
      found += f > p.qty ? p.qty : f;
      if (f < p.qty) missing += (p.qty - f);
    }
    final progress = neededTotal == 0 ? 0.0 : found / neededTotal;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Text(
                'Детали',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              _LegendChip(
                color: AppColors.good,
                label: '$found found',
              ),
              const SizedBox(width: 6),
              _LegendChip(
                color: AppColors.bad,
                label: '$missing missing',
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white10,
              valueColor:
                  const AlwaysStoppedAnimation<Color>(AppColors.amber),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegendChip extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendChip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
