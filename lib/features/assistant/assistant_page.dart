import 'package:flutter/material.dart';
import '../../shared/section_card.dart';

class AssistantPage extends StatelessWidget {
  const AssistantPage({super.key});
  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(20), children: [
    Text('AI 助手', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
    const SizedBox(height: 16),
    SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.primary, size: 36),
      const SizedBox(height: 10),
      const Text('聪明的生活管家，即将上线', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('这里将支持自然语言记账、事项提取和每日总结。当前第 1 周工程未接入 AI 服务，也不会向网络上传任何个人记录。'),
    ])),
    const SizedBox(height: 14),
    const SectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('未来可以这样说', style: TextStyle(fontWeight: FontWeight.w700)),
      SizedBox(height: 12),
      Text('“中午吃饭花了 28 元，晚上打车 16 元。”'),
      SizedBox(height: 8),
      Text('“周五之前交实验报告，提前一天提醒。”'),
      SizedBox(height: 8),
      Text('“总结一下我本周的支出和待办。”'),
    ])),
  ]);
}
