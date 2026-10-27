import 'dart:async';
import 'dart:typed_data';

import 'core.g.dart';
import 'api.dart';
import 'snapshots.dart';
import 'user_ref.dart';
import 'conversation_ref.dart';

export 'core.g.dart'
    show
        ApiUrlOptions,
        GenericFileMetadata,
        ImageFileMetadata,
        VideoFileMetadata,
        AudioFileMetadata,
        VoiceRecordingFileMetadata;

final Finalizer<int> _conversationListSubscriptionFinalizer = Finalizer((
  handle,
) async {
  await hostApi?.conversationListSubscriptionDeleteHandle(handle);
});

/// A subscription to your most recently active conversations.
///
/// @remarks
/// Get a ConversationListSubscription by calling [TalkSession.subscribeConversations].
///
/// The subscription is 'windowed'. Initially, this window contains the 20 most recent conversations.
/// Conversations are ordered by last activity. The last activity of a conversation is either `joinedAt` or `lastMessage.createdAt`, whichever is higher.
///
/// The window will automatically expand to include any conversations you join, and any old conversations that receive new messages after subscribing.
///
/// You can expand this window by calling [ConversationListSubscription.loadMore], which extends the window further into the past.
///
/// Remember to `.unsubscribe` the subscription once you are done with it.
///
/// @public
class ConversationListSubscription {
  final CoreHostApi _api;
  final int _handle;

  // I have no idea on how to port state
  //SubscriptionState state;

  /// Resolves when the subscription starts receiving updates from the server.
  ///
  /// @remarks
  /// Wait for this promise if you want to perform some action as soon as the subscription is active.
  ///
  /// The promise rejects if the subscription is terminated before it connects.
  final Future<void> connected;

  /// Resolves when the subscription permanently stops receiving updates from the server.
  ///
  /// @remarks
  /// This is either because you unsubscribed or because the subscription encountered an unrecoverable error.
  final Future<void> terminated;

  /// Expand the window to include older conversations
  ///
  /// @remarks
  /// Calling `loadMore` multiple times in parallel will still only load one page of conversations.
  ///
  /// Avoid calling `.loadMore` in a loop until you have loaded all conversations.
  /// This is usually unnecessary: any time a conversation receives a message, it appears at the start of the list of conversations.
  /// If you do need to call loadMore in a loop, make sure you set a small upper bound (e.g. 100) on the number of conversations, where the loop will exit.
  ///
  /// @param count - The number of additional conversations to load. Must be between 1 and 30. Default 20.
  Future<void> loadMore([int? count]) {
    return _api.conversationListSubscriptionLoadMore(_handle, count);
  }

  /// Unsubscribe from this resource and stop receiving updates.
  ///
  /// @remarks
  /// If the subscription is already in the [UnsubscribedState] or [ErrorState], this is a no-op.
  Future<void> unsubscribe() {
    conversationListSubscriptionOnSnapshots.remove(_handle);

    return _api.conversationListSubscriptionUnsubscribe(_handle);
  }

  ConversationListSubscription._({
    required CoreHostApi api,
    required int handle,
    required this.connected,
    required this.terminated,
  }) : _api = api,
       _handle = handle;
}

final Finalizer<int> _sessionOnErrorFinalizer = Finalizer((handle) async {
  await hostApi?.sessionOnErrorDeleteHandle(handle);
});

class ErrorSubscription {
  final CoreHostApi _api;
  final int _handle;

  Future<void> unsubscribe() {
    sessionOnErrorExceptions.remove(_handle);

    return _api.sessionOnErrorUnsubscribe(_handle);
  }

  ErrorSubscription._({required CoreHostApi api, required int handle})
    : _api = api,
      _handle = handle;
}

final Finalizer<int> _sessionFinalizer = Finalizer((handle) async {
  await hostApi?.sessionDeleteHandle(handle);
});

class TalkSession {
  final CoreHostApi _api;
  final int _handle;

  /// The unique TalkJS ID that you passed when calling [getTalkSession]
  final String appId;

  /// A reference to the user this session is connected as
  ///
  /// @remarks
  /// This is immutable. If you want to connect as a different user,
  /// call [getTalkSession] again to get a new session.
  ///
  /// Equivalent to calling [TalkSession.user] with the current user's ID.
  ///
  /// @see [TalkSession.user] which lets you get a reference to any user.
  final UserRef currentUser;

  /// Get a reference to a user
  ///
  /// @param id - The ID of the user that you want to reference
  /// @return A [UserRef] for the user with that ID
  /// @public
  Future<UserRef> user(String id) async {
    final handle = await _api.sessionUser(_handle, id);

    return makeUserRef(api: _api, handle: handle, id: id);
  }

  /// Get a reference to a conversation
  ///
  /// @param id - The ID of the conversation that you want to reference
  /// @return A [ConversationRef] for the conversation with that ID
  /// @public
  Future<ConversationRef> conversation(String id) async {
    final handle = await _api.sessionConversation(_handle, id);

    return makeConversationRef(api: _api, handle: handle, id: id);
  }

  /// Subscribes to the most recently active conversations for the current user
  ConversationListSubscription subscribeConversations(
    void Function(List<ConversationSnapshot> snapshot, bool loadedAll)
    onSnapshot,
  ) {
    final subscriptionHandle = nextId;
    nextId += 1;

    _api.sessionSubscribeConversations(_handle, subscriptionHandle);

    conversationListSubscriptionOnSnapshots[subscriptionHandle] = onSnapshot;

    final connectedCompleter = Completer<void>();
    final terminatedCompleter = Completer<void>();
    conversationListSubscriptionConnectedCompleters[subscriptionHandle] =
        connectedCompleter;
    conversationListSubscriptionTerminatedCompleters[subscriptionHandle] =
        terminatedCompleter;

    final subscription = ConversationListSubscription._(
      api: _api,
      handle: subscriptionHandle,
      connected: connectedCompleter.future,
      terminated: terminatedCompleter.future,
    );

    _conversationListSubscriptionFinalizer.attach(
      subscription,
      subscriptionHandle,
    );

    return subscription;
  }

  /// Attaches a handler that will be called when the session encounters an error
  ///
  /// Returns a callback which detaches your handler
  ErrorSubscription onError(void Function(Exception error) handler) {
    final subscriptionHandle = nextId;
    nextId += 1;

    _api.sessionOnError(_handle, subscriptionHandle);

    sessionOnErrorExceptions[subscriptionHandle] = handler;

    final subscription = ErrorSubscription._(
      api: _api,
      handle: subscriptionHandle,
    );

    _sessionOnErrorFinalizer.attach(subscription, subscriptionHandle);

    return subscription;
  }

  /// Upload a generic file without any additional metadata.
  ///
  /// @remarks
  /// This function does not send any message, it only uploads the file and returns a file token.
  /// To send the file in a message, pass the file token in a [SendFileBlock] when calling [ConversationRef.send].
  ///
  /// [See the documentation](https://talkjs.com/docs/Reference/Concepts/Message_Content/#sending-message-content) for more information about sending files in messages.
  ///
  /// If the file is a video, image, audio file, or voice recording, use one of the other functions like [uploadImage] instead.
  ///
  /// @param bytes The binary file data. Usually a [File](https://developer.mozilla.org/en-US/docs/Web/API/File).
  /// @param metadata Information about the file
  /// @return A file token that can be used to send the file in a message.
  Future<String> uploadFile(Uint8List bytes, GenericFileMetadata metadata) {
    return _api.sessionUploadFile(_handle, bytes, metadata);
  }

  /// Upload an image with image-specific metadata.
  ///
  /// @remarks
  /// This is a variant of [TalkSession.uploadFile] used for images.
  ///
  /// @param bytes The binary image data. Usually a [File](https://developer.mozilla.org/en-US/docs/Web/API/File).
  /// @param metadata Information about the image.
  /// @return A file token that can be used to send the image in a message.
  Future<String> uploadImage(Uint8List bytes, ImageFileMetadata metadata) {
    return _api.sessionUploadImage(_handle, bytes, metadata);
  }

  /// Upload a video with video-specific metadata.
  ///
  /// @remarks
  /// This is a variant of [TalkSession.uploadFile] used for videos.
  ///
  /// @param bytes The binary video data. Usually a [File](https://developer.mozilla.org/en-US/docs/Web/API/File).
  /// @param metadata Information about the video.
  /// @return A file token that can be used to send the video in a message.
  Future<String> uploadVideo(Uint8List bytes, VideoFileMetadata metadata) {
    return _api.sessionUploadVideo(_handle, bytes, metadata);
  }

  /// Upload an audio file with audio-specific metadata.
  ///
  /// @remarks
  /// This is a variant of [TalkSession.uploadFile] used for audio files.
  ///
  /// @param bytes The binary audio data. Usually a [File](https://developer.mozilla.org/en-US/docs/Web/API/File).
  /// @param metadata Information about the audio file.
  /// @return A file token that can be used to send the audio file in a message.
  Future<String> uploadAudio(Uint8List bytes, AudioFileMetadata metadata) {
    return _api.sessionUploadAudio(_handle, bytes, metadata);
  }

  /// Upload a voice recording with voice-specific metadata.
  ///
  /// @remarks
  /// This is a variant of [TalkSession.uploadFile] used for voice recordings.
  ///
  /// @param bytes The binary audio data. Usually a [File](https://developer.mozilla.org/en-US/docs/Web/API/File).
  /// @param metadata Information about the voice recording.
  /// @return A file token that can be used to send the audio file in a message.
  Future<String> uploadVoice(
    Uint8List bytes,
    VoiceRecordingFileMetadata metadata,
  ) {
    return _api.sessionUploadVoice(_handle, bytes, metadata);
  }

  TalkSession._({
    required CoreHostApi api,
    required int handle,
    required this.appId,
    required String userId,
  }) : _api = api,
       _handle = handle,
       currentUser = makeUserRef(
         api: api,
         handle: handle,
         id: userId,
         attachFinalizer: false,
       );
}

/// Returns a TalkSession option for the specified App ID and User ID.
///
/// @param appId - Your app's unique TalkJS ID. Get it from the **Settings** page of the [dashboard](https://talkjs.com/dashboard).
/// @param userId - The `id` of the user you want to connect and act as. Any messages you send will be sent as this user.
/// @param token - A token to authenticate the session with. Ignored if a TalkSession object already exists for this appId + userId.
/// @param forceCreateNew - @suppress
/// If set to true, then `getTalkSession` will bypass the registry and create a new session
/// This option is the only way to have two sessions for the same user with different auth tokens.
///
/// IE it's an undocumented, secret escape hatch for that specific weird niche use case.
/// It *is* designed to be used by customers, but it's undocumented so they'd only find out about it
/// if they contacted live support and we told them about it.
/// @param signature - @suppress
/// @param apiUrls - @suppress
/// @param host - @suppress
///
/// note: it makes little sense to have both `host` and `apiUrls`. I intend to
/// remove `apiUrls` in the future in favour of just `host`.
/// @param clientBuild - @suppress
///
/// @remarks
/// Backed by a registry, so calling this function twice with the same app and user returns the same session object both times.
/// A new session will be created if the old one encountered an error or got garbage collected.
///
/// The `token` and `tokenFetcher` properties are ignored if there is already a session for that user in the registry.
Future<TalkSession> getTalkSession({
  required String appId,
  required String userId,
  String? token,
  bool forceCreateNew = false,
  String? signature,
  ApiUrlOptions? apiUrls,
  String? host,
  String? clientBuild,
}) async {
  if (hostApi == null) {
    hostApi = CoreHostApi();
    CoreFlutterApi.setUp(CoreFlutterApiImplementation());
  }

  final handle = await hostApi!.getTalkSession(
    appId,
    userId,
    token,
    forceCreateNew,
    signature,
    apiUrls,
    host,
    clientBuild,
  );
  final session = TalkSession._(
    api: hostApi!,
    handle: handle,
    appId: appId,
    userId: userId,
  );

  _sessionFinalizer.attach(session, handle);

  return session;
}
