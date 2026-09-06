/// Anonymous YouTube live chat client for Dart.
/// Polls the YouTube InnerTube API — no OAuth required.
library dart_youtube_chat;

export 'src/live_chat.dart' show LiveChat;
export 'src/updated_metadata.dart' show UpdatedMetadata;
export 'src/parser.dart'
    show
        getOptionsFromLivePage,
        parseChatBatch,
        parseChatData,
        convertColorToHex6,
        normalizeYoutubeImageUrl;
export 'src/requests.dart'
    show
        YoutubeHttpClient,
        YoutubeRequestFailure,
        YoutubeRequestException,
        fetchChat,
        fetchLivePage;
export 'src/types/data.dart'
    show
        Author,
        Badge,
        ChatItem,
        ChatItemKind,
        EmojiItem,
        FetchOptions,
        ImageItem,
        ImageVariant,
        LiveChatBatch,
        LiveChatEvent,
        MessageItem,
        SuperChat,
        YoutubeId;
export 'src/types/updated_metadata.dart';
