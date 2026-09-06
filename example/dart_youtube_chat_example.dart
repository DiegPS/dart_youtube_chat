import 'package:dart_youtube_chat/dart_youtube_chat.dart';

Future<void> main() async {
  final chat = LiveChat(
    id: const YoutubeId(handle: '@channel'),
  );
  chat.messages.listen((item) {
    final text = item.message
        .map((part) => part.isEmoji ? part.emoji!.emojiText : part.text)
        .join();
    print('${item.author.name}: $text');
  });
  chat.events.listen((event) {
    print('YouTube event: ${event.actionType}/${event.rendererType}');
  });
  chat.errors.listen((error) => print('Non-fatal chat error: $error'));

  await chat.start();
}
