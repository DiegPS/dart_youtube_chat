import 'dart:async';
import 'dart:collection';

import 'package:dart_youtube_chat/src/requests.dart';
import 'package:dart_youtube_chat/src/types/data.dart';

class LiveChat {
  LiveChat._(
    this._id,
    this._interval,
    this._client,
    this._ownsClient,
    this._options,
  );

  factory LiveChat({
    required YoutubeId id,
    Duration? interval,
    YoutubeHttpClient? client,
  }) {
    return LiveChat._(
      id,
      interval,
      client ?? YoutubeHttpClient(),
      client == null,
      null,
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
  }) {
    return LiveChat._(
      const YoutubeId(),
      interval,
      client ?? YoutubeHttpClient(),
      client == null,
      options,
    );
  }

  final YoutubeId _id;
  final Duration? _interval;
  final YoutubeHttpClient _client;
  final bool _ownsClient;
  final _msgController = StreamController<ChatItem>.broadcast();
  final _eventController = StreamController<LiveChatEvent>.broadcast();
  final _batchController = StreamController<LiveChatBatch>.broadcast();
  final _errController = StreamController<Exception>.broadcast();
  final _pollController = StreamController<DateTime>.broadcast();
  final _seenIds = <String>{};
  final _seenOrder = Queue<String>();

  FetchOptions? _options;
  Timer? _timer;
  bool _running = false;
  bool _startedOnce = false;
  bool _pollInFlight = false;
  bool _closed = false;

  Stream<ChatItem> get messages => _msgController.stream;
  Stream<LiveChatEvent> get events => _eventController.stream;
  Stream<LiveChatBatch> get batches => _batchController.stream;
  Stream<Exception> get errors => _errController.stream;
  Stream<DateTime> get polls => _pollController.stream;
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
    if (_closed) {
      throw StateError('LiveChat was stopped while starting');
    }
    _running = true;
    _schedule(Duration.zero);
  }

  void stop() {
    if (_closed) return;
    _closed = true;
    _running = false;
    _timer?.cancel();
    _timer = null;
    if (_ownsClient) _client.close();
    unawaited(_msgController.close());
    unawaited(_eventController.close());
    unawaited(_batchController.close());
    unawaited(_errController.close());
    unawaited(_pollController.close());
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
      if (batch.continuation.isNotEmpty) {
        _options = options.copyWith(continuation: batch.continuation);
      }
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
          _msgController.add(item);
        }
      }
    } on Exception catch (error) {
      if (_running && !_errController.isClosed) _errController.add(error);
    } finally {
      _pollInFlight = false;
      if (_running) _schedule(nextDelay);
    }
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
