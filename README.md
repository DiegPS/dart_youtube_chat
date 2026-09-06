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

`LiveChatEvent.raw` and `ChatItem.raw` intentionally expose unrecognized
YouTube fields for forward-compatible integrations. They may contain tracking
or continuation values; applications should not log them directly.

## Live schema inspection

The included inspector reports only aggregate schema information and never
prints chat text, user names, API keys, or continuation tokens:

```shell
dart run bin/inspect_live_chat.dart "@channel" 5
```

InnerTube is an undocumented YouTube interface and can change without notice.
