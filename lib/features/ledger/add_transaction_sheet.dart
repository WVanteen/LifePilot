import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers.dart';

Future<void> showAddTransactionSheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => const _AddTransactionSheet(),
  );
}

class _AddTransactionSheet extends ConsumerStatefulWidget {
  const _AddTransactionSheet();
  @override
  ConsumerState<_AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<_AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  String _kind = 'expense';
  String? _categoryId;
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _categoryId == null) return;
    setState(() => _saving = true);
    try {
      await ref.read(ledgerRepositoryProvider).addManual(
        kind: _kind, amount: _amount.text, categoryId: _categoryId!, note: _note.text,
      );
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(const SnackBar(content: Text('账目已保存到本地')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('保存失败：$e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(ledgerCategoriesProvider);
    final candidates = categoriesAsync.value?.where((c) => c.type == _kind).toList() ?? [];
    final selected = candidates.any((c) => c.id == _categoryId) ? _categoryId : null;
    return Padding(
      padding: EdgeInsets.only(left: 22, right: 22, bottom: MediaQuery.viewInsetsOf(context).bottom + 24),
      child: Form(key: _formKey, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('新增账目', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        SegmentedButton<String>(segments: const [
          ButtonSegment(value: 'expense', label: Text('支出'), icon: Icon(Icons.remove)),
          ButtonSegment(value: 'income', label: Text('收入'), icon: Icon(Icons.add)),
        ], selected: {_kind}, onSelectionChanged: (value) => setState(() {
          _kind = value.first;
          _categoryId = null;
        })),
        const SizedBox(height: 16),
        TextFormField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '金额（人民币）', prefixText: '¥ '),
          validator: (value) {
            final raw = (value ?? '').trim();
            if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(raw)) return '请输入有效金额，最多两位小数';
            if (raw == '0' || raw == '0.0' || raw == '0.00') return '金额必须大于 0';
            return null;
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(_kind),
          initialValue: selected,
          decoration: const InputDecoration(labelText: '分类'),
          items: candidates.map((c) => DropdownMenuItem(value: c.id, child: Text(c.name))).toList(),
          validator: (v) => v == null ? '请选择分类' : null,
          onChanged: (v) => setState(() => _categoryId = v),
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _note, maxLines: 2, decoration: const InputDecoration(labelText: '备注（可选）')),
        const SizedBox(height: 20),
        FilledButton(onPressed: _saving ? null : _submit, child: Padding(
          padding: const EdgeInsets.all(12), child: Text(_saving ? '正在保存...' : '保存账目'),
        )),
      ]))),
    );
  }
}
