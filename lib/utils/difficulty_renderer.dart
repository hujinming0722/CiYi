import 'dart:math';

import 'package:characters/characters.dart';

/// 分句渲染结果：把句子拆为可独立填入的 token 序列
class RenderedSentence {
  final List<SentenceToken> tokens;

  const RenderedSentence(this.tokens);

  /// 当前展示文本（未填入的空白显示为 □，已填入的显示答案字）
  String toDisplayString() {
    return tokens
        .map((t) => t.isBlank ? (t.filled ? t.answer : '□') : t.text)
        .join();
  }

  /// 是否所有空白都已填入
  bool get allFilled => tokens.where((t) => t.isBlank).every((t) => t.filled);

  /// 空白槽位总数
  int get blankCount => tokens.where((t) => t.isBlank).length;

  /// 已填入数量
  int get filledCount => tokens.where((t) => t.isBlank && t.filled).length;

  /// 收集所有空白槽位的答案字（去重，保持顺序）
  List<String> get answers {
    final seen = <String>{};
    final result = <String>[];
    for (final t in tokens) {
      if (t.isBlank && !seen.contains(t.answer)) {
        seen.add(t.answer);
        result.add(t.answer);
      }
    }
    return result;
  }

  /// 填入一个字：找到第一个答案匹配且未填充的空白槽位
  /// 返回是否成功填入
  bool fillChar(String ch) {
    for (final t in tokens) {
      if (t.isBlank && !t.filled && t.answer == ch) {
        t.filled = true;
        return true;
      }
    }
    return false;
  }

  /// 重置所有填入状态
  void resetFill() {
    for (final t in tokens) {
      t.filled = false;
    }
  }
}

/// 句子中的一个片段：可见文字或空白槽位
class SentenceToken {
  final String text; // 可见文字（空白槽位为空串）
  final bool isBlank; // 是否是空白槽位
  final String answer; // 空白槽位对应的答案字
  bool filled; // 是否已被填入

  SentenceToken({
    this.text = '',
    this.isBlank = false,
    this.answer = '',
    this.filled = false,
  });
}

/// 难度渲染器：4 个档位，整篇统一难度，每分句独立渲染。
///
/// 等级1｜少量挖空：随机挑选少量实词关键词替换为下划线，其余文字原样保留
/// 等级2｜保留句首 2~3 个字，后面全部文字替换为下划线
/// 等级3｜仅保留句首 1 个字，剩余全部文字变为下划线
/// 等级4｜全部汉字隐藏，仅保留原有标点符号
class DifficultyRenderer {
  static const _punctuation = '，。、？！；：""''（）《》〈〉「」『』—…·';

  static bool _isHanzi(String ch) {
    final code = ch.codeUnitAt(0);
    return code >= 0x4E00 && code <= 0x9FFF;
  }

  /// 渲染单个分句。seed 保证同一句同一难度渲染结果稳定（可复现）。
  static RenderedSentence render(String sentence, int difficulty, int seed) {
    switch (difficulty) {
      case 1:
        return _renderLevel1(sentence, seed);
      case 2:
        return _renderLevel2(sentence, seed);
      case 3:
        return _renderLevel3(sentence);
      case 4:
        return _renderLevel4(sentence);
      default:
        return RenderedSentence(sentence.characters
            .map((ch) => SentenceToken(text: ch))
            .toList());
    }
  }

  /// 等级1：按标点分段，每段随机挖空约 30% 的汉字（至少 1 个）
  static RenderedSentence _renderLevel1(String sentence, int seed) {
    final rand = Random(seed);
    final tokens = <SentenceToken>[];
    final segments = _splitByPunctuation(sentence);
    for (final seg in segments) {
      if (seg.hanziCount == 0) {
        tokens.add(SentenceToken(text: seg.text));
        continue;
      }
      final chars = seg.text.characters.toList();
      final hanziPositions = <int>[];
      for (var i = 0; i < chars.length; i++) {
        if (_isHanzi(chars[i])) hanziPositions.add(i);
      }
      final digCount = max(1, (hanziPositions.length * 0.3).round());
      final shuffled = hanziPositions.toList()..shuffle(rand);
      final digSet = shuffled.take(digCount).toSet();
      for (var i = 0; i < chars.length; i++) {
        if (digSet.contains(i)) {
          tokens.add(SentenceToken(isBlank: true, answer: chars[i]));
        } else {
          tokens.add(SentenceToken(text: chars[i]));
        }
      }
    }
    return RenderedSentence(tokens);
  }

  /// 等级2：保留句首 2~3 个汉字，其余汉字全部替换为下划线，标点保留
  static RenderedSentence _renderLevel2(String sentence, int seed) {
    final rand = Random(seed);
    final keep = rand.nextBool() ? 2 : 3;
    return _keepHead(sentence, keep);
  }

  /// 等级3：仅保留句首 1 个汉字，其余汉字全部替换为下划线，标点保留
  static RenderedSentence _renderLevel3(String sentence) {
    return _keepHead(sentence, 1);
  }

  static RenderedSentence _keepHead(String sentence, int keepCount) {
    final tokens = <SentenceToken>[];
    var kept = 0;
    for (final ch in sentence.characters) {
      if (_isHanzi(ch) && kept < keepCount) {
        tokens.add(SentenceToken(text: ch));
        kept++;
      } else if (_isHanzi(ch)) {
        tokens.add(SentenceToken(isBlank: true, answer: ch));
      } else {
        tokens.add(SentenceToken(text: ch));
      }
    }
    return RenderedSentence(tokens);
  }

  /// 等级4：全部汉字隐藏，仅保留标点
  static RenderedSentence _renderLevel4(String sentence) {
    final tokens = <SentenceToken>[];
    for (final ch in sentence.characters) {
      if (_isHanzi(ch)) {
        tokens.add(SentenceToken(isBlank: true, answer: ch));
      } else {
        tokens.add(SentenceToken(text: ch));
      }
    }
    return RenderedSentence(tokens);
  }

  /// 按标点切段，保留标点附着在段尾
  static List<_Segment> _splitByPunctuation(String sentence) {
    final segments = <_Segment>[];
    final buf = StringBuffer();
    var hanziCount = 0;
    for (final ch in sentence.characters) {
      buf.write(ch);
      if (_isHanzi(ch)) hanziCount++;
      if (_punctuation.contains(ch)) {
        segments.add(_Segment(buf.toString(), hanziCount));
        buf.clear();
        hanziCount = 0;
      }
    }
    if (buf.isNotEmpty) {
      segments.add(_Segment(buf.toString(), hanziCount));
    }
    return segments;
  }

  /// 默写比对：提取汉字序列（去除标点、空格），完全一致则正确
  static bool dictationMatch(String original, String input) {
    String hanziOnly(String s) {
      final buf = StringBuffer();
      for (final ch in s.characters) {
        if (_isHanzi(ch)) buf.write(ch);
      }
      return buf.toString();
    }

    return hanziOnly(original) == hanziOnly(input);
  }
}

class _Segment {
  final String text;
  final int hanziCount;
  const _Segment(this.text, this.hanziCount);
}
