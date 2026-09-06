import 'package:dart_youtube_chat/dart_youtube_chat.dart';
import 'package:dart_youtube_chat/src/types/yt_response.dart';
import 'package:test/test.dart';

void main() {
  test('normalizes image URLs', () {
    expect(normalizeYoutubeImageUrl('//lh3.googleusercontent.com/a'),
        'https://lh3.googleusercontent.com/a');
    expect(normalizeYoutubeImageUrl('http://yt4.ggpht.com/a'),
        'https://yt4.ggpht.com/a');
  });

  test('preserves image variants, badges, custom emoji, and polling data', () {
    final response = GetLiveChatResponse.fromJson(_response());
    final batch = parseChatBatch(response);
    final item = batch.messages.single;
    final image = item.author.thumbnail!;

    expect(image.variants, hasLength(2));
    expect(image.bestFor(16, pixelRatio: 2).width, 32);
    expect(image.bestFor(40, pixelRatio: 2).width, 64);
    expect(item.author.badges, hasLength(2));
    expect(item.message.last.emoji!.isCustomEmoji, isTrue);
    expect(batch.pollingInterval, const Duration(milliseconds: 1750));
    expect(batch.events.single.rendererType,
        'liveChatViewerEngagementMessageRenderer');
    expect(batch.events.single.text, 'Public service notice');
  });
}

Map<String, dynamic> _response() => {
      'continuationContents': {
        'liveChatContinuation': {
          'continuations': [
            {
              'timedContinuationData': {
                'continuation': 'next',
                'timeoutMs': 1750,
              },
            },
          ],
          'actions': [
            {
              'addChatItemAction': {
                'item': {
                  'liveChatTextMessageRenderer': {
                    'id': 'message-1',
                    'timestampUsec': '1700000000000000',
                    'authorName': {'simpleText': 'Anonymous'},
                    'authorExternalChannelId': 'channel-1',
                    'authorPhoto': {
                      'thumbnails': [
                        {
                          'url': '//example.test/a32',
                          'width': 32,
                          'height': 32
                        },
                        {
                          'url': 'https://example.test/a64',
                          'width': 64,
                          'height': 64
                        },
                      ],
                    },
                    'authorBadges': [
                      _badge('Member', '//example.test/member'),
                      _badge('Milestone', 'https://example.test/year'),
                    ],
                    'message': {
                      'runs': [
                        {'text': 'Hello '},
                        {
                          'emoji': {
                            'emojiId': 'custom-1',
                            'shortcuts': [':wave:'],
                            'isCustomEmoji': true,
                            'image': {
                              'thumbnails': [
                                {'url': '//example.test/emoji', 'width': 24},
                              ],
                            },
                          },
                        },
                      ],
                    },
                  },
                },
              },
            },
            {
              'addChatItemAction': {
                'item': {
                  'liveChatViewerEngagementMessageRenderer': {
                    'id': 'notice-1',
                    'message': {
                      'runs': [
                        {'text': 'Public service notice'},
                      ],
                    },
                  },
                },
              },
            },
          ],
        },
      },
    };

Map<String, dynamic> _badge(String label, String url) => {
      'liveChatAuthorBadgeRenderer': {
        'tooltip': label,
        'customThumbnail': {
          'thumbnails': [
            {'url': url, 'width': 16, 'height': 16},
          ],
        },
      },
    };
