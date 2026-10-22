import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/utils/money.dart';
import '../../shared/section_card.dart';
import 'add_transaction_sheet.dart';

class LedgerPage extends ConsumerWidget {
  const LedgerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(ledgerEntriesProvider);
    final categories = ref.watch(ledgerCategoriesProvider).value ?? [];
    final categoryNames = {for (final c in categories) c.id: c.name};
    final month = localYmd(DateTime.now()).substring(0, 7);
    final current = entries.value?.where((t) => t.localDate.startsWith(month)).toList() ?? [];
    final income = current.where((t) => t.kind == 'income').fold<int>(0, (s, t) => s + t.amountMinor);
    final expense = current.where((t) => t.kind == 'expense').fold<int>(0, (s, t) => s + t.amountMinor);

    return ListView(padding: const EdgeInsets.fromLTRB(20, 20, 20, 24), children: [
      Row(children: [
        Expanded(child: Text('记账', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700))),
        FilledButton.icon(onPressed: () => showAddTransactionSheet(context), icon: const Icon(Icons.add), label: const Text('记一笔')),
      ]),
      const SizedBox(height: 16),
      SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('$month 月度概览', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _Amount(label: '收入', value: formatCny(income))),
          Expanded(child: _Amount(label: '支出', value: formatCny(expense))),
        ]),
        const SizedBox(height: 12),
        Text('结余 ${formatCny(income - expense)}', style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        const Text('第 1 周暂只开放人民币收入、支出；转账和退款将在后续完成。', style: TextStyle(fontSize: 12)),
      ])),
      const SizedBox(height: 18),
      const Text('全部流水', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
      const SizedBox(height: 10),
      entries.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('读取账本失败：$e'),
        data: (rows) => rows.isEmpty
            ? const SectionCard(child: Text('还没有账目。点击右上方的「记一笔」创建第一条记录。'))
            : Column(children: rows.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: SectionCard(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(child: Icon(t.kind == 'expense' ? Icons.arrow_upward : Icons.arrow_downward)),
                  title: Text(categoryNames[t.categoryId] ?? '其他'),
                  subtitle: Text('${t.localDate}${t.note == null ? '' : ' · ${t.note}'}'),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text('${t.kind == 'expense' ? '-' : '+'}${formatCny(t.amountMinor)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                    PopupMenuButton<String>(tooltip: '账目操作', onSelected: (action) async {
                      if (action != 'delete') return;
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (dialogContext) => AlertDialog(
                          title: const Text('删除账目？'),
                          content: const Text('删除后不会显示在流水和统计中。'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dialogContext).pop(false),
                              child: const Text('取消'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(dialogContext).pop(true),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed != true || !context.mounted) return;
                      try {
                        await ref.read(ledgerRepositoryProvider).softDelete(t.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('账目已删除')),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('删除失败：$e')),
                          );
                        }
                      }
                    }, itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('删除'))]),
                  ]),
                ))),
              ).toList()),
      ),
    ]);
  }
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    const SizedBox(height: 6),
    Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
  ]);
}
