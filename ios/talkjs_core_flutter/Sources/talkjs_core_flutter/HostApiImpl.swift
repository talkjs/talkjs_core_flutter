import Flutter
import Foundation
import talkjs_core_swift

final class HostApiImpl: CoreHostApi {
  private var nextId: Int64 = 0
  private var sessions: [Int64: Session] = [:]
  private var users: [Int64: UserRef] = [:]
  private var userSubscriptions: [Int64: UserSubscription] = [:]
  private var userOnlineSubscriptions: [Int64: UserOnlineSubscription] = [:]
  private var conversations: [Int64: ConversationRef] = [:]
  private var conversationSubscriptions: [Int64: ConversationSubscription] = [:]
  private var conversationListSubscriptions: [Int64: ConversationListSubscription] = [:]
  private var sessionOnErrorSubscriptions: [Int64: any Subscription] = [:]
  private var messageSubscriptions: [Int64: MessageSubscription] = [:]
  private var participantSubscriptions: [Int64: ParticipantSubscription] = [:]
  private var typingSubscriptions: [Int64: TypingSubscription] = [:]
  private var participants: [Int64: ParticipantRef] = [:]
  private var messages: [Int64: MessageRef] = [:]
  private var reactions: [Int64: ReactionRef] = [:]

  // Session
  func getTalkSession(
    appId: String,
    userId: String,
    token: String?,
    forceCreateNew: Bool,
    signature: String?,
    apiUrls: ApiUrlOptions?,
    host: String?,
    clientBuild: String?,
  ) throws -> Int64 {
    // clientBuild is omitted because the Swift API doesn't expose it
    let session = talkjs_core_swift.getTalkSession(
      appId: appId,
      userId: userId,
      host: host ?? "",
      token: token,
      signature: signature,
      apiUrls: apiUrls.map {
        talkjs_core_swift.ApiUrlOptions(
          realtimeWsApiUrl: $0.realtimeWsApiUrl,
          internalHttpApiUrl: $0.internalHttpApiUrl,
          restApiHttpUrl: $0.restApiHttpUrl,
        )
      },
      forceCreateNew: forceCreateNew,
    )

    let handle = nextId
    nextId += 1

    sessions[handle] = session
    users[handle] = session.currentUser

    return handle
  }

  func sessionDeleteHandle(handle: Int64) throws {
    users.removeValue(forKey: handle)
    sessions.removeValue(forKey: handle)
  }

  func sessionUser(handle: Int64, id: String) throws -> Int64 {
    guard let session = sessions[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid session handle \(handle)",
        details: "",
      )
    }

    let ref = session.user(id: id)

    let userHandle = nextId
    nextId += 1

    users[userHandle] = ref

    return userHandle
  }

  func sessionConversation(handle: Int64, id: String) throws -> Int64 {
    guard let session = sessions[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid session handle \(handle)",
        details: "",
      )
    }

    let ref = session.conversation(id: id)

    let conversationHandle = nextId
    nextId += 1

    conversations[conversationHandle] = ref

    return conversationHandle
  }

  func sessionSubscribeConversations(handle: Int64, subscriptionHandle: Int64) throws {
    guard let session = sessions[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid session handle \(handle)",
        details: "",
      )
    }

    let subscription = session.subscribeConversations { snapshot, loadedAll in
      let json = String(data: try! JSONEncoder().encode(snapshot), encoding: .utf8)!
      Task { @MainActor in
        flutterApi?.newConversationListSnapshot(
          handle: subscriptionHandle,
          snapshotJson: json,
          loadedAll: loadedAll,
        ) { _ in }
      }
    }

    conversationListSubscriptions[subscriptionHandle] = subscription

    Task { @MainActor in
      do {
        _ = try await subscription.connected.await()
        flutterApi?.conversationListSubscriptionConnectedResolve(handle: subscriptionHandle) { _ in }
      } catch {
        flutterApi?.conversationListSubscriptionConnectedReject(
          handle: subscriptionHandle,
          error: (error as? TalkJSError)?.message ?? "",
        ) { _ in }
      }
    }

    Task { @MainActor in
      do {
        _ = try await subscription.terminated.await()
        flutterApi?.conversationListSubscriptionTerminatedResolve(handle: subscriptionHandle) { _ in }
      } catch {
        flutterApi?.conversationListSubscriptionTerminatedReject(
          handle: subscriptionHandle,
          error: (error as? TalkJSError)?.message ?? "",
        ) { _ in }
      }
    }
  }

  func sessionOnError(handle: Int64, subscriptionHandle: Int64) throws {
    guard let session = sessions[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid session handle \(handle)",
        details: "",
      )
    }

    let subscription = session.onError { error in
      Task { @MainActor in
        flutterApi?.newSessionError(
          handle: subscriptionHandle,
          message: error.message ?? "",
        ) { _ in }
      }
    }

    sessionOnErrorSubscriptions[subscriptionHandle] = subscription
  }

  func sessionUploadFile(
    handle: Int64,
    bytes: FlutterStandardTypedData,
    metadata: GenericFileMetadata,
    completion: @escaping (Result<String, Error>) -> Void,
  ) {
    guard let session = sessions[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid session handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      let token = await session.uploadFile(
        data: bytes.data.map { Int8(bitPattern: $0) },
        metadata: talkjs_core_swift.GenericFileMetadata(filename: metadata.filename),
      )
      completion(.success(token))
    }
  }

  func sessionUploadImage(
    handle: Int64,
    bytes: FlutterStandardTypedData,
    metadata: ImageFileMetadata,
    completion: @escaping (Result<String, Error>) -> Void,
  ) {
    guard let session = sessions[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid session handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      let token = await session.uploadImage(
        data: bytes.data.map { Int8(bitPattern: $0) },
        metadata: talkjs_core_swift.ImageFileMetadata(
          filename: metadata.filename,
          width: metadata.width.map { Int($0) },
          height: metadata.height.map { Int($0) },
        ),
      )
      completion(.success(token))
    }
  }

  func sessionUploadVideo(
    handle: Int64,
    bytes: FlutterStandardTypedData,
    metadata: VideoFileMetadata,
    completion: @escaping (Result<String, Error>) -> Void,
  ) {
    guard let session = sessions[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid session handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      let token = await session.uploadVideo(
        data: bytes.data.map { Int8(bitPattern: $0) },
        metadata: talkjs_core_swift.VideoFileMetadata(
          filename: metadata.filename,
          duration: metadata.duration,
          width: metadata.width.map { Int($0) },
          height: metadata.height.map { Int($0) },
        ),
      )
      completion(.success(token))
    }
  }

  func sessionUploadAudio(
    handle: Int64,
    bytes: FlutterStandardTypedData,
    metadata: AudioFileMetadata,
    completion: @escaping (Result<String, Error>) -> Void,
  ) {
    guard let session = sessions[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid session handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      let token = await session.uploadAudio(
        data: bytes.data.map { Int8(bitPattern: $0) },
        metadata: talkjs_core_swift.AudioFileMetadata(
          filename: metadata.filename,
          duration: metadata.duration,
        ),
      )
      completion(.success(token))
    }
  }

  func sessionUploadVoice(
    handle: Int64,
    bytes: FlutterStandardTypedData,
    metadata: VoiceRecordingFileMetadata,
    completion: @escaping (Result<String, Error>) -> Void,
  ) {
    guard let session = sessions[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid session handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      let token = await session.uploadVoice(
        data: bytes.data.map { Int8(bitPattern: $0) },
        metadata: talkjs_core_swift.VoiceRecordingFileMetadata(
          filename: metadata.filename,
          duration: metadata.duration,
        ),
      )
      completion(.success(token))
    }
  }

  // ConversationListSubscription
  func conversationListSubscriptionDeleteHandle(handle: Int64) throws {
    conversationListSubscriptions.removeValue(forKey: handle)
  }

  func conversationListSubscriptionLoadMore(
    handle: Int64,
    count: Int64?,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let subscription = conversationListSubscriptions[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid conversation list subscription handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      await subscription.loadMore(count: count.map { Int($0) })
      completion(.success(()))
    }
  }

  func conversationListSubscriptionUnsubscribe(handle: Int64) throws {
    guard let subscription = conversationListSubscriptions[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid conversation list subscription handle \(handle)",
        details: "",
      )
    }

    subscription.unsubscribe()
  }

  // ErrorSubscription
  func sessionOnErrorDeleteHandle(handle: Int64) throws {
    sessionOnErrorSubscriptions.removeValue(forKey: handle)
  }

  func sessionOnErrorUnsubscribe(handle: Int64) throws {
    guard let subscription = sessionOnErrorSubscriptions[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid error subscription handle \(handle)",
        details: "",
      )
    }

    subscription.unsubscribe()
  }

  // User
  func userDeleteHandle(handle: Int64) throws {
    users.removeValue(forKey: handle)
  }

  func userGet(
    handle: Int64,
    completion: @escaping (Result<String?, Error>) -> Void,
  ) {
    guard let ref = users[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid user handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      let snapshot = await ref.get().map {
        String(data: try! JSONEncoder().encode($0), encoding: .utf8)!
      }
      completion(.success(snapshot))
    }
  }

  func userSet(
    handle: Int64,
    name: String?,
    custom: [String: String?]?,
    locale: String?,
    photoUrl: String?,
    role: String?,
    welcomeMessage: String?,
    email: [String]?,
    phone: [String]?,
    pushTokens: [String: Bool?]?,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = users[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid user handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      await ref.set(
        name: name,
        role: role,
        photoUrl: photoUrl,
        email: email,
        custom: custom,
        locale: locale,
        phone: phone,
        pushTokens: pushTokens,
        welcomeMessage: welcomeMessage,
      )
      completion(.success(()))
    }
  }

  func userCreateIfNotExists(
    handle: Int64,
    name: String,
    custom: [String: String]?,
    locale: String?,
    photoUrl: String?,
    role: String?,
    welcomeMessage: String?,
    email: [String]?,
    phone: [String]?,
    pushTokens: [String: Bool]?,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = users[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid user handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      await ref.createIfNotExists(
        name: name,
        role: role,
        photoUrl: photoUrl,
        email: email,
        custom: custom,
        locale: locale,
        phone: phone,
        pushTokens: pushTokens,
        welcomeMessage: welcomeMessage,
      )
      completion(.success(()))
    }
  }

  func userDeleteFields(
    handle: Int64,
    fields: [String],
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = users[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid user handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      await ref.deleteFields(fields)
      completion(.success(()))
    }
  }

  func userSubscribe(handle: Int64, subscriptionHandle: Int64) throws {
    guard let ref = users[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid user handle \(handle)",
        details: "",
      )
    }

    let subscription = ref.subscribe { snapshot in
      let json = snapshot.map {
        String(data: try! JSONEncoder().encode($0), encoding: .utf8)!
      }
      Task { @MainActor in
        flutterApi?.newUserSnapshot(
          handle: subscriptionHandle,
          snapshotJson: json,
        ) { _ in }
      }
    }

    userSubscriptions[subscriptionHandle] = subscription

    Task { @MainActor in
      do {
        _ = try await subscription.connected.await()
        flutterApi?.userSubscriptionConnectedResolve(handle: subscriptionHandle) { _ in }
      } catch {
        flutterApi?.userSubscriptionConnectedReject(
          handle: subscriptionHandle,
          error: (error as? TalkJSError)?.message ?? "",
        ) { _ in }
      }
    }

    Task { @MainActor in
      do {
        _ = try await subscription.terminated.await()
        flutterApi?.userSubscriptionTerminatedResolve(handle: subscriptionHandle) { _ in }
      } catch {
        flutterApi?.userSubscriptionTerminatedReject(
          handle: subscriptionHandle,
          error: (error as? TalkJSError)?.message ?? "",
        ) { _ in }
      }
    }
  }

  func userSubscribeOnline(handle: Int64, subscriptionHandle: Int64) throws {
    guard let ref = users[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid user handle \(handle)",
        details: "",
      )
    }

    let subscription = ref.subscribeOnline { snapshot in
      let json = snapshot.map {
        String(data: try! JSONEncoder().encode($0), encoding: .utf8)!
      }
      Task { @MainActor in
        flutterApi?.newUserOnlineSnapshot(
          handle: subscriptionHandle,
          snapshotJson: json,
        ) { _ in }
      }
    }

    userOnlineSubscriptions[subscriptionHandle] = subscription

    Task { @MainActor in
      do {
        _ = try await subscription.connected.await()
        flutterApi?.userOnlineSubscriptionConnectedResolve(handle: subscriptionHandle) { _ in }
      } catch {
        flutterApi?.userOnlineSubscriptionConnectedReject(
          handle: subscriptionHandle,
          error: (error as? TalkJSError)?.message ?? "",
        ) { _ in }
      }
    }

    Task { @MainActor in
      do {
        _ = try await subscription.terminated.await()
        flutterApi?.userOnlineSubscriptionTerminatedResolve(handle: subscriptionHandle) { _ in }
      } catch {
        flutterApi?.userOnlineSubscriptionTerminatedReject(
          handle: subscriptionHandle,
          error: (error as? TalkJSError)?.message ?? "",
        ) { _ in }
      }
    }
  }

  // UserSubscription
  func userSubscriptionDeleteHandle(handle: Int64) throws {
    userSubscriptions.removeValue(forKey: handle)
  }

  func userSubscriptionUnsubscribe(handle: Int64) throws {
    guard let subscription = userSubscriptions[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid user subscription handle \(handle)",
        details: "",
      )
    }

    subscription.unsubscribe()
  }

  // UserOnlineSubscription
  func userOnlineSubscriptionDeleteHandle(handle: Int64) throws {
    userOnlineSubscriptions.removeValue(forKey: handle)
  }

  func userOnlineSubscriptionUnsubscribe(handle: Int64) throws {
    guard let subscription = userOnlineSubscriptions[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid user online subscription handle \(handle)",
        details: "",
      )
    }

    subscription.unsubscribe()
  }

  // Conversation
  func conversationDeleteHandle(handle: Int64) throws {
    conversations.removeValue(forKey: handle)
  }

  func conversationGet(
    handle: Int64,
    completion: @escaping (Result<String?, Error>) -> Void,
  ) {
    guard let ref = conversations[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid conversation handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      let snapshot = await ref.get().map {
        String(data: try! JSONEncoder().encode($0), encoding: .utf8)!
      }
      completion(.success(snapshot))
    }
  }

  func conversationSet(
    handle: Int64,
    subject: String?,
    photoUrl: String?,
    welcomeMessages: [String]?,
    custom: [String: String?]?,
    accessJson: String?,
    notifyJson: String?,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = conversations[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid conversation handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      do {
        let access = try accessJson.map {
          try JSONDecoder().decode(ConversationAccess.self, from: Data($0.utf8))
        }
        let notify = try notifyJson.map {
          try JSONDecoder().decode(NotificationSettings.self, from: Data($0.utf8))
        }
        await ref.set(
          subject: subject,
          photoUrl: photoUrl,
          welcomeMessages: welcomeMessages,
          custom: custom,
          access: access,
          notify: notify,
        )
        completion(.success(()))
      } catch {
        completion(.failure(error))
      }
    }
  }

  func conversationCreateIfNotExists(
    handle: Int64,
    subject: String?,
    photoUrl: String?,
    welcomeMessages: [String]?,
    custom: [String: String]?,
    accessJson: String?,
    notifyJson: String?,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = conversations[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid conversation handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      do {
        let access = try accessJson.map {
          try JSONDecoder().decode(ConversationAccess.self, from: Data($0.utf8))
        }
        let notify = try notifyJson.map {
          try JSONDecoder().decode(NotificationSettings.self, from: Data($0.utf8))
        }
        await ref.createIfNotExists(
          access: access,
          custom: custom,
          notify: notify,
          photoUrl: photoUrl,
          subject: subject,
          welcomeMessages: welcomeMessages,
        )
        completion(.success(()))
      } catch {
        completion(.failure(error))
      }
    }
  }

  func conversationDeleteFields(
    handle: Int64,
    fields: [String],
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = conversations[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid conversation handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      await ref.deleteFields(fields)
      completion(.success(()))
    }
  }

  func conversationMarkAsRead(
    handle: Int64,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = conversations[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid conversation handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      await ref.markAsRead()
      completion(.success(()))
    }
  }

  func conversationMarkAsUnread(
    handle: Int64,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = conversations[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid conversation handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      await ref.markAsUnread()
      completion(.success(()))
    }
  }

  func conversationMarkAsTyping(
    handle: Int64,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = conversations[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid conversation handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      await ref.markAsTyping()
      completion(.success(()))
    }
  }

  func conversationParticipant(handle: Int64, user: String) throws -> Int64 {
    guard let conversation = conversations[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid conversation handle \(handle)",
        details: "",
      )
    }

    let ref = conversation.participant(user: user)

    let participantHandle = nextId
    nextId += 1

    participants[participantHandle] = ref

    return participantHandle
  }

  func conversationMessage(handle: Int64, messageId: String) throws -> Int64 {
    guard let conversation = conversations[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid conversation handle \(handle)",
        details: "",
      )
    }

    let ref = conversation.message(id: messageId)

    let messageHandle = nextId
    nextId += 1

    messages[messageHandle] = ref

    return messageHandle
  }

  func conversationSend(
    handle: Int64,
    text: String,
    custom: [String: String]?,
    referencedMessage: String?,
    completion: @escaping (Result<MessageRefBuildData, Error>) -> Void,
  ) {
    guard let conversation = conversations[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid conversation handle \(handle)",
        details: "",
      )))
      return
    }

    let messageHandle = nextId
    nextId += 1

    Task { @MainActor in
      let ref = await conversation.send(
        text: text,
        referencedMessage: referencedMessage,
        custom: custom,
      )

      messages[messageHandle] = ref

      completion(.success(MessageRefBuildData(
        handle: messageHandle,
        id: ref.id,
        conversationId: ref.conversationId,
      )))
    }
  }

  func conversationSendMessage(
    handle: Int64,
    contentJson: String,
    custom: [String: String]?,
    referencedMessage: String?,
    completion: @escaping (Result<MessageRefBuildData, Error>) -> Void,
  ) {
    guard let conversation = conversations[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid conversation handle \(handle)",
        details: "",
      )))
      return
    }

    let messageHandle = nextId
    nextId += 1

    Task { @MainActor in
      do {
        let ref = await conversation.send(
          content: try decodeSendContentBlocks(Data(contentJson.utf8)),
          referencedMessage: referencedMessage,
          custom: custom,
        )

        messages[messageHandle] = ref

        completion(.success(MessageRefBuildData(
          handle: messageHandle,
          id: ref.id,
          conversationId: ref.conversationId,
        )))
      } catch {
        completion(.failure(error))
      }
    }
  }

  func conversationSubscribe(handle: Int64, subscriptionHandle: Int64) throws {
    guard let ref = conversations[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid conversation handle \(handle)",
        details: "",
      )
    }

    let subscription = ref.subscribe { snapshot in
      let json = snapshot.map {
        String(data: try! JSONEncoder().encode($0), encoding: .utf8)!
      }
      Task { @MainActor in
        flutterApi?.newConversationSnapshot(
          handle: subscriptionHandle,
          snapshotJson: json,
        ) { _ in }
      }
    }

    conversationSubscriptions[subscriptionHandle] = subscription

    Task { @MainActor in
      do {
        _ = try await subscription.connected.await()
        flutterApi?.conversationSubscriptionConnectedResolve(handle: subscriptionHandle) { _ in }
      } catch {
        flutterApi?.conversationSubscriptionConnectedReject(
          handle: subscriptionHandle,
          error: (error as? TalkJSError)?.message ?? "",
        ) { _ in }
      }
    }

    Task { @MainActor in
      do {
        _ = try await subscription.terminated.await()
        flutterApi?.conversationSubscriptionTerminatedResolve(handle: subscriptionHandle) { _ in }
      } catch {
        flutterApi?.conversationSubscriptionTerminatedReject(
          handle: subscriptionHandle,
          error: (error as? TalkJSError)?.message ?? "",
        ) { _ in }
      }
    }
  }

  func conversationSubscribeMessages(handle: Int64, subscriptionHandle: Int64) throws {
    guard let ref = conversations[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid conversation handle \(handle)",
        details: "",
      )
    }

    let subscription = ref.subscribeMessages { snapshot, loadedAll in
      let json = snapshot.map {
        String(data: try! JSONEncoder().encode($0), encoding: .utf8)!
      }
      Task { @MainActor in
        flutterApi?.newMessageSnapshot(
          handle: subscriptionHandle,
          snapshotJson: json,
          loadedAll: loadedAll,
        ) { _ in }
      }
    }

    messageSubscriptions[subscriptionHandle] = subscription

    Task { @MainActor in
      do {
        _ = try await subscription.connected.await()
        flutterApi?.messageSubscriptionConnectedResolve(handle: subscriptionHandle) { _ in }
      } catch {
        flutterApi?.messageSubscriptionConnectedReject(
          handle: subscriptionHandle,
          error: (error as? TalkJSError)?.message ?? "",
        ) { _ in }
      }
    }

    Task { @MainActor in
      do {
        _ = try await subscription.terminated.await()
        flutterApi?.messageSubscriptionTerminatedResolve(handle: subscriptionHandle) { _ in }
      } catch {
        flutterApi?.messageSubscriptionTerminatedReject(
          handle: subscriptionHandle,
          error: (error as? TalkJSError)?.message ?? "",
        ) { _ in }
      }
    }
  }

  func conversationSubscribeParticipants(handle: Int64, subscriptionHandle: Int64) throws {
    guard let ref = conversations[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid conversation handle \(handle)",
        details: "",
      )
    }

    let subscription = ref.subscribeParticipants { snapshot, loadedAll in
      let json = snapshot.map {
        String(data: try! JSONEncoder().encode($0), encoding: .utf8)!
      }
      Task { @MainActor in
        flutterApi?.newParticipantSnapshot(
          handle: subscriptionHandle,
          snapshotJson: json,
          loadedAll: loadedAll,
        ) { _ in }
      }
    }

    participantSubscriptions[subscriptionHandle] = subscription

    Task { @MainActor in
      do {
        _ = try await subscription.connected.await()
        flutterApi?.participantSubscriptionConnectedResolve(handle: subscriptionHandle) { _ in }
      } catch {
        flutterApi?.participantSubscriptionConnectedReject(
          handle: subscriptionHandle,
          error: (error as? TalkJSError)?.message ?? "",
        ) { _ in }
      }
    }

    Task { @MainActor in
      do {
        _ = try await subscription.terminated.await()
        flutterApi?.participantSubscriptionTerminatedResolve(handle: subscriptionHandle) { _ in }
      } catch {
        flutterApi?.participantSubscriptionTerminatedReject(
          handle: subscriptionHandle,
          error: (error as? TalkJSError)?.message ?? "",
        ) { _ in }
      }
    }
  }

  func conversationSubscribeTyping(handle: Int64, subscriptionHandle: Int64) throws {
    guard let ref = conversations[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid conversation handle \(handle)",
        details: "",
      )
    }

    let subscription = ref.subscribeTyping { snapshot in
      let json = snapshot.map {
        String(data: try! JSONEncoder().encode($0), encoding: .utf8)!
      }
      Task { @MainActor in
        flutterApi?.newTypingSnapshot(
          handle: subscriptionHandle,
          snapshotJson: json,
        ) { _ in }
      }
    }

    typingSubscriptions[subscriptionHandle] = subscription

    Task { @MainActor in
      do {
        _ = try await subscription.connected.await()
        flutterApi?.typingSubscriptionConnectedResolve(handle: subscriptionHandle) { _ in }
      } catch {
        flutterApi?.typingSubscriptionConnectedReject(
          handle: subscriptionHandle,
          error: (error as? TalkJSError)?.message ?? "",
        ) { _ in }
      }
    }

    Task { @MainActor in
      do {
        _ = try await subscription.terminated.await()
        flutterApi?.typingSubscriptionTerminatedResolve(handle: subscriptionHandle) { _ in }
      } catch {
        flutterApi?.typingSubscriptionTerminatedReject(
          handle: subscriptionHandle,
          error: (error as? TalkJSError)?.message ?? "",
        ) { _ in }
      }
    }
  }

  // ConversationSubscription
  func conversationSubscriptionDeleteHandle(handle: Int64) throws {
    conversationSubscriptions.removeValue(forKey: handle)
  }

  func conversationSubscriptionUnsubscribe(handle: Int64) throws {
    guard let subscription = conversationSubscriptions[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid conversation subscription handle \(handle)",
        details: "",
      )
    }

    subscription.unsubscribe()
  }

  // MessageSubscription
  func messageSubscriptionDeleteHandle(handle: Int64) throws {
    messageSubscriptions.removeValue(forKey: handle)
  }

  func messageSubscriptionLoadMore(
    handle: Int64,
    count: Int64?,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let subscription = messageSubscriptions[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid message subscription handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      await subscription.loadMore(count: count.map { Int($0) })
      completion(.success(()))
    }
  }

  func messageSubscriptionUnsubscribe(handle: Int64) throws {
    guard let subscription = messageSubscriptions[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid message subscription handle \(handle)",
        details: "",
      )
    }

    subscription.unsubscribe()
  }

  // ParticipantSubscription
  func participantSubscriptionDeleteHandle(handle: Int64) throws {
    participantSubscriptions.removeValue(forKey: handle)
  }

  func participantSubscriptionLoadMore(
    handle: Int64,
    count: Int64?,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let subscription = participantSubscriptions[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid participant subscription handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      await subscription.loadMore(count: count.map { Int($0) })
      completion(.success(()))
    }
  }

  func participantSubscriptionUnsubscribe(handle: Int64) throws {
    guard let subscription = participantSubscriptions[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid participant subscription handle \(handle)",
        details: "",
      )
    }

    subscription.unsubscribe()
  }

  // TypingSubscription
  func typingSubscriptionDeleteHandle(handle: Int64) throws {
    typingSubscriptions.removeValue(forKey: handle)
  }

  func typingSubscriptionUnsubscribe(handle: Int64) throws {
    guard let subscription = typingSubscriptions[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid typing subscription handle \(handle)",
        details: "",
      )
    }

    subscription.unsubscribe()
  }

  // Participant
  func participantDeleteHandle(handle: Int64) throws {
    participants.removeValue(forKey: handle)
  }

  func participantGet(
    handle: Int64,
    completion: @escaping (Result<String?, Error>) -> Void,
  ) {
    guard let ref = participants[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid participant handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      let snapshot = await ref.get().map {
        String(data: try! JSONEncoder().encode($0), encoding: .utf8)!
      }
      completion(.success(snapshot))
    }
  }

  func participantSet(
    handle: Int64,
    accessJson: String?,
    notifyJson: String?,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = participants[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid participant handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      do {
        let access = try accessJson.map {
          try JSONDecoder().decode(ConversationAccess.self, from: Data($0.utf8))
        }
        let notify = try notifyJson.map {
          try JSONDecoder().decode(NotificationSettings.self, from: Data($0.utf8))
        }
        await ref.set(
          access: access,
          notify: notify,
        )
        completion(.success(()))
      } catch {
        completion(.failure(error))
      }
    }
  }

  func participantEdit(
    handle: Int64,
    accessJson: String?,
    notifyJson: String?,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = participants[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid participant handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      do {
        let access = try accessJson.map {
          try JSONDecoder().decode(ConversationAccess.self, from: Data($0.utf8))
        }
        let notify = try notifyJson.map {
          try JSONDecoder().decode(NotificationSettings.self, from: Data($0.utf8))
        }
        await ref.edit(
          access: access,
          notify: notify,
        )
        completion(.success(()))
      } catch {
        completion(.failure(error))
      }
    }
  }

  func participantCreateIfNotExists(
    handle: Int64,
    accessJson: String?,
    notifyJson: String?,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = participants[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid participant handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      do {
        let access = try accessJson.map {
          try JSONDecoder().decode(ConversationAccess.self, from: Data($0.utf8))
        }
        let notify = try notifyJson.map {
          try JSONDecoder().decode(NotificationSettings.self, from: Data($0.utf8))
        }
        await ref.createIfNotExists(
          access: access,
          notify: notify,
        )
        completion(.success(()))
      } catch {
        completion(.failure(error))
      }
    }
  }

  func participantDeleteFields(
    handle: Int64,
    fields: [String],
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = participants[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid participant handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      await ref.deleteFields(fields)
      completion(.success(()))
    }
  }

  func participantDelete(
    handle: Int64,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = participants[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid participant handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      await ref.delete()
      completion(.success(()))
    }
  }

  // Message
  func messageDeleteHandle(handle: Int64) throws {
    messages.removeValue(forKey: handle)
  }

  func messageGet(
    handle: Int64,
    completion: @escaping (Result<String?, Error>) -> Void,
  ) {
    guard let ref = messages[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid message handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      let snapshot = await ref.get().map {
        String(data: try! JSONEncoder().encode($0), encoding: .utf8)!
      }
      completion(.success(snapshot))
    }
  }

  func messageEdit(
    handle: Int64,
    text: String?,
    custom: [String: String?]?,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = messages[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid message handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      await ref.edit(
        text: text,
        custom: custom,
      )
      completion(.success(()))
    }
  }

  func messageEditMessage(
    handle: Int64,
    contentJson: String,
    custom: [String: String?]?,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = messages[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid message handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      do {
        await ref.edit(
          content: try decodeSendContentBlocks(Data(contentJson.utf8)),
          custom: custom,
        )
        completion(.success(()))
      } catch {
        completion(.failure(error))
      }
    }
  }

  func messageDeleteFields(
    handle: Int64,
    fields: [String],
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = messages[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid message handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      await ref.deleteFields(fields)
      completion(.success(()))
    }
  }

  func messageDelete(
    handle: Int64,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = messages[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid message handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      await ref.delete()
      completion(.success(()))
    }
  }

  func messageReaction(handle: Int64, emoji: String) throws -> Int64 {
    guard let message = messages[handle] else {
      throw PigeonError(
        code: "null-error",
        message: "Invalid message handle \(handle)",
        details: "",
      )
    }

    let ref = message.reaction(emoji: emoji)

    let reactionHandle = nextId
    nextId += 1

    reactions[reactionHandle] = ref

    return reactionHandle
  }

  // Reaction
  func reactionDeleteHandle(handle: Int64) throws {
    reactions.removeValue(forKey: handle)
  }

  func reactionAdd(
    handle: Int64,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = reactions[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid reaction handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      await ref.add()
      completion(.success(()))
    }
  }

  func reactionRemove(
    handle: Int64,
    completion: @escaping (Result<Void, Error>) -> Void,
  ) {
    guard let ref = reactions[handle] else {
      completion(.failure(PigeonError(
        code: "null-error",
        message: "Invalid reaction handle \(handle)",
        details: "",
      )))
      return
    }

    Task { @MainActor in
      await ref.remove()
      completion(.success(()))
    }
  }
}
