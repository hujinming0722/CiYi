import 'dart:convert';

/// 段落分组（可选功能）：长篇文本可手动划分段落
class ParagraphGroup {
  final String name;
  final int start; // 起始分句索引（含）
  final int end; // 结束分句索引（不含）

  const ParagraphGroup({required this.name, required this.start, required this.end});

  Map<String, dynamic> toJson() => {'name': name, 'start': start, 'end': end};

  factory ParagraphGroup.fromJson(Map<String, dynamic> json) => ParagraphGroup(
        name: json['name'] as String,
        start: json['start'] as int,
        end: json['end'] as int,
      );
}

/// 一篇背诵文本
class Poem {
  final int? id;
  final String title;
  final String originalText;
  final List<String> sentences;
  final List<ParagraphGroup> paragraphs;
  int practiceCount;
  final DateTime createdAt;

  Poem({
    this.id,
    required this.title,
    required this.originalText,
    required this.sentences,
    this.paragraphs = const [],
    this.practiceCount = 0,
    required this.createdAt,
  });

  /// 薄弱分句（生疏）索引集合，由数据库标记加载后填充
  Set<int> weakIndices = {};

  /// 熟练分句索引集合
  Set<int> skilledIndices = {};

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'original_text': originalText,
        'sentences': jsonEncode(sentences),
        'paragraphs': jsonEncode(paragraphs.map((p) => p.toJson()).toList()),
        'practice_count': practiceCount,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory Poem.fromMap(Map<String, dynamic> map) => Poem(
        id: map['id'] as int?,
        title: map['title'] as String,
        originalText: map['original_text'] as String,
        sentences: (jsonDecode(map['sentences'] as String) as List).cast<String>(),
        paragraphs: (jsonDecode(map['paragraphs'] as String? ?? '[]') as List)
            .map((e) => ParagraphGroup.fromJson(e as Map<String, dynamic>))
            .toList(),
        practiceCount: map['practice_count'] as int? ?? 0,
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}
