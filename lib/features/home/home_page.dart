import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/providers.dart';
import '../../core/utils/money.dart';
import '../../shared/section_card.dart';
import '../ledger/add_transaction_sheet.dart';
import '../planner/add_task_sheet.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(ledgerEntriesProvider);
    final tasks = ref.watch(activeTasksProvider);
    final now = DateTime.now();
    final month = localYmd(now).substring(0, 7);
    final monthExpense = entries.value?.where((t) => t.localDate.startsWith(month) && t.kind == 'expense')
            .fold<int>(0, (sum, t) => sum + t.amountMinor) ?? 0;
    final pending = tasks.value?.where((t) => t.status != 'done').length ?? 0;
    final greeting = now.hour < 11 ? '早上好' : now.hour < 18 ? '下午好' : '晚上好';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 28),
      children: [
        Text('LifePilot  ·  $greeting', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text('${now.year} 年 ${now.month} 月 ${now.day} 日 · 为你的每一天留个记录',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 22),
        Row(children: [
          Expanded(child: _MetricTile(label: '本月支出', value: formatCny(monthExpense), icon: Icons.wallet_outlined)),
          const SizedBox(width: 12),
          Expanded(child: _MetricTile(label: '未完成待办', value: '$pending 项', icon: Icons.task_alt)),
        ]),
        const SizedBox(height: 16),
        SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.bolt_outlined), SizedBox(width: 8), Text('快捷操作', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(child: FilledButton.tonalIcon(onPressed: () => showAddTransactionSheet(context), icon: const Icon(Icons.add), label: const Text('记一笔'))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(onPressed: () => showAddTaskSheet(context), icon: const Icon(Icons.check_circle_outline), label: const Text('加待办'))),
          ]),
        ])),
        const SizedBox(height: 16),
        SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('近期待办', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))),
            TextButton(onPressed: () => context.go('/planner'), child: const Text('查看全部')),
          ]),
          ...tasks.when(
            loading: () => [const LinearProgressIndicator()],
            error: (e, _) => [Text('待办加载失败：$e')],
            data: (rows) {
              final upcoming = rows.where((t) => t.status != 'done').take(3).toList();
              if (upcoming.isEmpty) return [const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('还没有未完成待办，点击上方「加待办」开始。'))];
              return upcoming.map((t) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.radio_button_unchecked), title: Text(t.title), subtitle: t.dueDate == null ? null : Text('截止：${t.dueDate}'))).toList();
            },
          ),
        ])),
        const SizedBox(height: 16),
        SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [Icon(Icons.auto_awesome), SizedBox(width: 8), Text('AI 助手', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700))]),
          const SizedBox(height: 10),
          const Text('自然语言识别、智能提醒和每日总结将在后续阶段接入。当前应用无需联网即可记账和管理待办。'),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.go('/assistant'), child: const Text('了解计划 →'))),
        ])),
      ],
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.label, required this.value, required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => SectionCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 7),
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
        ]),
      );
}
