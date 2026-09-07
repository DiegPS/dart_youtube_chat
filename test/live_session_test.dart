import 'dart:convert';

import 'package:dart_youtube_chat/dart_youtube_chat.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('resolves the live page once and drives chat and metadata together',
      () async {
    var pageRequests = 0;
    final client = YoutubeHttpClient(client: MockClient((request) async {
      if (request.method == 'GET') {
        pageRequests++;
        return http.Response(_livePage, 200);
      }
      if (request.url.path.endsWith('/updated_metadata')) {
        return http.Response(
            jsonEncode({
              'continuation': {
                'timedContinuationData': {
                  'continuation': 'metadata-next',
                  'timeoutMs': 60000,
                },
              },
              'actions': [
                {
                  'updateViewershipAction': {
                    'viewCount': {
                      'videoViewCountRenderer': {
                        'originalViewCount': '88',
                        'isLive': true,
                      },
                    },
                  },
                },
              ],
            }),
            200);
      }
      return http.Response(_chatResponse, 200);
    }));
    final session = YoutubeLiveSession(
      id: const YoutubeId(handle: '@channel'),
      chatInterval: const Duration(minutes: 1),
      metadataInterval: const Duration(minutes: 1),
      client: client,
    );

    final message = session.messages.first;
    final metadata = session.metadataStates.first;
    await session.start();

    expect((await message).id, 'message-1');
    expect((await metadata).viewership?.originalViewCountValue, 88);
    expect(pageRequests, 1);
    expect(session.liveId, 'live-id');
    session.stop();
  });

  test('stop is idempotent and closes every public session stream', () async {
    final client = YoutubeHttpClient(client: MockClient((request) async {
      if (request.method == 'GET') return http.Response(_livePage, 200);
      if (request.url.path.endsWith('/updated_metadata')) {
        return http.Response(
            jsonEncode({
              'continuation': {
                'timedContinuationData': {
                  'continuation': 'next',
                  'timeoutMs': 60000,
                },
              },
            }),
            200);
      }
      return http.Response(_chatResponse, 200);
    }));
    final session = YoutubeLiveSession(
      id: const YoutubeId(handle: '@channel'),
      client: client,
    );
    final messagesDone = expectLater(session.messages, emitsDone);
    final metadataDone = expectLater(session.metadataStates, emitsDone);

    await session.start();
    session.stop();
    session.stop();

    await messagesDone;
    await metadataDone;
    expect(session.isRunning, isFalse);
  });
}

const _livePage = '''
<link rel="canonical" href="https://www.youtube.com/watch?v=live-id">
"INNERTUBE_API_KEY":"test-key"
"clientVersion":"2.0"
"continuation":"chat-first"
''';

final _chatResponse = jsonEncode({
  'continuationContents': {
    'liveChatContinuation': {
      'continuations': [
        {
          'timedContinuationData': {
            'continuation': 'chat-next',
            'timeoutMs': 60000,
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
                'message': {
                  'runs': [
                    {'text': 'Hello'},
                  ],
                },
              },
            },
          },
        },
      ],
    },
  },
});
