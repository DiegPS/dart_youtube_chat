import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dart_youtube_chat/dart_youtube_chat.dart';

Future<void> main(List<String> arguments) async {
  final handle = arguments.isEmpty ? '@PastorJerryEze' : arguments.first;
  final requestedPolls =
      arguments.length > 1 ? int.tryParse(arguments[1]) ?? 5 : 5;
  if (requestedPolls < 1 || requestedPolls > 30) {
    stderr.writeln('Poll count must be between 1 and 30.');
    exitCode = 64;
    return;
  }

  final chat = LiveChat(id: YoutubeId(handle: handle));
  final summary = _InspectionSummary();
  final errors = <String>[];
  final errorSubscription = chat.errors.listen(
    (error) => errors.add(error.runtimeType.toString()),
  );
  final completion = chat.batches.take(requestedPolls).forEach(summary.add);

  try {
    await chat.start();
    await completion.timeout(const Duration(minutes: 2));
    stdout.writeln(const JsonEncoder.withIndent('  ').convert({
      'channel': handle,
      'liveIdPresent': chat.liveId.isNotEmpty,
      ...summary.toJson(),
      'errorTypes': errors,
    }));
  } catch (error) {
    if (error is YoutubeRequestException) {
      stderr.writeln(
        'Inspection failed: ${error.failure.name} during ${error.operation}; '
        'status=${error.statusCode}; cause=${error.cause}',
      );
    } else {
      stderr.writeln('Inspection failed: ${error.runtimeType}');
    }
    exitCode = 1;
  } finally {
    chat.stop();
    await errorSubscription.cancel();
  }
}

class _InspectionSummary {
  var batches = 0;
  var messages = 0;
  var imageVariants = 0;
  final messageKinds = <String, int>{};
  final actionTypes = <String, int>{};
  final rendererTypes = <String, int>{};
  final imageSchemes = <String, int>{};
  final pollingIntervalsMs = <int>{};
  var emptyAuthorNames = 0;
  var singleWordAuthorNames = 0;
  var multiWordAuthorNames = 0;
  var handleStyleAuthorNames = 0;

  void add(LiveChatBatch batch) {
    batches++;
    messages += batch.messages.length;
    pollingIntervalsMs.add(batch.pollingInterval.inMilliseconds);
    for (final event in batch.events) {
      _increment(actionTypes, event.actionType);
      _increment(rendererTypes, event.rendererType);
    }
    for (final message in batch.messages) {
      _increment(messageKinds, message.kind.name);
      final authorName = message.author.name.trim();
      if (authorName.isEmpty) {
        emptyAuthorNames++;
      } else {
        if (authorName.startsWith('@')) handleStyleAuthorNames++;
        if (authorName.split(RegExp(r'\s+')).length > 1) {
          multiWordAuthorNames++;
        } else {
          singleWordAuthorNames++;
        }
      }
      _addImage(message.author.thumbnail);
      for (final badge in message.author.badges) {
        _addImage(badge.thumbnail);
      }
      _addImage(message.superChat?.sticker);
      for (final part in message.message) {
        final emoji = part.emoji;
        if (emoji != null) _addUrl(emoji.url);
      }
    }
  }

  void _addImage(ImageItem? image) {
    if (image == null) return;
    imageVariants += image.variants.length;
    for (final variant in image.variants) {
      _addUrl(variant.url);
    }
  }

  void _addUrl(String value) {
    final scheme = Uri.tryParse(value)?.scheme ?? 'invalid';
    _increment(imageSchemes, scheme.isEmpty ? 'missing' : scheme);
  }

  Map<String, Object> toJson() => {
        'batches': batches,
        'messages': messages,
        'messageKinds': messageKinds,
        'secondaryActionTypes': actionTypes,
        'secondaryRendererTypes': rendererTypes,
        'imageVariants': imageVariants,
        'imageSchemes': imageSchemes,
        'pollingIntervalsMs': pollingIntervalsMs.toList()..sort(),
        'authorNameShape': {
          'empty': emptyAuthorNames,
          'singleWord': singleWordAuthorNames,
          'multipleWords': multiWordAuthorNames,
          'startsWithAt': handleStyleAuthorNames,
        },
      };
}

void _increment(Map<String, int> counts, String key) {
  if (key.isEmpty) return;
  counts.update(key, (value) => value + 1, ifAbsent: () => 1);
}
