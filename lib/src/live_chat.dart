import 'dart:async';
import 'dart:collection';
import 'dart:math';

import 'package:dart_youtube_chat/src/requests.dart';
import 'package:dart_youtube_chat/src/external_emotes.dart';
import 'package:dart_youtube_chat/src/types/data.dart';

class LiveChat {
  LiveChat._(
    this._id,
    this._interval,
    this._client,
    this._ownsClient,
    this._options,
    this._minimumRetryDelay,
    this._maximumRetryDelay,
    this._rediscoverAfterFailures,
    this._randomDouble,
    this._emoteLoader,
    this._ownsEmoteLoader,
  );

  factory LiveChat({
    required YoutubeId id,
    Duration? interval,
    YoutubeHttpClient? client,
    Duration minimumRetryDelay = const Duration(seconds: 1),
    Duration maximumRetryDelay = const Duration(seconds: 30),
    int rediscoverAfterFailures = 3,
    double Function()? randomDouble,
    YoutubeExternalEmoteLoader? externalEmoteLoader,
    bool loadExternalEmotes = true,
  }) {
    return LiveChat._(
      id,
      interval,
      client ?? YoutubeHttpClient(),
      client == null,
      null,
      minimumRetryDelay,
      maximumRetryDelay,
      rediscoverAfterFailures,
      randomDouble ?? Random().nextDouble,
      loadExternalEmotes
          ? externalEmoteLoader ?? YoutubeExternalEmoteLoader()
          : null,
      loadExternalEmotes && externalEmoteLoader == null,
    );
  }

  /// Creates a chat from options already resolved from the live page.
  ///
  /// This avoids downloading the same page again when chat and metadata share
  /// one [FetchOptions] instance.
  factory LiveChat.fromOptions({
    required FetchOptions options,
    Duration? interval,
    YoutubeHttpClient? client,
    YoutubeId id = const YoutubeId(),
    Duration minimumRetryDelay = const Duration(seconds: 1),
    Duration maximumRetryDelay = const Duration(seconds: 30),
    int rediscoverAfterFailures = 3,
    double Function()? randomDouble,
    YoutubeExternalEmoteLoader? externalEmoteLoader,
    bool loadExternalEmotes = true,
  }) {
    return LiveChat._(
      id,
      interval,
      client ?? YoutubeHttpClient(),
      client == null,
      options,
      minimumRetryDelay,
      maximumRetryDelay,
      rediscoverAfterFailures,
      randomDouble ?? Random().nextDouble,
      loadExternalEmotes
          ? externalEmoteLoader ?? YoutubeExternalEmoteLoader()
          : null,
      loadExternalEmotes && externalEmoteLoader == null,
    );
  }

  final YoutubeId _id;
  final Duration? _interval;
  final YoutubeHttpClient _client;
  final bool _ownsClient;
  final Duration _minimumRetryDelay;
  final Duration _maximumRetryDelay;
  final int _rediscoverAfterFailures;
  final double Function() _randomDouble;
  final YoutubeExternalEmoteLoader? _emoteLoader;
  final bool _ownsEmoteLoader;
  final _msgController = StreamController<ChatItem>.broadcast();
  final _eventController = StreamController<LiveChatEvent>.broadcast();
  final _batchController = StreamController<LiveChatBatch>.broadcast();
  final _errController = StreamController<Exception>.broadcast();
  final _pollController = StreamController<DateTime>.broadcast();
  final _enrichmentErrorController = StreamController<Exception>.broadcast();
  final _seenIds = <String>{};
  final _seenOrder = Queue<String>();

  FetchOptions? _options;
  Timer? _timer;
  bool _running = false;
  bool _startedOnce = false;
  bool _pollInFlight = false;
  bool _closed = false;
  int _consecutiveFailures = 0;
  Map<String, EmojiItem> _externalEmotes = const {};

  Stream<ChatItem> get messages => _msgController.stream;
  Stream<LiveChatEvent> get events => _eventController.stream;
  Stream<LiveChatBatch> get batches => _batchController.stream;
  Stream<Exception> get errors => _errController.stream;
  Stream<DateTime> get polls => _pollController.stream;
  Stream<Exception> get enrichmentErrors => _enrichmentErrorController.stream;
  String get liveId => _options?.liveId ?? '';
  bool get isRunning => _running;

  Future<void> start() async {
    if (_closed) throw StateError('LiveChat is closed');
    if (_running) throw StateError('LiveChat is already running');
    if (_startedOnce) {
      throw StateError('A stopped LiveChat cannot be restarted');
    }
    if (_options == null &&
        _id.channelId.isEmpty &&
        _id.liveId.isEmpty &&
        _id.handle.isEmpty) {
      throw ArgumentError('YoutubeId must have channelId, liveId, or handle');
    }
    _startedOnce = true;
    if (_options == null) {
      try {
        _options = await _client.fetchLivePage(_id);
      } catch (_) {
        if (!_closed) _startedOnce = false;
        rethrow;
      }
    }
    if (_options!.channelId.isEmpty && _id.channelId.isNotEmpty) {
      _options = _options!.copyWith(channelId: _id.channelId);
    }
    if (_closed) {
      throw StateError('LiveChat was stopped while starting');
    }
    _running = true;
    if (_emoteLoader != null && _options!.channelId.isNotEmpty) {
      unawaited(_loadExternalEmotes(_options!.channelId));
    }
    _schedule(Duration.zero);
  }

  void stop() {
    if (_closed) return;
    _closed = true;
    _running = false;
    _timer?.cancel();
    _timer = null;
    if (_ownsClient) _client.close();
    if (_ownsEmoteLoader) _emoteLoader?.close();
    unawaited(_msgController.close());
    unawaited(_eventController.close());
    unawaited(_batchController.close());
    unawaited(_errController.close());
    unawaited(_pollController.close());
    unawaited(_enrichmentErrorController.close());
  }

  void _schedule(Duration delay) {
    if (!_running) return;
    _timer?.cancel();
    _timer = Timer(delay, _execute);
  }

  Future<void> _execute() async {
    final options = _options;
    if (options == null || !_running || _pollInFlight) return;
    _pollInFlight = true;
    var nextDelay = _interval ?? const Duration(seconds: 1);
    try {
      final batch = await _client.fetchChatBatch(options);
      if (!_running) return;
      if (batch.continuation.isEmpty) {
        throw const YoutubeRequestException(
          YoutubeRequestFailure.malformedResponse,
          'fetchChat',
          cause: FormatException('Live chat continuation is missing'),
        );
      }
      _options = options.copyWith(continuation: batch.continuation);
      _consecutiveFailures = 0;
      nextDelay = _interval ?? batch.pollingInterval;
      if (!_pollController.isClosed) {
        _pollController.add(DateTime.now().toUtc());
      }
      if (!_batchController.isClosed) _batchController.add(batch);
      for (final event in batch.events) {
        if (!_eventController.isClosed) _eventController.add(event);
      }
      for (final item in batch.messages) {
        if (_remember(item.id) && !_msgController.isClosed) {
          _msgController.add(item.copyWith(
            message: applyYoutubeExternalEmotes(item.message, _externalEmotes),
          ));
        }
      }
    } on Exception catch (error) {
      if (_running && !_errController.isClosed) _errController.add(error);
      _consecutiveFailures++;
      nextDelay = _retryDelay(_consecutiveFailures, error);
      if (_canRediscover && _consecutiveFailures >= _rediscoverAfterFailures) {
        try {
          _options = await _client.fetchLivePage(_id);
          _consecutiveFailures = 0;
          nextDelay = Duration.zero;
        } on Exception catch (rediscoveryError) {
          if (_running && !_errController.isClosed) {
            _errController.add(rediscoveryError);
          }
        }
      }
    } finally {
      _pollInFlight = false;
      if (_running) _schedule(nextDelay);
    }
  }

  Future<void> _loadExternalEmotes(String channelId) async {
    final loaded = await _emoteLoader!.load(
      channelId,
      onError: (error, _) {
        if (_running && !_enrichmentErrorController.isClosed) {
          _enrichmentErrorController.add(
            error is Exception ? error : Exception(error.toString()),
          );
        }
      },
    );
    if (_running) _externalEmotes = loaded;
  }

  bool get _canRediscover =>
      _id.channelId.isNotEmpty ||
      _id.liveId.isNotEmpty ||
      _id.handle.isNotEmpty;

  Duration _retryDelay(int failures, Exception error) {
    final exponential =
        _minimumRetryDelay.inMilliseconds * pow(2, min(failures - 1, 10));
    final capped = min(exponential.round(), _maximumRetryDelay.inMilliseconds);
    var result = Duration(
      milliseconds: (capped * (0.8 + _randomDouble() * 0.4)).round(),
    );
    if (error is YoutubeRequestException &&
        (error.statusCode == 429 || error.statusCode == 403) &&
        result < const Duration(seconds: 5)) {
      result = const Duration(seconds: 5);
    }
    return result;
  }

  bool _remember(String id) {
    if (id.isEmpty) return true;
    if (!_seenIds.add(id)) return false;
    _seenOrder.add(id);
    while (_seenOrder.length > 5000) {
      _seenIds.remove(_seenOrder.removeFirst());
    }
    return true;
  }
}
