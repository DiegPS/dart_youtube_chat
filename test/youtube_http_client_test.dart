import 'dart:async';
import 'dart:convert';

import 'package:dart_youtube_chat/dart_youtube_chat.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  const options = FetchOptions(
    apiKey: 'test-key',
    clientVersion: 'test-version',
    continuation: 'test-continuation',
    liveId: 'live-id',
  );

  test('requests a stable localized live page for handles', () async {
    final client = YoutubeHttpClient(client: MockClient((request) async {
      expect(request.url.path, '/@channel/live');
      expect(request.url.queryParameters['hl'], 'en');
      expect(request.url.queryParameters['gl'], 'US');
      return http.Response('''
        <link rel="canonical" href="https://www.youtube.com/watch?v=live-id">
        "INNERTUBE_API_KEY": "test-key"
        "clientVersion": "2.20240101.00.00"
        "continuation": "continuation"
      ''', 200);
    }));

    final result = await client.fetchLivePage(
      const YoutubeId(handle: '@channel'),
    );
    expect(result.liveId, 'live-id');
  });

  test('uses injected HTTP client and returns typed polling data', () async {
    final client = YoutubeHttpClient(client: MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.headers['content-type'], contains('application/json'));
      expect(jsonDecode(request.body)['continuation'], 'test-continuation');
      return http.Response(_emptyResponse('next-token', 900), 200);
    }));
    final batch = await client.fetchChatBatch(options);
    expect(batch.continuation, 'next-token');
    expect(batch.pollingInterval, const Duration(milliseconds: 900));
  });

  test('reports HTTP failure without leaking its body', () async {
    final client = YoutubeHttpClient(
      client: MockClient((_) async => http.Response('secret-body', 503)),
    );
    await expectLater(
      client.fetchChatBatch(options),
      throwsA(isA<YoutubeRequestException>()
          .having((e) => e.failure, 'failure', YoutubeRequestFailure.http)
          .having((e) => e.statusCode, 'status', 503)
          .having(
              (e) => e.toString(), 'safe message', isNot(contains('secret')))),
    );
  });

  test('reports malformed response', () async {
    final client = YoutubeHttpClient(
      client: MockClient((_) async => http.Response('{broken', 200)),
    );
    await expectLater(
      client.fetchChatBatch(options),
      throwsA(isA<YoutubeRequestException>().having((e) => e.failure, 'failure',
          YoutubeRequestFailure.malformedResponse)),
    );
  });

  test('reports timeout', () async {
    final client = YoutubeHttpClient(
      requestTimeout: const Duration(milliseconds: 5),
      client: MockClient((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('{}', 200);
      }),
    );
    await expectLater(
      client.fetchChatBatch(options),
      throwsA(isA<YoutubeRequestException>()
          .having((e) => e.failure, 'failure', YoutubeRequestFailure.timeout)),
    );
  });
}

String _emptyResponse(String continuation, int timeoutMs) => jsonEncode({
      'continuationContents': {
        'liveChatContinuation': {
          'actions': <Object>[],
          'continuations': [
            {
              'timedContinuationData': {
                'continuation': continuation,
                'timeoutMs': timeoutMs,
              },
            },
          ],
        },
      },
    });
