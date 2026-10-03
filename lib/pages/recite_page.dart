import 'dart:math';

import 'package:flutter/material.dart';

import '../database/database_helper.dart';
import '../models/poem.dart';
import '../utils/difficulty_renderer.dart';
import 'detail_page.dart';

/// 背诵主界面
///
/// 核心机制：4 个难度档位整篇统一；以分句为最小单元独立控制显隐；
/// 同一时间仅聚焦当前激活分句。
/// 扩展：备选字区（点击填入空白）、提示一下（辅助回忆）。
class RecitePage extends StatefulWidget {
  final Poem poem;
  final bool onlyWeak;
  final int difficulty;

  const RecitePage({
    super.key,
    required this.poem,
    this.onlyWeak = false,
    this.difficulty = 1,
  });

  @override
  State<RecitePage> createState() => _RecitePageState();
}

class _RecitePageState extends State<RecitePage> {
  late Poem _poem;
  late int _difficulty;
  late List<int> _visibleIndices; // 当前练习的分句索引（全文/生疏/段落）
  int _activePos = 0; // 激活句在 _visibleIndices 中的位置
  bool _revealed = false; // 当前激活句是否展开全文

  /// 每个分句的渲染结果缓存（含填入状态）
  final Map<int, RenderedSentence> _renderedCache = {};

  /// 备选字列表（当前激活句的空白答案字，随机选 6 个）
  List<String> _candidateChars = [];

  /// 分句列表滚动控制器
  final ScrollController _scrollController = ScrollController();

  /// 每个分句的 GlobalKey（用于自动滚动定位）
  final Map<int, GlobalKey> _sentenceKeys = {};

  @override
  void initState() {
    super.initState();
    _poem = widget.poem;
    _difficulty = widget.difficulty;
    _initVisible();
    _refreshCandidates();
    // 后台保存到本地数据库，不阻塞界面渲染
    _ensureSaved();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// 确定本次练习的分句范围
  void _initVisible() {
    if (widget.onlyWeak && _poem.weakIndices.isNotEmpty) {
      _visibleIndices = _poem.weakIndices.toList()..sort();
    } else {
      _visibleIndices = List.generate(_poem.sentences.length, (i) => i);
    }
  }

  /// 新文本首次进入背诵时保存到本地数据库（后台执行，失败不影响背诵）
  Future<void> _ensureSaved() async {
    try {
      if (_poem.id == null) {
        final id = await DatabaseHelper.instance.insertPoem(_poem);
        _poem = Poem(
          id: id,
          title: _poem.title,
          originalText: _poem.originalText,
          sentences: _poem.sentences,
          paragraphs: _poem.paragraphs,
          practiceCount: _poem.practiceCount,
          createdAt: _poem.createdAt,
        );
      }
    } catch (_) {
      // 数据库保存失败不影响本次背诵，仅标记功能不可用
    }
  }

  int get _activeSentenceIndex => _visibleIndices[_activePos];

  RenderedSentence _rendered(int sentenceIndex) {
    return _renderedCache.putIfAbsent(
      sentenceIndex,
      () => DifficultyRenderer.render(
        _poem.sentences[sentenceIndex],
        _difficulty,
        sentenceIndex * 1000 + _difficulty,
      ),
    );
  }

  /// 刷新备选字：从当前句随机抽字，不足从全文补充，随机位置放入正确答案
  void _refreshCandidates() {
    final rendered = _rendered(_activeSentenceIndex);
    final random = Random(DateTime.now().microsecondsSinceEpoch);

    // 找到当前第一个未填入的空白槽位的答案字
    final nextBlank = rendered.tokens.firstWhere(
      (t) => t.isBlank && !t.filled,
      orElse: () => SentenceToken(),
    );
    final mustHave = nextBlank.isBlank ? nextBlank.answer : '';

    // 从当前句收集汉字（去重）
    final sentenceChars = <String>{};
    for (final ch in _poem.sentences[_activeSentenceIndex].characters) {
      final code = ch.codeUnitAt(0);
      if (code >= 0x4E00 && code <= 0x9FFF) {
        sentenceChars.add(ch);
      }
    }

    // 如果当前句汉字不足 6 个，从全文补充
    if (sentenceChars.length < 6) {
      for (var i = 0; i < _poem.sentences.length; i++) {
        if (i == _activeSentenceIndex) continue;
        for (final ch in _poem.sentences[i].characters) {
          final code = ch.codeUnitAt(0);
          if (code >= 0x4E00 && code <= 0x9FFF) {
            sentenceChars.add(ch);
          }
        }
        if (sentenceChars.length >= 6) break;
      }
    }

    // 随机抽取 6 个不重复的字
    final pool = sentenceChars.toList()..shuffle(random);
    final candidates = pool.take(6).toList();

    // 如果正确答案不在其中，随机替换一个位置
    if (mustHave.isNotEmpty && !candidates.contains(mustHave)) {
      final replacePos = random.nextInt(candidates.length);
      candidates[replacePos] = mustHave;
    }

    _candidateChars = candidates;
  }

  // ---------------- 交互 ----------------

  void _next() {
    if (_activePos < _visibleIndices.length - 1) {
      setState(() {
        _activePos++;
        _revealed = false;
        _refreshCandidates();
      });
      _scrollToActive();
    }
  }

  void _prev() {
    if (_activePos > 0) {
      setState(() {
        _activePos--;
        _revealed = false;
        _refreshCandidates();
      });
      _scrollToActive();
    }
  }

  /// 自动滚动到当前激活句
  void _scrollToActive() {
    final sentenceIndex = _activeSentenceIndex;
    final key = _sentenceKeys[sentenceIndex];
    if (key?.currentContext != null) {
      Scrollable.ensureVisible(
        key!.currentContext!,
        duration: const Duration(milliseconds: 300),
        alignment: 0.3, // 激活句显示在 30% 位置（偏上方，留出下方操作区空间）
      );
    }
  }

  void _toggleReveal() {
    setState(() => _revealed = !_revealed);
  }

  void _resetAll() {
    setState(() {
      _activePos = 0;
      _revealed = false;
      _renderedCache.clear();
      _refreshCandidates();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已重置全文，回到第 1 句')),
    );
  }

  void _changeDifficulty() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('切换难度（整篇统一重新渲染）',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final d in const [
              (1, '等级1｜少量挖空：隐藏少量实词关键词'),
              (2, '等级2｜保留句首 2~3 个字'),
              (3, '等级3｜仅保留句首 1 个字'),
              (4, '等级4｜仅保留标点'),
            ])
              ListTile(
                leading: CircleAvatar(child: Text('${d.$1}')),
                title: Text(d.$2),
                trailing: _difficulty == d.$1 ? const Icon(Icons.check, color: Colors.green) : null,
                onTap: () {
                  setState(() {
                    _difficulty = d.$1;
                    _revealed = false;
                    _renderedCache.clear();
                    _refreshCandidates();
                  });
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  /// 点击备选字：严格按顺序填入当前第一个空白
  /// 填对 → 填入并重新抽取备选字；填错 → 弹窗提示
  void _onCandidateTap(String ch) {
    final rendered = _rendered(_activeSentenceIndex);
    // 找到当前第一个未填入的空白槽位
    final nextBlank = rendered.tokens.firstWhere(
      (t) => t.isBlank && !t.filled,
      orElse: () => SentenceToken(),
    );
    if (!nextBlank.isBlank) {
      // 没有空白了
      return;
    }
    if (nextBlank.answer == ch) {
      // 填对了：填入并重新抽取备选字
      setState(() {
        rendered.fillChar(ch);
        _refreshCandidates();
      });
      if (rendered.allFilled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('本句已全部填入完成！')),
        );
        // 自动切换到下一句
        if (_activePos < _visibleIndices.length - 1) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) _next();
          });
        } else {
          // 所有句子都完成了，提示是否切换到下一难度
          _showDifficultyCompleteDialog();
        }
      }
    } else {
      // 填错了：弹窗提示
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('不对哦'),
          content: Text('当前应该填的字是「${nextBlank.answer}」，不是「$ch」。'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('继续')),
          ],
        ),
      );
    }
  }

  /// 完成当前难度所有句子后，提示是否切换到下一难度
  /// 无论用户选择什么，都会回到文章开头
  void _showDifficultyCompleteDialog() {
    if (_difficulty >= 4) {
      // 已经是最高难度
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('恭喜！'),
          content: const Text('你已完成最高难度（等级4）的全部句子！\n可以标记熟练后退出，或继续复习。'),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _resetToStart();
              },
              child: const Text('继续'),
            ),
          ],
        ),
      );
      return;
    }
    final nextDifficulty = _difficulty + 1;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('难度完成！'),
        content: Text('你已完成难度 $_difficulty 的全部句子！\n是否切换到难度 $nextDifficulty（提示更少）？'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _resetToStart();
            },
            child: const Text('继续当前难度'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _difficulty = nextDifficulty;
                _revealed = false;
                _renderedCache.clear();
                _refreshCandidates();
              });
              _resetToStart();
            },
            child: Text('切换到难度 $nextDifficulty'),
          ),
        ],
      ),
    );
  }

  /// 回到文章开头（第一句）
  void _resetToStart() {
    setState(() {
      _activePos = 0;
      _revealed = false;
      _refreshCandidates();
    });
    // 滚动到顶部
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  /// 提示一下：显示当前句的前几个字辅助回忆
  void _showHint() {
    final sentence = _poem.sentences[_activeSentenceIndex];
    final hanzi = sentence.characters.where((ch) {
      final code = ch.codeUnitAt(0);
      return code >= 0x4E00 && code <= 0x9FFF;
    }).toList();
    final hintCount = min(3, hanzi.length);
    final hint = hanzi.take(hintCount).join();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('提示'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('本句前 $hintCount 个字：', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 8),
            Text(hint, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 4)),
            const SizedBox(height: 12),
            Text('共 ${hanzi.length} 字，已填 ${_rendered(_activeSentenceIndex).filledCount} / ${_rendered(_activeSentenceIndex).blankCount} 个空白',
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('继续背诵')),
        ],
      ),
    );
  }

  /// 默写输入：弹出输入框，提交后与原文比对，自动标记对错
  void _openDictation() {
    final sentenceIndex = _activeSentenceIndex;
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('默写第 ${sentenceIndex + 1} 句'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('提示：${_rendered(sentenceIndex).toDisplayString()}',
                style: const TextStyle(fontSize: 13, color: Colors.grey)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: '输入默写内容',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final input = controller.text.trim();
              final correct = input.isNotEmpty &&
                  DifficultyRenderer.dictationMatch(_poem.sentences[sentenceIndex], input);
              Navigator.pop(ctx);
              _showDictationResult(correct);
            },
            child: const Text('提交比对'),
          ),
        ],
      ),
    );
  }

  void _showDictationResult(bool correct) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(correct ? Icons.check_circle : Icons.cancel,
            color: correct ? Colors.green : Colors.red, size: 48),
        title: Text(correct ? '默写正确' : '默写有误'),
        content: correct
            ? const Text('这一句已掌握，可标记为「熟练」。')
            : Text('原文：${_poem.sentences[_activeSentenceIndex]}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('关闭')),
          if (correct)
            FilledButton(
              onPressed: () {
                _mark('skilled');
                Navigator.pop(ctx);
              },
              child: const Text('标记熟练'),
            ),
        ],
      ),
    );
  }

  /// 标记当前分句：熟练 / 生疏
  Future<void> _mark(String mark) async {
    if (_poem.id == null) return;
    final sentenceIndex = _activeSentenceIndex;
    await DatabaseHelper.instance.setMark(_poem.id!, sentenceIndex, mark);
    setState(() {
      if (mark == 'skilled') {
        _poem.skilledIndices.add(sentenceIndex);
        _poem.weakIndices.remove(sentenceIndex);
      } else {
        _poem.weakIndices.add(sentenceIndex);
        _poem.skilledIndices.remove(sentenceIndex);
      }
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mark == 'skilled' ? '已标记为「熟练」' : '已标记为「生疏」，将进入复习池')),
    );
  }

  void _exit() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => DetailPage(poem: _poem)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_poem.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: '切换难度（当前 $_difficulty 级）',
            icon: Badge(
              label: Text('$_difficulty'),
              child: const Icon(Icons.tune),
            ),
            onPressed: _changeDifficulty,
          ),
          IconButton(
            tooltip: '退出背诵',
            icon: const Icon(Icons.exit_to_app),
            onPressed: _exit,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildStatusBar(),
          Expanded(child: _buildSentenceList()),
          _buildCandidateArea(),
          _buildActionBar(),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    final sIdx = _activeSentenceIndex;
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Text('第 ${sIdx + 1} / ${_poem.sentences.length} 句',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(width: 12),
            Text('难度 $_difficulty'),
            const Spacer(),
            if (_poem.skilledIndices.contains(sIdx))
              const Chip(
                label: Text('熟练', style: TextStyle(fontSize: 12)),
                backgroundColor: Color(0xFFE8F5E9),
                side: BorderSide(color: Colors.green),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            if (_poem.weakIndices.contains(sIdx))
              const Chip(
                label: Text('生疏', style: TextStyle(fontSize: 12)),
                backgroundColor: Color(0xFFFFF3E0),
                side: BorderSide(color: Colors.orange),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSentenceList() {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _visibleIndices.length,
      itemBuilder: (context, pos) {
        final sentenceIndex = _visibleIndices[pos];
        final isActive = pos == _activePos;
        final isRevealed = isActive && _revealed;
        // 为每个分句分配 GlobalKey（用于自动滚动定位）
        _sentenceKeys[sentenceIndex] ??= GlobalKey();
        return Padding(
          key: _sentenceKeys[sentenceIndex],
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Material(
            color: isActive
                ? Theme.of(context).colorScheme.primaryContainer
                : Theme.of(context).colorScheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => setState(() {
                _activePos = pos;
                _revealed = false;
                _refreshCandidates();
              }),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    SizedBox(
                      width: 32,
                      child: Text('${sentenceIndex + 1}',
                          style: TextStyle(
                            color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey,
                            fontWeight: isActive ? FontWeight.bold : null,
                          )),
                    ),
                    Expanded(
                      child: Text(
                        isRevealed
                            ? _poem.sentences[sentenceIndex]
                            : _rendered(sentenceIndex).toDisplayString(),
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.6,
                          letterSpacing: 1,
                          fontWeight: isActive ? FontWeight.bold : null,
                          color: isRevealed
                              ? Theme.of(context).colorScheme.primary
                              : null,
                        ),
                      ),
                    ),
                    if (isActive)
                      Icon(Icons.play_arrow, color: Theme.of(context).colorScheme.primary),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// 备选字区：6 个字按钮，点击填入当前激活句的空白
  Widget _buildCandidateArea() {
    final rendered = _rendered(_activeSentenceIndex);
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('备选字', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(width: 8),
                Text('已填 ${rendered.filledCount} / ${rendered.blankCount}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _candidateChars.map((ch) {
                // 所有备选字都可点击，点击后自动判断对错
                return SizedBox(
                  width: 48,
                  height: 48,
                  child: OutlinedButton(
                    onPressed: () => _onCandidateTap(ch),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      side: BorderSide(color: Colors.blue),
                    ),
                    child: Text(ch, style: const TextStyle(fontSize: 20, color: Colors.blue)),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _activePos > 0 ? _prev : null,
                    icon: const Icon(Icons.skip_previous),
                    label: const Text('上一句'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _toggleReveal,
                    icon: Icon(_revealed ? Icons.visibility_off : Icons.visibility),
                    label: Text(_revealed ? '隐藏当前句' : '显示当前句'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _activePos < _visibleIndices.length - 1 ? _next : null,
                    icon: const Icon(Icons.skip_next),
                    label: const Text('下一句'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _resetAll,
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('重置全文'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _openDictation,
                    icon: const Icon(Icons.edit_note),
                    label: const Text('默写输入'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _mark('skilled'),
                    icon: const Icon(Icons.thumb_up_outlined, color: Colors.green),
                    label: const Text('熟练'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.green),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _mark('weak'),
                    icon: const Icon(Icons.thumb_down_outlined, color: Colors.orange),
                    label: const Text('生疏'),
                    style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _showHint,
                icon: const Icon(Icons.lightbulb_outline, color: Colors.white),
                label: const Text('提示一下'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
