import 'dart:async';
import 'dart:convert';

import 'package:dart_youtube_chat/src/parser.dart';
import 'package:dart_youtube_chat/src/types/data.dart';
import 'package:dart_youtube_chat/src/types/updated_metadata.dart';
import 'package:dart_youtube_chat/src/types/yt_response.dart';
import 'package:http/http.dart' as http;

const _baseUrl = 'https://www.youtube.com/youtubei/v1/live_chat/get_live_chat';
const _updatedMetadataUrl =
    'https://www.youtube.com/youtubei/v1/updated_metadata';
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
    this.context = const YoutubeClientContext(),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration requestTimeout;
  final YoutubeClientContext context;
  bool _closed = false;

  Future<FetchOptions> fetchLivePage(YoutubeId id) async {
    final url = _generateLiveUrl(id, context);
    if (url == null) {
      throw ArgumentError('YoutubeId must have channelId, liveId, or handle');
    }
    final response = await _send(
      'fetchLivePage',
      () => _client.get(url, headers: {
        'User-Agent':
            context.userAgent.isEmpty ? _userAgent : context.userAgent,
      }),
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
              'hl': context.languageCode,
              'gl': context.regionCode,
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

  Future<UpdatedMetadataBatch> fetchUpdatedMetadata(
    FetchOptions options, {
    String continuation = '',
  }) async {
    if (options.liveId.isEmpty) {
      throw ArgumentError.value(options.liveId, 'liveId', 'must not be empty');
    }
    final url = options.apiKey.isNotEmpty
        ? Uri.parse('$_updatedMetadataUrl?key=${options.apiKey}')
        : Uri.parse(_updatedMetadataUrl);
    final body = <String, dynamic>{
      'context': {
        'client': {
          'clientVersion': options.clientVersion,
          'clientName': _clientName,
          'hl': context.languageCode,
          'gl': context.regionCode,
        },
      },
      'videoId': options.liveId,
      if (continuation.isNotEmpty) 'continuation': continuation,
    };
    final response = await _send(
      'fetchUpdatedMetadata',
      () => _client.post(
        url,
        body: jsonEncode(body),
        headers: const {'Content-Type': 'application/json; charset=UTF-8'},
      ),
    );
    _requireSuccess(response, 'fetchUpdatedMetadata');
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }
      return UpdatedMetadataBatch.fromJson(decoded);
    } catch (error) {
      throw YoutubeRequestException(
        YoutubeRequestFailure.malformedResponse,
        'fetchUpdatedMetadata',
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

Uri? _generateLiveUrl(YoutubeId id, YoutubeClientContext context) {
  final query = {
    'hl': context.languageCode,
    'gl': context.regionCode,
  };
  if (id.channelId.isNotEmpty) {
    return Uri.parse('$_youtubeBase/channel/${id.channelId}/live')
        .replace(queryParameters: query);
  }
  if (id.liveId.isNotEmpty) {
    return Uri.parse('$_youtubeBase/watch').replace(queryParameters: {
      'v': id.liveId,
      ...query,
    });
  }
  if (id.handle.isNotEmpty) {
    final handle = id.handle.startsWith('@') ? id.handle : '@${id.handle}';
    return Uri.parse('$_youtubeBase/$handle/live')
        .replace(queryParameters: query);
  }
  return null;
}
