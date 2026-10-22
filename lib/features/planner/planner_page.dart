import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../shared/section_card.dart';
import 'add_task_sheet.dart';
import 'add_journal_sheet.dart';

class PlannerPage extends ConsumerWidget {
  const PlannerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(length: 3, child: Column(children: [
      Padding(padding: const EdgeInsets.fromLTRB(20, 22, 20, 8), child: Align(
        alignment: Alignment.centerLeft,
        child: Text('计划与记录', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      )),
      const TabBar(tabs: [Tab(text: '待办'), Tab(text: '日程'), Tab(text: '日记')]),
      Expanded(child: TabBarView(children: [
        _TasksTab(ref: ref),
        const _EventsPlaceholder(),
        _JournalTab(ref: ref),
      ])),
    ]));
  }
}

class _TasksTab extends StatelessWidget {
  const _TasksTab({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(activeTasksProvider);
    return ListView(padding: const EdgeInsets.all(20), children: [
      Align(alignment: Alignment.centerRight, child: FilledButton.icon(
        onPressed: () => showAddTaskSheet(context), icon: const Icon(Icons.add), label: const Text('新增待办'),
      )),
      const SizedBox(height: 12),
      tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('读取待办失败：$e'),
        data: (rows) => rows.isEmpty
          ? const SectionCard(child: Text('还没有待办，点击「新增待办」创建第一项。'))
          : Column(children: rows.map((t) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SectionCard(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4), child: CheckboxListTile(
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              value: t.status == 'done',
              onChanged: (_) => ref.read(plannerRepositoryProvider).toggleTask(t),
              title: Text(t.title, style: TextStyle(decoration: t.status == 'done' ? TextDecoration.lineThrough : null)),
              subtitle: t.dueDate == null ? null : Text('日期：${t.dueDate}（未设置具体提醒时间）'),
            )),
          )).toList()),
      ),
    ]);
  }
}

class _EventsPlaceholder extends StatelessWidget {
  const _EventsPlaceholder();
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: const [
    SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('日程模块 · 数据层已建立', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
      SizedBox(height: 9),
      Text('Events 数据表已就绪，日历视图、日程表单和通知调度会在第 3–4 周开发。'),
    ])),
  ]);
}

class _JournalTab extends StatelessWidget {
  const _JournalTab({required this.ref});
  final WidgetRef ref;
  @override
  Widget build(BuildContext context) {
    final journals = ref.watch(journalEntriesProvider);
    return ListView(padding: const EdgeInsets.all(20), children: [
      Align(alignment: Alignment.centerRight, child: FilledButton.icon(
        onPressed: () => showAddJournalSheet(context), icon: const Icon(Icons.edit_note), label: const Text('写记录'),
      )),
      const SizedBox(height: 12),
      journals.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Text('读取日记失败：$e'),
        data: (rows) => rows.isEmpty
          ? const SectionCard(child: Text('还没有每日记录。今天发生了什么？'))
          : Column(children: rows.map((j) => Padding(padding: const EdgeInsets.only(bottom: 8),
            child: SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(j.journalDate, style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8), Text(j.content),
            ]))),
          ).toList()),
      ),
    ]);
  }
}
