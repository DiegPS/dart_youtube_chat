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
    final chatErrorsDone = expectLater(session.chatErrors, emitsDone);
    final metadataErrorsDone = expectLater(session.metadataErrors, emitsDone);

    await session.start();
    session.stop();
    session.stop();

    await messagesDone;
    await metadataDone;
    await chatErrorsDone;
    await metadataErrorsDone;
    expect(session.isRunning, isFalse);
  });

  test('keeps chat and metadata errors on independent streams', () async {
    final client = YoutubeHttpClient(client: MockClient((request) async {
      if (request.method == 'GET') return http.Response(_livePage, 200);
      if (request.url.path.endsWith('/updated_metadata')) {
        return http.Response('metadata unavailable', 503);
      }
      return http.Response(_chatResponse, 200);
    }));
    final session = YoutubeLiveSession(
      id: const YoutubeId(handle: '@channel'),
      chatInterval: const Duration(minutes: 1),
      metadataInterval: const Duration(minutes: 1),
      client: client,
    );
    addTearDown(session.stop);
    final message = session.messages.first;
    final metadataError = session.metadataErrors.first;
    final combinedError = session.errors.first;
    var chatErrorCount = 0;
    session.chatErrors.listen((_) => chatErrorCount++);

    await session.start();

    expect((await message).id, 'message-1');
    expect(await metadataError, isA<Exception>());
    expect(await combinedError, isA<Exception>());
    expect(chatErrorCount, 0);
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
