import 'dart:async';
import 'dart:convert';

import 'package:dart_youtube_chat/src/types/data.dart';
import 'package:http/http.dart' as http;

/// Loads anonymous channel-specific BTTV, FFZ, and 7TV emotes for YouTube.
final class YoutubeExternalEmoteLoader {
  YoutubeExternalEmoteLoader({
    http.Client? httpClient,
    this.requestTimeout = const Duration(seconds: 5),
  })  : _client = httpClient ?? http.Client(),
        _ownsClient = httpClient == null;

  final http.Client _client;
  final bool _ownsClient;
  final Duration requestTimeout;

  Future<Map<String, EmojiItem>> load(
    String channelId, {
    void Function(Object error, StackTrace stackTrace)? onError,
  }) async {
    if (channelId.trim().isEmpty) return const {};
    final results = await Future.wait([
      _safe(() => _loadBttv(channelId), onError),
      _safe(() => _loadFfz(channelId), onError),
      _safe(() => _loadSevenTv(channelId), onError),
    ]);
    return Map.unmodifiable({for (final result in results) ...result});
  }

  Future<Map<String, EmojiItem>> _safe(
    Future<Map<String, EmojiItem>> Function() operation,
    void Function(Object, StackTrace)? onError,
  ) async {
    try {
      return await operation();
    } on YoutubeExternalEmoteNotFound {
      return const {};
    } catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      return const {};
    }
  }

  Future<Map<String, EmojiItem>> _loadBttv(String channelId) async {
    final document = await _json(
      Uri.parse('https://api.betterttv.net/3/cached/users/youtube/$channelId'),
    );
    if (document is! Map) return const {};
    final values = <dynamic>[
      ...(document['channelEmotes'] as List<dynamic>? ?? const []),
      ...(document['sharedEmotes'] as List<dynamic>? ?? const []),
    ];
    return {
      for (final value in values.whereType<Map>())
        if (value['id'] != null && value['code'] is String)
          value['code'] as String: _emoji(
            value['code'] as String,
            'https://cdn.betterttv.net/emote/${value['id']}/1x',
          ),
    };
  }

  Future<Map<String, EmojiItem>> _loadFfz(String channelId) async {
    final document = await _json(
      Uri.parse('https://api.frankerfacez.com/v1/room/yt/$channelId'),
    );
    if (document is! Map) return const {};
    final sets = document['sets'];
    if (sets is! Map) return const {};
    final result = <String, EmojiItem>{};
    for (final value in sets.values.whereType<Map>()) {
      final entries = value['emoticons'];
      if (entries is! List) continue;
      for (final item in entries.whereType<Map>()) {
        final name = item['name']?.toString() ?? '';
        final animated = item['animated'];
        final urls = item['urls'];
        final source = animated is Map
            ? animated['1']?.toString() ?? ''
            : urls is Map
                ? urls['1']?.toString() ?? ''
                : '';
        if (name.isNotEmpty && source.isNotEmpty) {
          result[name] = _emoji(
            name,
            source.startsWith('//') ? 'https:$source' : source,
          );
        }
      }
    }
    return result;
  }

  Future<Map<String, EmojiItem>> _loadSevenTv(String channelId) async {
    final document = await _json(
      Uri.parse('https://7tv.io/v3/users/youtube/$channelId'),
      notFoundStatuses: const {400, 404},
    );
    if (document is! Map) return const {};
    final set = document['emote_set'];
    final values = set is Map ? set['emotes'] : null;
    if (values is! List) return const {};
    return {
      for (final item in values.whereType<Map>())
        if (item['id'] != null && item['name'] is String)
          item['name'] as String: _emoji(
            item['name'] as String,
            'https://cdn.7tv.app/emote/${item['id']}/1x.webp',
          ),
    };
  }

  Future<Object?> _json(
    Uri uri, {
    Set<int> notFoundStatuses = const {404},
  }) async {
    final response = await _client.get(uri).timeout(requestTimeout);
    if (notFoundStatuses.contains(response.statusCode)) {
      throw const YoutubeExternalEmoteNotFound();
    }
    if (response.statusCode != 200) {
      throw YoutubeExternalEmoteHttpException(uri, response.statusCode);
    }
    return jsonDecode(response.body);
  }

  EmojiItem _emoji(String name, String url) => EmojiItem(
        url: url,
        alt: name,
        emojiText: name,
        isCustomEmoji: true,
      );

  void close() {
    if (_ownsClient) _client.close();
  }
}

List<MessageItem> applyYoutubeExternalEmotes(
  List<MessageItem> message,
  Map<String, EmojiItem> emotes,
) {
  if (emotes.isEmpty) return message;
  final result = <MessageItem>[];
  for (final part in message) {
    if (part.isEmoji) {
      result.add(part);
      continue;
    }
    for (final match in RegExp(r'\S+|\s+').allMatches(part.text)) {
      final text = match.group(0)!;
      final emote = emotes[text];
      result.add(
          emote == null ? MessageItem.text(text) : MessageItem.emoji(emote));
    }
  }
  return List.unmodifiable(result);
}

final class YoutubeExternalEmoteHttpException implements Exception {
  const YoutubeExternalEmoteHttpException(this.uri, this.statusCode);
  final Uri uri;
  final int statusCode;
}

final class YoutubeExternalEmoteNotFound implements Exception {
  const YoutubeExternalEmoteNotFound();
}
