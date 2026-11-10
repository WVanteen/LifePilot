import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/money.dart';
import 'task_event_repository.dart';

Future<void> showTaskEditor(BuildContext context, {Task? task}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _TaskEditor(task: task),
    );
Future<void> showEventEditor(
  BuildContext context,
  DateTime date, {
  Event? event,
}) => showDialog<void>(
  context: context,
  builder: (_) => _EventEditor(date: date, event: event),
);

Future<bool> _confirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        title: const Text('确认删除？'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialog, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialog, true),
            child: const Text('删除'),
          ),
        ],
      ),
    ) ??
    false;

class PlannerTasksTab extends ConsumerStatefulWidget {
  const PlannerTasksTab({super.key});
  @override
  ConsumerState<PlannerTasksTab> createState() => _PlannerTasksTabState();
}

class _PlannerTasksTabState extends ConsumerState<PlannerTasksTab> {
  String status = 'all', dateFilter = 'all', order = 'date';
  @override
  Widget build(BuildContext context) => StreamBuilder<List<Task>>(
    stream: ref.watch(taskEventRepositoryProvider).watchTasks(),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text('读取待办失败：${snapshot.error}'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final today = localYmd(DateTime.now());
      final tasks = snapshot.data!
          .where(
            (t) =>
                (status == 'all' || t.status == status) &&
                (dateFilter == 'all' ||
                    (dateFilter == 'none'
                        ? t.dueDate == null
                        : dateFilter == 'today'
                        ? t.dueDate == today
                        : t.dueDate != null &&
                              t.dueDate!.compareTo(today) < 0 &&
                              t.status != 'done')),
          )
          .toList();
      tasks.sort((a, b) {
        var d = (a.dueDate ?? '9999').compareTo(b.dueDate ?? '9999');
        if (d == 0) {
          d = (a.dueAtUtc ?? 9223372036854775807).compareTo(
            b.dueAtUtc ?? 9223372036854775807,
          );
        }
        final p = b.priority.compareTo(a.priority);
        return order == 'date' ? (d == 0 ? p : d) : (p == 0 ? d : p);
      });
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => showTaskEditor(context),
              icon: const Icon(Icons.add),
              label: const Text('新增待办'),
            ),
          ),
          Wrap(
            spacing: 8,
            children: [
              DropdownButton<String>(
                value: status,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('全部状态')),
                  DropdownMenuItem(value: 'todo', child: Text('未完成')),
                  DropdownMenuItem(value: 'done', child: Text('已完成')),
                ],
                onChanged: (v) => setState(() => status = v!),
              ),
              DropdownButton<String>(
                value: dateFilter,
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('全部日期')),
                  DropdownMenuItem(value: 'today', child: Text('今天到期')),
                  DropdownMenuItem(value: 'overdue', child: Text('已逾期')),
                  DropdownMenuItem(value: 'none', child: Text('无截止日期')),
                ],
                onChanged: (v) => setState(() => dateFilter = v!),
              ),
              DropdownButton<String>(
                value: order,
                items: const [
                  DropdownMenuItem(value: 'date', child: Text('按截止日期')),
                  DropdownMenuItem(value: 'priority', child: Text('按优先级')),
                ],
                onChanged: (v) => setState(() => order = v!),
              ),
            ],
          ),
          if (tasks.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('暂无符合条件的待办'),
            ),
          ...tasks.map(
            (t) => Card(
              child: ListTile(
                leading: Checkbox(
                  value: t.status == 'done',
                  onChanged: (v) async {
                    try {
                      await ref
                          .read(taskEventRepositoryProvider)
                          .setTaskDone(t.id, v ?? false);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
                      }
                    }
                  },
                ),
                title: Text(
                  t.title,
                  style: TextStyle(
                    decoration: t.status == 'done'
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                ),
                subtitle: Text(
                  '${t.dueDate ?? '无截止日期'}${t.dueAtUtc == null ? '' : ' ${TimeOfDay.fromDateTime(DateTime.fromMillisecondsSinceEpoch(t.dueAtUtc!, isUtc: true).toLocal()).format(context)}'} · ${['低', '中', '高'][t.priority.clamp(0, 2)]}优先级${t.details == null ? '' : '\n${t.details}'}',
                ),
                onTap: () => showTaskEditor(context, task: t),
                trailing: IconButton(
                  tooltip: '删除待办',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (!await _confirm(context, '待办将被删除。') || !context.mounted) {
                      return;
                    }
                    try {
                      await ref
                          .read(taskEventRepositoryProvider)
                          .deleteTask(t.id);
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
                      }
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class PlannerEventsTab extends ConsumerWidget {
  const PlannerEventsTab({super.key, required this.selectedDate});
  final DateTime selectedDate;
  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) => StreamBuilder<List<Event>>(
    stream: ref
        .watch(taskEventRepositoryProvider)
        .watchEventsForDate(selectedDate),
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(child: Text('读取日程失败：${snapshot.error}'));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: () => showEventEditor(context, selectedDate),
              icon: const Icon(Icons.add),
              label: const Text('新增日程'),
            ),
          ),
          if (snapshot.data!.isEmpty)
            const Padding(padding: EdgeInsets.all(16), child: Text('当天没有日程')),
          ...snapshot.data!.map(
            (e) => Card(
              child: ListTile(
                title: Text(e.title),
                subtitle: Text(
                  e.allDay
                      ? '全天 · ${e.eventDate}'
                      : e.startsAtUtc == null || e.endsAtUtc == null
                      ? '时间未设置'
                      : '${DateTime.fromMillisecondsSinceEpoch(e.startsAtUtc!, isUtc: true).toLocal().toString().substring(0, 16)} 至 ${DateTime.fromMillisecondsSinceEpoch(e.endsAtUtc!, isUtc: true).toLocal().toString().substring(0, 16)}',
                ),
                onTap: () => showEventEditor(context, selectedDate, event: e),
                trailing: IconButton(
                  tooltip: '删除日程',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (!await _confirm(context, '日程删除后无法恢复。') ||
                        !context.mounted) {
                      return;
                    }
                    try {
                      await ref
                          .read(taskEventRepositoryProvider)
                          .deleteEvent(e.id);
                    } catch (error) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(
                          context,
                        ).showSnackBar(SnackBar(content: Text('删除失败：$error')));
                      }
                    }
                  },
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _TaskEditor extends ConsumerStatefulWidget {
  const _TaskEditor({this.task});
  final Task? task;
  @override
  ConsumerState<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<_TaskEditor> {
  late final TextEditingController title, details;
  DateTime? date;
  TimeOfDay? time;
  int priority = 1;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final t = widget.task;
    title = TextEditingController(text: t?.title);
    details = TextEditingController(text: t?.details);
    date = DateTime.tryParse(t?.dueDate ?? '');
    priority = (t?.priority ?? 1).clamp(0, 2);
    if (t?.dueAtUtc != null) {
      time = TimeOfDay.fromDateTime(
        DateTime.fromMillisecondsSinceEpoch(
          t!.dueAtUtc!,
          isUtc: true,
        ).toLocal(),
      );
    }
  }

  @override
  void dispose() {
    title.dispose();
    details.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.task == null ? '新增待办' : '编辑待办'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: '标题'),
          ),
          TextField(
            controller: details,
            decoration: const InputDecoration(labelText: '描述（可选）'),
            maxLines: 2,
          ),
          DropdownButtonFormField<int>(
            initialValue: priority,
            decoration: const InputDecoration(labelText: '优先级'),
            items: const [
              DropdownMenuItem(value: 0, child: Text('低')),
              DropdownMenuItem(value: 1, child: Text('中')),
              DropdownMenuItem(value: 2, child: Text('高')),
            ],
            onChanged: (v) => setState(() => priority = v!),
          ),
          TextButton(
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: date ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (d != null && mounted) setState(() => date = d);
            },
            child: Text(
              date == null ? '选择截止日期（可选）' : '截止日期：${localYmd(date!)}',
            ),
          ),
          if (date != null)
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: time ?? TimeOfDay.now(),
                      );
                      if (t != null && mounted) setState(() => time = t);
                    },
                    child: Text(
                      time == null ? '设置截止时间' : time!.format(context),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '清除截止日期',
                  onPressed: () => setState(() {
                    date = null;
                    time = null;
                  }),
                  icon: const Icon(Icons.clear),
                ),
                if (time != null)
                  IconButton(
                    tooltip: '清除截止时间',
                    onPressed: () => setState(() => time = null),
                    icon: const Icon(Icons.access_time),
                  ),
              ],
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                setState(() => saving = true);
                try {
                  await ref
                      .read(taskEventRepositoryProvider)
                      .saveTask(
                        id: widget.task?.id,
                        title: title.text,
                        details: details.text,
                        priority: priority,
                        dueDate: date,
                        dueTime: time == null
                            ? null
                            : DateTime(2000, 1, 1, time!.hour, time!.minute),
                      );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
                  }
                } finally {
                  if (mounted) setState(() => saving = false);
                }
              },
        child: Text(saving ? '保存中…' : '保存'),
      ),
    ],
  );
}

class _EventEditor extends ConsumerStatefulWidget {
  const _EventEditor({required this.date, this.event});
  final DateTime date;
  final Event? event;
  @override
  ConsumerState<_EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends ConsumerState<_EventEditor> {
  late final TextEditingController title, description;
  late DateTime start, end;
  late bool allDay;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    final e = widget.event;
    title = TextEditingController(text: e?.title);
    description = TextEditingController(text: e?.description);
    final d = DateTime.tryParse(e?.eventDate ?? '') ?? widget.date;
    start = e?.startsAtUtc == null
        ? DateTime(d.year, d.month, d.day, 9)
        : DateTime.fromMillisecondsSinceEpoch(
            e!.startsAtUtc!,
            isUtc: true,
          ).toLocal();
    end = e?.endsAtUtc == null
        ? start.add(const Duration(hours: 1))
        : DateTime.fromMillisecondsSinceEpoch(
            e!.endsAtUtc!,
            isUtc: true,
          ).toLocal();
    allDay = e?.allDay ?? false;
  }

  @override
  void dispose() {
    title.dispose();
    description.dispose();
    super.dispose();
  }

  Future<DateTime?> pick(DateTime value, {required bool withTime}) async {
    final d = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (d == null || !mounted) return null;
    if (!withTime) return DateTime(d.year, d.month, d.day);
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    return t == null
        ? null
        : DateTime(d.year, d.month, d.day, t.hour, t.minute);
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.event == null ? '新增日程' : '编辑日程'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: title,
            decoration: const InputDecoration(labelText: '标题'),
          ),
          TextField(
            controller: description,
            decoration: const InputDecoration(labelText: '描述（可选）'),
            maxLines: 2,
          ),
          SwitchListTile(
            value: allDay,
            onChanged: (v) => setState(() => allDay = v),
            title: const Text('全天'),
          ),
          TextButton(
            onPressed: () async {
              final d = await pick(start, withTime: !allDay);
              if (d != null && mounted) setState(() => start = d);
            },
            child: Text(
              allDay
                  ? '日期：${localYmd(start)}'
                  : '开始：${start.toString().substring(0, 16)}',
            ),
          ),
          if (!allDay)
            TextButton(
              onPressed: () async {
                final d = await pick(end, withTime: true);
                if (d != null && mounted) setState(() => end = d);
              },
              child: Text('结束：${end.toString().substring(0, 16)}'),
            ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: saving
            ? null
            : () async {
                setState(() => saving = true);
                try {
                  await ref
                      .read(taskEventRepositoryProvider)
                      .saveEvent(
                        id: widget.event?.id,
                        title: title.text,
                        description: description.text,
                        date: start,
                        allDay: allDay,
                        start: start,
                        end: end,
                      );
                  if (context.mounted) Navigator.pop(context);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
                  }
                } finally {
                  if (mounted) setState(() => saving = false);
                }
              },
        child: Text(saving ? '保存中…' : '保存'),
      ),
    ],
  );
}
