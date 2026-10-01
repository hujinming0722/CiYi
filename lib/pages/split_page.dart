import 'package:flutter/material.dart';

import '../models/poem.dart';
import '../utils/sentence_splitter.dart';
import 'recite_page.dart';

/// 分句预处理页：自动分句（按 。？！；），用户可手动编辑
/// 支持：合并分句、拆分分句、删除空行、段落分组、难度选择
class SplitPage extends StatefulWidget {
  final String originalText;
  final String title;

  const SplitPage({super.key, required this.originalText, required this.title});

  @override
  State<SplitPage> createState() => _SplitPageState();
}

class _SplitPageState extends State<SplitPage> {
  late List<String> _sentences;
  late List<ParagraphGroup> _paragraphs;
  int _difficulty = 1;
  bool _showParagraphPanel = false;

  @override
  void initState() {
    super.initState();
    _sentences = SentenceSplitter.split(widget.originalText);
    _paragraphs = [];
  }

  // ---------------- 分句编辑 ----------------

  void _editSentence(int index) {
    final controller = TextEditingController(text: _sentences[index]);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('编辑第 ${index + 1} 句'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          autofocus: true,
          decoration: const InputDecoration(border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final text = controller.text.trim();
              if (text.isNotEmpty) {
                setState(() => _sentences[index] = text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
  }

  /// 合并到下一句
  void _mergeWithNext(int index) {
    if (index >= _sentences.length - 1) return;
    setState(() {
      _sentences[index] = '${_sentences[index]}${_sentences[index + 1]}';
      _sentences.removeAt(index + 1);
      _rebuildParagraphs();
    });
  }

  /// 拆分：用户输入在第几个字之后拆分
  void _splitSentence(int index) {
    final sentence = _sentences[index];
    if (sentence.length < 2) return;
    final controller = TextEditingController(text: '${sentence.length ~/ 2}');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('拆分第 ${index + 1} 句'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(sentence, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '在第几个字之后拆分',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final pos = int.tryParse(controller.text.trim());
              final parts = pos == null ? null : SentenceSplitter.splitAt(sentence, pos);
              if (parts != null) {
                setState(() {
                  _sentences.replaceRange(index, index + 1, parts);
                  _rebuildParagraphs();
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('拆分位置无效')),
                );
              }
              Navigator.pop(ctx);
            },
            child: const Text('拆分'),
          ),
        ],
      ),
    );
  }

  void _deleteSentence(int index) {
    setState(() {
      _sentences.removeAt(index);
      _rebuildParagraphs();
    });
  }

  void _addSentence() {
    setState(() => _sentences.add(''));
  }

  /// 分句增删后重建段落范围（裁剪越界范围）
  void _rebuildParagraphs() {
    _paragraphs = _paragraphs
        .map((p) => ParagraphGroup(
              name: p.name,
              start: p.start.clamp(0, _sentences.length),
              end: p.end.clamp(0, _sentences.length),
            ))
        .where((p) => p.end > p.start)
        .toList();
  }

  // ---------------- 段落分组 ----------------

  void _addParagraph() {
    if (_sentences.isEmpty) return;
    final nameController = TextEditingController(text: '段落${_paragraphs.length + 1}');
    int start = 0, end = _sentences.length;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('新建段落分组'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: '段落名称',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Text('范围：第 ${start + 1} 句 ~ 第 $end 句（共 ${_sentences.length} 句）'),
              RangeSlider(
                values: RangeValues(start.toDouble(), end.toDouble()),
                min: 0,
                max: _sentences.length.toDouble(),
                divisions: _sentences.length,
                labels: RangeLabels('${start + 1}', '$end'),
                onChanged: (v) => setLocal(() {
                  start = v.start.round();
                  end = v.end.round();
                }),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
            FilledButton(
              onPressed: () {
                if (end > start) {
                  setState(() => _paragraphs.add(ParagraphGroup(
                        name: nameController.text.trim().isEmpty
                            ? '段落${_paragraphs.length + 1}'
                            : nameController.text.trim(),
                        start: start,
                        end: end,
                      )));
                }
                Navigator.pop(ctx);
              },
              child: const Text('添加'),
            ),
          ],
        ),
      ),
    );
  }

  int? _paragraphOf(int sentenceIndex) {
    for (var i = 0; i < _paragraphs.length; i++) {
      final p = _paragraphs[i];
      if (sentenceIndex >= p.start && sentenceIndex < p.end) return i;
    }
    return null;
  }

  // ---------------- 进入背诵 ----------------

  void _confirm() {
    final valid = _sentences.where((s) => s.trim().isNotEmpty).toList();
    if (valid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('分句结果为空，请至少保留一句')),
      );
      return;
    }
    final poem = Poem(
      title: widget.title,
      originalText: widget.originalText,
      sentences: valid,
      paragraphs: _paragraphs,
      createdAt: DateTime.now(),
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecitePage(poem: poem, difficulty: _difficulty),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('分句预处理'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 难度选择
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('选择难度（整篇统一）', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(value: 1, label: Text('1 少量挖空')),
                    ButtonSegment(value: 2, label: Text('2 保留句首')),
                    ButtonSegment(value: 3, label: Text('3 仅首字')),
                    ButtonSegment(value: 4, label: Text('4 仅标点')),
                  ],
                  selected: {_difficulty},
                  onSelectionChanged: (s) => setState(() => _difficulty = s.first),
                ),
              ],
            ),
          ),
          const Divider(),
          // 分句列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _sentences.length + 1,
              itemBuilder: (context, i) {
                if (i == _sentences.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: OutlinedButton.icon(
                      onPressed: _addSentence,
                      icon: const Icon(Icons.add),
                      label: const Text('添加分句'),
                    ),
                  );
                }
                return _buildSentenceTile(i);
              },
            ),
          ),
          // 底部操作栏
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _showParagraphPanel
                          ? null
                          : () => setState(() => _showParagraphPanel = true),
                      icon: const Icon(Icons.folder_outlined),
                      label: Text(_paragraphs.isEmpty ? '段落分组' : '段落（${_paragraphs.length}）'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _confirm,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('确认，开始背诵'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (_showParagraphPanel) _buildParagraphPanel(),
        ],
      ),
    );
  }

  Widget _buildSentenceTile(int i) {
    final text = _sentences[i];
    final paraIdx = _paragraphOf(i);
    final isEmpty = text.trim().isEmpty;
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: isEmpty ? Colors.red.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            SizedBox(
              width: 36,
              child: Text('${i + 1}', style: TextStyle(color: Colors.grey.shade600)),
            ),
            Expanded(
              child: InkWell(
                onTap: () => _editSentence(i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    isEmpty ? '（空句，点击编辑或删除）' : text,
                    style: TextStyle(
                      fontSize: 16,
                      color: isEmpty ? Colors.red : null,
                    ),
                  ),
                ),
              ),
            ),
            if (paraIdx != null)
              Padding(
                padding: const EdgeInsets.only(right: 4),
                child: Chip(
                  label: Text(_paragraphs[paraIdx].name, style: const TextStyle(fontSize: 11)),
                  padding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  backgroundColor: Colors.blue.shade50,
                ),
              ),
            IconButton(
              tooltip: '编辑',
              icon: const Icon(Icons.edit_outlined, size: 20),
              onPressed: () => _editSentence(i),
            ),
            IconButton(
              tooltip: '拆分',
              icon: const Icon(Icons.content_cut, size: 20),
              onPressed: text.length < 2 ? null : () => _splitSentence(i),
            ),
            IconButton(
              tooltip: '合并到下一句',
              icon: const Icon(Icons.merge, size: 20),
              onPressed: i >= _sentences.length - 1 ? null : () => _mergeWithNext(i),
            ),
            IconButton(
              tooltip: '删除',
              icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
              onPressed: () => _deleteSentence(i),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParagraphPanel() {
    return Material(
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('段落分组（可选）',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _showParagraphPanel = false),
                    child: const Text('收起'),
                  ),
                ],
              ),
              const Text('背诵时可选择"背诵全文"或"仅背诵某段落"。',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 8),
              if (_paragraphs.isEmpty)
                const Text('尚未划分段落', style: TextStyle(color: Colors.grey)),
              for (var i = 0; i < _paragraphs.length; i++)
                ListTile(
                  dense: true,
                  title: Text(_paragraphs[i].name),
                  subtitle: Text('第 ${_paragraphs[i].start + 1} ~ ${_paragraphs[i].end} 句'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () => setState(() => _paragraphs.removeAt(i)),
                  ),
                ),
              OutlinedButton.icon(
                onPressed: _addParagraph,
                icon: const Icon(Icons.add),
                label: const Text('添加段落'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
