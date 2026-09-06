import 'dart:async';
import 'dart:convert';

import 'package:dart_youtube_chat/dart_youtube_chat.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('serializes polling, deduplicates messages, and stops cleanly',
      () async {
    var activeRequests = 0;
    var maximumActive = 0;
    var pollNumber = 0;
    final transport = YoutubeHttpClient(client: MockClient((request) async {
      if (request.method == 'GET') return http.Response(_livePage, 200);
      activeRequests++;
      if (activeRequests > maximumActive) maximumActive = activeRequests;
      await Future<void>.delayed(const Duration(milliseconds: 15));
      pollNumber++;
      activeRequests--;
      return http.Response(_chatResponse('continuation-$pollNumber'), 200);
    }));
    final chat = LiveChat(
      id: const YoutubeId(handle: '@channel'),
      interval: const Duration(milliseconds: 1),
      client: transport,
    );
    final messages = <ChatItem>[];
    final subscription = chat.messages.listen(messages.add);

    await chat.start();
    await chat.polls.take(3).drain<void>();
    chat.stop();
    await subscription.cancel();

    expect(maximumActive, 1);
    expect(messages, hasLength(1));
    expect(messages.single.id, 'same-message');
    expect(chat.isRunning, isFalse);
  });

  test('continues polling after a transient service error', () async {
    var posts = 0;
    final transport = YoutubeHttpClient(client: MockClient((request) async {
      if (request.method == 'GET') return http.Response(_livePage, 200);
      posts++;
      if (posts == 1) return http.Response('temporarily unavailable', 503);
      return http.Response(_chatResponse('recovered'), 200);
    }));
    final chat = LiveChat(
      id: const YoutubeId(handle: '@channel'),
      interval: const Duration(milliseconds: 1),
      client: transport,
    );
    final error = chat.errors.first;
    final message = chat.messages.first;

    await chat.start();
    expect(await error, isA<YoutubeRequestException>());
    expect((await message).id, 'same-message');
    expect(posts, greaterThanOrEqualTo(2));
    chat.stop();
  });

  test('can retry when loading the initial live page fails', () async {
    var pageRequests = 0;
    final transport = YoutubeHttpClient(client: MockClient((request) async {
      if (request.method == 'GET') {
        pageRequests++;
        return pageRequests == 1
            ? http.Response('temporarily unavailable', 503)
            : http.Response(_livePage, 200);
      }
      return http.Response(_chatResponse('recovered'), 200);
    }));
    final chat = LiveChat(
      id: const YoutubeId(handle: '@channel'),
      interval: const Duration(milliseconds: 1),
      client: transport,
    );

    await expectLater(chat.start(), throwsA(isA<YoutubeRequestException>()));
    await chat.start();
    expect((await chat.messages.first).id, 'same-message');
    expect(pageRequests, 2);
    chat.stop();
  });

  test('stopping while the initial page loads cannot revive the chat',
      () async {
    final pageResponse = Completer<http.Response>();
    final pageRequested = Completer<void>();
    final transport = YoutubeHttpClient(client: MockClient((request) async {
      if (request.method == 'GET') {
        pageRequested.complete();
        return pageResponse.future;
      }
      return http.Response(_chatResponse('unexpected'), 200);
    }));
    final chat = LiveChat(
      id: const YoutubeId(handle: '@channel'),
      client: transport,
    );

    final starting = chat.start();
    await pageRequested.future;
    chat.stop();
    pageResponse.complete(http.Response(_livePage, 200));

    await expectLater(starting, throwsA(isA<StateError>()));
    expect(chat.isRunning, isFalse);
    await expectLater(chat.start(), throwsA(isA<StateError>()));
  });

  test('rejects an empty YouTube identifier before making a request', () async {
    var requests = 0;
    final transport = YoutubeHttpClient(client: MockClient((_) async {
      requests++;
      return http.Response(_livePage, 200);
    }));
    final chat = LiveChat(id: const YoutubeId(), client: transport);

    await expectLater(chat.start(), throwsA(isA<ArgumentError>()));
    expect(requests, 0);
    chat.stop();
  });

  test('rejects concurrent start calls', () async {
    final response = Completer<http.Response>();
    final requested = Completer<void>();
    final transport = YoutubeHttpClient(client: MockClient((request) async {
      if (request.method == 'GET') {
        requested.complete();
        return response.future;
      }
      return http.Response(_chatResponse('next'), 200);
    }));
    final chat = LiveChat(
      id: const YoutubeId(handle: '@channel'),
      client: transport,
    );

    final firstStart = chat.start();
    await requested.future;
    await expectLater(chat.start(), throwsA(isA<StateError>()));
    response.complete(http.Response(_livePage, 200));
    await firstStart;
    chat.stop();
  });

  test('rejects another start while already running', () async {
    final transport = YoutubeHttpClient(client: MockClient((request) async {
      if (request.method == 'GET') return http.Response(_livePage, 200);
      return http.Response(_chatResponse('next'), 200);
    }));
    final chat = LiveChat(
      id: const YoutubeId(handle: '@channel'),
      client: transport,
    );

    await chat.start();
    await expectLater(chat.start(), throwsA(isA<StateError>()));
    chat.stop();
  });

  test('stop is idempotent and closes public streams', () async {
    final transport = YoutubeHttpClient(client: MockClient((request) async {
      if (request.method == 'GET') return http.Response(_livePage, 200);
      return http.Response(_chatResponse('next'), 200);
    }));
    final chat = LiveChat(
      id: const YoutubeId(handle: '@channel'),
      client: transport,
    );
    final messagesDone = expectLater(chat.messages, emitsDone);
    final eventsDone = expectLater(chat.events, emitsDone);

    await chat.start();
    chat.stop();
    chat.stop();

    await messagesDone;
    await eventsDone;
    expect(chat.isRunning, isFalse);
  });

  test('does not close an externally supplied HTTP client', () async {
    final transport = YoutubeHttpClient(client: MockClient((request) async {
      if (request.method == 'GET') return http.Response(_livePage, 200);
      return http.Response(_chatResponse('next'), 200);
    }));
    final chat = LiveChat(
      id: const YoutubeId(handle: '@channel'),
      client: transport,
    );

    await chat.start();
    chat.stop();

    final options =
        await transport.fetchLivePage(const YoutubeId(handle: '@channel'));
    expect(options.liveId, 'live-id');
    transport.close();
  });
}

const _livePage = '''
<link rel="canonical" href="https://www.youtube.com/watch?v=live-id">
"INNERTUBE_API_KEY": "test-key"
"clientVersion": "2.20240101.00.00"
"continuation": "first-continuation"
''';

String _chatResponse(String continuation) => jsonEncode({
      'continuationContents': {
        'liveChatContinuation': {
          'continuations': [
            {
              'timedContinuationData': {
                'continuation': continuation,
                'timeoutMs': 1,
              },
            },
          ],
          'actions': [
            {
              'addChatItemAction': {
                'item': {
                  'liveChatTextMessageRenderer': {
                    'id': 'same-message',
                    'timestampUsec': '1700000000000000',
                    'authorName': {'simpleText': 'Anonymous'},
                    'authorExternalChannelId': 'channel-1',
                    'authorPhoto': {'thumbnails': <Object>[]},
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
