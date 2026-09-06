Map<String, dynamic> updatedMetadataFixture({
  String continuation = 'metadata-next',
  int timeoutMs = 5000,
}) =>
    {
      'responseContext': {
        'visitorData': 'visitor',
        'serviceTrackingParams': [
          {
            'service': 'GFEEDBACK',
            'params': [
              {'key': 'logged_in', 'value': '0'},
            ],
          },
        ],
        'mainAppWebResponseContext': {'loggedOut': true},
        'responseId': 'response-id',
        'webResponseContextExtensionData': {
          'webResponseContextPreloadData': {
            'preloadMessageNames': ['likeCountEntity'],
          },
          'hasDecorated': true,
        },
      },
      'continuation': {
        'timedContinuationData': {
          'timeoutMs': timeoutMs,
          'continuation': continuation,
        },
      },
      'actions': [
        {
          'updateViewershipAction': {
            'viewCount': {
              'videoViewCountRenderer': {
                'viewCount': {'simpleText': '1,234 watching'},
                'isLive': true,
                'extraShortViewCount': {
                  'accessibility': {
                    'accessibilityData': {'label': '1,234 watching'},
                  },
                  'simpleText': '1.2K',
                },
                'unlabeledViewCountValue': {'simpleText': '1,234'},
                'originalViewCount': '1234',
              },
            },
          },
        },
        {
          'updateDateTextAction': {
            'dateText': {'simpleText': 'Started streaming today'},
          },
        },
        {
          'updateTitleAction': {
            'title': {
              'runs': [
                {'text': 'Breaking news'},
              ],
            },
          },
        },
        {
          'updateDescriptionAction': {
            'description': {
              'runs': [
                {'text': 'Watch '},
                {
                  'text': 'live',
                  'bold': true,
                  'navigationEndpoint': {
                    'urlEndpoint': {'url': 'https://example.test/live'},
                  },
                },
              ],
            },
          },
        },
        {
          'futureMetadataAction': {'future': true},
        },
      ],
      'frameworkUpdates': {
        'entityBatchUpdate': {
          'mutations': [
            {
              'entityKey': 'like-count',
              'type': 'ENTITY_MUTATION_TYPE_REPLACE',
              'payload': {
                'likeCountEntity': {
                  'key': 'like-count',
                  'likeCountIfLiked': {'content': '101'},
                  'likeCountIfDisliked': {'content': '99'},
                  'likeCountIfIndifferent': {'content': '100'},
                  'expandedLikeCountIfLiked': {'content': '101 likes'},
                  'expandedLikeCountIfDisliked': {'content': '99 likes'},
                  'expandedLikeCountIfIndifferent': {'content': '100 likes'},
                  'likeCountLabel': {'content': '100 likes'},
                  'likeButtonA11yText': {'content': 'Like this video'},
                  'likeCountIfLikedNumber': '101',
                  'likeCountIfDislikedNumber': '99',
                  'likeCountIfIndifferentNumber': '100',
                  'shouldExpandLikeCount': false,
                  'sentimentFactoidA11yTextIfLiked': {
                    'content': 'You and 100 others liked this video',
                  },
                  'sentimentFactoidA11yTextIfDisliked': {
                    'content': '100 people liked this video',
                  },
                  'futureLikeField': 'preserved',
                },
              },
            },
          ],
          'timestamp': {'seconds': '1788700000', 'nanos': 123000000},
        },
      },
      'futureTopLevel': {'preserved': true},
    };
