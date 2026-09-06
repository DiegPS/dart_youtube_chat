import 'dart:async';
import 'dart:convert';

import 'package:dart_youtube_chat/src/parser.dart';
import 'package:dart_youtube_chat/src/types/data.dart';
import 'package:dart_youtube_chat/src/types/yt_response.dart';
import 'package:http/http.dart' as http;

const _baseUrl = 'https://www.youtube.com/youtubei/v1/live_chat/get_live_chat';
const _youtubeBase = 'https://www.youtube.com';
const _clientName = 'WEB';
const _userAgent =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36';

enum YoutubeRequestFailure { network, timeout, http, malformedResponse }

class YoutubeRequestException implements Exception {
  final YoutubeRequestFailure failure;
  final String operation;
  final int? statusCode;
  final Object? cause;

  const YoutubeRequestException(
    this.failure,
    this.operation, {
    this.statusCode,
    this.cause,
  });

  @override
  String toString() {
    final status = statusCode == null ? '' : ' (HTTP $statusCode)';
    return 'YoutubeRequestException: $operation failed$status [$failure]';
  }
}

class YoutubeHttpClient {
  YoutubeHttpClient({
    http.Client? client,
    this.requestTimeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration requestTimeout;
  bool _closed = false;

  Future<FetchOptions> fetchLivePage(YoutubeId id) async {
    final url = _generateLiveUrl(id);
    if (url == null) {
      throw ArgumentError('YoutubeId must have channelId, liveId, or handle');
    }
    final response = await _send(
      'fetchLivePage',
      () => _client.get(Uri.parse(url), headers: {'User-Agent': _userAgent}),
    );
    _requireSuccess(response, 'fetchLivePage');
    try {
      return getOptionsFromLivePage(response.body);
    } catch (error) {
      throw YoutubeRequestException(
        YoutubeRequestFailure.malformedResponse,
        'fetchLivePage',
        cause: error,
      );
    }
  }

  Future<LiveChatBatch> fetchChatBatch(FetchOptions options) async {
    final url = options.apiKey.isNotEmpty
        ? Uri.parse('$_baseUrl?key=${options.apiKey}')
        : Uri.parse(_baseUrl);
    final response = await _send(
      'fetchChat',
      () => _client.post(
        url,
        body: jsonEncode({
          'context': {
            'client': {
              'clientVersion': options.clientVersion,
              'clientName': _clientName,
            },
          },
          'continuation': options.continuation,
        }),
        headers: const {'Content-Type': 'application/json; charset=UTF-8'},
      ),
    );
    _requireSuccess(response, 'fetchChat');
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }
      return parseChatBatch(GetLiveChatResponse.fromJson(decoded));
    } catch (error) {
      throw YoutubeRequestException(
        YoutubeRequestFailure.malformedResponse,
        'fetchChat',
        cause: error,
      );
    }
  }

  Future<http.Response> _send(
    String operation,
    Future<http.Response> Function() request,
  ) async {
    if (_closed) throw StateError('YoutubeHttpClient is closed');
    try {
      return await request().timeout(requestTimeout);
    } on TimeoutException catch (error) {
      throw YoutubeRequestException(
        YoutubeRequestFailure.timeout,
        operation,
        cause: error,
      );
    } catch (error) {
      throw YoutubeRequestException(
        YoutubeRequestFailure.network,
        operation,
        cause: error,
      );
    }
  }

  void _requireSuccess(http.Response response, String operation) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw YoutubeRequestException(
        YoutubeRequestFailure.http,
        operation,
        statusCode: response.statusCode,
      );
    }
  }

  void close() {
    if (_closed) return;
    _closed = true;
    if (_ownsClient) _client.close();
  }
}

Future<(List<ChatItem>, String)> fetchChat(FetchOptions options) async {
  final client = YoutubeHttpClient();
  try {
    final batch = await client.fetchChatBatch(options);
    return (batch.messages, batch.continuation);
  } finally {
    client.close();
  }
}

Future<FetchOptions> fetchLivePage(YoutubeId id) async {
  final client = YoutubeHttpClient();
  try {
    return await client.fetchLivePage(id);
  } finally {
    client.close();
  }
}

String? _generateLiveUrl(YoutubeId id) {
  if (id.channelId.isNotEmpty) {
    return '$_youtubeBase/channel/${id.channelId}/live?hl=en&gl=US';
  }
  if (id.liveId.isNotEmpty) {
    return '$_youtubeBase/watch?v=${id.liveId}&hl=en&gl=US';
  }
  if (id.handle.isNotEmpty) {
    final handle = id.handle.startsWith('@') ? id.handle : '@${id.handle}';
    return '$_youtubeBase/$handle/live?hl=en&gl=US';
  }
  return null;
}
