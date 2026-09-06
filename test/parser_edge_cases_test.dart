import 'package:dart_youtube_chat/dart_youtube_chat.dart';
import 'package:dart_youtube_chat/src/types/yt_response.dart';
import 'package:test/test.dart';

void main() {
  group('live page parser', () {
    test('rejects a page without a canonical live id', () {
      expect(
          () => getOptionsFromLivePage('clientVersion":"1"'), throwsException);
    });

    test('rejects a page without a client version', () {
      expect(() => getOptionsFromLivePage(_page(clientVersion: false)),
          throwsException);
    });

    test('rejects a page without a continuation', () {
      expect(() => getOptionsFromLivePage(_page(continuation: false)),
          throwsException);
    });

    test('detects replay with either quote style', () {
      expect(() => getOptionsFromLivePage('${_page()}\n"isReplay":true'),
          throwsException);
      expect(() => getOptionsFromLivePage("${_page()}\n'isReplay': true"),
          throwsException);
    });
  });

  group('image URL normalization', () {
    test('trims surrounding whitespace', () {
      expect(normalizeYoutubeImageUrl('  https://example.test/a  '),
          'https://example.test/a');
    });

    test('upgrades trusted Google and YouTube hosts', () {
      expect(normalizeYoutubeImageUrl('http://a.googleusercontent.com/a'),
          'https://a.googleusercontent.com/a');
      expect(normalizeYoutubeImageUrl('http://i.ytimg.com/a'),
          'https://i.ytimg.com/a');
    });

    test('does not rewrite an unrelated HTTP host', () {
      expect(normalizeYoutubeImageUrl('http://example.test/a'),
          'http://example.test/a');
    });

    test('leaves an empty value empty', () {
      expect(normalizeYoutubeImageUrl(''), isEmpty);
    });
  });

  group('chat response parser', () {
    test('empty response uses safe defaults', () {
      final batch = parseChatBatch(GetLiveChatResponse.fromJson(const {}));
      expect(batch.messages, isEmpty);
      expect(batch.events, isEmpty);
      expect(batch.continuation, isEmpty);
      expect(batch.pollingInterval, const Duration(seconds: 1));
    });

    test('invalidation continuation and timeout are preserved', () {
      final batch = parseChatBatch(GetLiveChatResponse.fromJson({
        'continuationContents': {
          'liveChatContinuation': {
            'actions': <Object>[],
            'continuations': [
              {
                'invalidationContinuationData': {
                  'continuation': 'invalidate-next',
                  'timeoutMs': 2500.0,
                },
              },
            ],
          },
        },
      }));
      expect(batch.continuation, 'invalidate-next');
      expect(batch.pollingInterval, const Duration(milliseconds: 2500));
    });

    test('role icon badges become author flags', () {
      final item = _parseRenderer('liveChatTextMessageRenderer', {
        ..._base(),
        'authorBadges': [
          _iconBadge('OWNER'),
          _iconBadge('VERIFIED'),
          _iconBadge('MODERATOR'),
        ],
        'message': {
          'runs': [
            {'text': 'hello'}
          ]
        },
      });
      expect(item.isOwner, isTrue);
      expect(item.isVerified, isTrue);
      expect(item.isModerator, isTrue);
      expect(item.author.badges, isEmpty);
    });

    test('paid message retains amount, color, kind and renderer', () {
      final item = _parseRenderer('liveChatPaidMessageRenderer', {
        ..._base(),
        'message': {
          'runs': [
            {'text': 'great'}
          ]
        },
        'purchaseAmountText': {'simpleText': r'$5.00'},
        'bodyBackgroundColor': 0xFF123456,
      });
      expect(item.kind, ChatItemKind.paidMessage);
      expect(item.superChat!.amount, r'$5.00');
      expect(item.superChat!.color, '#123456');
      expect(item.rendererType, 'liveChatPaidMessageRenderer');
    });

    test('paid sticker retains accessibility label and image', () {
      final item = _parseRenderer('liveChatPaidStickerRenderer', {
        ..._base(),
        'purchaseAmountText': {'simpleText': 'MXN 20'},
        'backgroundColor': 0xFFABCDEF,
        'sticker': {
          'thumbnails': [
            {'url': '//i.ytimg.com/sticker', 'width': 48, 'height': 48},
          ],
          'accessibility': {
            'accessibilityData': {'label': 'Dancing sticker'},
          },
        },
      });
      expect(item.kind, ChatItemKind.paidSticker);
      expect(item.superChat!.sticker!.alt, 'Dancing sticker');
      expect(item.superChat!.sticker!.url, startsWith('https://'));
    });

    test('membership retains structured and plain text', () {
      final item = _parseRenderer('liveChatMembershipItemRenderer', {
        ..._base(),
        'headerSubtext': {
          'runs': [
            {'text': 'Member for '},
            {
              'emoji': {
                'emojiId': '12',
                'shortcuts': ['12 months'],
                'image': {'thumbnails': <Object>[]},
              },
            },
          ],
        },
      });
      expect(item.kind, ChatItemKind.membership);
      expect(item.isMembership, isTrue);
      expect(item.isMembershipEvent, isTrue);
      expect(item.membershipText, 'Member for 12 months');
      expect(item.message, hasLength(2));
    });

    test('timestamp is parsed from microseconds', () {
      final item = _parseRenderer('liveChatTextMessageRenderer', {
        ..._base(timestamp: '1700000000123456'),
        'message': {'runs': <Object>[]},
      });
      expect(item.timestamp.microsecondsSinceEpoch, 1700000000123456);
    });

    test('unknown renderer is exposed as a raw event', () {
      final raw = {
        'addBannerToLiveChatCommand': {
          'bannerRenderer': {
            'id': 'banner-1',
            'message': {'simpleText': 'Notice'},
          },
        },
      };
      final batch = parseChatBatch(
          GetLiveChatResponse.fromJson(_responseWithActions([raw])));
      expect(batch.messages, isEmpty);
      expect(batch.events.single.actionType, 'addBannerToLiveChatCommand');
      expect(batch.events.single.rendererType, 'bannerRenderer');
      expect(batch.events.single.id, 'banner-1');
      expect(batch.events.single.text, 'Notice');
      expect(batch.events.single.raw, raw);
    });

    test('non-string event id is safely omitted', () {
      final batch = parseChatBatch(GetLiveChatResponse.fromJson(
        _responseWithActions([
          {
            'customAction': {
              'customRenderer': {'id': 42},
            },
          },
        ]),
      ));
      expect(batch.events.single.id, isEmpty);
    });

    test('raw chat renderer payload remains available', () {
      final item = _parseRenderer('liveChatTextMessageRenderer', {
        ..._base(),
        'trackingParams': 'opaque',
        'message': {
          'runs': [
            {'text': 'hello'}
          ]
        },
      });
      final renderer =
          item.raw['liveChatTextMessageRenderer'] as Map<String, dynamic>;
      expect(renderer['trackingParams'], 'opaque');
    });
  });
}

String _page({bool clientVersion = true, bool continuation = true}) => '''
<link rel="canonical" href="https://www.youtube.com/watch?v=live-id">
${clientVersion ? '"clientVersion":"2.0"' : ''}
${continuation ? '"continuation":"next"' : ''}
''';

Map<String, dynamic> _base({String timestamp = '1700000000000000'}) => {
      'id': 'message-1',
      'timestampUsec': timestamp,
      'authorName': {'simpleText': 'Ada'},
      'authorExternalChannelId': 'channel-1',
      'authorPhoto': {'thumbnails': <Object>[]},
    };

Map<String, dynamic> _iconBadge(String iconType) => {
      'liveChatAuthorBadgeRenderer': {
        'tooltip': iconType,
        'icon': {'iconType': iconType},
      },
    };

ChatItem _parseRenderer(String renderer, Map<String, dynamic> value) {
  final response = GetLiveChatResponse.fromJson(_responseWithActions([
    {
      'addChatItemAction': {
        'item': {renderer: value},
      },
    },
  ]));
  return parseChatBatch(response).messages.single;
}

Map<String, dynamic> _responseWithActions(List<Object> actions) => {
      'continuationContents': {
        'liveChatContinuation': {
          'actions': actions,
          'continuations': <Object>[],
        },
      },
    };
