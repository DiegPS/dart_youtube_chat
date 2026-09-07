import 'package:dart_youtube_chat/dart_youtube_chat.dart';
import 'package:test/test.dart';

void main() {
  group('YoutubeId.tryParse', () {
    test('accepts handles, channel ids, video ids and YouTube URLs', () {
      expect(YoutubeId.tryParse('@channel')?.handle, '@channel');
      expect(YoutubeId.tryParse('UC1234567890123456789012')?.channelId,
          'UC1234567890123456789012');
      expect(YoutubeId.tryParse('dQw4w9WgXcQ')?.liveId, 'dQw4w9WgXcQ');
      expect(
        YoutubeId.tryParse('https://www.youtube.com/watch?v=dQw4w9WgXcQ')
            ?.liveId,
        'dQw4w9WgXcQ',
      );
      expect(
        YoutubeId.tryParse('https://youtu.be/dQw4w9WgXcQ')?.liveId,
        'dQw4w9WgXcQ',
      );
      expect(
        YoutubeId.tryParse('https://youtube.com/@channel/live')?.handle,
        '@channel',
      );
    });

    test('rejects foreign hosts and malformed identifiers', () {
      expect(
        YoutubeId.tryParse('https://evil.test/watch?v=dQw4w9WgXcQ'),
        isNull,
      );
      expect(YoutubeId.tryParse('not a valid id'), isNull);
      expect(YoutubeId.tryParse(''), isNull);
    });

    test('parse throws a FormatException for invalid input', () {
      expect(() => YoutubeId.parse('invalid input'), throwsFormatException);
    });

    test('tryParseVideoUrl accepts only explicit video URLs', () {
      expect(
        YoutubeId.tryParseVideoUrl(
          'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
        )?.liveId,
        'dQw4w9WgXcQ',
      );
      expect(
        YoutubeId.tryParseVideoUrl('https://youtu.be/dQw4w9WgXcQ')?.liveId,
        'dQw4w9WgXcQ',
      );
      expect(YoutubeId.tryParseVideoUrl('dQw4w9WgXcQ'), isNull);
      expect(
        YoutubeId.tryParseVideoUrl('https://youtube.com/@channel'),
        isNull,
      );
      expect(
        YoutubeId.tryParseVideoUrl(
          'https://example.com/watch?v=dQw4w9WgXcQ',
        ),
        isNull,
      );
    });
  });
}
