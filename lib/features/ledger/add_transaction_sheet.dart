import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/utils/money.dart';

Future<void> showAddTransactionSheet(BuildContext context) async {
  await showTransactionSheet(context);
}

Future<bool?> showTransactionSheet(
  BuildContext context, {
  LedgerTransaction? transaction,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) => _TransactionSheet(transaction: transaction),
  );
}

class _TransactionSheet extends ConsumerStatefulWidget {
  const _TransactionSheet({this.transaction});

  final LedgerTransaction? transaction;

  @override
  ConsumerState<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<_TransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late String _kind;
  late String? _categoryId;
  late String? _accountId;
  late DateTime _transactionDate;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final transaction = widget.transaction;
    _amount = TextEditingController(
      text: transaction == null ? '' : _amountInput(transaction.amountMinor),
    );
    _note = TextEditingController(text: transaction?.note ?? '');
    _kind = transaction?.kind ?? 'expense';
    _categoryId = transaction?.categoryId;
    _accountId = transaction?.accountId ?? 'acc_cash';
    _transactionDate =
        DateTime.tryParse(transaction?.localDate ?? '') ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _transactionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '选择交易日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (selected != null) setState(() => _transactionDate = selected);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() ||
        _categoryId == null ||
        _accountId == null) {
      return;
    }
    setState(() => _saving = true);
    try {
      final repository = ref.read(ledgerRepositoryProvider);
      if (widget.transaction == null) {
        await repository.addManual(
          kind: _kind,
          amount: _amount.text,
          categoryId: _categoryId!,
          accountId: _accountId!,
          transactionDate: _transactionDate,
          note: _note.text,
        );
      } else {
        await repository.updateManual(
          id: widget.transaction!.id,
          kind: _kind,
          amount: _amount.text,
          categoryId: _categoryId!,
          accountId: _accountId!,
          transactionDate: _transactionDate,
          note: _note.text,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
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
    final categoriesAsync = ref.watch(ledgerCategoriesProvider);
    final accountsAsync = ref.watch(ledgerAccountsProvider);
    final categories =
        categoriesAsync.value
            ?.where((category) => category.type == _kind)
            .toList() ??
        [];
    final accounts = accountsAsync.value ?? [];
    final selectedCategory =
        categories.any((category) => category.id == _categoryId)
        ? _categoryId
        : null;
    final selectedAccount = accounts.any((account) => account.id == _accountId)
        ? _accountId
        : null;
    final dataError = categoriesAsync.hasError
        ? categoriesAsync.error
        : accountsAsync.hasError
        ? accountsAsync.error
        : null;

    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.transaction == null ? '新增账目' : '编辑账目',
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'expense',
                    label: Text('支出'),
                    icon: Icon(Icons.remove),
                  ),
                  ButtonSegment(
                    value: 'income',
                    label: Text('收入'),
                    icon: Icon(Icons.add),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: _saving
                    ? null
                    : (value) => setState(() {
                        _kind = value.first;
                        _categoryId = null;
                      }),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _amount,
                autofocus: widget.transaction == null,
                enabled: !_saving,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: '金额（人民币）',
                  prefixText: '¥ ',
                ),
                validator: (value) {
                  try {
                    parseCnyMinor(value ?? '');
                    return null;
                  } on FormatException catch (error) {
                    return error.message;
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                key: ValueKey('category-$_kind-$selectedCategory'),
                initialValue: selectedCategory,
                decoration: const InputDecoration(labelText: '分类'),
                items: categories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                    )
                    .toList(),
                validator: (value) => value == null ? '请选择分类' : null,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _categoryId = value),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedAccount,
                decoration: const InputDecoration(labelText: '账户'),
                items: accounts
                    .map(
                      (account) => DropdownMenuItem(
                        value: account.id,
                        child: Text('${account.name} · ${account.currency}'),
                      ),
                    )
                    .toList(),
                validator: (value) => value == null ? '请选择账户' : null,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _accountId = value),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickDate,
                icon: const Icon(Icons.calendar_today_outlined),
                label: Text('交易日期：${localYmd(_transactionDate)}'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                enabled: !_saving,
                maxLines: 2,
                maxLength: 200,
                decoration: const InputDecoration(labelText: '备注（可选）'),
              ),
              if (categoriesAsync.isLoading || accountsAsync.isLoading) ...[
                const SizedBox(height: 12),
                const LinearProgressIndicator(),
              ],
              if (dataError != null) ...[
                const SizedBox(height: 12),
                Text(
                  '加载账户或分类失败：$dataError',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _saving || dataError != null ? null : _submit,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(_saving ? '正在保存...' : '保存账目'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _amountInput(int amountMinor) {
    final whole = amountMinor ~/ 100;
    final fraction = (amountMinor % 100).toString().padLeft(2, '0');
    return '$whole.$fraction';
  }
}
