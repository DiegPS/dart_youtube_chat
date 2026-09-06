import 'package:dart_youtube_chat/dart_youtube_chat.dart';
import 'package:test/test.dart';

import 'fixtures/updated_metadata_fixture.dart';

void main() {
  test('models every known updated metadata field', () {
    final batch = UpdatedMetadataBatch.fromJson(updatedMetadataFixture());

    expect(batch.responseContext.visitorData, 'visitor');
    expect(batch.responseContext.responseId, 'response-id');
    expect(batch.responseContext.mainAppWebResponseContext?.loggedOut, isTrue);
    expect(batch.responseContext.serviceTrackingParams.single.service,
        'GFEEDBACK');
    expect(batch.responseContext.serviceTrackingParams.single.params.single.key,
        'logged_in');
    expect(
      batch
          .responseContext.webResponseContextExtensionData?.preloadMessageNames,
      ['likeCountEntity'],
    );
    expect(batch.responseContext.webResponseContextExtensionData?.hasDecorated,
        isTrue);

    expect(batch.continuation.token, 'metadata-next');
    expect(batch.pollingInterval, const Duration(seconds: 5));

    expect(batch.viewership?.viewCount.text, '1,234 watching');
    expect(batch.viewership?.isLive, isTrue);
    expect(batch.viewership?.extraShortViewCount.text, '1.2K');
    expect(batch.viewership?.extraShortViewCount.accessibilityLabel,
        '1,234 watching');
    expect(batch.viewership?.unlabeledViewCountValue.text, '1,234');
    expect(batch.viewership?.originalViewCount, '1234');
    expect(batch.viewership?.originalViewCountValue, 1234);

    expect(batch.dateText?.text, 'Started streaming today');
    expect(batch.title?.text, 'Breaking news');
    expect(batch.description?.text, 'Watch live');
    expect(batch.description?.runs.last.text, 'live');
    expect(batch.description?.runs.last.raw['bold'], isTrue);

    expect(batch.actions.map((action) => action.type), [
      UpdatedMetadataActionType.viewership,
      UpdatedMetadataActionType.dateText,
      UpdatedMetadataActionType.title,
      UpdatedMetadataActionType.description,
      UpdatedMetadataActionType.unknown,
    ]);
    expect(batch.actions.last.actionName, 'futureMetadataAction');

    final entityBatch = batch.frameworkUpdates.entityBatchUpdate!;
    expect(entityBatch.timestamp?.seconds, '1788700000');
    expect(entityBatch.timestamp?.nanos, 123000000);
    final mutation = entityBatch.mutations.single;
    expect(mutation.entityKey, 'like-count');
    expect(mutation.type, 'ENTITY_MUTATION_TYPE_REPLACE');
    final likes = mutation.likeCountEntity!;
    expect(likes.key, 'like-count');
    expect(likes.likeCountIfLiked.content, '101');
    expect(likes.likeCountIfDisliked.content, '99');
    expect(likes.likeCountIfIndifferent.content, '100');
    expect(likes.expandedLikeCountIfLiked.content, '101 likes');
    expect(likes.expandedLikeCountIfDisliked.content, '99 likes');
    expect(likes.expandedLikeCountIfIndifferent.content, '100 likes');
    expect(likes.likeCountLabel.content, '100 likes');
    expect(likes.likeButtonA11yText.content, 'Like this video');
    expect(likes.likeCountIfLikedNumber, '101');
    expect(likes.likeCountIfDislikedNumber, '99');
    expect(likes.likeCountIfIndifferentNumber, '100');
    expect(likes.shouldExpandLikeCount, isFalse);
    expect(likes.sentimentFactoidA11yTextIfLiked.content,
        'You and 100 others liked this video');
    expect(likes.sentimentFactoidA11yTextIfDisliked.content,
        '100 people liked this video');
  });

  test('preserves unknown fields losslessly through raw and toJson', () {
    final source = updatedMetadataFixture();
    final batch = UpdatedMetadataBatch.fromJson(source);

    expect(batch.raw['futureTopLevel'], {'preserved': true});
    expect(batch.actions.last.raw, {
      'futureMetadataAction': {'future': true},
    });
    expect(
        batch.frameworkUpdates.entityBatchUpdate!.mutations.single
            .likeCountEntity!.raw['futureLikeField'],
        'preserved');
    expect(batch.toJson(), source);
  });

  test('handles a sparse incremental response', () {
    final batch = UpdatedMetadataBatch.fromJson({
      'continuation': {
        'timedContinuationData': {
          'continuation': 'next',
          'timeoutMs': 7000,
        },
      },
      'actions': [
        {
          'updateViewershipAction': {
            'viewCount': {
              'videoViewCountRenderer': {
                'viewCount': {'simpleText': '2 watching'},
                'isLive': false,
              },
            },
          },
        },
      ],
    });

    expect(batch.title, isNull);
    expect(batch.description, isNull);
    expect(batch.dateText, isNull);
    expect(batch.viewership?.isLive, isFalse);
    expect(batch.pollingInterval, const Duration(seconds: 7));
    expect(batch.frameworkUpdates.entityBatchUpdate, isNull);
  });

  test('ignores tracking keys when identifying an action', () {
    final batch = UpdatedMetadataBatch.fromJson({
      'actions': [
        {
          'trackingParams': 'opaque',
          'updateTitleAction': {
            'title': {'simpleText': 'Updated title'},
          },
        },
      ],
    });

    expect(batch.actions.single.type, UpdatedMetadataActionType.title);
    expect(batch.title?.text, 'Updated title');
  });

  test('uses a safe polling interval for missing or invalid timing', () {
    expect(
      UpdatedMetadataBatch.fromJson(const {}).pollingInterval,
      const Duration(seconds: 5),
    );
    final invalid = UpdatedMetadataBatch.fromJson({
      'continuation': {
        'timedContinuationData': {
          'continuation': 'next',
          'timeoutMs': -1,
        },
      },
    });
    expect(invalid.pollingInterval, const Duration(seconds: 5));
  });
}
