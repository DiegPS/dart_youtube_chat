import 'package:dart_youtube_chat/dart_youtube_chat.dart';
import 'package:test/test.dart';

void main() {
  group('parser', () {
    test('convertColorToHex6 strips alpha correctly', () {
      // 0xFF1DE9B6 = 4282282422 → #1DE9B6
      expect(convertColorToHex6(0xFF1DE9B6), equals('#1DE9B6'));
      // 0xFFE91E63 → #E91E63
      expect(convertColorToHex6(0xFFE91E63), equals('#E91E63'));
    });

    test('getOptionsFromLivePage throws on replay', () {
      const fakeHtml = '''
        <link rel="canonical" href="https://www.youtube.com/watch?v=abc123">
        "INNERTUBE_API_KEY": "AIzaFake"
        "clientVersion": "2.20240101.00.00"
        "continuation": "cont_token_xyz"
        "isReplay": true
      ''';
      expect(
        () => getOptionsFromLivePage(fakeHtml),
        throwsException,
      );
    });

    test('getOptionsFromLivePage parses valid page', () {
      const fakeHtml = '''
        <link rel="canonical" href="https://www.youtube.com/watch?v=testId123">
        "INNERTUBE_API_KEY": "AIzaTestKey"
        "clientVersion": "2.20240101.00.00"
        "continuation": "cont_token_xyz"
      ''';
      final opts = getOptionsFromLivePage(fakeHtml);
      expect(opts.liveId, equals('testId123'));
      expect(opts.apiKey, equals('AIzaTestKey'));
      expect(opts.clientVersion, equals('2.20240101.00.00'));
      expect(opts.continuation, equals('cont_token_xyz'));
    });

    test('getOptionsFromLivePage exposes the broadcaster channel ID', () {
      const html = '''
        <link rel="canonical" href="https://www.youtube.com/watch?v=testId123">
        "clientVersion": "2.20240101.00.00"
        "continuation": "cont_token_xyz"
        "videoDetails":{"videoId":"abcdefghijk",
        "channelId":"UC1234567890123456789012"}
      ''';
      final options = getOptionsFromLivePage(html);

      expect(options.channelId, 'UC1234567890123456789012');
    });

    test('uses the public microformat external channel ID as fallback', () {
      const html = '''
        <link rel="canonical" href="https://www.youtube.com/watch?v=testId123">
        "clientVersion":"2.20240101.00.00"
        "continuation":"cont_token_xyz"
        "ownerProfileUrl":"http://www.youtube.com/@creator",
        "externalChannelId":"UCabcdefghijklmnopqrstuv"
      ''';

      expect(
        getOptionsFromLivePage(html).channelId,
        'UCabcdefghijklmnopqrstuv',
      );
    });

    test('getOptionsFromLivePage works without INNERTUBE_API_KEY', () {
      const fakeHtml = '''
        <link rel="canonical" href="https://www.youtube.com/watch?v=noKeyId">
        "clientVersion": "2.20240101.00.00"
        "continuation": "cont_token_xyz"
      ''';
      final opts = getOptionsFromLivePage(fakeHtml);
      expect(opts.liveId, equals('noKeyId'));
      expect(opts.apiKey, equals(''));
    });
  });

  group('YoutubeId', () {
    test('accepts handle without @ prefix', () {
      const id = YoutubeId(handle: 'MrBeast');
      expect(id.handle, equals('MrBeast'));
    });
  });
}
