import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/src/core.g.dart',
    dartOptions: DartOptions(),
    kotlinOut:
        'android/src/main/kotlin/com/example/talkjs_core_flutter/Core.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.example.talkjs_core_flutter'),
    swiftOut:
        'ios/talkjs_core_flutter/Sources/talkjs_core_flutter/Core.g.swift',
    swiftOptions: SwiftOptions(),
    dartPackageName: 'talkjs_core_flutter',
  ),
)
// This is used as a return type from the Native side, and contains all the
// data needed to build a MessageRef in Dart.
class MessageRefBuildData {
  int handle;
  String id;
  String conversationId;

  MessageRefBuildData({
    required this.handle,
    required this.id,
    required this.conversationId,
  });
}

class ApiUrlOptions {
  String realtimeWsApiUrl;
  String internalHttpApiUrl;
  String restApiHttpUrl;

  ApiUrlOptions({
    required this.realtimeWsApiUrl,
    required this.internalHttpApiUrl,
    required this.restApiHttpUrl,
  });
}

class GenericFileMetadata {
  /// The name of the file including extension.
  String filename;

  GenericFileMetadata({required this.filename});
}

class ImageFileMetadata {
  /// The name of the file including extension.
  String filename;

  /// The width of the image in pixels, if known.
  int? width;

  /// The height of the image in pixels, if known.
  int? height;

  ImageFileMetadata({required this.filename, this.width, this.height});
}

class VideoFileMetadata {
  /// The name of the file including extension.
  String filename;

  /// The width of the video in pixels, if known.
  int? width;

  /// The height of the video in pixels, if known.
  int? height;

  /// The duration of the video in seconds, if known.
  double? duration;

  VideoFileMetadata({
    required this.filename,
    this.width,
    this.height,
    this.duration,
  });
}

class AudioFileMetadata {
  /// The name of the file including extension.
  String filename;

  /// The duration of the audio file in seconds, if known.
  double? duration;

  AudioFileMetadata({required this.filename, this.duration});
}

class VoiceRecordingFileMetadata {
  /// The name of the file including extension.
  String filename;

  /// The duration of the recording in seconds, if known.
  double? duration;

  VoiceRecordingFileMetadata({required this.filename, this.duration});
}

@HostApi()
abstract class CoreHostApi {
  // Session
  int getTalkSession(
    String appId,
    String userId,
    String? token,
    bool? forceCreateNew,
    String? signature,
    ApiUrlOptions? apiUrls,
    String? host,
    String? clientBuild,
  );
  void sessionDeleteHandle(int handle);
  int sessionUser(int handle, String id);
  int sessionConversation(int handle, String id);
  void sessionSubscribeConversations(int handle, int subscriptionHandle);
  void sessionOnError(int handle, int subscriptionHandle);

  @async
  String sessionUploadFile(
    int handle,
    Uint8List bytes,
    GenericFileMetadata metadata,
  );

  @async
  String sessionUploadImage(
    int handle,
    Uint8List bytes,
    ImageFileMetadata metadata,
  );

  @async
  String sessionUploadVideo(
    int handle,
    Uint8List bytes,
    VideoFileMetadata metadata,
  );

  @async
  String sessionUploadAudio(
    int handle,
    Uint8List bytes,
    AudioFileMetadata metadata,
  );

  @async
  String sessionUploadVoice(
    int handle,
    Uint8List bytes,
    VoiceRecordingFileMetadata metadata,
  );

  // ConversationListSubscription
  void conversationListSubscriptionDeleteHandle(int handle);

  @async
  void conversationListSubscriptionLoadMore(int handle, int? count);

  void conversationListSubscriptionUnsubscribe(int handle);

  // ErrorSubscription
  void sessionOnErrorDeleteHandle(int handle);
  void sessionOnErrorUnsubscribe(int handle);

  // User
  void userDeleteHandle(int handle);

  @async
  String? userGet(int handle);

  @async
  void userSet(
    int handle,
    String? name,
    Map<String, String?>? custom,
    String? locale,
    String? photoUrl,
    String? role,
    String? welcomeMessage,
    List<String>? email,
    List<String>? phone,
    Map<String, bool?>? pushTokens,
  );

  @async
  void userCreateIfNotExists(
    int handle,
    String name,
    Map<String, String>? custom,
    String? locale,
    String? photoUrl,
    String? role,
    String? welcomeMessage,
    List<String>? email,
    List<String>? phone,
    Map<String, bool>? pushTokens,
  );

  @async
  void userDeleteFields(int handle, List<String> fields);

  void userSubscribe(int handle, int subscriptionHandle);
  void userSubscribeOnline(int handle, int subscriptionHandle);

  // UserSubscription
  void userSubscriptionDeleteHandle(int handle);
  void userSubscriptionUnsubscribe(int handle);

  // UserOnlineSubscription
  void userOnlineSubscriptionDeleteHandle(int handle);
  void userOnlineSubscriptionUnsubscribe(int handle);

  // Conversation
  void conversationDeleteHandle(int handle);

  @async
  String? conversationGet(int handle);

  @async
  void conversationSet(
    int handle,
    String? subject,
    String? photoUrl,
    List<String>? welcomeMessages,
    Map<String, String?>? custom,
    String? accessJson,
    String? notifyJson,
  );

  @async
  void conversationCreateIfNotExists(
    int handle,
    String? subject,
    String? photoUrl,
    List<String>? welcomeMessages,
    Map<String, String>? custom,
    String? accessJson,
    String? notifyJson,
  );

  @async
  void conversationDeleteFields(int handle, List<String> fields);

  @async
  void conversationMarkAsRead(int handle);

  @async
  void conversationMarkAsUnread(int handle);

  @async
  void conversationMarkAsTyping(int handle);

  int conversationParticipant(int handle, String user);
  int conversationMessage(int handle, String messageId);

  @async
  MessageRefBuildData conversationSend(
    int handle,
    String text,
    Map<String, String>? custom,
    String? referencedMessage,
  );

  @async
  MessageRefBuildData conversationSendMessage(
    int handle,
    String contentJson,
    Map<String, String>? custom,
    String? referencedMessage,
  );

  void conversationSubscribe(int handle, int subscriptionHandle);
  void conversationSubscribeMessages(int handle, int subscriptionHandle);
  void conversationSubscribeParticipants(int handle, int subscriptionHandle);
  void conversationSubscribeTyping(int handle, int subscriptionHandle);

  // ConversationSubscription
  void conversationSubscriptionDeleteHandle(int handle);
  void conversationSubscriptionUnsubscribe(int handle);

  // MessageSubscription
  void messageSubscriptionDeleteHandle(int handle);

  @async
  void messageSubscriptionLoadMore(int handle, int? count);

  void messageSubscriptionUnsubscribe(int handle);

  // ParticipantSubscription
  void participantSubscriptionDeleteHandle(int handle);

  @async
  void participantSubscriptionLoadMore(int handle, int? count);

  void participantSubscriptionUnsubscribe(int handle);

  // TypingSubscription
  void typingSubscriptionDeleteHandle(int handle);
  void typingSubscriptionUnsubscribe(int handle);

  // Participant
  void participantDeleteHandle(int handle);

  @async
  String? participantGet(int handle);

  @async
  void participantSet(int handle, String? accessJson, String? notifyJson);

  @async
  void participantEdit(int handle, String? accessJson, String? notifyJson);

  @async
  void participantCreateIfNotExists(
    int handle,
    String? accessJson,
    String? notifyJson,
  );

  @async
  void participantDeleteFields(int handle, List<String> fields);

  @async
  void participantDelete(int handle);

  // Message
  void messageDeleteHandle(int handle);

  @async
  String? messageGet(int handle);

  @async
  void messageEdit(int handle, String? text, Map<String, String?>? custom);

  @async
  void messageEditMessage(
    int handle,
    String contentJson,
    Map<String, String?>? custom,
  );

  @async
  void messageDeleteFields(int handle, List<String> fields);

  @async
  void messageDelete(int handle);

  int messageReaction(int handle, String emoji);

  // Reaction
  void reactionDeleteHandle(int handle);

  @async
  void reactionAdd(int handle);

  @async
  void reactionRemove(int handle);
}

@HostApi()
abstract class TestHostApi {
  // Test endpoints
  String testContentSerialization(String contentJson);
}

@FlutterApi()
abstract class CoreFlutterApi {
  void newUserSnapshot(int handle, String? snapshotJson);
  void newUserOnlineSnapshot(int handle, String? snapshotJson);
  void newConversationSnapshot(int handle, String? snapshotJson);
  void newConversationListSnapshot(
    int handle,
    String snapshotJson,
    bool loadedAll,
  );
  void newSessionError(int handle, String message);
  void newMessageSnapshot(int handle, String? snapshotJson, bool loadedAll);
  void newParticipantSnapshot(int handle, String? snapshotJson, bool loadedAll);
  void newTypingSnapshot(int handle, String? snapshotJson);
  void userSubscriptionConnectedResolve(int handle);
  void userSubscriptionConnectedReject(int handle, String error);
  void userSubscriptionTerminatedResolve(int handle);
  void userSubscriptionTerminatedReject(int handle, String error);
  void userOnlineSubscriptionConnectedResolve(int handle);
  void userOnlineSubscriptionConnectedReject(int handle, String error);
  void userOnlineSubscriptionTerminatedResolve(int handle);
  void userOnlineSubscriptionTerminatedReject(int handle, String error);
  void conversationListSubscriptionConnectedResolve(int handle);
  void conversationListSubscriptionConnectedReject(int handle, String error);
  void conversationListSubscriptionTerminatedResolve(int handle);
  void conversationListSubscriptionTerminatedReject(int handle, String error);
  void conversationSubscriptionConnectedResolve(int handle);
  void conversationSubscriptionConnectedReject(int handle, String error);
  void conversationSubscriptionTerminatedResolve(int handle);
  void conversationSubscriptionTerminatedReject(int handle, String error);
  void messageSubscriptionConnectedResolve(int handle);
  void messageSubscriptionConnectedReject(int handle, String error);
  void messageSubscriptionTerminatedResolve(int handle);
  void messageSubscriptionTerminatedReject(int handle, String error);
  void participantSubscriptionConnectedResolve(int handle);
  void participantSubscriptionConnectedReject(int handle, String error);
  void participantSubscriptionTerminatedResolve(int handle);
  void participantSubscriptionTerminatedReject(int handle, String error);
  void typingSubscriptionConnectedResolve(int handle);
  void typingSubscriptionConnectedReject(int handle, String error);
  void typingSubscriptionTerminatedResolve(int handle);
  void typingSubscriptionTerminatedReject(int handle, String error);
}
