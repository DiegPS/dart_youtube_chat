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
  final items = <ChatItem>[];
  for (final action in data.actions) {
    final item = _parseActionToChatItem(action);
    if (item != null) items.add(item);
  }

  String continuation = '';
  if (data.continuations.isNotEmpty) {
    continuation = data.continuations.first.continuation;
  }

  return (items, continuation);
}

// ── helpers ────────────────────────────────────────────────────────────────────

ImageItem _parseThumbnailToImageItem(List<Thumbnail> thumbnails, String alt) {
  if (thumbnails.isEmpty) return ImageItem(url: '', alt: alt);
  // Take the last (largest) thumbnail — same as the Go implementation.
  return ImageItem(url: thumbnails.last.url, alt: alt);
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
      final thumbUrl =
          emoji.thumbnails.isNotEmpty ? emoji.thumbnails.first.url : '';
      final shortcut = emoji.shortcuts.isNotEmpty ? emoji.shortcuts.first : '';
      items.add(MessageItem.emoji(EmojiItem(
        url: thumbUrl,
        alt: shortcut,
        emojiText: emoji.isCustomEmoji ? shortcut : emoji.emojiId,
        isCustomEmoji: emoji.isCustomEmoji,
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

  if (item.textMessage != null) {
    base = item.textMessage!.base;
    messageRuns = item.textMessage!.messageRuns;
  } else if (item.paidMessage != null) {
    base = item.paidMessage!.base;
    messageRuns = item.paidMessage!.messageRuns;
  } else if (item.paidSticker != null) {
    base = item.paidSticker!.base;
  } else if (item.membership != null) {
    base = item.membership!.base;
    messageRuns = item.membership!.headerSubtextRuns;
    isMembership = true;
    isMembershipEvent = true;
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

  Badge? badge;
  bool isOwner = false;
  bool isVerified = false;
  bool isModerator = false;

  for (final entry in base.authorBadges) {
    if (entry.customThumbnails != null) {
      badge = Badge(
        thumbnail:
            _parseThumbnailToImageItem(entry.customThumbnails!, entry.tooltip),
        label: entry.tooltip,
      );
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
      badge: badge,
    ),
    message: _parseMessageRuns(messageRuns),
    superChat: superChat,
    isMembership: isMembership,
    isMembershipEvent: isMembershipEvent,
    isOwner: isOwner,
    isVerified: isVerified,
    isModerator: isModerator,
    timestamp: timestamp,
  );
}
