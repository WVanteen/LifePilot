import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/utils/money.dart';
import 'ledger_statistics_service.dart';

/// Independent page; navigation can use MaterialPageRoute without a new route.
class LedgerStatisticsPage extends ConsumerStatefulWidget {
  const LedgerStatisticsPage({super.key});
  @override
  ConsumerState<LedgerStatisticsPage> createState() =>
      _LedgerStatisticsPageState();
}

class _LedgerStatisticsPageState extends ConsumerState<LedgerStatisticsPage> {
  DateTime date = DateTime.now();
  int period = 1;
  @override
  Widget build(BuildContext context) {
    final start = switch (period) {
      0 => DateTime(date.year, date.month, date.day),
      1 => DateTime(date.year, date.month),
      _ => DateTime(date.year),
    };
    final end = switch (period) {
      0 => DateTime(date.year, date.month, date.day + 1),
      1 => DateTime(date.year, date.month + 1),
      _ => DateTime(date.year + 1),
    };
    final db = ref.watch(appDatabaseProvider);
    final categoryNames = <String, String>{
      for (final c in ref.watch(ledgerCategoriesProvider).value ?? [])
        c.id: c.name,
    };
    final accountNames = <String, String>{
      for (final a in ref.watch(ledgerAccountsProvider).value ?? [])
        a.id: a.name,
    };
    return Scaffold(
      appBar: AppBar(title: const Text('收支统计')),
      body: Column(
        children: [
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('日')),
              ButtonSegment(value: 1, label: Text('月')),
              ButtonSegment(value: 2, label: Text('年')),
            ],
            selected: {period},
            onSelectionChanged: (v) => setState(() => period = v.first),
          ),
          TextButton.icon(
            onPressed: () async {
              final chosen = await showDatePicker(
                context: context,
                initialDate: date,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (chosen != null && mounted) setState(() => date = chosen);
            },
            icon: const Icon(Icons.calendar_month),
            label: Text(
              period == 0
                  ? localYmd(date)
                  : period == 1
                  ? localYmd(date).substring(0, 7)
                  : '${date.year}',
            ),
          ),
          Expanded(
            child: StreamBuilder<LedgerStatistics>(
              stream: LedgerStatisticsService(db).watch(start, end),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('读取统计失败：${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final data = snapshot.requireData;
                Widget totals(LedgerTotals t) => Text(
                  '收入 ${formatCny(t.income)}   净支出 ${formatCny(t.expense)}   结余 ${formatCny(t.balance)}',
                );
                Widget section(
                  String title,
                  Map<String, LedgerTotals> values,
                  Map<String, String> names,
                ) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (values.isEmpty) const Text('暂无数据'),
                    ...values.entries.map(
                      (e) => ListTile(
                        title: Text(names[e.key] ?? '未知'),
                        subtitle: totals(e.value),
                      ),
                    ),
                  ],
                );
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      '统计概览',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    totals(data.total),
                    const SizedBox(height: 16),
                    section('分类收支', data.categories, categoryNames),
                    const SizedBox(height: 16),
                    section('账户收支', data.accounts, accountNames),
                    const SizedBox(height: 16),
                    Text(
                      '每日收支趋势',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Text('紫色：收入；橙色：净支出。零线以下表示退款超过当日支出。'),
                    if (data.daily.isEmpty)
                      const Text('暂无数据')
                    else
                      _TrendChart(daily: data.daily),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.daily});
  final Map<String, LedgerTotals> daily;

  @override
  Widget build(BuildContext context) {
    final maxValue = daily.values.fold<int>(
      0,
      (max, value) => [
        max,
        value.income.abs(),
        value.expense.abs(),
      ].reduce((a, b) => a > b ? a : b),
    );
    final hasNegative = daily.values.any(
      (value) => value.expense < 0 || value.income < 0,
    );
    final colors = Theme.of(context).colorScheme;
    Widget bar(int amount, Color color) {
      final height = maxValue == 0
          ? 0.0
          : amount.abs() / maxValue * (hasNegative ? 85 : 150);
      return SizedBox(
        width: 14,
        height: hasNegative ? 170 : 150,
        child: Stack(
          children: [
            Positioned(
              left: 1,
              right: 1,
              top: hasNegative ? 85 : 150,
              child: Container(height: 1, color: colors.outline),
            ),
            Positioned(
              left: 1,
              right: 1,
              top: amount >= 0 ? (hasNegative ? 85 : 150) - height : 85,
              child: Container(
                height: height,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (final entry in daily.entries)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 16, 4, 0),
              child: Tooltip(
                message:
                    '${entry.key}\n收入 ${formatCny(entry.value.income)}\n净支出 ${formatCny(entry.value.expense)}',
                child: Column(
                  children: [
                    Row(
                      children: [
                        bar(entry.value.income, colors.primary),
                        bar(entry.value.expense, Colors.deepOrange),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.key.substring(5),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
