import 'dart:async';

import 'package:dart_youtube_chat/src/requests.dart';
import 'package:dart_youtube_chat/src/types/data.dart';

/// YouTube live chat poller.
///
/// Fetches the live page once, then polls `/live_chat/get_live_chat` at
/// [interval] (default 1 second) and emits [ChatItem]s on [messages].
///
/// ```dart
/// final chat = await LiveChat.start(YoutubeId(handle: 'MrBeast'));
///
/// chat.messages.listen((item) => print(item.author.name));
///
/// // when done:
/// chat.stop();
/// ```
class LiveChat {
  final StreamController<ChatItem> _msgController =
      StreamController.broadcast();
  final StreamController<Exception> _errController =
      StreamController.broadcast();
  final StreamController<DateTime> _pollController =
      StreamController.broadcast();

  final YoutubeId _id;
  final Duration _interval;

  FetchOptions? _options;
  Timer? _timer;
  bool _running = false;

  /// Emits every incoming [ChatItem]. Broadcast — multiple listeners allowed.
  Stream<ChatItem> get messages => _msgController.stream;

  /// Non-fatal polling errors. Does not stop the poller.
  Stream<Exception> get errors => _errController.stream;

  /// Successful poll ticks, even if no new messages were returned.
  Stream<DateTime> get polls => _pollController.stream;

  /// The live video ID once [start] succeeds.
  String get liveId => _options?.liveId ?? '';

  LiveChat._(this._id, this._interval);

  /// Creates a [LiveChat] for [id] but does **not** start polling yet.
  /// Use [start] to begin.
  factory LiveChat({
    required YoutubeId id,
    Duration interval = const Duration(seconds: 1),
  }) =>
      LiveChat._(id, interval);

  /// Fetches the live page, then starts the polling timer.
  /// Throws if the channel is not found or the stream is already finished.
  Future<void> start() async {
    if (_running) throw StateError('LiveChat is already running');
    if (_id.channelId.isEmpty && _id.liveId.isEmpty && _id.handle.isEmpty) {
      throw ArgumentError('YoutubeId must have channelId, liveId, or handle');
    }

    final opts = await fetchLivePage(_id);
    _options = opts;
    _running = true;
    _timer = Timer.periodic(_interval, (_) => _execute());
  }

  /// Stops polling and closes both streams.
  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    if (!_msgController.isClosed) _msgController.close();
    if (!_errController.isClosed) _errController.close();
    if (!_pollController.isClosed) _pollController.close();
  }

  Future<void> _execute() async {
    final opts = _options;
    if (opts == null || !_running) return;

    try {
      final (items, continuation) = await fetchChat(opts);
      _options = opts.copyWith(continuation: continuation);
      if (!_pollController.isClosed) {
        _pollController.add(DateTime.now().toUtc());
      }
      for (final item in items) {
        if (!_msgController.isClosed) _msgController.add(item);
      }
    } on Exception catch (e) {
      if (!_errController.isClosed) _errController.add(e);
    }
  }
}
