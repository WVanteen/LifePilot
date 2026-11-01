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
  bool _accountChosen = false;

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
    _accountId = transaction?.accountId;
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
    final defaultAccount = ref.read(defaultAccountProvider);
    final accountId = widget.transaction == null && !_accountChosen
        ? defaultAccount.value?.id
        : _accountId;
    if (!_formKey.currentState!.validate() ||
        _categoryId == null ||
        accountId == null ||
        defaultAccount.hasError ||
        defaultAccount.isLoading) {
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
          accountId: accountId,
          transactionDate: _transactionDate,
          note: _note.text,
        );
      } else {
        await repository.updateManual(
          id: widget.transaction!.id,
          kind: _kind,
          amount: _amount.text,
          categoryId: _categoryId!,
          accountId: accountId,
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
    final defaultAsync = ref.watch(defaultAccountProvider);
    final categories =
        categoriesAsync.value
            ?.where(
              (category) =>
                  category.type == _kind &&
                  (category.isActive ||
                      (category.id == widget.transaction?.categoryId &&
                          _kind == widget.transaction?.kind)),
            )
            .toList() ??
        [];
    final accounts = (accountsAsync.value ?? [])
        .where(
          (account) =>
              account.isActive || account.id == widget.transaction?.accountId,
        )
        .toList();
    final selectedCategory =
        categories.any((category) => category.id == _categoryId)
        ? _categoryId
        : null;
    final requestedAccount = widget.transaction == null && !_accountChosen
        ? defaultAsync.value?.id
        : _accountId;
    final selectedAccount =
        accounts.any((account) => account.id == requestedAccount)
        ? requestedAccount
        : null;
    final dataError = categoriesAsync.hasError
        ? categoriesAsync.error
        : accountsAsync.hasError
        ? accountsAsync.error
        : defaultAsync.hasError
        ? defaultAsync.error
        : null;
    final balance = selectedAccount == null
        ? null
        : ref.watch(accountBalanceProvider(selectedAccount));
    final selected = accounts
        .where((account) => account.id == selectedAccount)
        .firstOrNull;

    return Padding(
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.transaction == null ? '新增账目' : '编辑账目',
                    style: const TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                FilledButton(
                  onPressed:
                      _saving ||
                          dataError != null ||
                          accountsAsync.isLoading ||
                          defaultAsync.isLoading
                      ? null
                      : _submit,
                  child: Text(_saving ? '保存中…' : '保存'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                              child: Text(
                                '${category.name}${category.isActive ? '' : ' · 已停用'}',
                              ),
                            ),
                          )
                          .toList(),
                      validator: (value) => value == null ? '请选择分类' : null,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _categoryId = value),
                    ),
                    if (!categoriesAsync.isLoading &&
                        !categoriesAsync.hasError &&
                        categories.isEmpty)
                      const Text('没有可用分类，请前往“我的”添加或恢复分类。'),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      key: ValueKey('account-$selectedAccount'),
                      initialValue: selectedAccount,
                      decoration: const InputDecoration(labelText: '账户'),
                      items: accounts
                          .map(
                            (account) => DropdownMenuItem(
                              value: account.id,
                              child: Text(
                                '${account.name} · ${_typeName(account.accountType)}${account.id == defaultAsync.value?.id ? ' · 默认' : ''}${account.isActive ? '' : ' · 已停用'}',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      validator: (value) => value == null ? '请选择账户' : null,
                      onChanged: _saving
                          ? null
                          : (value) => setState(() {
                              _accountChosen = true;
                              _accountId = value;
                            }),
                    ),
                    if (balance != null && selected != null)
                      balance.when(
                        loading: () => const Text('余额加载中…'),
                        error: (error, _) => Text('余额读取失败：$error'),
                        data: (value) => Text(
                          selected.currency == 'CNY'
                              ? '余额：${formatCny(value)}'
                              : '余额：${selected.currency} $value 最小单位',
                        ),
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
                    if (categoriesAsync.isLoading ||
                        accountsAsync.isLoading ||
                        defaultAsync.isLoading) ...[
                      const SizedBox(height: 12),
                      const LinearProgressIndicator(),
                    ],
                    if (dataError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        '加载账户或分类失败：$dataError',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _amountInput(int amountMinor) {
    final whole = amountMinor ~/ 100;
    final fraction = (amountMinor % 100).toString().padLeft(2, '0');
    return '$whole.$fraction';
  }

  static String _typeName(String type) =>
      const {
        'cash': '现金',
        'bank': '银行卡',
        'wechat': '微信',
        'alipay': '支付宝',
        'other': '其他',
      }[type] ??
      type;
}
