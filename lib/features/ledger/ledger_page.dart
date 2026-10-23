import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';
import '../../core/utils/money.dart';
import '../../shared/section_card.dart';
import 'add_transaction_sheet.dart';
import 'ledger_repository.dart';

class LedgerPage extends ConsumerStatefulWidget {
  const LedgerPage({super.key});

  @override
  ConsumerState<LedgerPage> createState() => _LedgerPageState();
}

class _LedgerPageState extends ConsumerState<LedgerPage> {
  String? _kindFilter;
  String? _categoryFilter;
  DateTimeRange? _dateRange;

  @override
  Widget build(BuildContext context) {
    final entries = ref.watch(ledgerEntriesProvider);
    final categories = ref.watch(ledgerCategoriesProvider).value ?? [];
    final accounts = ref.watch(ledgerAccountsProvider).value ?? [];
    final summary = ref.watch(currentMonthLedgerSummaryProvider);
    final categoryExpenses = ref.watch(currentMonthCategoryExpensesProvider);
    final categoryNames = {
      for (final category in categories) category.id: category.name,
    };
    final accountNames = {
      for (final account in accounts) account.id: account.name,
    };
    final month = localYmd(DateTime.now()).substring(0, 7);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '记账',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => showAddTransactionSheet(context),
              icon: const Icon(Icons.add),
              label: const Text('记一笔'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _SummaryCard(month: month, summary: summary),
        const SizedBox(height: 14),
        _CategorySummaryCard(expenses: categoryExpenses),
        const SizedBox(height: 14),
        _buildFilters(categories),
        const SizedBox(height: 18),
        Row(
          children: [
            const Expanded(
              child: Text(
                '账目流水',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
              ),
            ),
            if (_hasFilters)
              TextButton(onPressed: _clearFilters, child: const Text('清除筛选')),
          ],
        ),
        const SizedBox(height: 10),
        entries.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => SectionCard(child: Text('读取账本失败：$error')),
          data: (rows) {
            final filtered = rows.where(_matchesFilters).toList();
            if (filtered.isEmpty) {
              return SectionCard(
                child: Text(
                  _hasFilters ? '没有符合当前筛选条件的账目。' : '还没有账目。点击右上方的「记一笔」创建第一条记录。',
                ),
              );
            }
            return Column(
              children: filtered
                  .map(
                    (transaction) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TransactionTile(
                        transaction: transaction,
                        categoryName:
                            categoryNames[transaction.categoryId] ?? '其他',
                        accountName:
                            accountNames[transaction.accountId] ?? '未知账户',
                        onEdit: () => showTransactionSheet(
                          context,
                          transaction: transaction,
                        ),
                        onDelete: () => _delete(transaction),
                      ),
                    ),
                  )
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  Widget _buildFilters(List<Category> categories) {
    final matchingCategories = categories
        .where(
          (category) => _kindFilter == null || category.type == _kindFilter,
        )
        .toList();
    final selectedCategory =
        matchingCategories.any((category) => category.id == _categoryFilter)
        ? _categoryFilter
        : null;
    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('筛选', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('全部'),
                selected: _kindFilter == null,
                onSelected: (_) => setState(() {
                  _kindFilter = null;
                  _categoryFilter = null;
                }),
              ),
              ChoiceChip(
                label: const Text('支出'),
                selected: _kindFilter == 'expense',
                onSelected: (_) => setState(() {
                  _kindFilter = 'expense';
                  _categoryFilter = null;
                }),
              ),
              ChoiceChip(
                label: const Text('收入'),
                selected: _kindFilter == 'income',
                onSelected: (_) => setState(() {
                  _kindFilter = 'income';
                  _categoryFilter = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            key: ValueKey('filter-$_kindFilter-$selectedCategory'),
            initialValue: selectedCategory,
            decoration: const InputDecoration(labelText: '分类', isDense: true),
            items: matchingCategories
                .map(
                  (category) => DropdownMenuItem(
                    value: category.id,
                    child: Text(category.name),
                  ),
                )
                .toList(),
            onChanged: (value) => setState(() => _categoryFilter = value),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _selectDateRange,
            icon: const Icon(Icons.date_range_outlined),
            label: Text(
              _dateRange == null
                  ? '选择日期范围'
                  : '${localYmd(_dateRange!.start)} 至 ${localYmd(_dateRange!.end)}',
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesFilters(LedgerTransaction transaction) {
    if (_kindFilter != null && transaction.kind != _kindFilter) return false;
    if (_categoryFilter != null && transaction.categoryId != _categoryFilter) {
      return false;
    }
    if (_dateRange != null) {
      final start = localYmd(_dateRange!.start);
      final end = localYmd(_dateRange!.end);
      if (transaction.localDate.compareTo(start) < 0 ||
          transaction.localDate.compareTo(end) > 0) {
        return false;
      }
    }
    return true;
  }

  bool get _hasFilters =>
      _kindFilter != null || _categoryFilter != null || _dateRange != null;

  void _clearFilters() {
    setState(() {
      _kindFilter = null;
      _categoryFilter = null;
      _dateRange = null;
    });
  }

  Future<void> _selectDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: now,
      initialDateRange: _dateRange,
      helpText: '筛选交易日期',
      cancelText: '取消',
      confirmText: '确定',
      saveText: '确定',
    );
    if (range != null) setState(() => _dateRange = range);
  }

  Future<void> _delete(LedgerTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('删除账目？'),
        content: const Text('删除后该账目不会显示在流水和统计中。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final repository = ref.read(ledgerRepositoryProvider);
      await repository.softDelete(transaction.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('账目已删除'),
          action: SnackBarAction(
            label: '撤销',
            onPressed: () async {
              try {
                await repository.restore(transaction.id);
              } catch (error) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('撤销失败：$error')));
                }
              }
            },
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败：$error')));
      }
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.month, required this.summary});

  final String month;
  final AsyncValue<LedgerSummary> summary;

  @override
  Widget build(BuildContext context) => SectionCard(
    child: summary.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Text('读取月度统计失败：$error'),
      data: (value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$month 月度概览',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _Amount(
                  label: '收入',
                  value: formatCny(value.incomeMinor),
                ),
              ),
              Expanded(
                child: _Amount(
                  label: '支出',
                  value: formatCny(value.expenseMinor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '结余 ${formatCny(value.balanceMinor)}',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text('当前手动记账支持人民币收入与支出。', style: TextStyle(fontSize: 12)),
        ],
      ),
    ),
  );
}

class _CategorySummaryCard extends StatelessWidget {
  const _CategorySummaryCard({required this.expenses});

  final AsyncValue<List<CategoryExpenseTotal>> expenses;

  @override
  Widget build(BuildContext context) => SectionCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('本月分类支出', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        expenses.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, _) => Text('读取分类统计失败：$error'),
          data: (rows) => rows.isEmpty
              ? const Text('本月还没有支出。')
              : Column(
                  children: rows
                      .map(
                        (row) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Expanded(child: Text(row.categoryName)),
                              Text(
                                formatCny(row.amountMinor),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      .toList(),
                ),
        ),
      ],
    ),
  );
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.categoryName,
    required this.accountName,
    required this.onEdit,
    required this.onDelete,
  });

  final LedgerTransaction transaction;
  final String categoryName;
  final String accountName;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => SectionCard(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onEdit,
      leading: CircleAvatar(
        child: Icon(
          transaction.kind == 'expense'
              ? Icons.arrow_upward
              : Icons.arrow_downward,
        ),
      ),
      title: Text(categoryName),
      subtitle: Text(
        '${transaction.localDate} · $accountName'
        '${transaction.note == null ? '' : '\n${transaction.note}'}',
      ),
      isThreeLine: transaction.note != null,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${transaction.kind == 'expense' ? '-' : '+'}'
            '${formatCny(transaction.amountMinor)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          PopupMenuButton<String>(
            tooltip: '账目操作',
            onSelected: (action) {
              if (action == 'edit') onEdit();
              if (action == 'delete') onDelete();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('编辑')),
              PopupMenuItem(value: 'delete', child: Text('删除')),
            ],
          ),
        ],
      ),
    ),
  );
}

class _Amount extends StatelessWidget {
  const _Amount({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: 6),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}
