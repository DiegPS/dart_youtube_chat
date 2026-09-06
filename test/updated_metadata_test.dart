import 'dart:async';
import 'dart:convert';

import 'package:dart_youtube_chat/dart_youtube_chat.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

import 'fixtures/updated_metadata_fixture.dart';

void main() {
  const options = FetchOptions(
    apiKey: 'test-key',
    clientVersion: 'test-version',
    continuation: 'chat-continuation',
    liveId: 'live-id',
  );

  test('fetchUpdatedMetadata sends video id and optional continuation',
      () async {
    var requestNumber = 0;
    final client = YoutubeHttpClient(client: MockClient((request) async {
      requestNumber++;
      expect(request.url.path, '/youtubei/v1/updated_metadata');
      expect(request.url.queryParameters['key'], 'test-key');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['videoId'], 'live-id');
      expect((body['context'] as Map)['client'], {
        'clientVersion': 'test-version',
        'clientName': 'WEB',
      });
      expect(body['continuation'], requestNumber == 1 ? isNull : 'next-token');
      return http.Response(
        jsonEncode(updatedMetadataFixture(continuation: 'next-token')),
        200,
      );
    }));

    final first = await client.fetchUpdatedMetadata(options);
    final second = await client.fetchUpdatedMetadata(
      options,
      continuation: first.continuation.token,
    );

    expect(second.continuation.token, 'next-token');
    expect(requestNumber, 2);
  });

  test('fetchUpdatedMetadata reports HTTP and malformed response failures',
      () async {
    final httpFailure = YoutubeHttpClient(
      client: MockClient((_) async => http.Response('unavailable', 503)),
    );
    await expectLater(
      httpFailure.fetchUpdatedMetadata(options),
      throwsA(isA<YoutubeRequestException>()
          .having(
              (error) => error.failure, 'failure', YoutubeRequestFailure.http)
          .having(
              (error) => error.operation, 'operation', 'fetchUpdatedMetadata')),
    );

    final malformed = YoutubeHttpClient(
      client: MockClient((_) async => http.Response('[]', 200)),
    );
    await expectLater(
      malformed.fetchUpdatedMetadata(options),
      throwsA(isA<YoutubeRequestException>().having(
        (error) => error.failure,
        'failure',
        YoutubeRequestFailure.malformedResponse,
      )),
    );
  });

  test('fetchUpdatedMetadata rejects an empty video id without transport',
      () async {
    var requests = 0;
    final client = YoutubeHttpClient(client: MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    }));

    await expectLater(
      client.fetchUpdatedMetadata(const FetchOptions(
        apiKey: '',
        clientVersion: 'version',
        continuation: '',
        liveId: '',
      )),
      throwsA(isA<ArgumentError>()),
    );
    expect(requests, 0);
  });

  test('UpdatedMetadata follows tokens and server polling intervals serially',
      () async {
    var activeRequests = 0;
    var maximumActiveRequests = 0;
    var requestNumber = 0;
    final continuations = <Object?>[];
    final client = YoutubeHttpClient(client: MockClient((request) async {
      activeRequests++;
      maximumActiveRequests = activeRequests > maximumActiveRequests
          ? activeRequests
          : maximumActiveRequests;
      requestNumber++;
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      continuations.add(body['continuation']);
      await Future<void>.delayed(const Duration(milliseconds: 10));
      activeRequests--;
      return http.Response(
        jsonEncode(updatedMetadataFixture(
          continuation: 'token-$requestNumber',
          timeoutMs: 1,
        )),
        200,
      );
    }));
    final metadata = UpdatedMetadata(options: options, client: client);

    final batches = metadata.batches.take(3).toList();
    metadata.start();
    final received = await batches.timeout(const Duration(seconds: 2));
    metadata.stop();

    expect(received, hasLength(3));
    expect(continuations, [null, 'token-1', 'token-2']);
    expect(maximumActiveRequests, 1);
    expect(metadata.isRunning, isFalse);
  });

  test('UpdatedMetadata reports transient errors and then recovers', () async {
    var requests = 0;
    final client = YoutubeHttpClient(client: MockClient((_) async {
      requests++;
      if (requests == 1) return http.Response('temporary', 503);
      return http.Response(
        jsonEncode(updatedMetadataFixture(timeoutMs: 1)),
        200,
      );
    }));
    final metadata = UpdatedMetadata(
      options: options,
      interval: const Duration(milliseconds: 1),
      client: client,
    );

    final error = metadata.errors.first;
    final recovered = metadata.batches.first;
    metadata.start();

    expect(await error, isA<YoutubeRequestException>());
    expect((await recovered).viewership?.isLive, isTrue);
    metadata.stop();
  });

  test('UpdatedMetadata closes streams and cannot restart after stop',
      () async {
    final client = YoutubeHttpClient(client: MockClient((_) async {
      return http.Response(
        jsonEncode(updatedMetadataFixture(timeoutMs: 1)),
        200,
      );
    }));
    final metadata = UpdatedMetadata(options: options, client: client);

    metadata.start();
    await metadata.batches.first;
    final done = expectLater(metadata.batches, emitsDone);
    metadata.stop();
    metadata.stop();

    await done;
    expect(() => metadata.start(), throwsStateError);
  });
}
