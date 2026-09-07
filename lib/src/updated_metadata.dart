import 'dart:async';

import 'package:dart_youtube_chat/src/requests.dart';
import 'package:dart_youtube_chat/src/types/data.dart';
import 'package:dart_youtube_chat/src/types/updated_metadata.dart';

/// Polls YouTube's anonymous `updated_metadata` endpoint serially.
class UpdatedMetadata {
  UpdatedMetadata._(
    this._options,
    this._interval,
    this._client,
    this._ownsClient,
  );

  factory UpdatedMetadata({
    required FetchOptions options,
    Duration? interval,
    YoutubeHttpClient? client,
  }) {
    return UpdatedMetadata._(
      options,
      interval,
      client ?? YoutubeHttpClient(),
      client == null,
    );
  }

  final FetchOptions _options;
  final Duration? _interval;
  final YoutubeHttpClient _client;
  final bool _ownsClient;
  final _batchController = StreamController<UpdatedMetadataBatch>.broadcast();
  final _stateController = StreamController<UpdatedMetadataState>.broadcast();
  final _errorController = StreamController<Exception>.broadcast();
  final _pollController = StreamController<DateTime>.broadcast();

  Timer? _timer;
  String _continuation = '';
  bool _running = false;
  bool _startedOnce = false;
  bool _pollInFlight = false;
  bool _closed = false;
  UpdatedMetadataState _state = const UpdatedMetadataState();

  Stream<UpdatedMetadataBatch> get batches => _batchController.stream;
  Stream<UpdatedMetadataState> get states => _stateController.stream;
  Stream<Exception> get errors => _errorController.stream;
  Stream<DateTime> get polls => _pollController.stream;
  bool get isRunning => _running;
  String get continuation => _continuation;
  UpdatedMetadataState get currentState => _state;

  void start() {
    if (_closed) throw StateError('UpdatedMetadata is closed');
    if (_running) throw StateError('UpdatedMetadata is already running');
    if (_startedOnce) {
      throw StateError('A stopped UpdatedMetadata cannot be restarted');
    }
    if (_options.liveId.isEmpty) {
      throw ArgumentError.value(
        _options.liveId,
        'options.liveId',
        'must not be empty',
      );
    }
    _startedOnce = true;
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
    unawaited(_batchController.close());
    unawaited(_stateController.close());
    unawaited(_errorController.close());
    unawaited(_pollController.close());
  }

  void _schedule(Duration delay) {
    if (!_running) return;
    _timer?.cancel();
    _timer = Timer(delay, _execute);
  }

  Future<void> _execute() async {
    if (!_running || _pollInFlight) return;
    _pollInFlight = true;
    var nextDelay = _interval ?? const Duration(seconds: 5);
    try {
      final batch = await _client.fetchUpdatedMetadata(
        _options,
        continuation: _continuation,
      );
      if (!_running) return;
      if (batch.continuation.token.isNotEmpty) {
        _continuation = batch.continuation.token;
      }
      nextDelay = _interval ?? batch.pollingInterval;
      if (!_pollController.isClosed) {
        _pollController.add(DateTime.now().toUtc());
      }
      if (!_batchController.isClosed) _batchController.add(batch);
      _state = _state.apply(batch);
      if (!_stateController.isClosed) _stateController.add(_state);
    } on Exception catch (error) {
      if (_running && !_errorController.isClosed) {
        _errorController.add(error);
      }
    } finally {
      _pollInFlight = false;
      if (_running) _schedule(nextDelay);
    }
  }
}
