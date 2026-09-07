# dart_youtube_chat

Anonymous, dependency-injectable YouTube live-chat and live-metadata client for
Dart. It uses the same logged-out InnerTube responses available to a browser;
OAuth, cookies, API-console credentials, and a YouTube account are not required.

> InnerTube is undocumented and may change without notice. This package keeps
> unknown payloads intact and treats polling errors as recoverable, but callers
> should still surface connection health to users.

## Scope

The package intentionally consumes only two InnerTube endpoints:

| Endpoint | Purpose |
| --- | --- |
| `live_chat/get_live_chat` | Messages, authors, emoji, badges, purchases, memberships, moderation events, banners, notices, tickers, and continuations. |
| `updated_metadata` | Viewership, live state, title, date, description, like-count entities, and continuations. |

It does not sign users in, send messages, vote, purchase, or execute moderation
commands. Buttons, menus, tracking values, and endpoint parameters are exposed
only as read-only data.

## Highlights

- Resolves a live stream from a handle, channel ID, video ID, or supported URL.
- One shared session for chat and metadata, with only one `/live` page request.
- Serialized polling that follows each endpoint's continuation and interval.
- Capped exponential retry backoff; repeated invalid chat continuations trigger
  anonymous live-page rediscovery, while stale metadata tokens reset safely.
- Message-ID deduplication with bounded memory.
- Typed text, custom emoji, memberships, Super Chats, and paid stickers.
- Optional channel-specific BetterTTV, FrankerFaceZ, and 7TV emotes whenever
  the live page exposes the broadcaster's channel ID directly.
- Typed deletion, banner, ticker, notice, poll, tooltip, and gift events.
- Full image variant lists, dimensions, HTTPS normalization, and size selection.
- Incremental metadata batches plus an accumulated metadata snapshot.
- Lossless `raw` payloads for known and future response fields.
- Injectable `http.Client`, locale, timeout, and typed request failures.
- Non-fatal error streams and idempotent resource cleanup.

## Install

```yaml
dependencies:
  dart_youtube_chat: ^0.6.0
```

```sh
dart pub get
```

## Recommended usage: one live session

`YoutubeLiveSession` resolves the live page once and then drives chat and
metadata independently. Subscribe before `start()` so the first poll cannot be
missed.

```dart
import 'package:dart_youtube_chat/dart_youtube_chat.dart';

final session = YoutubeLiveSession(
  id: YoutubeId.parse('https://youtube.com/@channel/live'),
);

session.messages.listen((message) {
  final text = message.message.map((part) {
    return part.isEmoji ? part.emoji!.emojiText : part.text;
  }).join();
  print('${message.author.name}: $text');
});

session.events.listen((event) {
  switch (event.kind) {
    case LiveChatEventKind.messageDeleted:
      print('Deleted: ${event.targetItemId}');
    case LiveChatEventKind.authorMessagesDeleted:
      print('Author cleared: ${event.authorChannelId}');
    default:
      print('${event.actionType}/${event.rendererType}');
  }
});

session.metadataStates.listen((state) {
  print('Viewers: ${state.viewership?.originalViewCountValue}');
  print('Title: ${state.title?.text}');
});

session.chatErrors.listen((error) => print('Chat error: $error'));
session.metadataErrors.listen((error) => print('Metadata error: $error'));
await session.start();
session.stop();
```

The session exposes `messages`, `events`, `chatBatches`, `metadataBatches`,
`metadataStates`, `chatErrors`, `metadataErrors`, `errors`, `chatPolls`, and
`metadataPolls`. The combined `errors` stream is convenient for diagnostics;
the source-specific streams let an application keep chat connected when only a
metadata refresh fails. `stop()` is idempotent. A stopped session cannot be
restarted; create a new session for a new connection.

## Identifiers and URLs

Use `YoutubeId.tryParse` for user input and `YoutubeId.parse` when invalid input
should throw a `FormatException`.

```dart
YoutubeId.tryParse('@channel');
YoutubeId.tryParse('UCxxxxxxxxxxxxxxxxxxxxxx');
YoutubeId.tryParse('dQw4w9WgXcQ');
YoutubeId.tryParse('https://youtu.be/dQw4w9WgXcQ');
YoutubeId.tryParse('https://www.youtube.com/watch?v=dQw4w9WgXcQ');
```

Only recognized YouTube hosts are accepted. A foreign URL containing a `v`
query parameter is rejected.

Use `YoutubeId.tryParseVideoUrl` when a workflow specifically requires an
explicit video/live URL rather than a handle, channel URL, or bare video ID.

## Chat data and images

`ChatItem` contains the message ID, renderer kind, microsecond timestamp,
author channel ID, author name and photo variants, all membership badges, role
flags, structured text/emoji parts, purchase data, and the complete renderer in
`raw`.

Choose an image based on its actual display size instead of downloading the
largest thumbnail:

```dart
final avatar = message.author.thumbnail?.bestFor(32, pixelRatio: 2);
final emoji = message.message
    .where((part) => part.isEmoji)
    .first
    .emoji!
    .bestFor(18, pixelRatio: 2);
```

`Author.allBadges` provides the complete visual badge list while preserving the
legacy single `badge` field. Image URLs from YouTube CDN hosts are normalized to
HTTPS.

## Events

Anything that is not a normal display message is emitted through `events`.
Known commands receive a `LiveChatEventKind` and typed target fields:

| Kind | Useful fields |
| --- | --- |
| `messageDeleted` | `targetItemId`, `text` |
| `authorMessagesDeleted` | `authorChannelId` |
| `chatItemReplaced` | `targetItemId` |
| `bannerAdded`, `bannerRemoved` | `id`, `targetActionId`, `text` |
| `tickerAdded`, `tickerRemoved` | `id`, `targetItemId`, `duration` |
| `viewerNotice` | `id`, `text`, `buttons`, `menuActions` |
| `membershipGiftPurchased` | `id`, `authorChannelId`, `authorName`, `authorThumbnail`, `timestamp`, `giftMembershipCount`, `text` |
| `membershipGiftReceived` | `id`, `authorChannelId`, `authorName`, `authorThumbnail`, `timestamp`, `text` |
| `pollUpdated`, `tooltip` | `id`, `text` |
| `unknown` | `actionType`, `rendererType`, `raw` |

`buttons` and `menuActions` are `LiveChatAction` values. They retain labels,
icons, accessibility text, endpoint names, and raw parameters, but the package
never executes them. Normal `ChatItem` values expose the same read-only lists.

## Live metadata

YouTube sends metadata incrementally. A first batch often contains title, date,
description, viewership, and likes; later batches may contain only viewership.
Use `metadataBatches` when every source delta matters and `metadataStates` for a
ready-to-display accumulated snapshot.

```dart
session.metadataBatches.listen((batch) {
  print(batch.actions.map((action) => action.actionName));
});

session.metadataStates.listen((state) {
  print(state.viewership?.isLive);
  print(state.viewership?.originalViewCountValue);
  print(state.likeCount?.likeCountIfIndifferentNumber);
});
```

Every metadata model implements `toJson()` by returning its preserved source
shape. Unknown actions remain available with
`UpdatedMetadataActionType.unknown`.

## Low-level requests and separate pollers

For one-shot requests or deterministic tests, inject an HTTP client:

```dart
final youtube = YoutubeHttpClient(
  client: myHttpClient,
  requestTimeout: const Duration(seconds: 10),
  context: const YoutubeClientContext(
    languageCode: 'es',
    regionCode: 'MX',
  ),
);

final options = await youtube.fetchLivePage(YoutubeId.parse('@channel'));
final chatBatch = await youtube.fetchChatBatch(options);
final metadataBatch = await youtube.fetchUpdatedMetadata(options);
youtube.close();
```

`LiveChat` and `UpdatedMetadata` remain available as separate pollers.
`LiveChat.fromOptions` accepts already-resolved `FetchOptions` to avoid another
live-page request.

## Errors and lifecycle

Network operations throw `YoutubeRequestException` with one of `network`,
`timeout`, `http` (with `statusCode`), or `malformedResponse`. Response bodies,
API keys, continuation values, and user content are not placed in exception
strings. Pollers emit transient failures on `errors` and continue using a safe
delay. Initial live-page resolution fails `start()` so the caller can retry or
show a connection error.

When an external `http.Client` or `YoutubeHttpClient` is injected, ownership
stays with the caller. Internally created clients are closed by the owning
session or poller.

## Forward compatibility and privacy

Malformed list entries are skipped instead of invalidating a complete batch.
Unknown renderers become `LiveChatEventKind.unknown`; the full chat response is
available through `LiveChatBatch.raw`/`toJson()`. Metadata batches follow the
same lossless strategy.

Raw payloads may contain opaque tracking, endpoint, visitor, and continuation
values. Do not log or publish them. The included inspectors report aggregate
schema information without printing chat text, author names, API keys, or
continuation tokens:

```sh
dart run bin/inspect_live_chat.dart "@channel" 5
dart run bin/inspect_updated_metadata.dart "@channel"
```

## Development

```sh
dart pub get
dart format --output=none --set-exit-if-changed .
dart analyze
dart test
```

Tests cover parsing, lossless serialization, malformed/future renderers,
polling intervals, continuation rotation, deduplication, timeouts, recovery,
resource ownership, session sharing, and stream closure without requiring a
live network connection.
