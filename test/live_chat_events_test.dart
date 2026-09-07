import 'package:dart_youtube_chat/dart_youtube_chat.dart';
import 'package:dart_youtube_chat/src/types/yt_response.dart';
import 'package:test/test.dart';

void main() {
  group('typed live-chat events', () {
    test('models one-message and one-author deletions', () {
      final batch = _batch([
        {
          'markChatItemAsDeletedAction': {
            'targetItemId': 'message-1',
            'deletedStateMessage': {'simpleText': 'Message deleted'},
          },
        },
        {
          'markChatItemsByAuthorAsDeletedAction': {
            'externalChannelId': 'channel-1',
          },
        },
      ]);

      expect(batch.events[0].kind, LiveChatEventKind.messageDeleted);
      expect(batch.events[0].targetItemId, 'message-1');
      expect(batch.events[0].text, 'Message deleted');
      expect(batch.events[1].kind, LiveChatEventKind.authorMessagesDeleted);
      expect(batch.events[1].authorChannelId, 'channel-1');
    });

    test('models banner and ticker lifecycle commands', () {
      final batch = _batch([
        {
          'addBannerToLiveChatCommand': {
            'bannerRenderer': {
              'liveChatBannerRenderer': {
                'actionId': 'banner-action',
                'contents': {
                  'liveChatTextMessageRenderer': {
                    'id': 'banner-message',
                    'message': {'simpleText': 'Pinned notice'},
                  },
                },
              },
            },
          },
        },
        {
          'removeBannerForLiveChatCommand': {'targetActionId': 'banner-action'},
        },
        {
          'addLiveChatTickerItemAction': {
            'durationSec': '15',
            'item': {
              'liveChatTickerPaidMessageItemRenderer': {'id': 'ticker-1'},
            },
          },
        },
        {
          'removeLiveChatTickerItemAction': {'targetItemId': 'ticker-1'},
        },
      ]);

      expect(batch.events.map((event) => event.kind), [
        LiveChatEventKind.bannerAdded,
        LiveChatEventKind.bannerRemoved,
        LiveChatEventKind.tickerAdded,
        LiveChatEventKind.tickerRemoved,
      ]);
      expect(batch.events[0].id, 'banner-message');
      expect(batch.events[0].targetActionId, 'banner-action');
      expect(batch.events[2].duration, const Duration(seconds: 15));
      expect(batch.events[3].targetItemId, 'ticker-1');
    });

    test('models gifted membership purchase and redemption announcements', () {
      final batch = _batch([
        {
          'addChatItemAction': {
            'item': {
              'liveChatSponsorshipsGiftPurchaseAnnouncementRenderer': {
                'id': 'gift-1',
                'timestampUsec': '1700000000000000',
                'authorExternalChannelId': 'gifter-channel',
                'header': {
                  'liveChatSponsorshipsHeaderRenderer': {
                    'authorName': {'simpleText': 'Gifter'},
                    'primaryText': {
                      'runs': [
                        {'text': 'Gifted 5 memberships'},
                      ],
                    },
                  },
                },
                'giftMembershipsCount': 5,
              },
            },
          },
        },
        {
          'addChatItemAction': {
            'item': {
              'liveChatSponsorshipsGiftRedemptionAnnouncementRenderer': {
                'id': 'redemption-1',
                'timestampUsec': '1700000001000000',
                'authorExternalChannelId': 'recipient-channel',
                'message': {'simpleText': 'Received a gift membership'},
              },
            },
          },
        },
      ]);

      expect(batch.messages, isEmpty);
      expect(batch.events[0].kind, LiveChatEventKind.membershipGiftPurchased);
      expect(batch.events[0].giftMembershipCount, 5);
      expect(batch.events[0].authorChannelId, 'gifter-channel');
      expect(batch.events[0].text, 'Gifted 5 memberships');
      expect(batch.events[1].kind, LiveChatEventKind.membershipGiftReceived);
      expect(batch.events[1].authorChannelId, 'recipient-channel');
    });

    test('exposes buttons and menu actions without executing commands', () {
      final batch = _batch([
        {
          'addChatItemAction': {
            'item': {
              'liveChatViewerEngagementMessageRenderer': {
                'id': 'notice-1',
                'message': {'simpleText': 'Welcome'},
                'actionButton': {
                  'buttonRenderer': {
                    'text': {'simpleText': 'Learn more'},
                    'icon': {'iconType': 'OPEN_IN_NEW'},
                    'accessibility': {'label': 'Learn more about chat'},
                    'navigationEndpoint': {
                      'urlEndpoint': {'url': 'https://example.test/help'},
                    },
                  },
                },
                'contextMenuEndpoint': {
                  'liveChatItemContextMenuEndpoint': {'params': 'opaque'},
                },
              },
            },
          },
        },
      ]);

      final event = batch.events.single;
      expect(event.kind, LiveChatEventKind.viewerNotice);
      expect(event.buttons.single.text, 'Learn more');
      expect(event.buttons.single.iconType, 'OPEN_IN_NEW');
      expect(event.buttons.single.accessibilityLabel, 'Learn more about chat');
      expect(event.buttons.single.endpointName, 'navigationEndpoint');
      expect(event.menuActions.single.endpointName, 'contextMenuEndpoint');
      expect(event.menuActions.single.raw, contains('contextMenuEndpoint'));
    });
  });

  group('lossless and resilient parsing', () {
    test('retains the entire response envelope on the parsed batch', () {
      final json = {
        'responseContext': {'visitorData': 'opaque'},
        'continuationContents': {
          'liveChatContinuation': {
            'actions': <Object>[],
            'continuations': <Object>[],
            'emojis': [
              {'emojiId': 'future'}
            ],
          },
        },
        'futureTopLevelField': {'kept': true},
      };

      final batch = parseChatBatch(GetLiveChatResponse.fromJson(json));

      expect(batch.raw, same(json));
      expect(batch.toJson(), same(json));
    });

    test('skips malformed list members and preserves unknown actions', () {
      final json = {
        'continuationContents': {
          'liveChatContinuation': {
            'actions': [
              null,
              'bad',
              {
                'addChatItemAction': {'item': 'not-a-map'},
              },
              {
                'futureAction': {
                  'futureRenderer': {
                    'id': 'future-1',
                    'message': {'runs': 'not-a-list'},
                  },
                },
              },
              {
                'addChatItemAction': {
                  'item': {
                    'liveChatTextMessageRenderer': {
                      'id': 'tolerant-message',
                      'timestampUsec': 123,
                      'authorName': 'not-a-map',
                      'authorPhoto': {
                        'thumbnails': [null, 'bad', {'url': 42}],
                      },
                      'authorBadges': [null, 'bad'],
                      'message': {
                        'runs': [
                          null,
                          'bad',
                          {
                            'emoji': {
                              'isCustomEmoji': 'not-a-bool',
                              'shortcuts': [42],
                              'image': {'thumbnails': 'not-a-list'},
                            },
                          },
                        ],
                      },
                    },
                  },
                },
              },
            ],
            'continuations': [42, null],
          },
        },
      };

      final batch = parseChatBatch(GetLiveChatResponse.fromJson(json));

      expect(batch.messages.single.id, 'tolerant-message');
      expect(batch.messages.single.message.single.emoji?.isCustomEmoji, isFalse);
      expect(batch.events, hasLength(2));
      expect(batch.events.last.kind, LiveChatEventKind.unknown);
      expect(batch.events.last.rendererType, 'futureRenderer');
      expect(batch.events.last.raw, contains('futureAction'));
    });
  });
}

LiveChatBatch _batch(List<Object?> actions) => parseChatBatch(
      GetLiveChatResponse.fromJson({
        'continuationContents': {
          'liveChatContinuation': {
            'actions': actions,
            'continuations': <Object>[],
          },
        },
      }),
    );
