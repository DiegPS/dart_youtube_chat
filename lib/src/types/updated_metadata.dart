/// Typed response models for YouTube's anonymous `updated_metadata` endpoint.
library;

class UpdatedMetadataBatch {
  final UpdatedMetadataResponseContext responseContext;
  final UpdatedMetadataContinuation continuation;
  final List<UpdatedMetadataAction> actions;
  final UpdatedMetadataFrameworkUpdates frameworkUpdates;
  final Map<String, dynamic> raw;

  UpdatedMetadataBatch._({
    required this.responseContext,
    required this.continuation,
    required this.actions,
    required this.frameworkUpdates,
    required this.raw,
  });

  factory UpdatedMetadataBatch.fromJson(Map<String, dynamic> json) {
    return UpdatedMetadataBatch._(
      responseContext: UpdatedMetadataResponseContext.fromJson(
        _map(json['responseContext']),
      ),
      continuation: UpdatedMetadataContinuation.fromJson(
        _map(json['continuation']),
      ),
      actions: _mapList(json['actions'])
          .map(UpdatedMetadataAction.fromJson)
          .toList(growable: false),
      frameworkUpdates: UpdatedMetadataFrameworkUpdates.fromJson(
        _map(json['frameworkUpdates']),
      ),
      raw: Map.unmodifiable(json),
    );
  }

  Duration get pollingInterval => continuation.pollingInterval;

  UpdatedMetadataViewership? get viewership {
    for (final action in actions) {
      if (action.viewership != null) return action.viewership;
    }
    return null;
  }

  UpdatedMetadataText? get dateText => _firstText(
        UpdatedMetadataActionType.dateText,
        (action) => action.dateText,
      );

  UpdatedMetadataText? get title => _firstText(
        UpdatedMetadataActionType.title,
        (action) => action.title,
      );

  UpdatedMetadataText? get description => _firstText(
        UpdatedMetadataActionType.description,
        (action) => action.description,
      );

  UpdatedMetadataText? _firstText(
    UpdatedMetadataActionType type,
    UpdatedMetadataText? Function(UpdatedMetadataAction action) select,
  ) {
    for (final action in actions) {
      if (action.type == type) return select(action);
    }
    return null;
  }

  Map<String, dynamic> toJson() => raw;
}

/// Accumulated snapshot produced from incremental metadata batches.
///
/// YouTube commonly sends title and description only once, then emits sparse
/// viewership or like-count updates. Applying a batch retains earlier values
/// unless the batch explicitly replaces them.
class UpdatedMetadataState {
  final UpdatedMetadataViewership? viewership;
  final UpdatedMetadataText? dateText;
  final UpdatedMetadataText? title;
  final UpdatedMetadataText? description;
  final UpdatedMetadataLikeCountEntity? likeCount;
  final UpdatedMetadataBatch? lastBatch;

  const UpdatedMetadataState({
    this.viewership,
    this.dateText,
    this.title,
    this.description,
    this.likeCount,
    this.lastBatch,
  });

  /// Returns a snapshot containing all values supplied by [batch].
  UpdatedMetadataState apply(UpdatedMetadataBatch batch) {
    UpdatedMetadataLikeCountEntity? nextLikeCount;
    final mutations = batch.frameworkUpdates.entityBatchUpdate?.mutations ??
        const <UpdatedMetadataEntityMutation>[];
    for (final mutation in mutations) {
      if (mutation.likeCountEntity != null) {
        nextLikeCount = mutation.likeCountEntity;
      }
    }
    return UpdatedMetadataState(
      viewership: batch.viewership ?? viewership,
      dateText: batch.dateText ?? dateText,
      title: batch.title ?? title,
      description: batch.description ?? description,
      likeCount: nextLikeCount ?? likeCount,
      lastBatch: batch,
    );
  }
}

class UpdatedMetadataResponseContext {
  final String visitorData;
  final List<UpdatedMetadataServiceTrackingParams> serviceTrackingParams;
  final UpdatedMetadataMainAppWebResponseContext? mainAppWebResponseContext;
  final String responseId;
  final UpdatedMetadataWebResponseContextExtensionData?
      webResponseContextExtensionData;
  final Map<String, dynamic> raw;

  UpdatedMetadataResponseContext._({
    required this.visitorData,
    required this.serviceTrackingParams,
    required this.mainAppWebResponseContext,
    required this.responseId,
    required this.webResponseContextExtensionData,
    required this.raw,
  });

  factory UpdatedMetadataResponseContext.fromJson(Map<String, dynamic> json) {
    final mainApp = _nullableMap(json['mainAppWebResponseContext']);
    final extension = _nullableMap(json['webResponseContextExtensionData']);
    return UpdatedMetadataResponseContext._(
      visitorData: _string(json['visitorData']),
      serviceTrackingParams: _mapList(json['serviceTrackingParams'])
          .map(UpdatedMetadataServiceTrackingParams.fromJson)
          .toList(growable: false),
      mainAppWebResponseContext: mainApp == null
          ? null
          : UpdatedMetadataMainAppWebResponseContext.fromJson(mainApp),
      responseId: _string(json['responseId']),
      webResponseContextExtensionData: extension == null
          ? null
          : UpdatedMetadataWebResponseContextExtensionData.fromJson(extension),
      raw: Map.unmodifiable(json),
    );
  }

  Map<String, dynamic> toJson() => raw;
}

class UpdatedMetadataServiceTrackingParams {
  final String service;
  final List<UpdatedMetadataTrackingParam> params;
  final Map<String, dynamic> raw;

  UpdatedMetadataServiceTrackingParams._({
    required this.service,
    required this.params,
    required this.raw,
  });

  factory UpdatedMetadataServiceTrackingParams.fromJson(
    Map<String, dynamic> json,
  ) {
    return UpdatedMetadataServiceTrackingParams._(
      service: _string(json['service']),
      params: _mapList(json['params'])
          .map(UpdatedMetadataTrackingParam.fromJson)
          .toList(growable: false),
      raw: Map.unmodifiable(json),
    );
  }

  Map<String, dynamic> toJson() => raw;
}

class UpdatedMetadataTrackingParam {
  final String key;
  final String value;
  final Map<String, dynamic> raw;

  UpdatedMetadataTrackingParam._({
    required this.key,
    required this.value,
    required this.raw,
  });

  factory UpdatedMetadataTrackingParam.fromJson(Map<String, dynamic> json) {
    return UpdatedMetadataTrackingParam._(
      key: _string(json['key']),
      value: _string(json['value']),
      raw: Map.unmodifiable(json),
    );
  }

  Map<String, dynamic> toJson() => raw;
}

class UpdatedMetadataMainAppWebResponseContext {
  final bool loggedOut;
  final Map<String, dynamic> raw;

  UpdatedMetadataMainAppWebResponseContext._({
    required this.loggedOut,
    required this.raw,
  });

  factory UpdatedMetadataMainAppWebResponseContext.fromJson(
    Map<String, dynamic> json,
  ) {
    return UpdatedMetadataMainAppWebResponseContext._(
      loggedOut: json['loggedOut'] == true,
      raw: Map.unmodifiable(json),
    );
  }

  Map<String, dynamic> toJson() => raw;
}

class UpdatedMetadataWebResponseContextExtensionData {
  final List<String> preloadMessageNames;
  final bool hasDecorated;
  final Map<String, dynamic> raw;

  UpdatedMetadataWebResponseContextExtensionData._({
    required this.preloadMessageNames,
    required this.hasDecorated,
    required this.raw,
  });

  factory UpdatedMetadataWebResponseContextExtensionData.fromJson(
    Map<String, dynamic> json,
  ) {
    final preload = _map(json['webResponseContextPreloadData']);
    return UpdatedMetadataWebResponseContextExtensionData._(
      preloadMessageNames: _stringList(preload['preloadMessageNames']),
      hasDecorated: json['hasDecorated'] == true,
      raw: Map.unmodifiable(json),
    );
  }

  Map<String, dynamic> toJson() => raw;
}

class UpdatedMetadataContinuation {
  final String token;
  final Duration pollingInterval;
  final Map<String, dynamic> raw;

  UpdatedMetadataContinuation._({
    required this.token,
    required this.pollingInterval,
    required this.raw,
  });

  factory UpdatedMetadataContinuation.fromJson(Map<String, dynamic> json) {
    final timed = _map(json['timedContinuationData']);
    final parsedTimeoutMs = _integer(timed['timeoutMs'], fallback: 5000);
    final timeoutMs = parsedTimeoutMs > 0 ? parsedTimeoutMs : 5000;
    return UpdatedMetadataContinuation._(
      token: _string(timed['continuation']),
      pollingInterval: Duration(milliseconds: timeoutMs),
      raw: Map.unmodifiable(json),
    );
  }

  Map<String, dynamic> toJson() => raw;
}

enum UpdatedMetadataActionType {
  viewership,
  dateText,
  title,
  description,
  unknown,
}

class UpdatedMetadataAction {
  final UpdatedMetadataActionType type;
  final String actionName;
  final UpdatedMetadataViewership? viewership;
  final UpdatedMetadataText? dateText;
  final UpdatedMetadataText? title;
  final UpdatedMetadataText? description;
  final Map<String, dynamic> raw;

  UpdatedMetadataAction._({
    required this.type,
    required this.actionName,
    required this.viewership,
    required this.dateText,
    required this.title,
    required this.description,
    required this.raw,
  });

  factory UpdatedMetadataAction.fromJson(Map<String, dynamic> json) {
    final actionName = json.keys.firstWhere(
      (key) => key != 'trackingParams' && key != 'clickTrackingParams',
      orElse: () => json.isEmpty ? '' : json.keys.first,
    );
    final action = _map(json[actionName]);
    return switch (actionName) {
      'updateViewershipAction' => UpdatedMetadataAction._(
          type: UpdatedMetadataActionType.viewership,
          actionName: actionName,
          viewership: UpdatedMetadataViewership.fromJson(
            _map(_map(action['viewCount'])['videoViewCountRenderer']),
          ),
          dateText: null,
          title: null,
          description: null,
          raw: Map.unmodifiable(json),
        ),
      'updateDateTextAction' => UpdatedMetadataAction._(
          type: UpdatedMetadataActionType.dateText,
          actionName: actionName,
          viewership: null,
          dateText: UpdatedMetadataText.fromJson(_map(action['dateText'])),
          title: null,
          description: null,
          raw: Map.unmodifiable(json),
        ),
      'updateTitleAction' => UpdatedMetadataAction._(
          type: UpdatedMetadataActionType.title,
          actionName: actionName,
          viewership: null,
          dateText: null,
          title: UpdatedMetadataText.fromJson(_map(action['title'])),
          description: null,
          raw: Map.unmodifiable(json),
        ),
      'updateDescriptionAction' => UpdatedMetadataAction._(
          type: UpdatedMetadataActionType.description,
          actionName: actionName,
          viewership: null,
          dateText: null,
          title: null,
          description:
              UpdatedMetadataText.fromJson(_map(action['description'])),
          raw: Map.unmodifiable(json),
        ),
      _ => UpdatedMetadataAction._(
          type: UpdatedMetadataActionType.unknown,
          actionName: actionName,
          viewership: null,
          dateText: null,
          title: null,
          description: null,
          raw: Map.unmodifiable(json),
        ),
    };
  }

  Map<String, dynamic> toJson() => raw;
}

class UpdatedMetadataViewership {
  final UpdatedMetadataText viewCount;
  final bool isLive;
  final UpdatedMetadataText extraShortViewCount;
  final UpdatedMetadataText unlabeledViewCountValue;
  final String originalViewCount;
  final Map<String, dynamic> raw;

  UpdatedMetadataViewership._({
    required this.viewCount,
    required this.isLive,
    required this.extraShortViewCount,
    required this.unlabeledViewCountValue,
    required this.originalViewCount,
    required this.raw,
  });

  factory UpdatedMetadataViewership.fromJson(Map<String, dynamic> json) {
    return UpdatedMetadataViewership._(
      viewCount: UpdatedMetadataText.fromJson(_map(json['viewCount'])),
      isLive: json['isLive'] == true,
      extraShortViewCount:
          UpdatedMetadataText.fromJson(_map(json['extraShortViewCount'])),
      unlabeledViewCountValue:
          UpdatedMetadataText.fromJson(_map(json['unlabeledViewCountValue'])),
      originalViewCount: _string(json['originalViewCount']),
      raw: Map.unmodifiable(json),
    );
  }

  int? get originalViewCountValue => int.tryParse(originalViewCount);

  Map<String, dynamic> toJson() => raw;
}

class UpdatedMetadataText {
  final String simpleText;
  final List<UpdatedMetadataTextRun> runs;
  final String accessibilityLabel;
  final Map<String, dynamic> raw;

  UpdatedMetadataText._({
    required this.simpleText,
    required this.runs,
    required this.accessibilityLabel,
    required this.raw,
  });

  factory UpdatedMetadataText.fromJson(Map<String, dynamic> json) {
    final accessibility =
        _map(_map(json['accessibility'])['accessibilityData']);
    return UpdatedMetadataText._(
      simpleText: _string(json['simpleText']),
      runs: _mapList(json['runs'])
          .map(UpdatedMetadataTextRun.fromJson)
          .toList(growable: false),
      accessibilityLabel: _string(accessibility['label']),
      raw: Map.unmodifiable(json),
    );
  }

  String get text =>
      simpleText.isNotEmpty ? simpleText : runs.map((run) => run.text).join();

  Map<String, dynamic> toJson() => raw;
}

class UpdatedMetadataTextRun {
  final String text;
  final Map<String, dynamic> raw;

  UpdatedMetadataTextRun._({required this.text, required this.raw});

  factory UpdatedMetadataTextRun.fromJson(Map<String, dynamic> json) {
    return UpdatedMetadataTextRun._(
      text: _string(json['text']),
      raw: Map.unmodifiable(json),
    );
  }

  Map<String, dynamic> toJson() => raw;
}

class UpdatedMetadataFrameworkUpdates {
  final UpdatedMetadataEntityBatchUpdate? entityBatchUpdate;
  final Map<String, dynamic> raw;

  UpdatedMetadataFrameworkUpdates._({
    required this.entityBatchUpdate,
    required this.raw,
  });

  factory UpdatedMetadataFrameworkUpdates.fromJson(Map<String, dynamic> json) {
    final batch = _nullableMap(json['entityBatchUpdate']);
    return UpdatedMetadataFrameworkUpdates._(
      entityBatchUpdate: batch == null
          ? null
          : UpdatedMetadataEntityBatchUpdate.fromJson(batch),
      raw: Map.unmodifiable(json),
    );
  }

  Map<String, dynamic> toJson() => raw;
}

class UpdatedMetadataEntityBatchUpdate {
  final List<UpdatedMetadataEntityMutation> mutations;
  final UpdatedMetadataTimestamp? timestamp;
  final Map<String, dynamic> raw;

  UpdatedMetadataEntityBatchUpdate._({
    required this.mutations,
    required this.timestamp,
    required this.raw,
  });

  factory UpdatedMetadataEntityBatchUpdate.fromJson(Map<String, dynamic> json) {
    final timestamp = _nullableMap(json['timestamp']);
    return UpdatedMetadataEntityBatchUpdate._(
      mutations: _mapList(json['mutations'])
          .map(UpdatedMetadataEntityMutation.fromJson)
          .toList(growable: false),
      timestamp: timestamp == null
          ? null
          : UpdatedMetadataTimestamp.fromJson(timestamp),
      raw: Map.unmodifiable(json),
    );
  }

  Map<String, dynamic> toJson() => raw;
}

class UpdatedMetadataTimestamp {
  final String seconds;
  final int nanos;
  final Map<String, dynamic> raw;

  UpdatedMetadataTimestamp._({
    required this.seconds,
    required this.nanos,
    required this.raw,
  });

  factory UpdatedMetadataTimestamp.fromJson(Map<String, dynamic> json) {
    return UpdatedMetadataTimestamp._(
      seconds: _string(json['seconds']),
      nanos: _integer(json['nanos']),
      raw: Map.unmodifiable(json),
    );
  }

  DateTime? get dateTime {
    final secondsValue = int.tryParse(seconds);
    if (secondsValue == null) return null;
    return DateTime.fromMicrosecondsSinceEpoch(
      secondsValue * Duration.microsecondsPerSecond + nanos ~/ 1000,
      isUtc: true,
    );
  }

  Map<String, dynamic> toJson() => raw;
}

class UpdatedMetadataEntityMutation {
  final String entityKey;
  final String type;
  final UpdatedMetadataLikeCountEntity? likeCountEntity;
  final Map<String, dynamic> raw;

  UpdatedMetadataEntityMutation._({
    required this.entityKey,
    required this.type,
    required this.likeCountEntity,
    required this.raw,
  });

  factory UpdatedMetadataEntityMutation.fromJson(Map<String, dynamic> json) {
    final likeCount = _nullableMap(_map(json['payload'])['likeCountEntity']);
    return UpdatedMetadataEntityMutation._(
      entityKey: _string(json['entityKey']),
      type: _string(json['type']),
      likeCountEntity: likeCount == null
          ? null
          : UpdatedMetadataLikeCountEntity.fromJson(likeCount),
      raw: Map.unmodifiable(json),
    );
  }

  Map<String, dynamic> toJson() => raw;
}

class UpdatedMetadataLikeCountEntity {
  final String key;
  final UpdatedMetadataContent likeCountIfLiked;
  final UpdatedMetadataContent likeCountIfDisliked;
  final UpdatedMetadataContent likeCountIfIndifferent;
  final UpdatedMetadataContent expandedLikeCountIfLiked;
  final UpdatedMetadataContent expandedLikeCountIfDisliked;
  final UpdatedMetadataContent expandedLikeCountIfIndifferent;
  final UpdatedMetadataContent likeCountLabel;
  final UpdatedMetadataContent likeButtonA11yText;
  final String likeCountIfLikedNumber;
  final String likeCountIfDislikedNumber;
  final String likeCountIfIndifferentNumber;
  final bool shouldExpandLikeCount;
  final UpdatedMetadataContent sentimentFactoidA11yTextIfLiked;
  final UpdatedMetadataContent sentimentFactoidA11yTextIfDisliked;
  final Map<String, dynamic> raw;

  UpdatedMetadataLikeCountEntity._({
    required this.key,
    required this.likeCountIfLiked,
    required this.likeCountIfDisliked,
    required this.likeCountIfIndifferent,
    required this.expandedLikeCountIfLiked,
    required this.expandedLikeCountIfDisliked,
    required this.expandedLikeCountIfIndifferent,
    required this.likeCountLabel,
    required this.likeButtonA11yText,
    required this.likeCountIfLikedNumber,
    required this.likeCountIfDislikedNumber,
    required this.likeCountIfIndifferentNumber,
    required this.shouldExpandLikeCount,
    required this.sentimentFactoidA11yTextIfLiked,
    required this.sentimentFactoidA11yTextIfDisliked,
    required this.raw,
  });

  factory UpdatedMetadataLikeCountEntity.fromJson(Map<String, dynamic> json) {
    UpdatedMetadataContent content(String key) =>
        UpdatedMetadataContent.fromJson(_map(json[key]));

    return UpdatedMetadataLikeCountEntity._(
      key: _string(json['key']),
      likeCountIfLiked: content('likeCountIfLiked'),
      likeCountIfDisliked: content('likeCountIfDisliked'),
      likeCountIfIndifferent: content('likeCountIfIndifferent'),
      expandedLikeCountIfLiked: content('expandedLikeCountIfLiked'),
      expandedLikeCountIfDisliked: content('expandedLikeCountIfDisliked'),
      expandedLikeCountIfIndifferent: content('expandedLikeCountIfIndifferent'),
      likeCountLabel: content('likeCountLabel'),
      likeButtonA11yText: content('likeButtonA11yText'),
      likeCountIfLikedNumber: _string(json['likeCountIfLikedNumber']),
      likeCountIfDislikedNumber: _string(json['likeCountIfDislikedNumber']),
      likeCountIfIndifferentNumber:
          _string(json['likeCountIfIndifferentNumber']),
      shouldExpandLikeCount: json['shouldExpandLikeCount'] == true,
      sentimentFactoidA11yTextIfLiked:
          content('sentimentFactoidA11yTextIfLiked'),
      sentimentFactoidA11yTextIfDisliked:
          content('sentimentFactoidA11yTextIfDisliked'),
      raw: Map.unmodifiable(json),
    );
  }

  Map<String, dynamic> toJson() => raw;
}

class UpdatedMetadataContent {
  final String content;
  final Map<String, dynamic> raw;

  UpdatedMetadataContent._({required this.content, required this.raw});

  factory UpdatedMetadataContent.fromJson(Map<String, dynamic> json) {
    return UpdatedMetadataContent._(
      content: _string(json['content']),
      raw: Map.unmodifiable(json),
    );
  }

  Map<String, dynamic> toJson() => raw;
}

Map<String, dynamic> _map(Object? value) =>
    value is Map<String, dynamic> ? value : const {};

Map<String, dynamic>? _nullableMap(Object? value) =>
    value is Map<String, dynamic> ? value : null;

List<Map<String, dynamic>> _mapList(Object? value) => value is List
    ? value.whereType<Map<String, dynamic>>().toList(growable: false)
    : const [];

List<String> _stringList(Object? value) => value is List
    ? value.whereType<String>().toList(growable: false)
    : const [];

String _string(Object? value) => value is String ? value : '';

int _integer(Object? value, {int fallback = 0}) =>
    value is num ? value.toInt() : fallback;
