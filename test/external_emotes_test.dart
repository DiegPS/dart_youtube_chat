import 'package:dart_youtube_chat/dart_youtube_chat.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

void main() {
  test('loads BTTV, FFZ and 7TV YouTube channel emotes by channel ID',
      () async {
    final requested = <Uri>[];
    final loader = YoutubeExternalEmoteLoader(
      httpClient: MockClient((request) async {
        requested.add(request.url);
        return switch (request.url.host) {
          'api.betterttv.net' => http.Response(
              '{"channelEmotes":[{"id":"b","code":"BttvYT"}],'
              '"sharedEmotes":[]}',
              200,
            ),
          'api.frankerfacez.com' => http.Response(
              '{"sets":{"1":{"emoticons":[{"name":"FfzYT",'
              '"urls":{"1":"//ffz/youtube"}}]}}}',
              200,
            ),
          _ => http.Response(
              '{"emote_set":{"emotes":[{"id":"s","name":"SevenYT"}]}}',
              200,
            ),
        };
      }),
    );

    final emotes = await loader.load('UC123');

    expect(emotes.keys, containsAll(['BttvYT', 'FfzYT', 'SevenYT']));
    expect(
        requested.map((uri) => uri.toString()),
        containsAll([
          'https://api.betterttv.net/3/cached/users/youtube/UC123',
          'https://api.frankerfacez.com/v1/room/yt/UC123',
          'https://7tv.io/v3/users/youtube/UC123',
        ]));
  });

  test('a missing provider does not discard other provider results', () async {
    final loader = YoutubeExternalEmoteLoader(
      httpClient: MockClient((request) async => request.url.host == '7tv.io'
          ? http.Response(
              '{"emote_set":{"emotes":[{"id":"s","name":"Works"}]}}',
              200,
            )
          : http.Response('', 404)),
    );

    expect(await loader.load('UC123'), contains('Works'));
  });

  test('7TV bad request means the YouTube channel has no mapping', () async {
    final errors = <Object>[];
    final loader = YoutubeExternalEmoteLoader(
      httpClient: MockClient((request) async => request.url.host == '7tv.io'
          ? http.Response('no connection', 400)
          : http.Response('', 404)),
    );

    expect(
        await loader.load('UC123', onError: (e, _) => errors.add(e)), isEmpty);
    expect(errors, isEmpty);
  });

  test('replaces only complete text tokens and preserves native emoji', () {
    const native = EmojiItem(
      url: 'native',
      alt: ':native:',
      emojiText: ':native:',
      isCustomEmoji: true,
    );
    const external = EmojiItem(
      url: 'external',
      alt: 'Wave',
      emojiText: 'Wave',
      isCustomEmoji: true,
    );

    final result = applyYoutubeExternalEmotes(
      const [
        MessageItem.text('Wave WaveSuffix '),
        MessageItem.emoji(native),
      ],
      const {'Wave': external},
    );

    expect(result[0].emoji, same(external));
    expect(result[1].text, ' ');
    expect(result[2].text, 'WaveSuffix');
    expect(result[4].emoji, same(native));
  });
}
