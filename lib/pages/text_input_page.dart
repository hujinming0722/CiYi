import 'package:flutter/material.dart';

import 'split_page.dart';

/// 文本导入页：用户粘贴自定义文本，提交后进入分句预处理
class TextInputPage extends StatefulWidget {
  const TextInputPage({super.key});

  @override
  State<TextInputPage> createState() => _TextInputPageState();
}

class _TextInputPageState extends State<TextInputPage> {
  final _controller = TextEditingController();
  final _titleController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请先粘贴文本内容')),
      );
      return;
    }
    final title = _titleController.text.trim().isEmpty
        ? _deriveTitle(text)
        : _titleController.text.trim();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SplitPage(
          originalText: text,
          title: title,
        ),
      ),
    );
  }

  /// 自动取前 12 个字作为默认标题
  String _deriveTitle(String text) {
    final cleaned = text.replaceAll(RegExp(r'\s+'), '');
    return cleaned.length <= 12 ? cleaned : '${cleaned.substring(0, 12)}…';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('粘贴文本'), centerTitle: true),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: '标题（可选，默认取正文开头）',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                textAlignVertical: TextAlignVertical.top,
                decoration: const InputDecoration(
                  labelText: '粘贴文本内容',
                  hintText: '庆历四年春，滕子京谪守巴陵郡。越明年，政通人和，百废具兴。',
                  border: OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.check),
              label: const Text('确认，进入分句预处理'),
            ),
          ],
        ),
      ),
    );
  }
}
