import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/poem.dart';
import 'detail_page.dart';
import 'recite_page.dart';
import 'text_input_page.dart';

/// 首页：背诵文本库 + 粘贴新文本入口
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Poem> _poems = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final poems = await DatabaseHelper.instance.getAllPoems();
    if (!mounted) return;
    setState(() {
      _poems = poems;
      _loading = false;
    });
  }

  Future<void> _openTextInput() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const TextInputPage()),
    );
    if (created == true) _load();
  }

  /// 点击篇目：提供 ①从头完整背诵 ②仅复习生疏分句 两个入口
  void _openPoem(Poem poem) {
    final hasWeak = poem.weakIndices.isNotEmpty;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(poem.title, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('共 ${poem.sentences.length} 句 · 练习 ${poem.practiceCount} 次'
                  '${hasWeak ? ' · 生疏 ${poem.weakIndices.length} 句' : ''}'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.menu_book),
              title: const Text('从头完整背诵'),
              onTap: () {
                Navigator.pop(ctx);
                _startRecite(poem, onlyWeak: false);
              },
            ),
            if (hasWeak)
              ListTile(
                leading: const Icon(Icons.priority_high, color: Colors.orange),
                title: Text('仅复习生疏分句（${poem.weakIndices.length}）'),
                onTap: () {
                  Navigator.pop(ctx);
                  _startRecite(poem, onlyWeak: true);
                },
              ),
            ListTile(
              leading: const Icon(Icons.article_outlined),
              title: const Text('查看文本详情'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DetailPage(poem: poem)),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('删除篇目', style: TextStyle(color: Colors.red)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDelete(poem);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startRecite(Poem poem, {required bool onlyWeak}) async {
    // 进入背诵前练习次数 +1
    poem.practiceCount++;
    await DatabaseHelper.instance.updatePoem(poem);
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => RecitePage(poem: poem, onlyWeak: onlyWeak),
      ),
    );
    _load();
  }

  Future<void> _confirmDelete(Poem poem) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除篇目'),
        content: Text('确定删除「${poem.title}」吗？该篇目及其全部熟练/生疏标记将一并清除，且不可恢复。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok == true && poem.id != null) {
      await DatabaseHelper.instance.deletePoem(poem.id!);
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('古诗背诵'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _poems.isEmpty
              ? _buildEmpty()
              : _buildList(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openTextInput,
        icon: const Icon(Icons.add),
        label: const Text('粘贴新文本'),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories, size: 72, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text('还没有背诵篇目', style: TextStyle(fontSize: 16)),
          const SizedBox(height: 8),
          Text(
            '点击下方按钮，粘贴古诗、文言文或短文开始背诵',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 88),
      itemCount: _poems.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, i) {
        final poem = _poems[i];
        final weakCount = poem.weakIndices.length;
        return ListTile(
          title: Text(poem.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text('${poem.sentences.length} 句 · 练习 ${poem.practiceCount} 次'),
          trailing: weakCount > 0
              ? Chip(
                  label: Text('生疏 $weakCount'),
                  backgroundColor: Colors.orange.shade50,
                  side: BorderSide(color: Colors.orange.shade200),
                  padding: EdgeInsets.zero,
                  labelStyle: const TextStyle(fontSize: 12),
                )
              : const Icon(Icons.chevron_right),
          onTap: () => _openPoem(poem),
        );
      },
    );
  }
}
