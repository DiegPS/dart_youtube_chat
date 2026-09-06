import 'package:dart_youtube_chat/dart_youtube_chat.dart';
import 'package:test/test.dart';

void main() {
  group('YoutubeId', () {
    test('defaults every identifier to empty', () {
      const id = YoutubeId();
      expect((id.channelId, id.liveId, id.handle), ('', '', ''));
    });

    test('preserves all supplied identifiers', () {
      const id = YoutubeId(channelId: 'c', liveId: 'l', handle: '@h');
      expect((id.channelId, id.liveId, id.handle), ('c', 'l', '@h'));
    });
  });

  group('FetchOptions', () {
    const options = FetchOptions(
      apiKey: 'key',
      clientVersion: 'version',
      continuation: 'first',
      liveId: 'live',
    );

    test('copyWith replaces only the continuation', () {
      final copy = options.copyWith(continuation: 'second');
      expect(copy.apiKey, 'key');
      expect(copy.clientVersion, 'version');
      expect(copy.continuation, 'second');
      expect(copy.liveId, 'live');
    });

    test('copyWith keeps continuation when omitted', () {
      expect(options.copyWith().continuation, 'first');
    });
  });

  group('Image models', () {
    const variants = [
      ImageVariant(url: 'small', width: 16, height: 10),
      ImageVariant(url: 'medium', width: 32, height: 32),
      ImageVariant(url: 'large', width: 128, height: 64),
    ];
    const image = ImageItem(
      url: 'fallback',
      alt: 'avatar',
      width: 8,
      height: 8,
      variants: variants,
    );

    test('longestSide uses width for landscape image', () {
      expect(variants.last.longestSide, 128);
    });

    test('longestSide uses height for portrait image', () {
      const portrait = ImageVariant(url: 'p', width: 12, height: 40);
      expect(portrait.longestSide, 40);
    });

    test('bestFor chooses smallest sufficient variant', () {
      expect(image.bestFor(15).url, 'small');
      expect(image.bestFor(17).url, 'medium');
    });

    test('bestFor accounts for device pixel ratio', () {
      expect(image.bestFor(20, pixelRatio: 2).url, 'large');
    });

    test('bestFor chooses largest when target is unavailable', () {
      expect(image.bestFor(500).url, 'large');
    });

    test('bestFor uses primary image when variants are absent', () {
      const single = ImageItem(
        url: 'only',
        alt: 'only',
        width: 24,
        height: 24,
      );
      expect(single.bestFor(12).url, 'only');
    });

    test('bestFor does not mutate variant ordering', () {
      image.bestFor(20);
      expect(image.variants.map((variant) => variant.url),
          ['small', 'medium', 'large']);
    });
  });

  group('Message models', () {
    test('text run is not an emoji', () {
      const item = MessageItem.text('hello');
      expect(item.text, 'hello');
      expect(item.emoji, isNull);
      expect(item.isEmoji, isFalse);
    });

    test('emoji run contains no duplicate text', () {
      const emoji = EmojiItem(
        url: 'emoji',
        alt: ':wave:',
        emojiText: ':wave:',
        isCustomEmoji: true,
      );
      const item = MessageItem.emoji(emoji);
      expect(item.text, isEmpty);
      expect(item.emoji, same(emoji));
      expect(item.isEmoji, isTrue);
    });

    test('author supports legacy primary badge and complete badge list', () {
      const thumbnail = ImageItem(url: 'badge', alt: 'member');
      const badge = Badge(thumbnail: thumbnail, label: 'Member');
      const author = Author(
        name: 'Ada',
        channelId: 'channel',
        badge: badge,
        badges: [badge],
      );
      expect(author.badge, same(badge));
      expect(author.badges, [badge]);
    });
  });
}
