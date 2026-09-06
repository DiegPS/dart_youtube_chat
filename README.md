# dart_youtube_chat

Anonymous, dependency-injectable YouTube live-chat client for Dart. It resolves
a live stream from a channel ID, video ID, or handle and polls YouTube's public
InnerTube chat response without OAuth.

## Features

- Serialized polling that follows YouTube's requested interval.
- Message-ID deduplication and non-fatal error streams.
- Text, emoji, memberships, paid messages, and paid stickers.
- Every image variant with dimensions and normalized HTTPS URLs.
- Multiple author badges.
- Secondary banner, ticker, notice, and unknown events with their raw payload.
- Complete live metadata updates, including viewership and like-count entities.
- Injectable `http.Client`, request timeouts, and typed failures.

## Usage

```dart
final chat = LiveChat(
  id: const YoutubeId(handle: '@channel'),
);

chat.messages.listen((message) {
  print('${message.author.name}: ${message.message.length} parts');
});
chat.events.listen((event) {
  print('${event.actionType}/${event.rendererType}');
});
chat.errors.listen(print);

await chat.start();
// Later:
chat.stop();
```

For a single request or deterministic tests, inject a client:

```dart
final youtube = YoutubeHttpClient(
  client: myHttpClient,
  requestTimeout: const Duration(seconds: 10),
);
final options = await youtube.fetchLivePage(
  const YoutubeId(liveId: 'video-id'),
);
final batch = await youtube.fetchChatBatch(options);
youtube.close();
```

## Updated live metadata

Fetch one anonymous metadata update with the same options resolved from the
live page:

```dart
final youtube = YoutubeHttpClient();
final options = await youtube.fetchLivePage(
  const YoutubeId(handle: '@channel'),
);
final update = await youtube.fetchUpdatedMetadata(options);

print(update.viewership?.originalViewCountValue);
print(update.viewership?.isLive);
print(update.title?.text);
youtube.close();
```

Or follow YouTube's continuation token and recommended polling interval:

```dart
final metadata = UpdatedMetadata(options: options);
metadata.batches.listen((update) {
  print(update.viewership?.originalViewCountValue);
});
metadata.errors.listen(print);
metadata.start();
// Later:
metadata.stop();
```

Metadata responses are incremental: title, date, and description may appear in
the first batch while later batches contain only viewership changes. Every
typed model also exposes `raw` and `toJson()` so unknown fields remain intact.

`LiveChatEvent.raw` and `ChatItem.raw` intentionally expose unrecognized
YouTube fields for forward-compatible integrations. They may contain tracking
or continuation values; applications should not log them directly.

## Live schema inspection

The included inspector reports only aggregate schema information and never
prints chat text, user names, API keys, or continuation tokens:

```shell
dart run bin/inspect_live_chat.dart "@channel" 5
dart run bin/inspect_updated_metadata.dart "@channel"
```

InnerTube is an undocumented YouTube interface and can change without notice.
