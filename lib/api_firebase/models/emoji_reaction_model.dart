/// 이모티콘 반응 데이터 모델
class EmojiReactionModel {
  final String emoji;
  final String name;
  final int count;

  const EmojiReactionModel({
    required this.emoji,
    required this.name,
    this.count = 0,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EmojiReactionModel &&
        other.emoji == emoji &&
        other.name == name &&
        other.count == count;
  }

  @override
  int get hashCode => emoji.hashCode ^ name.hashCode ^ count.hashCode;
}

/// 사용 가능한 이모티콘들 (사진에서 확인된 이모티콘들)
class EmojiConstants {
  static const List<EmojiReactionModel> availableEmojis = [
    EmojiReactionModel(emoji: '😆', name: 'laughing'),
    EmojiReactionModel(emoji: '😍', name: 'heart_eyes'),
    EmojiReactionModel(emoji: '😭', name: 'crying'),
    EmojiReactionModel(emoji: '😡', name: 'angry'),
  ];
}
