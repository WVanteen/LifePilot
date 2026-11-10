import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/utils/money.dart';
import 'journal_repository.dart';
import 'journal_page.dart';
import 'task_event_repository.dart';
import 'task_event_pages.dart';

class PlannerPage extends ConsumerStatefulWidget {
  const PlannerPage({super.key});

  @override
  ConsumerState<PlannerPage> createState() => _PlannerPageState();
}

class _PlannerPageState extends ConsumerState<PlannerPage> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  late final TaskEventRepository _tasks;
  late final JournalRepository _journal;

  @override
  void initState() {
    super.initState();
    final db = ref.read(appDatabaseProvider);
    _tasks = TaskEventRepository(db);
    _journal = JournalRepository(db);
  }

  Future<void> _selectDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      helpText: '选择查看日期',
    );
    if (date != null && mounted) {
      setState(() => _date = DateUtils.dateOnly(date));
    }
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 3,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  '计划与记录',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: _selectDate,
                icon: const Icon(Icons.calendar_month),
                label: Text(localYmd(_date)),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: () => showModalBottomSheet<void>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            showDragHandle: true,
            builder: (_) =>
                _DailyOverview(date: _date, tasks: _tasks, journal: _journal),
          ),
          icon: const Icon(Icons.view_agenda_outlined),
          label: const Text('查看当天概览'),
        ),
        const TabBar(
          tabs: [
            Tab(text: '待办'),
            Tab(text: '日程'),
            Tab(text: '日记'),
          ],
        ),
        Expanded(
          child: TabBarView(
            children: [
              const PlannerTasksTab(),
              PlannerEventsTab(selectedDate: _date),
              JournalSection(repository: _journal, selectedDate: _date),
            ],
          ),
        ),
      ],
    ),
  );
}

class _DailyOverview extends StatelessWidget {
  const _DailyOverview({
    required this.date,
    required this.tasks,
    required this.journal,
  });
  final DateTime date;
  final TaskEventRepository tasks;
  final JournalRepository journal;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SizedBox(
      height: MediaQuery.sizeOf(context).height * .7,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
        children: [
          Text(
            '${localYmd(date)} 当天概览',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 16),
          Text('当天到期待办', style: Theme.of(context).textTheme.titleMedium),
          StreamBuilder(
            stream: tasks.watchTasks(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Text('待办读取失败');
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final rows = snapshot.data!
                  .where((task) => task.dueDate == localYmd(date))
                  .toList();
              if (rows.isEmpty) return const Text('当天没有到期待办');
              return Column(
                children: [
                  for (final task in rows)
                    ListTile(
                      dense: true,
                      title: Text(task.title),
                      subtitle: Text(task.status == 'done' ? '已完成' : '未完成'),
                    ),
                ],
              );
            },
          ),
          const Divider(),
          Text('当天日程', style: Theme.of(context).textTheme.titleMedium),
          StreamBuilder(
            stream: tasks.watchEventsForDate(date),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Text('日程读取失败');
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final rows = snapshot.data!;
              if (rows.isEmpty) return const Text('当天没有日程');
              return Column(
                children: [
                  for (final event in rows)
                    ListTile(
                      dense: true,
                      title: Text(event.title),
                      subtitle: Text(event.allDay ? '全天' : '定时日程'),
                    ),
                ],
              );
            },
          ),
          const Divider(),
          Text('当天日记', style: Theme.of(context).textTheme.titleMedium),
          StreamBuilder(
            stream: journal.watch(date: date),
            builder: (context, snapshot) {
              if (snapshot.hasError) return const Text('日记读取失败');
              if (!snapshot.hasData) return const LinearProgressIndicator();
              final rows = snapshot.data!;
              if (rows.isEmpty) return const Text('当天没有日记');
              return Column(
                children: [
                  for (final entry in rows)
                    ListTile(
                      dense: true,
                      title: Text(
                        entry.title?.isNotEmpty == true ? entry.title! : '无标题',
                      ),
                      subtitle: Text(
                        entry.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    ),
  );
}
