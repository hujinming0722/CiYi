import 'package:characters/characters.dart';

/// 分句工具：按句号。、问号？、感叹号！、分号；切分，标点附着在前句末尾。
/// 空文本、纯空格行自动过滤，不生成分句。
class SentenceSplitter {
  static const _separators = '。？！；';

  static List<String> split(String text) {
    final result = <String>[];
    final buffer = StringBuffer();
    for (final ch in text.characters) {
      buffer.write(ch);
      if (_separators.contains(ch)) {
        final s = buffer.toString().trim();
        if (s.isNotEmpty) result.add(s);
        buffer.clear();
      }
    }
    final rest = buffer.toString().trim();
    if (rest.isNotEmpty) result.add(rest);
    return result;
  }

  /// 在指定字符索引处拆分一句，返回两句（均非空时有效）
  static List<String>? splitAt(String sentence, int charIndex) {
    if (charIndex <= 0 || charIndex >= sentence.length) return null;
    final a = sentence.substring(0, charIndex).trim();
    final b = sentence.substring(charIndex).trim();
    if (a.isEmpty || b.isEmpty) return null;
    return [a, b];
  }
}
