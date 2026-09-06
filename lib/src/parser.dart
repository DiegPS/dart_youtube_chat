import 'package:dart_youtube_chat/src/types/data.dart';
import 'package:dart_youtube_chat/src/types/yt_response.dart';

final _regexCanonical = RegExp(
    r'<link rel="canonical" href="https://www\.youtube\.com/watch\?v=(.+?)">');
final _regexIsReplay = RegExp(r'''['"]isReplay['"]\s*:\s*(true)''');
final _regexApiKey =
    RegExp(r'''['"]INNERTUBE_API_KEY['"]\s*:\s*['"](.+?)['"]''');
final _regexClientVer =
    RegExp(r'''['"]clientVersion['"]\s*:\s*['"]([\d.]+?)['"]''');
final _regexContinuation =
    RegExp(r'''['"]continuation['"]\s*:\s*['"](.+?)['"]''');

/// Parses the raw HTML of a YouTube live page and returns [FetchOptions].
/// Throws if the stream is finished, not found, or required fields are missing.
FetchOptions getOptionsFromLivePage(String html) {
  final liveIdMatch = _regexCanonical.firstMatch(html);
  if (liveIdMatch == null) {
    throw Exception('Live stream was not found');
  }
  final liveId = liveIdMatch.group(1)!;

  if (_regexIsReplay.hasMatch(html)) {
    throw Exception('$liveId is a finished live stream');
  }

  final apiKeyMatch = _regexApiKey.firstMatch(html);
  // Since ~2023 YouTube accepts requests without the key — fall back to empty.
  final apiKey = apiKeyMatch?.group(1) ?? '';

  final clientVerMatch = _regexClientVer.firstMatch(html);
  if (clientVerMatch == null) {
    throw Exception('clientVersion was not found in live page');
  }
  final clientVersion = clientVerMatch.group(1)!;

  final contMatch = _regexContinuation.firstMatch(html);
  if (contMatch == null) {
    throw Exception('continuation was not found in live page');
  }
  final continuation = contMatch.group(1)!;

  return FetchOptions(
    apiKey: apiKey,
    clientVersion: clientVersion,
    continuation: continuation,
    liveId: liveId,
  );
}

/// Parses a [GetLiveChatResponse] into a list of [ChatItem]s and the next
/// continuation token.
(List<ChatItem>, String) parseChatData(GetLiveChatResponse data) {
  final batch = parseChatBatch(data);
  return (batch.messages, batch.continuation);
}

LiveChatBatch parseChatBatch(GetLiveChatResponse data) {
  final items = <ChatItem>[];
  final events = <LiveChatEvent>[];
  for (final action in data.actions) {
    final item = _parseActionToChatItem(action);
    if (item != null) {
      items.add(item);
    } else {
      events.add(_parseEvent(action));
    }
  }
  final continuation =
      data.continuations.isEmpty ? null : data.continuations.first;
  return LiveChatBatch(
    messages: items,
    events: events,
    continuation: continuation?.continuation ?? '',
    pollingInterval: Duration(milliseconds: continuation?.timeoutMs ?? 1000),
  );
}

// ── helpers ────────────────────────────────────────────────────────────────────

ImageItem _parseThumbnailToImageItem(List<Thumbnail> thumbnails, String alt) {
  if (thumbnails.isEmpty) return ImageItem(url: '', alt: alt);
  final variants = thumbnails
      .map((thumbnail) => ImageVariant(
            url: normalizeYoutubeImageUrl(thumbnail.url),
            width: thumbnail.width,
            height: thumbnail.height,
          ))
      .toList(growable: false);
  final selected = variants.last;
  return ImageItem(
    url: selected.url,
    alt: alt,
    width: selected.width,
    height: selected.height,
    variants: variants,
  );
}

String normalizeYoutubeImageUrl(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('//')) return 'https:$trimmed';
  final uri = Uri.tryParse(trimmed);
  if (uri != null &&
      uri.scheme == 'http' &&
      (uri.host.endsWith('googleusercontent.com') ||
          uri.host.endsWith('ggpht.com') ||
          uri.host.endsWith('ytimg.com'))) {
    return uri.replace(scheme: 'https').toString();
  }
  return trimmed;
}

/// Converts a 32-bit ARGB integer to a #RRGGBB hex string.
String convertColorToHex6(int colorInt) {
  final hex = colorInt.toRadixString(16).padLeft(8, '0');
  return '#${hex.substring(2).toUpperCase()}';
}

List<MessageItem> _parseMessageRuns(List<MessageRun> runs) {
  final items = <MessageItem>[];
  for (final run in runs) {
    if (run.text != null && run.text!.isNotEmpty) {
      items.add(MessageItem.text(run.text!));
    } else if (run.emoji != null) {
      final emoji = run.emoji!;
      // Use first thumbnail (shift() in the original TS).
      final shortcut = emoji.shortcuts.isNotEmpty ? emoji.shortcuts.first : '';
      final image = _parseThumbnailToImageItem(emoji.thumbnails, shortcut);
      items.add(MessageItem.emoji(EmojiItem(
        url: image.url,
        alt: shortcut,
        emojiText: emoji.isCustomEmoji ? shortcut : emoji.emojiId,
        isCustomEmoji: emoji.isCustomEmoji,
        variants: image.variants,
      )));
    }
  }
  return items;
}

ChatItem? _parseActionToChatItem(Action action) {
  final item = action.addChatItemAction;
  if (item == null) return null;

  MessageRendererBase? base;
  List<MessageRun> messageRuns = [];
  bool isMembership = false;
  bool isMembershipEvent = false;
  var kind = ChatItemKind.text;
  var membershipText = '';

  if (item.textMessage != null) {
    base = item.textMessage!.base;
    messageRuns = item.textMessage!.messageRuns;
  } else if (item.paidMessage != null) {
    base = item.paidMessage!.base;
    messageRuns = item.paidMessage!.messageRuns;
    kind = ChatItemKind.paidMessage;
  } else if (item.paidSticker != null) {
    base = item.paidSticker!.base;
    kind = ChatItemKind.paidSticker;
  } else if (item.membership != null) {
    base = item.membership!.base;
    messageRuns = item.membership!.headerSubtextRuns;
    isMembership = true;
    isMembershipEvent = true;
    kind = ChatItemKind.membership;
    membershipText = _plainText(messageRuns);
  }

  if (base == null) return null;

  // Timestamp: timestampUsec is microseconds since epoch as a string.
  DateTime timestamp;
  final usec = int.tryParse(base.timestampUsec);
  if (usec != null) {
    timestamp = DateTime.fromMicrosecondsSinceEpoch(usec);
  } else {
    timestamp = DateTime.now();
  }

  final authorThumb =
      _parseThumbnailToImageItem(base.authorThumbnails, base.authorName ?? '');

  final badges = <Badge>[];
  bool isOwner = false;
  bool isVerified = false;
  bool isModerator = false;

  for (final entry in base.authorBadges) {
    if (entry.customThumbnails != null) {
      badges.add(Badge(
        thumbnail:
            _parseThumbnailToImageItem(entry.customThumbnails!, entry.tooltip),
        label: entry.tooltip,
      ));
      isMembership = true;
    } else if (entry.iconType != null) {
      switch (entry.iconType) {
        case 'OWNER':
          isOwner = true;
        case 'VERIFIED':
          isVerified = true;
        case 'MODERATOR':
          isModerator = true;
      }
    }
  }

  SuperChat? superChat;
  if (item.paidSticker != null) {
    final r = item.paidSticker!;
    superChat = SuperChat(
      amount: r.purchaseAmountText,
      color: convertColorToHex6(r.backgroundColor),
      sticker: _parseThumbnailToImageItem(
          r.stickerThumbnails, r.stickerAccessibilityLabel),
    );
  } else if (item.paidMessage != null) {
    final r = item.paidMessage!;
    superChat = SuperChat(
      amount: r.purchaseAmountText,
      color: convertColorToHex6(r.bodyBackgroundColor),
    );
  }

  return ChatItem(
    id: base.id,
    author: Author(
      name: base.authorName ?? '',
      thumbnail: authorThumb,
      channelId: base.authorExternalChannelId,
      badge: badges.isEmpty ? null : badges.first,
      badges: badges,
    ),
    message: _parseMessageRuns(messageRuns),
    superChat: superChat,
    isMembership: isMembership,
    isMembershipEvent: isMembershipEvent,
    isOwner: isOwner,
    isVerified: isVerified,
    isModerator: isModerator,
    timestamp: timestamp,
    kind: kind,
    membershipText: membershipText,
    rendererType: item.rendererType,
    raw: item.raw,
  );
}

String _plainText(List<MessageRun> runs) => runs
    .map((run) =>
        run.text ??
        (run.emoji?.shortcuts.isNotEmpty == true
            ? run.emoji!.shortcuts.first
            : run.emoji?.emojiId ?? ''))
    .join();

LiveChatEvent _parseEvent(Action action) {
  final renderer = _findRenderer(action.raw);
  final rendererId = renderer?.$2['id'];
  return LiveChatEvent(
    actionType: action.actionType,
    rendererType: renderer?.$1 ?? '',
    id: rendererId is String ? rendererId : '',
    text: _extractText(renderer?.$2),
    raw: action.raw,
  );
}

(String, Map<String, dynamic>)? _findRenderer(Object? value) {
  if (value is Map<String, dynamic>) {
    for (final entry in value.entries) {
      if (entry.key.endsWith('Renderer') &&
          entry.value is Map<String, dynamic>) {
        return (entry.key, entry.value as Map<String, dynamic>);
      }
      final found = _findRenderer(entry.value);
      if (found != null) return found;
    }
  } else if (value is List) {
    for (final item in value) {
      final found = _findRenderer(item);
      if (found != null) return found;
    }
  }
  return null;
}

String _extractText(Map<String, dynamic>? renderer) {
  if (renderer == null) return '';
  for (final key in const ['message', 'headerPrimaryText', 'headerSubtext']) {
    final value = renderer[key];
    if (value is Map<String, dynamic>) {
      final simple = value['simpleText'];
      if (simple is String) return simple;
      final runs = value['runs'];
      if (runs is List) {
        return runs
            .whereType<Map<String, dynamic>>()
            .map((run) => run['text'] as String? ?? '')
            .join();
      }
    }
  }
  return '';
}
