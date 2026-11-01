import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../shared/section_card.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      Text(
        '我的',
        style: Theme.of(
          context,
        ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 16),
      const SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'LifePilot 0.1.0 · Week 1',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
            ),
            SizedBox(height: 8),
            Text('当前模式：个人本地数据。'),
            SizedBox(height: 8),
            Text('默认币种：人民币。'),
            SizedBox(height: 8),
            Text('记账、待办和日记保存在设备本地 SQLite 中。'),
          ],
        ),
      ),
      const SizedBox(height: 14),
      SectionCard(
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            title: const Text('账户管理'),
            leading: const Icon(Icons.account_balance_wallet_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/accounts'),
          ),
        ),
      ),
      SectionCard(
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            title: const Text('分类管理'),
            leading: const Icon(Icons.category_outlined),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/settings/categories'),
          ),
        ),
      ),
      const SizedBox(height: 14),
      const SectionCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '后续功能安排',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 12),
            Text('• 分类管理'),
            Text('• 日历与完整提醒系统'),
            Text('• 数据导出、备份和恢复'),
            Text('• AI 自然语言解析与确认'),
            Text('• 未来多端同步'),
          ],
        ),
      ),
      const SizedBox(height: 14),
      const Text(
        '提醒：卸载 App 或清除应用数据可能导致本地记录丢失。正式使用重要数据前，应先实现备份与恢复。',
        style: TextStyle(fontSize: 13),
      ),
    ],
  );
}
