import 'dart:convert';
import 'dart:io';

import 'package:dart_youtube_chat/dart_youtube_chat.dart';

Future<void> main(List<String> arguments) async {
  final handle = arguments.isEmpty ? '@latinanoticias' : arguments.first;
  final client = YoutubeHttpClient();
  try {
    final options = await client.fetchLivePage(YoutubeId(handle: handle));
    final first = await client.fetchUpdatedMetadata(options);
    final firstToken = first.continuation.token;
    if (firstToken.isEmpty) {
      throw StateError('The endpoint returned no continuation token');
    }

    await Future<void>.delayed(first.pollingInterval);
    final second = await client.fetchUpdatedMetadata(
      options,
      continuation: firstToken,
    );

    stdout.writeln(const JsonEncoder.withIndent('  ').convert({
      'channel': handle,
      'videoIdPresent': options.liveId.isNotEmpty,
      'first': _summary(first),
      'second': _summary(second),
      'continuationAccepted': second.continuation.token.isNotEmpty,
      'continuationRotated': second.continuation.token != firstToken,
    }));
  } on YoutubeRequestException catch (error) {
    stderr.writeln(
      'Inspection failed: ${error.failure.name} during ${error.operation}; '
      'status=${error.statusCode}',
    );
    exitCode = 1;
  } catch (error) {
    stderr.writeln('Inspection failed: ${error.runtimeType}');
    exitCode = 1;
  } finally {
    client.close();
  }
}

Map<String, Object?> _summary(UpdatedMetadataBatch batch) {
  return {
    'pollingIntervalMs': batch.pollingInterval.inMilliseconds,
    'actionTypes': batch.actions
        .map((action) => action.actionName)
        .where((name) => name.isNotEmpty)
        .toList(),
    'isLive': batch.viewership?.isLive,
    'viewCountAvailable': batch.viewership?.originalViewCount.isNotEmpty,
    'titleAvailable': batch.title?.text.isNotEmpty,
    'dateAvailable': batch.dateText?.text.isNotEmpty,
    'descriptionAvailable': batch.description?.text.isNotEmpty,
    'entityMutations':
        batch.frameworkUpdates.entityBatchUpdate?.mutations.length ?? 0,
    'rawTopLevelFields': batch.raw.keys.toList()..sort(),
  };
}
