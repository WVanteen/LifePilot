import 'package:flutter/material.dart';

import '../../core/database/app_database.dart';
import '../../core/utils/money.dart';

/// A live detail view. Data loading and mutations remain with the caller.
class LedgerDetailPage extends StatelessWidget {
  const LedgerDetailPage({
    super.key,
    required this.transaction,
    required this.accountNames,
    required this.categoryNames,
    this.onEdit,
  });

  final Stream<LedgerTransaction?> transaction;
  final Map<String, String> accountNames;
  final Map<String, String> categoryNames;
  final Future<void> Function(BuildContext, LedgerTransaction)? onEdit;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('账目详情')),
    body: StreamBuilder<LedgerTransaction?>(
      stream: transaction,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('读取账目失败：${snapshot.error}'));
        }
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final entry = snapshot.data;
        if (entry == null) return const Center(child: Text('账目不存在或已删除'));
        final type = _kindLabel(entry.kind);
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(type, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              formatCny(entry.amountMinor),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            _DetailRow(label: '交易日期', value: entry.localDate),
            _DetailRow(
              label: entry.kind == 'transfer' ? '转出账户' : '账户',
              value: accountNames[entry.accountId] ?? '未知账户',
            ),
            if (entry.targetAccountId != null)
              _DetailRow(
                label: '转入账户',
                value: accountNames[entry.targetAccountId] ?? '未知账户',
              ),
            if (entry.categoryId != null)
              _DetailRow(
                label: '分类',
                value: categoryNames[entry.categoryId] ?? '未知分类',
              ),
            if (entry.refundOfId != null)
              _DetailRow(label: '原支出编号', value: entry.refundOfId!),
            _DetailRow(
              label: '商家',
              value: entry.merchant?.isNotEmpty == true
                  ? entry.merchant!
                  : '未填写',
            ),
            _DetailRow(
              label: '备注',
              value: entry.note?.isNotEmpty == true ? entry.note! : '未填写',
            ),
            if (onEdit != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => onEdit!(context, entry),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('编辑账目'),
              ),
            ],
          ],
        );
      },
    ),
  );
}

/// The caller supplies soft-deleted records and the validated restoration operation.
class LedgerRecycleBinPage extends StatefulWidget {
  const LedgerRecycleBinPage({
    super.key,
    required this.transactions,
    required this.accountNames,
    required this.categoryNames,
    required this.onRestore,
  });

  final Stream<List<LedgerTransaction>> transactions;
  final Map<String, String> accountNames;
  final Map<String, String> categoryNames;
  final Future<void> Function(String) onRestore;

  @override
  State<LedgerRecycleBinPage> createState() => _LedgerRecycleBinPageState();
}

class _LedgerRecycleBinPageState extends State<LedgerRecycleBinPage> {
  final _pending = <String>{};

  Future<void> _restore(String id) async {
    if (_pending.contains(id)) return;
    setState(() => _pending.add(id));
    try {
      await widget.onRestore(id);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('账目已恢复')));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('恢复失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _pending.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('账目回收站')),
    body: StreamBuilder<List<LedgerTransaction>>(
      stream: widget.transactions,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('读取回收站失败：${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final rows = snapshot.data!;
        if (rows.isEmpty) return const Center(child: Text('回收站为空'));
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final entry = rows[index];
            final category =
                widget.categoryNames[entry.categoryId] ??
                _kindLabel(entry.kind);
            final account = widget.accountNames[entry.accountId] ?? '未知账户';
            return Card(
              child: ListTile(
                title: Text('$category · ${formatCny(entry.amountMinor)}'),
                subtitle: Text('${entry.localDate} · $account'),
                trailing: TextButton(
                  onPressed: _pending.contains(entry.id)
                      ? null
                      : () => _restore(entry.id),
                  child: Text(_pending.contains(entry.id) ? '恢复中' : '恢复'),
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

String _kindLabel(String kind) => switch (kind) {
  'expense' => '支出',
  'income' => '收入',
  'transfer' => '转账',
  'refund' => '退款',
  _ => '未知类型',
};

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    trailing: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: Text(value, textAlign: TextAlign.end),
    ),
  );
}
