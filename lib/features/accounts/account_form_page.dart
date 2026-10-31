import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import 'accounts_page.dart';

class AccountFormPage extends ConsumerStatefulWidget {
  const AccountFormPage({super.key, this.accountId});
  final String? accountId;
  @override
  ConsumerState<AccountFormPage> createState() => _AccountFormPageState();
}

class _AccountFormPageState extends ConsumerState<AccountFormPage> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController();
  final amount = TextEditingController(text: '0.00');
  String type = 'cash';
  bool makeDefault = false;
  bool saving = false;
  Account? existing;
  bool loading = false;
  String? error;
  @override
  void initState() {
    super.initState();
    if (widget.accountId != null) _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final repo = ref.read(accountRepositoryProvider);
      final account = await repo.getById(widget.accountId!);
      if (account == null) throw StateError('账户不存在');
      final currentDefault = await repo.getDefault();
      if (!mounted) return;
      existing = account;
      name.text = account.name;
      type = account.accountType;
      final n = account.openingBalanceMinor;
      amount.text =
          '${n < 0 ? '-' : ''}${n.abs() ~/ 100}.${(n.abs() % 100).toString().padLeft(2, '0')}';
      makeDefault = currentDefault?.id == account.id;
    } catch (e) {
      if (mounted) error = '$e';
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    super.dispose();
  }

  int _parse(String input) {
    final value = input.trim();
    if (!RegExp(r'^-?\d+(\.\d{1,2})?$').hasMatch(value)) {
      throw const FormatException('请输入有效金额，最多两位小数');
    }
    final negative = value.startsWith('-');
    final parts = (negative ? value.substring(1) : value).split('.');
    final whole = int.tryParse(parts[0]);
    if (whole == null || whole > 1000000000) {
      throw const FormatException('金额超过允许范围');
    }
    final minor =
        whole * 100 +
        (parts.length == 2 ? int.parse(parts[1].padRight(2, '0')) : 0);
    return negative ? -minor : minor;
  }

  Future<void> _save() async {
    if (saving || !form.currentState!.validate()) return;
    setState(() => saving = true);
    try {
      final repo = ref.read(accountRepositoryProvider);
      String id;
      if (existing == null) {
        id = await repo.create(
          name: name.text,
          accountType: type,
          currency: 'CNY',
          openingBalanceMinor: _parse(amount.text),
          makeDefault: makeDefault,
        );
      } else {
        id = existing!.id;
        await repo.update(
          id: id,
          name: name.text,
          accountType: type,
          openingBalanceMinor: _parse(amount.text),
          makeDefault: makeDefault,
        );
      }
      ref.invalidate(defaultAccountProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.accountId == null ? '添加账户' : '编辑账户')),
    body: loading
        ? const Center(child: CircularProgressIndicator())
        : error != null
        ? Center(child: Text('读取失败：$error'))
        : Form(
            key: form,
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.viewInsetsOf(context).bottom + 24,
              ),
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '账户名称'),
                  validator: (v) => (v ?? '').trim().isEmpty ? '请输入账户名称' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: accountTypeLabels.containsKey(type)
                      ? type
                      : null,
                  decoration: const InputDecoration(labelText: '账户类型'),
                  items: accountTypeLabels.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: saving ? null : (v) => setState(() => type = v!),
                  validator: (v) => v == null ? '请选择账户类型' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '初始余额',
                    prefixText: '¥ ',
                  ),
                  validator: (v) {
                    try {
                      _parse(v ?? '');
                      return null;
                    } on FormatException catch (e) {
                      return e.message;
                    }
                  },
                ),
                const SizedBox(height: 16),
                InputDecorator(
                  decoration: const InputDecoration(labelText: '币种'),
                  child: Text(existing?.currency ?? 'CNY'),
                ),
                if (existing != null && existing!.currency != 'CNY')
                  const Text('此币种的精度尚未配置，无法在此编辑初始余额。'),
                SwitchListTile(
                  title: const Text('设为默认账户'),
                  value: makeDefault,
                  onChanged: saving || (existing != null && !existing!.isActive)
                      ? null
                      : (v) => setState(() => makeDefault = v),
                ),
                FilledButton(
                  onPressed:
                      saving ||
                          (existing != null && existing!.currency != 'CNY')
                      ? null
                      : _save,
                  child: Text(saving ? '保存中…' : '保存'),
                ),
              ],
            ),
          ),
  );
}
