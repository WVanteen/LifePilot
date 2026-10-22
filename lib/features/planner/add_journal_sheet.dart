import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

Future<void> showAddJournalSheet(BuildContext context) async => showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _JournalForm(),
    );

class _JournalForm extends ConsumerStatefulWidget {
  const _JournalForm();
  @override
  ConsumerState<_JournalForm> createState() => _JournalFormState();
}

class _JournalFormState extends ConsumerState<_JournalForm> {
  final _controller = TextEditingController();
  bool _saving = false;
  @override
  void dispose() { _controller.dispose(); super.dispose(); }

  Future<void> _save() async {
    if (_controller.text.trim().isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(plannerRepositoryProvider).addJournal(_controller.text);
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
      const Text('写一条今日记录', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 14),
      TextField(controller: _controller, autofocus: true, minLines: 3, maxLines: 6, decoration: const InputDecoration(hintText: '今天做了什么？有什么值得记住的？')),
      const SizedBox(height: 14),
      FilledButton(onPressed: _saving ? null : _save, child: const Text('保存记录')),
    ]),
  );
}
