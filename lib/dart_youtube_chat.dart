/// Anonymous YouTube live chat client for Dart.
/// Polls the YouTube InnerTube API — no OAuth required.
library dart_youtube_chat;

export 'src/live_chat.dart' show LiveChat;
export 'src/parser.dart' show getOptionsFromLivePage, parseChatData, convertColorToHex6;
export 'src/requests.dart' show fetchChat, fetchLivePage;
export 'src/types/data.dart'
    show
        Author,
        Badge,
        ChatItem,
        EmojiItem,
        FetchOptions,
        ImageItem,
        MessageItem,
        SuperChat,
        YoutubeId;
