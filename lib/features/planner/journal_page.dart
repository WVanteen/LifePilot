import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/utils/money.dart';
import '../../shared/section_card.dart';
import 'journal_repository.dart';

/// The surrounding planner owns the selected calendar date.
class JournalSection extends StatefulWidget {
  const JournalSection({
    super.key,
    required this.repository,
    required this.selectedDate,
  });
  final JournalRepository repository;
  final DateTime selectedDate;
  @override
  State<JournalSection> createState() => _JournalSectionState();
}

class _JournalSectionState extends State<JournalSection> {
  final _search = TextEditingController();
  bool _allDates = false;
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _delete(JournalEntry entry) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除记录？'),
        content: const Text('删除后无法恢复，请确认是否删除。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await widget.repository.delete(entry.id);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败：$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    _allDates ? '所有日期' : '${localYmd(widget.selectedDate)} 的记录',
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _allDates = !_allDates),
                  child: Text(_allDates ? '查看所选日期' : '查看全部日期'),
                ),
                IconButton(
                  tooltip: '新增记录',
                  onPressed: () => showJournalEditor(
                    context,
                    repository: widget.repository,
                    initialDate: widget.selectedDate,
                  ),
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            TextField(
              controller: _search,
              decoration: const InputDecoration(
                labelText: '搜索标题或正文',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
      ),
      Expanded(
        child: StreamBuilder<List<JournalEntry>>(
          stream: widget.repository.watch(
            date: _allDates ? null : widget.selectedDate,
            keyword: _search.text,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('读取记录失败：${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final rows = snapshot.data!;
            if (rows.isEmpty) return const Center(child: Text('没有符合条件的记录'));
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: rows.length,
              itemBuilder: (context, index) {
                final entry = rows[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                entry.journalDate,
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: '记录操作',
                              onSelected: (value) {
                                if (value == 'edit') {
                                  showJournalEditor(
                                    context,
                                    repository: widget.repository,
                                    initialDate: widget.selectedDate,
                                    entry: entry,
                                  );
                                }
                                if (value == 'delete') _delete(entry);
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(value: 'edit', child: Text('编辑')),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text('删除'),
                                ),
                              ],
                            ),
                          ],
                        ),
                        if (entry.title != null && entry.title!.isNotEmpty)
                          Text(
                            entry.title!,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        const SizedBox(height: 4),
                        Text(entry.content),
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
  );
}

Future<void> showJournalEditor(
  BuildContext context, {
  required JournalRepository repository,
  required DateTime initialDate,
  JournalEntry? entry,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _JournalEditor(
      repository: repository,
      initialDate: initialDate,
      entry: entry,
    ),
  );
}

class _JournalEditor extends StatefulWidget {
  const _JournalEditor({
    required this.repository,
    required this.initialDate,
    this.entry,
  });
  final JournalRepository repository;
  final DateTime initialDate;
  final JournalEntry? entry;
  @override
  State<_JournalEditor> createState() => _JournalEditorState();
}

class _JournalEditorState extends State<_JournalEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _content;
  late DateTime _date;
  bool _saving = false;
  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.entry?.title ?? '');
    _content = TextEditingController(text: widget.entry?.content ?? '');
    _date =
        DateTime.tryParse(widget.entry?.journalDate ?? '') ??
        widget.initialDate;
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final entry = widget.entry;
      if (entry == null) {
        await widget.repository.create(
          date: _date,
          title: _title.text,
          content: _content.text,
        );
      } else {
        await widget.repository.update(
          id: entry.id,
          date: _date,
          title: _title.text,
          content: _content.text,
        );
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存失败：$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: 20,
      right: 20,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.entry == null ? '新增记录' : '编辑记录',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? '保存中…' : '保存'),
              ),
            ],
          ),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  TextFormField(
                    controller: _title,
                    enabled: !_saving,
                    decoration: const InputDecoration(labelText: '标题（可选）'),
                  ),
                  TextFormField(
                    controller: _content,
                    enabled: !_saving,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: '正文'),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? '请输入正文' : null,
                  ),
                  TextButton.icon(
                    onPressed: _saving
                        ? null
                        : () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _date,
                              firstDate: DateTime(1900),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null && mounted) {
                              setState(() => _date = picked);
                            }
                          },
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(localYmd(_date)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
