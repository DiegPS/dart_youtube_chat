/// JSON response structs for the YouTube InnerTube live chat API.
library;

class Thumbnail {
  final String url;
  final int width;
  final int height;

  const Thumbnail({required this.url, this.width = 0, this.height = 0});

  factory Thumbnail.fromJson(Map<String, dynamic> j) => Thumbnail(
        url: j['url'] as String? ?? '',
        width: j['width'] as int? ?? 0,
        height: j['height'] as int? ?? 0,
      );
}

class MessageRun {
  final String? text;
  final MessageEmoji? emoji;

  const MessageRun({this.text, this.emoji});

  factory MessageRun.fromJson(Map<String, dynamic> j) {
    if (j.containsKey('emoji')) {
      return MessageRun(
        emoji: MessageEmoji.fromJson(j['emoji'] as Map<String, dynamic>),
      );
    }
    return MessageRun(text: j['text'] as String?);
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
    final image = j['image'] as Map<String, dynamic>? ?? {};
    final rawThumbs = image['thumbnails'] as List<dynamic>? ?? [];
    return MessageEmoji(
      emojiId: j['emojiId'] as String? ?? '',
      shortcuts: (j['shortcuts'] as List<dynamic>? ?? []).cast<String>(),
      thumbnails: rawThumbs
          .map((t) => Thumbnail.fromJson(t as Map<String, dynamic>))
          .toList(),
      isCustomEmoji: j['isCustomEmoji'] as bool? ?? false,
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
    final renderer =
        j['liveChatAuthorBadgeRenderer'] as Map<String, dynamic>? ?? {};
    final customThumb = renderer['customThumbnail'] as Map<String, dynamic>?;
    final icon = renderer['icon'] as Map<String, dynamic>?;
    return AuthorBadgeEntry(
      customThumbnails: customThumb == null
          ? null
          : (customThumb['thumbnails'] as List<dynamic>? ?? [])
              .map((t) => Thumbnail.fromJson(t as Map<String, dynamic>))
              .toList(),
      iconType: icon?['iconType'] as String?,
      tooltip: renderer['tooltip'] as String? ?? '',
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
    final authorNameObj = j['authorName'] as Map<String, dynamic>?;
    final authorPhoto = j['authorPhoto'] as Map<String, dynamic>? ?? {};
    final rawThumbs = authorPhoto['thumbnails'] as List<dynamic>? ?? [];
    return MessageRendererBase(
      id: j['id'] as String? ?? '',
      timestampUsec: j['timestampUsec'] as String? ?? '0',
      authorName: authorNameObj?['simpleText'] as String?,
      authorThumbnails: rawThumbs
          .map((t) => Thumbnail.fromJson(t as Map<String, dynamic>))
          .toList(),
      authorBadges: (j['authorBadges'] as List<dynamic>? ?? [])
          .map((b) => AuthorBadgeEntry.fromJson(b as Map<String, dynamic>))
          .toList(),
      authorExternalChannelId: j['authorExternalChannelId'] as String? ?? '',
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
    final msg = j['message'] as Map<String, dynamic>? ?? {};
    return LiveChatTextMessageRenderer(
      base: MessageRendererBase.fromJson(j),
      messageRuns: (msg['runs'] as List<dynamic>? ?? [])
          .map((r) => MessageRun.fromJson(r as Map<String, dynamic>))
          .toList(),
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
    final msg = j['message'] as Map<String, dynamic>? ?? {};
    final amt = j['purchaseAmountText'] as Map<String, dynamic>? ?? {};
    return LiveChatPaidMessageRenderer(
      base: MessageRendererBase.fromJson(j),
      messageRuns: (msg['runs'] as List<dynamic>? ?? [])
          .map((r) => MessageRun.fromJson(r as Map<String, dynamic>))
          .toList(),
      purchaseAmountText: amt['simpleText'] as String? ?? '',
      bodyBackgroundColor: j['bodyBackgroundColor'] as int? ?? 0,
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
    final amt = j['purchaseAmountText'] as Map<String, dynamic>? ?? {};
    final sticker = j['sticker'] as Map<String, dynamic>? ?? {};
    final stickerAccess =
        (sticker['accessibility'] as Map<String, dynamic>? ?? {});
    final stickerAccData =
        (stickerAccess['accessibilityData'] as Map<String, dynamic>? ?? {});
    return LiveChatPaidStickerRenderer(
      base: MessageRendererBase.fromJson(j),
      purchaseAmountText: amt['simpleText'] as String? ?? '',
      stickerThumbnails: (sticker['thumbnails'] as List<dynamic>? ?? [])
          .map((t) => Thumbnail.fromJson(t as Map<String, dynamic>))
          .toList(),
      stickerAccessibilityLabel: stickerAccData['label'] as String? ?? '',
      backgroundColor: j['backgroundColor'] as int? ?? 0,
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
    final headerSubtext = j['headerSubtext'] as Map<String, dynamic>? ?? {};
    return LiveChatMembershipItemRenderer(
      base: MessageRendererBase.fromJson(j),
      headerSubtextRuns: (headerSubtext['runs'] as List<dynamic>? ?? [])
          .map((r) => MessageRun.fromJson(r as Map<String, dynamic>))
          .toList(),
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
        textMessage: j['liveChatTextMessageRenderer'] != null
            ? LiveChatTextMessageRenderer.fromJson(
                j['liveChatTextMessageRenderer'] as Map<String, dynamic>)
            : null,
        paidMessage: j['liveChatPaidMessageRenderer'] != null
            ? LiveChatPaidMessageRenderer.fromJson(
                j['liveChatPaidMessageRenderer'] as Map<String, dynamic>)
            : null,
        membership: j['liveChatMembershipItemRenderer'] != null
            ? LiveChatMembershipItemRenderer.fromJson(
                j['liveChatMembershipItemRenderer'] as Map<String, dynamic>)
            : null,
        paidSticker: j['liveChatPaidStickerRenderer'] != null
            ? LiveChatPaidStickerRenderer.fromJson(
                j['liveChatPaidStickerRenderer'] as Map<String, dynamic>)
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
    final add = j['addChatItemAction'] as Map<String, dynamic>?;
    return Action(
      addChatItemAction: add != null
          ? ActionItem.fromJson(add['item'] as Map<String, dynamic>? ?? {})
          : null,
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
    final inv = j['invalidationContinuationData'] as Map<String, dynamic>?;
    final timed = j['timedContinuationData'] as Map<String, dynamic>?;
    return ContinuationData(
      invalidationContinuation: inv?['continuation'] as String?,
      timedContinuation: timed?['continuation'] as String?,
      timeoutMs: (timed?['timeoutMs'] as num?)?.toInt() ??
          (inv?['timeoutMs'] as num?)?.toInt() ??
          1000,
    );
  }
}

class GetLiveChatResponse {
  final List<Action> actions;
  final List<ContinuationData> continuations;

  const GetLiveChatResponse({
    required this.actions,
    required this.continuations,
  });

  factory GetLiveChatResponse.fromJson(Map<String, dynamic> j) {
    final cc = j['continuationContents'] as Map<String, dynamic>? ?? {};
    final lcc = cc['liveChatContinuation'] as Map<String, dynamic>? ?? {};
    return GetLiveChatResponse(
      actions: (lcc['actions'] as List<dynamic>? ?? [])
          .map((a) => Action.fromJson(a as Map<String, dynamic>))
          .toList(),
      continuations: (lcc['continuations'] as List<dynamic>? ?? [])
          .map((c) => ContinuationData.fromJson(c as Map<String, dynamic>))
          .toList(),
    );
  }
}
