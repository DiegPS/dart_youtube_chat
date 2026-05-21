/// Core data types for dart_youtube_chat.
library;

class YoutubeId {
  final String channelId;
  final String liveId;
  final String handle;

  const YoutubeId({this.channelId = '', this.liveId = '', this.handle = ''});
}

class FetchOptions {
  final String apiKey;
  final String clientVersion;
  final String continuation;
  final String liveId;

  const FetchOptions({
    required this.apiKey,
    required this.clientVersion,
    required this.continuation,
    required this.liveId,
  });

  FetchOptions copyWith({String? continuation}) => FetchOptions(
        apiKey: apiKey,
        clientVersion: clientVersion,
        continuation: continuation ?? this.continuation,
        liveId: liveId,
      );
}

class ImageItem {
  final String url;
  final String alt;

  const ImageItem({required this.url, required this.alt});
}

class EmojiItem {
  final String url;
  final String alt;
  final String emojiText;
  final bool isCustomEmoji;

  const EmojiItem({
    required this.url,
    required this.alt,
    required this.emojiText,
    required this.isCustomEmoji,
  });
}

/// One segment of a chat message — either plain text or an emoji.
/// Exactly one of [text] (non-empty) or [emoji] (non-null) is set.
class MessageItem {
  final String text;
  final EmojiItem? emoji;

  const MessageItem.text(this.text) : emoji = null;
  const MessageItem.emoji(EmojiItem this.emoji) : text = '';

  bool get isEmoji => emoji != null;
}

class Badge {
  final ImageItem thumbnail;
  final String label;

  const Badge({required this.thumbnail, required this.label});
}

class Author {
  final String name;
  final ImageItem? thumbnail;
  final String channelId;
  final Badge? badge;

  const Author({
    required this.name,
    this.thumbnail,
    required this.channelId,
    this.badge,
  });
}

class SuperChat {
  final String amount;

  /// Hex color string: #RRGGBB (alpha stripped).
  final String color;
  final ImageItem? sticker;

  const SuperChat({required this.amount, required this.color, this.sticker});
}

class ChatItem {
  final String id;
  final Author author;
  final List<MessageItem> message;
  final SuperChat? superChat;
  final bool isMembership;
  final bool isMembershipEvent;
  final bool isOwner;
  final bool isVerified;
  final bool isModerator;
  final DateTime timestamp;

  const ChatItem({
    required this.id,
    required this.author,
    required this.message,
    this.superChat,
    required this.isMembership,
    this.isMembershipEvent = false,
    required this.isOwner,
    required this.isVerified,
    required this.isModerator,
    required this.timestamp,
  });
}
