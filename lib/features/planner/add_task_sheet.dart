import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';
import '../../core/utils/money.dart';

Future<void> showAddTaskSheet(BuildContext context) async => showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _TaskForm(),
    );

class _TaskForm extends ConsumerStatefulWidget {
  const _TaskForm();
  @override
  ConsumerState<_TaskForm> createState() => _TaskFormState();
}

class _TaskFormState extends ConsumerState<_TaskForm> {
  final _controller = TextEditingController();
  DateTime? _date;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(plannerRepositoryProvider).addTask(_controller.text, dueDate: _date);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.viewInsetsOf(context).bottom + 22),
    child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('新增待办', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 14),
      TextField(controller: _controller, autofocus: true, decoration: const InputDecoration(labelText: '要做什么？')),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: () async {
          final now = DateTime.now();
          final chosen = await showDatePicker(context: context, initialDate: _date ?? now, firstDate: DateTime(now.year - 1), lastDate: DateTime(now.year + 8));
          if (chosen != null && mounted) setState(() => _date = chosen);
        },
        icon: const Icon(Icons.calendar_today_outlined),
        label: Text(_date == null ? '选择日期（可选）' : localYmd(_date!)),
      ),
      const SizedBox(height: 12),
      FilledButton(onPressed: _saving ? null : _save, child: const Text('保存待办')),
      const SizedBox(height: 4),
      const Text('第一周只记录日期，不会发送提醒通知。', style: TextStyle(fontSize: 12), textAlign: TextAlign.center),
    ]),
  );
}
