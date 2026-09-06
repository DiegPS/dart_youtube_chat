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
  final int width;
  final int height;
  final List<ImageVariant> variants;

  const ImageItem({
    required this.url,
    required this.alt,
    this.width = 0,
    this.height = 0,
    this.variants = const [],
  });

  /// Returns the smallest image that can cover [logicalSize] at [pixelRatio].
  ImageVariant bestFor(double logicalSize, {double pixelRatio = 1}) {
    final target = (logicalSize * pixelRatio).ceil();
    final candidates = variants.isEmpty
        ? [ImageVariant(url: url, width: width, height: height)]
        : [...variants];
    candidates.sort((a, b) => a.longestSide.compareTo(b.longestSide));
    return candidates.firstWhere(
      (image) => image.longestSide >= target,
      orElse: () => candidates.last,
    );
  }
}

class ImageVariant {
  final String url;
  final int width;
  final int height;

  const ImageVariant({required this.url, this.width = 0, this.height = 0});

  int get longestSide => width > height ? width : height;
}

class EmojiItem {
  final String url;
  final String alt;
  final String emojiText;
  final bool isCustomEmoji;
  final List<ImageVariant> variants;

  const EmojiItem({
    required this.url,
    required this.alt,
    required this.emojiText,
    required this.isCustomEmoji,
    this.variants = const [],
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
  final List<Badge> badges;

  const Author({
    required this.name,
    this.thumbnail,
    required this.channelId,
    this.badge,
    this.badges = const [],
  });
}

enum ChatItemKind { text, paidMessage, paidSticker, membership }

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
  final ChatItemKind kind;
  final String membershipText;
  final String rendererType;
  final Map<String, dynamic> raw;

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
    this.kind = ChatItemKind.text,
    this.membershipText = '',
    this.rendererType = '',
    this.raw = const {},
  });
}

class LiveChatEvent {
  final String actionType;
  final String rendererType;
  final String id;
  final String text;
  final Map<String, dynamic> raw;

  const LiveChatEvent({
    required this.actionType,
    required this.rendererType,
    this.id = '',
    this.text = '',
    this.raw = const {},
  });
}

class LiveChatBatch {
  final List<ChatItem> messages;
  final List<LiveChatEvent> events;
  final String continuation;
  final Duration pollingInterval;

  const LiveChatBatch({
    required this.messages,
    required this.events,
    required this.continuation,
    required this.pollingInterval,
  });
}
