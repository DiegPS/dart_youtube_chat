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

/// Fetches one batch of chat messages.
/// Returns the parsed items and the next continuation token.
Future<(List<ChatItem>, String)> fetchChat(FetchOptions options) async {
  // YouTube has accepted requests without the key since ~2023, but we still
  // send it when available for maximum compatibility.
  final url = options.apiKey.isNotEmpty
      ? Uri.parse('$_baseUrl?key=${options.apiKey}')
      : Uri.parse(_baseUrl);

  final body = jsonEncode({
    'context': {
      'client': {
        'clientVersion': options.clientVersion,
        'clientName': _clientName,
      },
    },
    'continuation': options.continuation,
  });

  final response = await http.post(
    url,
    body: body,
    headers: {
      'Content-Type': 'application/json',
      // Mirrors the original JS/Go implementation.
      'Accept-Encoding': 'utf-8',
    },
  );

  if (response.statusCode != 200) {
    throw Exception('fetchChat: HTTP ${response.statusCode}');
  }

  final json = jsonDecode(response.body) as Map<String, dynamic>;
  final parsed = GetLiveChatResponse.fromJson(json);
  return parseChatData(parsed);
}

/// Fetches the live page HTML and extracts [FetchOptions].
/// Throws if the channel/live is not found or the stream has ended.
Future<FetchOptions> fetchLivePage(YoutubeId id) async {
  final url = _generateLiveUrl(id);
  if (url == null) throw Exception('fetchLivePage: YoutubeId is empty');

  final response = await http.get(
    Uri.parse(url),
    headers: {'User-Agent': _userAgent},
  );

  if (response.statusCode != 200) {
    throw Exception('fetchLivePage: HTTP ${response.statusCode} for $url');
  }

  return getOptionsFromLivePage(response.body);
}

String? _generateLiveUrl(YoutubeId id) {
  if (id.channelId.isNotEmpty) {
    return '$_youtubeBase/channel/${id.channelId}/live';
  }
  if (id.liveId.isNotEmpty) {
    return '$_youtubeBase/watch?v=${id.liveId}';
  }
  if (id.handle.isNotEmpty) {
    final handle = id.handle.startsWith('@') ? id.handle : '@${id.handle}';
    return '$_youtubeBase/$handle/live';
  }
  return null;
}
