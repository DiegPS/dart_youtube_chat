/// JSON response structs for the YouTube InnerTube live chat API.
library;

class Thumbnail {
  final String url;
  final int width;
  final int height;

  const Thumbnail({required this.url, this.width = 0, this.height = 0});

  factory Thumbnail.fromJson(Map<String, dynamic> j) => Thumbnail(
        url: _string(j['url']),
        width: _integer(j['width']),
        height: _integer(j['height']),
      );
}

class MessageRun {
  final String? text;
  final MessageEmoji? emoji;

  const MessageRun({this.text, this.emoji});

  factory MessageRun.fromJson(Map<String, dynamic> j) {
    final emoji = _nullableMap(j['emoji']);
    if (emoji != null) {
      return MessageRun(
        emoji: MessageEmoji.fromJson(emoji),
      );
    }
    return MessageRun(text: j['text'] is String ? j['text'] as String : null);
  }
}

class MessageEmoji {
  final String emojiId;
  final List<String> shortcuts;
  final List<Thumbnail> thumbnails;
  final bool isCustomEmoji;

  const MessageEmoji({
    required this.emojiId,
    required this.shortcuts,
    required this.thumbnails,
    required this.isCustomEmoji,
  });

  factory MessageEmoji.fromJson(Map<String, dynamic> j) {
    final image = _map(j['image']);
    return MessageEmoji(
      emojiId: _string(j['emojiId']),
      shortcuts: _stringList(j['shortcuts']),
      thumbnails:
          _mapList(image['thumbnails']).map(Thumbnail.fromJson).toList(),
      isCustomEmoji: j['isCustomEmoji'] == true,
    );
  }
}

class AuthorBadgeEntry {
  final List<Thumbnail>? customThumbnails;
  final String? iconType;
  final String tooltip;

  const AuthorBadgeEntry({
    this.customThumbnails,
    this.iconType,
    required this.tooltip,
  });

  factory AuthorBadgeEntry.fromJson(Map<String, dynamic> j) {
    final renderer = _map(j['liveChatAuthorBadgeRenderer']);
    final customThumb = _nullableMap(renderer['customThumbnail']);
    final icon = _nullableMap(renderer['icon']);
    return AuthorBadgeEntry(
      customThumbnails: customThumb == null
          ? null
          : _mapList(customThumb['thumbnails'])
              .map(Thumbnail.fromJson)
              .toList(),
      iconType:
          icon?['iconType'] is String ? icon!['iconType'] as String : null,
      tooltip: _string(renderer['tooltip']),
    );
  }
}

class MessageRendererBase {
  final String id;
  final String timestampUsec;
  final String? authorName;
  final List<Thumbnail> authorThumbnails;
  final List<AuthorBadgeEntry> authorBadges;
  final String authorExternalChannelId;

  const MessageRendererBase({
    required this.id,
    required this.timestampUsec,
    this.authorName,
    required this.authorThumbnails,
    required this.authorBadges,
    required this.authorExternalChannelId,
  });

  factory MessageRendererBase.fromJson(Map<String, dynamic> j) {
    final authorNameObj = _nullableMap(j['authorName']);
    final authorPhoto = _map(j['authorPhoto']);
    return MessageRendererBase(
      id: _string(j['id']),
      timestampUsec: _string(j['timestampUsec'], fallback: '0'),
      authorName: authorNameObj?['simpleText'] is String
          ? authorNameObj!['simpleText'] as String
          : null,
      authorThumbnails:
          _mapList(authorPhoto['thumbnails']).map(Thumbnail.fromJson).toList(),
      authorBadges:
          _mapList(j['authorBadges']).map(AuthorBadgeEntry.fromJson).toList(),
      authorExternalChannelId: _string(j['authorExternalChannelId']),
    );
  }
}

class LiveChatTextMessageRenderer {
  final MessageRendererBase base;
  final List<MessageRun> messageRuns;

  const LiveChatTextMessageRenderer({
    required this.base,
    required this.messageRuns,
  });

  factory LiveChatTextMessageRenderer.fromJson(Map<String, dynamic> j) {
    final msg = _map(j['message']);
    return LiveChatTextMessageRenderer(
      base: MessageRendererBase.fromJson(j),
      messageRuns: _mapList(msg['runs']).map(MessageRun.fromJson).toList(),
    );
  }
}

class LiveChatPaidMessageRenderer {
  final MessageRendererBase base;
  final List<MessageRun> messageRuns;
  final String purchaseAmountText;
  final int bodyBackgroundColor;

  const LiveChatPaidMessageRenderer({
    required this.base,
    required this.messageRuns,
    required this.purchaseAmountText,
    required this.bodyBackgroundColor,
  });

  factory LiveChatPaidMessageRenderer.fromJson(Map<String, dynamic> j) {
    final msg = _map(j['message']);
    final amt = _map(j['purchaseAmountText']);
    return LiveChatPaidMessageRenderer(
      base: MessageRendererBase.fromJson(j),
      messageRuns: _mapList(msg['runs']).map(MessageRun.fromJson).toList(),
      purchaseAmountText: _string(amt['simpleText']),
      bodyBackgroundColor: _integer(j['bodyBackgroundColor']),
    );
  }
}

class LiveChatPaidStickerRenderer {
  final MessageRendererBase base;
  final String purchaseAmountText;
  final List<Thumbnail> stickerThumbnails;
  final String stickerAccessibilityLabel;
  final int backgroundColor;

  const LiveChatPaidStickerRenderer({
    required this.base,
    required this.purchaseAmountText,
    required this.stickerThumbnails,
    required this.stickerAccessibilityLabel,
    required this.backgroundColor,
  });

  factory LiveChatPaidStickerRenderer.fromJson(Map<String, dynamic> j) {
    final amt = _map(j['purchaseAmountText']);
    final sticker = _map(j['sticker']);
    final stickerAccData =
        _map(_map(sticker['accessibility'])['accessibilityData']);
    return LiveChatPaidStickerRenderer(
      base: MessageRendererBase.fromJson(j),
      purchaseAmountText: _string(amt['simpleText']),
      stickerThumbnails:
          _mapList(sticker['thumbnails']).map(Thumbnail.fromJson).toList(),
      stickerAccessibilityLabel: _string(stickerAccData['label']),
      backgroundColor: _integer(j['backgroundColor']),
    );
  }
}

class LiveChatMembershipItemRenderer {
  final MessageRendererBase base;
  final List<MessageRun> headerSubtextRuns;

  const LiveChatMembershipItemRenderer({
    required this.base,
    required this.headerSubtextRuns,
  });

  factory LiveChatMembershipItemRenderer.fromJson(Map<String, dynamic> j) {
    final headerSubtext = _map(j['headerSubtext']);
    return LiveChatMembershipItemRenderer(
      base: MessageRendererBase.fromJson(j),
      headerSubtextRuns:
          _mapList(headerSubtext['runs']).map(MessageRun.fromJson).toList(),
    );
  }
}

class ActionItem {
  final LiveChatTextMessageRenderer? textMessage;
  final LiveChatPaidMessageRenderer? paidMessage;
  final LiveChatMembershipItemRenderer? membership;
  final LiveChatPaidStickerRenderer? paidSticker;
  final Map<String, dynamic> raw;
  final String rendererType;

  const ActionItem({
    this.textMessage,
    this.paidMessage,
    this.membership,
    this.paidSticker,
    this.raw = const {},
    this.rendererType = '',
  });

  factory ActionItem.fromJson(Map<String, dynamic> j) => ActionItem(
        textMessage: _nullableMap(j['liveChatTextMessageRenderer']) != null
            ? LiveChatTextMessageRenderer.fromJson(
                _map(j['liveChatTextMessageRenderer']))
            : null,
        paidMessage: _nullableMap(j['liveChatPaidMessageRenderer']) != null
            ? LiveChatPaidMessageRenderer.fromJson(
                _map(j['liveChatPaidMessageRenderer']))
            : null,
        membership: _nullableMap(j['liveChatMembershipItemRenderer']) != null
            ? LiveChatMembershipItemRenderer.fromJson(
                _map(j['liveChatMembershipItemRenderer']))
            : null,
        paidSticker: _nullableMap(j['liveChatPaidStickerRenderer']) != null
            ? LiveChatPaidStickerRenderer.fromJson(
                _map(j['liveChatPaidStickerRenderer']))
            : null,
        raw: Map.unmodifiable(j),
        rendererType: j.keys.firstWhere(
          (key) => key.endsWith('Renderer'),
          orElse: () => '',
        ),
      );
}

class Action {
  final ActionItem? addChatItemAction;
  final Map<String, dynamic> raw;
  final String actionType;

  const Action({
    this.addChatItemAction,
    this.raw = const {},
    this.actionType = '',
  });

  factory Action.fromJson(Map<String, dynamic> j) {
    final add = _nullableMap(j['addChatItemAction']);
    return Action(
      addChatItemAction:
          add != null ? ActionItem.fromJson(_map(add['item'])) : null,
      raw: Map.unmodifiable(j),
      actionType: j.keys.firstWhere(
        (key) => key != 'clickTrackingParams' && key != 'trackingParams',
        orElse: () => j.keys.isEmpty ? '' : j.keys.first,
      ),
    );
  }
}

class ContinuationData {
  final String? invalidationContinuation;
  final String? timedContinuation;
  final int timeoutMs;

  const ContinuationData({
    this.invalidationContinuation,
    this.timedContinuation,
    this.timeoutMs = 1000,
  });

  String get continuation =>
      invalidationContinuation ?? timedContinuation ?? '';

  factory ContinuationData.fromJson(Map<String, dynamic> j) {
    final inv = _nullableMap(j['invalidationContinuationData']);
    final timed = _nullableMap(j['timedContinuationData']);
    return ContinuationData(
      invalidationContinuation: inv?['continuation'] is String
          ? inv!['continuation'] as String
          : null,
      timedContinuation: timed?['continuation'] is String
          ? timed!['continuation'] as String
          : null,
      timeoutMs: timed?['timeoutMs'] is num
          ? (timed!['timeoutMs'] as num).toInt()
          : inv?['timeoutMs'] is num
              ? (inv!['timeoutMs'] as num).toInt()
              : 1000,
    );
  }
}

class GetLiveChatResponse {
  final List<Action> actions;
  final List<ContinuationData> continuations;
  final Map<String, dynamic> raw;

  const GetLiveChatResponse({
    required this.actions,
    required this.continuations,
    this.raw = const {},
  });

  factory GetLiveChatResponse.fromJson(Map<String, dynamic> j) {
    final cc = _map(j['continuationContents']);
    final lcc = _map(cc['liveChatContinuation']);
    return GetLiveChatResponse(
      actions: _mapList(lcc['actions']).map(Action.fromJson).toList(),
      continuations: _mapList(lcc['continuations'])
          .map(ContinuationData.fromJson)
          .toList(),
      raw: j,
    );
  }
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

Map<String, dynamic>? _nullableMap(Object? value) =>
    value is Map<String, dynamic> ? value : null;

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? value.whereType<Map<String, dynamic>>().toList(growable: false)
    : const [];

List<String> _stringList(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const [];

String _string(Object? value, {String fallback = ''}) =>
    value is String ? value : fallback;

int _integer(Object? value) => value is num ? value.toInt() : 0;
