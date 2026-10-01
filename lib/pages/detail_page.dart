import 'package:flutter/material.dart';

import '../models/poem.dart';
import 'recite_page.dart';

/// 文本详情页：退出背诵后查看完整原文与分句预览
class DetailPage extends StatelessWidget {
  final Poem poem;

  const DetailPage({super.key, required this.poem});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(poem.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 统计信息
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Chip(label: Text('共 ${poem.sentences.length} 句')),
              Chip(label: Text('练习 ${poem.practiceCount} 次')),
              Chip(
                label: Text('熟练 ${poem.skilledIndices.length} 句'),
                backgroundColor: Colors.green.shade50,
              ),
              Chip(
                label: Text('生疏 ${poem.weakIndices.length} 句'),
                backgroundColor: Colors.orange.shade50,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // 完整原文
          const Text('完整原文', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                poem.originalText,
                style: const TextStyle(fontSize: 16, height: 1.8, letterSpacing: 1),
              ),
            ),
          ),
          const SizedBox(height: 20),
          // 分句预览
          const Text('分句预览', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          for (var i = 0; i < poem.sentences.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 32,
                    child: Text('${i + 1}', style: TextStyle(color: Colors.grey.shade600)),
                  ),
                  Expanded(
                    child: Text(
                      poem.sentences[i],
                      style: const TextStyle(fontSize: 15, height: 1.6),
                    ),
                  ),
                  if (poem.skilledIndices.contains(i))
                    const Icon(Icons.thumb_up, size: 16, color: Colors.green),
                  if (poem.weakIndices.contains(i))
                    const Icon(Icons.thumb_down, size: 16, color: Colors.orange),
                ],
              ),
            ),
          const SizedBox(height: 24),
          // 重新背诵入口
          if (poem.weakIndices.isNotEmpty)
            FilledButton.icon(
              onPressed: () => _reRecite(context, onlyWeak: true),
              icon: const Icon(Icons.priority_high, color: Colors.orange),
              label: Text('仅复习生疏分句（${poem.weakIndices.length}）'),
            ),
          if (poem.weakIndices.isNotEmpty) const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: () => _reRecite(context, onlyWeak: false),
            icon: const Icon(Icons.replay),
            label: const Text('重新完整背诵'),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _reRecite(BuildContext context, {required bool onlyWeak}) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => RecitePage(poem: poem, onlyWeak: onlyWeak),
      ),
    );
  }
}
