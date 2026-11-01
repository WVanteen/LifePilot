import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/providers.dart';

const categoryIcons = <String, IconData>{
  'default': Icons.category_outlined,
  'food': Icons.restaurant,
  'transport': Icons.directions_bus,
  'shopping': Icons.shopping_bag_outlined,
  'home': Icons.home_outlined,
  'work': Icons.work_outline,
  'health': Icons.favorite_outline,
};

class CategoriesPage extends ConsumerStatefulWidget {
  const CategoriesPage({super.key});
  @override
  ConsumerState<CategoriesPage> createState() => _CategoriesPageState();
}

class _CategoriesPageState extends ConsumerState<CategoriesPage> {
  String type = 'expense';
  Future<void> edit([Category? category]) async {
    final name = TextEditingController(text: category?.name ?? '');
    var icon = categoryIcons.containsKey(category?.iconKey)
        ? category!.iconKey
        : 'default';
    final form = GlobalKey<FormState>();
    var saving = false;
    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      builder: (dialog) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(category == null ? '新增分类' : '编辑分类'),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '分类名称'),
                  validator: (v) => (v ?? '').trim().isEmpty ? '请输入分类名称' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: icon,
                  decoration: const InputDecoration(labelText: '图标'),
                  items: categoryIcons.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Icon(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setDialogState(() => icon = v!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(dialog),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: saving
                  ? null
                  : () async {
                      if (!form.currentState!.validate()) return;
                      setDialogState(() => saving = true);
                      try {
                        final repo = ref.read(categoryRepositoryProvider);
                        if (category == null) {
                          await repo.create(
                            name: name.text,
                            type: type,
                            iconKey: icon,
                          );
                        } else {
                          await repo.update(
                            id: category.id,
                            name: name.text,
                            iconKey: icon,
                          );
                        }
                        if (dialog.mounted) Navigator.pop(dialog);
                      } catch (e) {
                        if (dialog.mounted) {
                          ScaffoldMessenger.of(
                            dialog,
                          ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
                        }
                      } finally {
                        if (dialog.mounted) {
                          setDialogState(() => saving = false);
                        }
                      }
                    },
              child: Text(saving ? '保存中…' : '保存'),
            ),
          ],
        ),
      ),
    );
    await navigator.push(route);
    await route.completed;
    name.dispose();
  }

  Future<void> action(Category category, String action) async {
    if (action == 'edit') return edit(category);
    if (action == 'disable') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialog) => AlertDialog(
          title: const Text('停用分类？'),
          content: const Text('停用后不能用于新增账目，历史流水不会删除。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('停用'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    try {
      final repo = ref.read(categoryRepositoryProvider);
      if (action == 'disable') await repo.setActive(category.id, false);
      if (action == 'restore') await repo.setActive(category.id, true);
      if (action == 'up') await repo.move(category.id, -1);
      if (action == 'down') await repo.move(category.id, 1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('操作失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final categories = ref.watch(managedCategoriesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('分类管理'),
        actions: [
          TextButton.icon(
            onPressed: () => edit(),
            icon: const Icon(Icons.add),
            label: const Text('新增分类'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'expense', label: Text('支出分类')),
                    ButtonSegment(value: 'income', label: Text('收入分类')),
                  ],
                  selected: {type},
                  onSelectionChanged: (values) =>
                      setState(() => type = values.first),
                ),
              ),
            ),
          ),
          Expanded(
            child: categories.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('读取分类失败：$e')),
              data: (rows) {
                final visible = rows.where((c) => c.type == type).toList();
                if (visible.isEmpty) {
                  return const Center(child: Text('暂无分类，请新增分类。'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16),
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final category = visible[index];
                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            categoryIcons[category.iconKey] ??
                                Icons.category_outlined,
                          ),
                        ),
                        title: Text(category.name),
                        subtitle: Text(category.isActive ? '启用' : '已停用'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) => action(category, value),
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'edit',
                              child: Text('编辑'),
                            ),
                            const PopupMenuItem(value: 'up', child: Text('上移')),
                            const PopupMenuItem(
                              value: 'down',
                              child: Text('下移'),
                            ),
                            if (category.isActive)
                              const PopupMenuItem(
                                value: 'disable',
                                child: Text('停用'),
                              )
                            else
                              const PopupMenuItem(
                                value: 'restore',
                                child: Text('恢复'),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
