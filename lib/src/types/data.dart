/// Core data types for dart_youtube_chat.
library;

class YoutubeId {
  final String channelId;
  final String liveId;
  final String handle;

  const YoutubeId({this.channelId = '', this.liveId = '', this.handle = ''});

  /// Parses a channel, video, handle, or supported YouTube URL.
  ///
  /// Throws a [FormatException] when [value] is not an unambiguous YouTube
  /// identifier. Foreign URL hosts are always rejected.
  factory YoutubeId.parse(String value) {
    final result = tryParse(value);
    if (result == null) {
      throw FormatException('Invalid YouTube identifier', value);
    }
    return result;
  }

  /// Parses [value], or returns `null` when it is not a YouTube identifier.
  static YoutubeId? tryParse(String value) {
    final input = value.trim();
    if (input.isEmpty) return null;
    if (input.startsWith('@') && _handlePattern.hasMatch(input)) {
      return YoutubeId(handle: input);
    }
    if (_channelIdPattern.hasMatch(input)) {
      return YoutubeId(channelId: input);
    }
    if (_videoIdPattern.hasMatch(input)) return YoutubeId(liveId: input);

    final uri = Uri.tryParse(input);
    if (uri == null || !uri.hasScheme || !_youtubeHosts.contains(uri.host)) {
      return null;
    }
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    if (uri.host == 'youtu.be' && segments.isNotEmpty) {
      final id = segments.first;
      return _videoIdPattern.hasMatch(id) ? YoutubeId(liveId: id) : null;
    }
    final queryId = uri.queryParameters['v'];
    if (queryId != null && _videoIdPattern.hasMatch(queryId)) {
      return YoutubeId(liveId: queryId);
    }
    if (segments.length >= 2 && segments.first == 'channel') {
      final id = segments[1];
      return _channelIdPattern.hasMatch(id) ? YoutubeId(channelId: id) : null;
    }
    if (segments.isNotEmpty && _handlePattern.hasMatch(segments.first)) {
      return YoutubeId(handle: segments.first);
    }
    if (segments.length >= 2 &&
        const {'live', 'shorts', 'embed'}.contains(segments.first) &&
        _videoIdPattern.hasMatch(segments[1])) {
      return YoutubeId(liveId: segments[1]);
    }
    return null;
  }

  static final _handlePattern = RegExp(r'^@[A-Za-z0-9._-]{3,30}$');
  static final _channelIdPattern = RegExp(r'^UC[A-Za-z0-9_-]{22}$');
  static final _videoIdPattern = RegExp(r'^[A-Za-z0-9_-]{11}$');
  static const _youtubeHosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtu.be',
  };
}

/// Locale and browser identity sent with anonymous YouTube requests.
class YoutubeClientContext {
  final String languageCode;
  final String regionCode;
  final String userAgent;

  const YoutubeClientContext({
    this.languageCode = 'en',
    this.regionCode = 'US',
    this.userAgent = '',
  });
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

  /// The emoji image with all available size variants.
  ImageItem get image => ImageItem(url: url, alt: alt, variants: variants);

  /// Selects the smallest emoji image suitable for the rendered size.
  ImageVariant bestFor(double logicalSize, {double pixelRatio = 1}) =>
      image.bestFor(logicalSize, pixelRatio: pixelRatio);
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

  /// Every visual membership badge supplied by YouTube.
  List<Badge> get allBadges =>
      badges.isNotEmpty ? badges : (badge == null ? const [] : [badge!]);
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
  final List<LiveChatAction> buttons;
  final List<LiveChatAction> menuActions;
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
    this.buttons = const [],
    this.menuActions = const [],
    this.raw = const {},
  });
}

enum LiveChatEventKind {
  messageDeleted,
  authorMessagesDeleted,
  chatItemReplaced,
  bannerAdded,
  bannerRemoved,
  tickerAdded,
  tickerRemoved,
  viewerNotice,
  membershipGiftPurchased,
  membershipGiftReceived,
  pollUpdated,
  tooltip,
  unknown,
}

/// A command attached to a button or menu entry, exposed as read-only data.
class LiveChatAction {
  final String endpointName;
  final String text;
  final String iconType;
  final String accessibilityLabel;
  final Map<String, dynamic> raw;

  const LiveChatAction({
    required this.endpointName,
    this.text = '',
    this.iconType = '',
    this.accessibilityLabel = '',
    this.raw = const {},
  });
}

class LiveChatEvent {
  final LiveChatEventKind kind;
  final String actionType;
  final String rendererType;
  final String id;
  final String text;
  final String targetItemId;
  final String targetActionId;
  final String authorChannelId;
  final int giftMembershipCount;
  final Duration duration;
  final List<LiveChatAction> buttons;
  final List<LiveChatAction> menuActions;
  final Map<String, dynamic> raw;

  const LiveChatEvent({
    this.kind = LiveChatEventKind.unknown,
    required this.actionType,
    required this.rendererType,
    this.id = '',
    this.text = '',
    this.targetItemId = '',
    this.targetActionId = '',
    this.authorChannelId = '',
    this.giftMembershipCount = 0,
    this.duration = Duration.zero,
    this.buttons = const [],
    this.menuActions = const [],
    this.raw = const {},
  });
}

class LiveChatBatch {
  final List<ChatItem> messages;
  final List<LiveChatEvent> events;
  final String continuation;
  final Duration pollingInterval;
  final Map<String, dynamic> raw;

  const LiveChatBatch({
    required this.messages,
    required this.events,
    required this.continuation,
    required this.pollingInterval,
    this.raw = const {},
  });

  Map<String, dynamic> toJson() => raw;
}
