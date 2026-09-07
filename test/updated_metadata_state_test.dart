import 'package:dart_youtube_chat/dart_youtube_chat.dart';
import 'package:test/test.dart';

void main() {
  test('accumulates sparse metadata batches without erasing prior values', () {
    final initial = UpdatedMetadataBatch.fromJson({
      'actions': [
        {
          'updateTitleAction': {
            'title': {'simpleText': 'Live title'},
          },
        },
        {
          'updateViewershipAction': {
            'viewCount': {
              'videoViewCountRenderer': {
                'viewCount': {'simpleText': '100 watching'},
                'originalViewCount': '100',
                'isLive': true,
              },
            },
          },
        },
      ],
    });
    final sparse = UpdatedMetadataBatch.fromJson({
      'actions': [
        {
          'updateDateTextAction': {
            'dateText': {'simpleText': 'Streamed live now'},
          },
        },
      ],
      'frameworkUpdates': {
        'entityBatchUpdate': {
          'mutations': [
            {
              'entityKey': 'like-key',
              'type': 'ENTITY_MUTATION_TYPE_REPLACE',
              'payload': {
                'likeCountEntity': {
                  'key': 'like-key',
                  'likeCountIfIndifferentNumber': '12',
                },
              },
            },
          ],
        },
      },
    });

    final state = const UpdatedMetadataState().apply(initial).apply(sparse);

    expect(state.title?.text, 'Live title');
    expect(state.viewership?.originalViewCountValue, 100);
    expect(state.dateText?.text, 'Streamed live now');
    expect(state.likeCount?.likeCountIfIndifferentNumber, '12');
    expect(state.lastBatch, same(sparse));
  });

  test('unknown metadata actions remain lossless in their source batch', () {
    final json = {
      'actions': [
        {
          'futureMetadataAction': {'newValue': 42},
        },
      ],
    };
    final batch = UpdatedMetadataBatch.fromJson(json);
    final state = const UpdatedMetadataState().apply(batch);

    expect(batch.actions.single.type, UpdatedMetadataActionType.unknown);
    expect(batch.toJson(), equals(json));
    expect(state.lastBatch?.toJson(), equals(json));
  });
}
