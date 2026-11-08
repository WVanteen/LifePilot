import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/utils/money.dart';
import 'transfer_refund_service.dart';

class ExtendedTransactionPage extends ConsumerStatefulWidget {
  const ExtendedTransactionPage({super.key, this.transaction});
  final LedgerTransaction? transaction;
  @override
  ConsumerState<ExtendedTransactionPage> createState() =>
      _ExtendedTransactionPageState();
}

class _ExtendedTransactionPageState
    extends ConsumerState<ExtendedTransactionPage> {
  final _amount = TextEditingController();
  final _note = TextEditingController();
  final _operation = const Uuid().v4();
  String _kind = 'transfer';
  String? _from, _to, _expense;
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    if (t != null) {
      _kind = t.kind;
      _from = t.accountId;
      _to = t.targetAccountId;
      _expense = t.refundOfId;
      _amount.text =
          '${t.amountMinor ~/ 100}.${(t.amountMinor % 100).toString().padLeft(2, '0')}';
      _note.text = t.note ?? '';
      _date = DateTime.tryParse(t.localDate) ?? DateTime.now();
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final amount = parseCnyMinor(_amount.text);
      final service = TransferRefundService(ref.read(appDatabaseProvider));
      final existing = widget.transaction;
      if (_kind == 'transfer') {
        if (_from == null || _to == null) {
          throw const FormatException('请选择转出和转入账户');
        }
        if (existing == null) {
          await service.addTransfer(
            operationId: _operation,
            accountId: _from!,
            targetAccountId: _to!,
            amountMinor: amount,
            date: _date,
            note: _note.text,
          );
        } else {
          await service.editTransfer(
            id: existing.id,
            accountId: _from!,
            targetAccountId: _to!,
            amountMinor: amount,
            date: _date,
            note: _note.text,
          );
        }
      } else {
        if (existing == null) {
          if (_expense == null) throw const FormatException('请选择原支出');
          await service.addRefund(
            operationId: _operation,
            expenseId: _expense!,
            amountMinor: amount,
            date: _date,
            note: _note.text,
          );
        } else {
          await service.editRefund(
            id: existing.id,
            amountMinor: amount,
            date: _date,
            note: _note.text,
          );
        }
      }
      if (mounted) Navigator.pop(context);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(ledgerAccountsProvider);
    final entries = ref.watch(ledgerEntriesProvider);
    final allAccounts = accounts.value ?? [];
    final availableFrom = allAccounts
        .where((a) => a.isActive || a.id == widget.transaction?.accountId)
        .toList();
    final availableTo = allAccounts
        .where((a) => a.isActive || a.id == widget.transaction?.targetAccountId)
        .toList();
    final expenses = (entries.value ?? [])
        .where((e) => e.kind == 'expense')
        .toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.transaction == null
              ? '转账与退款'
              : '编辑${_kind == 'transfer' ? '转账' : '退款'}',
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (widget.transaction == null)
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'transfer', label: Text('转账')),
                ButtonSegment(value: 'refund', label: Text('退款')),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
          if (accounts.isLoading || entries.isLoading)
            const LinearProgressIndicator(),
          if (accounts.hasError || entries.hasError)
            const Text('账户或流水加载失败，请返回重试'),
          if (_kind == 'transfer') ...[
            DropdownButtonFormField<String>(
              initialValue: _from,
              decoration: const InputDecoration(labelText: '转出账户'),
              items: availableFrom
                  .map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.name}${a.isActive ? '' : ' · 已停用'}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _from = v),
            ),
            DropdownButtonFormField<String>(
              initialValue: _to,
              decoration: const InputDecoration(labelText: '转入账户'),
              items: availableTo
                  .map(
                    (a) => DropdownMenuItem(
                      value: a.id,
                      child: Text('${a.name}${a.isActive ? '' : ' · 已停用'}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _to = v),
            ),
          ] else if (widget.transaction == null) ...[
            DropdownButtonFormField<String>(
              initialValue: _expense,
              decoration: const InputDecoration(labelText: '原支出'),
              items: expenses
                  .map(
                    (e) => DropdownMenuItem(
                      value: e.id,
                      child: Text(
                        '${e.localDate} · ${formatCny(e.amountMinor)} · ${e.merchant ?? e.note ?? '支出'}',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _expense = v),
            ),
            if (expenses.isEmpty && !entries.isLoading) const Text('暂无可关联的支出'),
          ] else
            Text('原支出：${widget.transaction!.refundOfId}'),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '金额（元）'),
          ),
          TextField(
            controller: _note,
            maxLength: 200,
            decoration: const InputDecoration(labelText: '备注（可选）'),
          ),
          TextButton.icon(
            onPressed: () async {
              final date = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
              );
              if (date != null) setState(() => _date = date);
            },
            icon: const Icon(Icons.date_range),
            label: Text('交易日期：${localYmd(_date)}'),
          ),
        ],
      ),
    );
  }
}
