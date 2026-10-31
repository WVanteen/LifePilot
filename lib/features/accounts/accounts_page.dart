import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/utils/money.dart';

const accountTypeLabels = {'cash': '现金', 'bank': '银行卡', 'wechat': '微信', 'alipay': '支付宝', 'other': '其他'};
const accountTypeIcons = {'cash': Icons.payments_outlined, 'bank': Icons.account_balance_outlined, 'wechat': Icons.chat_outlined, 'alipay': Icons.account_balance_wallet_outlined, 'other': Icons.wallet_outlined};

class AccountsPage extends ConsumerWidget {
  const AccountsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accounts = ref.watch(managedAccountsProvider);
    final defaultAccount = ref.watch(defaultAccountProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('账户管理')),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.push('/settings/accounts/new'), icon: const Icon(Icons.add), label: const Text('添加账户')),
      body: accounts.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('读取账户失败：$e')),
        data: (rows) {
          final active = rows.where((a) => a.isActive).toList();
          final inactive = rows.where((a) => !a.isActive).toList();
          final balances = active.where((a) => a.currency == 'CNY').map((a) => ref.watch(accountBalanceProvider(a.id))).toList();
          final total = balances.any((b) => b.hasError) ? '读取失败' : balances.any((b) => b.isLoading || !b.hasValue) ? '加载中…' : formatCny(balances.fold<int>(0, (sum, b) => sum + b.requireValue));
          return ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
            Card(child: ListTile(title: const Text('启用账户总余额（人民币）'), subtitle: Text(total, style: Theme.of(context).textTheme.headlineSmall))),
            if (rows.any((a) => a.currency != 'CNY')) const Padding(padding: EdgeInsets.all(8), child: Text('其他币种未计入人民币总额。')),
            if (defaultAccount.hasError) Text('读取默认账户失败：${defaultAccount.error}'),
            const SizedBox(height: 12),
            const Text('启用账户', style: TextStyle(fontWeight: FontWeight.bold)),
            if (active.isEmpty) const Padding(padding: EdgeInsets.all(16), child: Text('暂无启用账户，请添加账户。')),
            ...active.map((a) => _AccountCard(account: a, isDefault: defaultAccount.value?.id == a.id)),
            if (inactive.isNotEmpty) ExpansionTile(title: Text('已停用账户（${inactive.length}）'), children: inactive.map((a) => _AccountCard(account: a, isDefault: false)).toList()),
          ]);
        },
      ),
    );
  }
}

class _AccountCard extends ConsumerWidget {
  const _AccountCard({required this.account, required this.isDefault});
  final Account account;
  final bool isDefault;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balance = ref.watch(accountBalanceProvider(account.id));
    return Card(child: ListTile(
      leading: CircleAvatar(child: Icon(accountTypeIcons[account.accountType] ?? Icons.wallet_outlined)),
      title: Row(children: [Expanded(child: Text(account.name)), if (isDefault) const Chip(label: Text('默认'))]),
      subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(accountTypeLabels[account.accountType] ?? account.accountType), balance.when(loading: () => const Text('余额加载中…'), error: (e, _) => Text('余额读取失败：$e'), data: (n) => Text(account.currency == 'CNY' ? formatCny(n) : '${account.currency} $n 最小单位'))]),
      trailing: PopupMenuButton<String>(onSelected: (action) async {
        if (action == 'edit') { context.push('/settings/accounts/${account.id}/edit'); return; }
        if (action == 'disable') {
          final confirmed = await showDialog<bool>(context: context, builder: (dialog) => AlertDialog(title: const Text('停用账户？'), content: const Text('停用后不能用于新增记账，历史账目不会删除。'), actions: [TextButton(onPressed: () => Navigator.pop(dialog, false), child: const Text('取消')), FilledButton(onPressed: () => Navigator.pop(dialog, true), child: const Text('停用'))]));
          if (confirmed != true || !context.mounted) return;
        }
        try {
          final repo = ref.read(accountRepositoryProvider);
          if (action == 'default') await repo.setDefault(account.id);
          if (action == 'disable') await repo.deactivate(account.id);
          if (action == 'restore') await repo.restore(account.id);
          ref.invalidate(defaultAccountProvider);
        } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('操作失败：$e'))); }
      }, itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('编辑')),
        if (account.isActive && !isDefault) const PopupMenuItem(value: 'default', child: Text('设为默认')),
        if (account.isActive) const PopupMenuItem(value: 'disable', child: Text('停用')) else const PopupMenuItem(value: 'restore', child: Text('恢复')),
      ]),
    ));
  }
}
