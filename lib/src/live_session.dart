import 'dart:async';

import 'package:dart_youtube_chat/src/live_chat.dart';
import 'package:dart_youtube_chat/src/requests.dart';
import 'package:dart_youtube_chat/src/types/data.dart';
import 'package:dart_youtube_chat/src/types/updated_metadata.dart';
import 'package:dart_youtube_chat/src/updated_metadata.dart';

enum YoutubeLiveLifecycle { live, ended }

/// Coordinates anonymous live chat and metadata from one resolved live page.
class YoutubeLiveSession {
  YoutubeLiveSession({
    required YoutubeId id,
    Duration? chatInterval,
    Duration? metadataInterval,
    YoutubeHttpClient? client,
  })  : _id = id,
        _chatInterval = chatInterval,
        _metadataInterval = metadataInterval,
        _client = client ?? YoutubeHttpClient(),
        _ownsClient = client == null;

  final YoutubeId _id;
  final Duration? _chatInterval;
  final Duration? _metadataInterval;
  final YoutubeHttpClient _client;
  final bool _ownsClient;

  final _messageController = StreamController<ChatItem>.broadcast();
  final _eventController = StreamController<LiveChatEvent>.broadcast();
  final _chatBatchController = StreamController<LiveChatBatch>.broadcast();
  final _metadataBatchController =
      StreamController<UpdatedMetadataBatch>.broadcast();
  final _metadataStateController =
      StreamController<UpdatedMetadataState>.broadcast();
  final _errorController = StreamController<Exception>.broadcast();
  final _chatErrorController = StreamController<Exception>.broadcast();
  final _metadataErrorController = StreamController<Exception>.broadcast();
  final _chatPollController = StreamController<DateTime>.broadcast();
  final _metadataPollController = StreamController<DateTime>.broadcast();
  final _lifecycleController =
      StreamController<YoutubeLiveLifecycle>.broadcast();

  final _subscriptions = <StreamSubscription<Object?>>[];
  LiveChat? _chat;
  UpdatedMetadata? _metadata;
  String _liveId = '';
  bool _running = false;
  bool _starting = false;
  bool _startedOnce = false;
  bool _closed = false;
  YoutubeLiveLifecycle? _lastLifecycle;

  Stream<ChatItem> get messages => _messageController.stream;
  Stream<LiveChatEvent> get events => _eventController.stream;
  Stream<LiveChatBatch> get chatBatches => _chatBatchController.stream;
  Stream<UpdatedMetadataBatch> get metadataBatches =>
      _metadataBatchController.stream;
  Stream<UpdatedMetadataState> get metadataStates =>
      _metadataStateController.stream;

  /// All chat and metadata errors, retained for backwards compatibility.
  Stream<Exception> get errors => _errorController.stream;

  /// Errors emitted by `get_live_chat` polling only.
  Stream<Exception> get chatErrors => _chatErrorController.stream;

  /// Errors emitted by `updated_metadata` polling only.
  Stream<Exception> get metadataErrors => _metadataErrorController.stream;
  Stream<DateTime> get chatPolls => _chatPollController.stream;
  Stream<DateTime> get metadataPolls => _metadataPollController.stream;
  Stream<YoutubeLiveLifecycle> get lifecycle => _lifecycleController.stream;
  String get liveId => _liveId;
  bool get isRunning => _running;

  /// Resolves the live page once and starts both polling loops.
  Future<void> start() async {
    if (_closed) throw StateError('YoutubeLiveSession is closed');
    if (_running || _starting) {
      throw StateError('YoutubeLiveSession is already running');
    }
    if (_startedOnce) {
      throw StateError('A stopped YoutubeLiveSession cannot be restarted');
    }
    _starting = true;
    FetchOptions options;
    try {
      options = await _client.fetchLivePage(_id);
    } catch (_) {
      _starting = false;
      rethrow;
    }
    if (_closed) {
      _starting = false;
      throw StateError('YoutubeLiveSession was stopped while starting');
    }

    _liveId = options.liveId;
    final chat = LiveChat.fromOptions(
      options: options,
      id: _id,
      interval: _chatInterval,
      client: _client,
    );
    final metadata = UpdatedMetadata(
      options: options,
      interval: _metadataInterval,
      client: _client,
    );
    _chat = chat;
    _metadata = metadata;
    _wire(chat, metadata);
    _startedOnce = true;
    _running = true;
    _starting = false;
    await chat.start();
    metadata.start();
  }

  /// Stops both polling loops and closes every session stream.
  void stop() {
    if (_closed) return;
    _closed = true;
    _running = false;
    _starting = false;
    _chat?.stop();
    _metadata?.stop();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    if (_ownsClient) _client.close();
    unawaited(_messageController.close());
    unawaited(_eventController.close());
    unawaited(_chatBatchController.close());
    unawaited(_metadataBatchController.close());
    unawaited(_metadataStateController.close());
    unawaited(_errorController.close());
    unawaited(_chatErrorController.close());
    unawaited(_metadataErrorController.close());
    unawaited(_chatPollController.close());
    unawaited(_metadataPollController.close());
    unawaited(_lifecycleController.close());
  }

  void _wire(LiveChat chat, UpdatedMetadata metadata) {
    _listen(chat.messages, _messageController);
    _listen(chat.events, _eventController);
    _listen(chat.batches, _chatBatchController);
    _listen(metadata.batches, _metadataBatchController);
    _subscriptions.add(metadata.states.listen((state) {
      if (!_metadataStateController.isClosed) {
        _metadataStateController.add(state);
      }
      final viewership = state.viewership;
      if (viewership == null) return;
      final lifecycle = viewership.isLive
          ? YoutubeLiveLifecycle.live
          : YoutubeLiveLifecycle.ended;
      if (_lastLifecycle == lifecycle) return;
      _lastLifecycle = lifecycle;
      if (!_lifecycleController.isClosed) {
        _lifecycleController.add(lifecycle);
      }
    }));
    _listenErrors(chat.errors, _chatErrorController);
    _listenErrors(metadata.errors, _metadataErrorController);
    _listen(chat.polls, _chatPollController);
    _listen(metadata.polls, _metadataPollController);
  }

  void _listen<T>(Stream<T> stream, StreamController<T> controller) {
    _subscriptions.add(stream.listen((value) {
      if (!controller.isClosed) controller.add(value);
    }));
  }

  void _listenErrors(
    Stream<Exception> stream,
    StreamController<Exception> sourceController,
  ) {
    _subscriptions.add(stream.listen((error) {
      if (!sourceController.isClosed) sourceController.add(error);
      if (!_errorController.isClosed) _errorController.add(error);
    }));
  }
}
