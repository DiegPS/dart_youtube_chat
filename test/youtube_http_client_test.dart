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

  test('builds a localized channel live URL', () async {
    final client = YoutubeHttpClient(client: MockClient((request) async {
      expect(request.url.path, '/channel/UC123/live');
      expect(request.url.queryParameters, containsPair('hl', 'en'));
      expect(request.url.queryParameters, containsPair('gl', 'US'));
      return http.Response(_livePage, 200);
    }));
    await client.fetchLivePage(const YoutubeId(channelId: 'UC123'));
  });

  test('builds a localized watch URL for a live id', () async {
    final client = YoutubeHttpClient(client: MockClient((request) async {
      expect(request.url.path, '/watch');
      expect(request.url.queryParameters, containsPair('v', 'video123'));
      expect(request.url.queryParameters, containsPair('hl', 'en'));
      return http.Response(_livePage, 200);
    }));
    await client.fetchLivePage(const YoutubeId(liveId: 'video123'));
  });

  test('omits API key query parameter when unavailable', () async {
    final client = YoutubeHttpClient(client: MockClient((request) async {
      expect(request.url.queryParameters.containsKey('key'), isFalse);
      return http.Response(_emptyResponse('next', 1000), 200);
    }));
    await client.fetchChatBatch(const FetchOptions(
      apiKey: '',
      clientVersion: 'version',
      continuation: 'continuation',
      liveId: 'live',
    ));
  });

  test('includes API key query parameter when supplied', () async {
    final client = YoutubeHttpClient(client: MockClient((request) async {
      expect(request.url.queryParameters['key'], 'test-key');
      return http.Response(_emptyResponse('next', 1000), 200);
    }));
    await client.fetchChatBatch(options);
  });

  test('reports transport exceptions as network failures', () async {
    final client = YoutubeHttpClient(
      client: MockClient((_) async => throw Exception('offline')),
    );
    await expectLater(
      client.fetchChatBatch(options),
      throwsA(isA<YoutubeRequestException>().having(
          (error) => error.failure, 'failure', YoutubeRequestFailure.network)),
    );
  });

  test('rejects a JSON array as a malformed chat response', () async {
    final client = YoutubeHttpClient(
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    await expectLater(
      client.fetchChatBatch(options),
      throwsA(isA<YoutubeRequestException>().having((error) => error.failure,
          'failure', YoutubeRequestFailure.malformedResponse)),
    );
  });

  test('wraps malformed live page content as a typed failure', () async {
    final client = YoutubeHttpClient(
      client: MockClient((_) async => http.Response('<html></html>', 200)),
    );
    await expectLater(
      client.fetchLivePage(const YoutubeId(handle: '@missing')),
      throwsA(isA<YoutubeRequestException>().having((error) => error.failure,
          'failure', YoutubeRequestFailure.malformedResponse)),
    );
  });

  test('closed client rejects subsequent requests', () async {
    final client = YoutubeHttpClient(
      client: MockClient((_) async => http.Response(_livePage, 200)),
    );
    client.close();
    client.close();
    await expectLater(
      client.fetchLivePage(const YoutubeId(handle: '@channel')),
      throwsA(isA<StateError>()),
    );
  });
}

const _livePage = '''
<link rel="canonical" href="https://www.youtube.com/watch?v=live-id">
"clientVersion":"2.0"
"continuation":"next"
''';

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
