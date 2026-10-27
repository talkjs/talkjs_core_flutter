package com.example.talkjs_core_flutter

import com.talkjs.core.ConversationListSubscription
import com.talkjs.core.ConversationRef
import com.talkjs.core.ConversationSubscription
import com.talkjs.core.MessageRef
import com.talkjs.core.MessageSubscription
import com.talkjs.core.ParticipantRef
import com.talkjs.core.ParticipantSubscription
import com.talkjs.core.ReactionRef
import com.talkjs.core.Subscription
import com.talkjs.core.TalkSession
import com.talkjs.core.TypingSubscription
import com.talkjs.core.UserOnlineSubscription
import com.talkjs.core.UserRef
import com.talkjs.core.UserSubscription
import com.talkjs.core.jsonFormat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

private var flutterApi: CoreFlutterApi? = null

private class PigeonApiImplementation : CoreHostApi {
    private val scope = CoroutineScope(Dispatchers.Default)

    private var nextId = 0L
    private val sessions: MutableMap<Long, TalkSession> = mutableMapOf()
    private val users: MutableMap<Long, UserRef> = mutableMapOf()
    private val userSubscriptions: MutableMap<Long, UserSubscription> = mutableMapOf()
    private val userOnlineSubscriptions: MutableMap<Long, UserOnlineSubscription> = mutableMapOf()
    private val conversations: MutableMap<Long, ConversationRef> = mutableMapOf()
    private val conversationSubscriptions: MutableMap<Long, ConversationSubscription> =
        mutableMapOf()
    private val conversationListSubscriptions: MutableMap<Long, ConversationListSubscription> =
        mutableMapOf()
    private val sessionOnErrorSubscriptions: MutableMap<Long, Subscription> = mutableMapOf()
    private val messageSubscriptions: MutableMap<Long, MessageSubscription> = mutableMapOf()
    private val participantSubscriptions: MutableMap<Long, ParticipantSubscription> = mutableMapOf()
    private val typingSubscriptions: MutableMap<Long, TypingSubscription> = mutableMapOf()
    private val participants: MutableMap<Long, ParticipantRef> = mutableMapOf()
    private val messages: MutableMap<Long, MessageRef> = mutableMapOf()
    private val reactions: MutableMap<Long, ReactionRef> = mutableMapOf()

    // Session
    override fun getTalkSession(
        appId: String,
        userId: String,
        token: String?,
        forceCreateNew: Boolean,
        signature: String?,
        apiUrls: ApiUrlOptions?,
        host: String?,
        clientBuild: String?,
    ): Long {
        val session = com.talkjs.core.getTalkSession(
            appId = appId,
            userId = userId,
            token = token,
            forceCreateNew = forceCreateNew,
            signature = signature,
            apiUrls = apiUrls?.let {
                com.talkjs.core.ApiUrlOptions(
                    realtimeWsApiUrl = it.realtimeWsApiUrl,
                    internalHttpApiUrl = it.internalHttpApiUrl,
                    restApiHttpUrl = it.restApiHttpUrl,
                )
            },
            host = host,
            clientBuild = clientBuild,
        )

        val handle = nextId
        nextId += 1

        sessions[handle] = session
        users[handle] = session.currentUser

        return handle
    }

    override fun sessionDeleteHandle(handle: Long) {
        println("Kotlin: sessionDeleteHandle $handle")

        users.remove(handle)
        sessions.remove(handle)
    }

    override fun sessionUser(handle: Long, id: String): Long {
        val session = sessions[handle] ?: throw FlutterError(
            "null-error",
            "Invalid session handle $handle",
            "",
        )

        val ref = session.user(id)

        val userHandle = nextId
        nextId += 1

        users[userHandle] = ref

        return userHandle
    }

    override fun sessionConversation(handle: Long, id: String): Long {
        val session = sessions[handle] ?: throw FlutterError(
            "null-error",
            "Invalid session handle $handle",
            "",
        )

        val ref = session.conversation(id)

        val conversationHandle = nextId
        nextId += 1

        conversations[conversationHandle] = ref

        return conversationHandle
    }

    override fun sessionSubscribeConversations(handle: Long, subscriptionHandle: Long) {
        val ref = sessions[handle] ?: throw FlutterError(
            "null-error",
            "Invalid session handle $handle",
            "",
        )

        val subscription = ref.subscribeConversations { snapshot, loadedAll ->
            scope.launch(Dispatchers.Main) {
                flutterApi?.newConversationListSnapshot(
                    subscriptionHandle,
                    jsonFormat.encodeToString(snapshot),
                    loadedAll,
                ) {}
            }
        }

        conversationListSubscriptions[subscriptionHandle] = subscription

        scope.launch {
            try {
                subscription.connected.await()
                scope.launch(Dispatchers.Main) {
                    flutterApi?.conversationListSubscriptionConnectedResolve(subscriptionHandle) {}
                }
            } catch (e: Exception) {
                scope.launch(Dispatchers.Main) {
                    flutterApi?.conversationListSubscriptionConnectedReject(
                        subscriptionHandle, e.message ?: ""
                    ) {}
                }
            }
        }

        scope.launch {
            try {
                subscription.terminated.await()
                scope.launch(Dispatchers.Main) {
                    flutterApi?.conversationListSubscriptionTerminatedResolve(subscriptionHandle) {}
                }
            } catch (e: Exception) {
                scope.launch(Dispatchers.Main) {
                    flutterApi?.conversationListSubscriptionTerminatedReject(
                        subscriptionHandle, e.message ?: ""
                    ) {}
                }
            }
        }
    }

    override fun sessionOnError(handle: Long, subscriptionHandle: Long) {
        val session = sessions[handle] ?: throw FlutterError(
            "null-error",
            "Invalid session handle $handle",
            "",
        )

        val subscription = session.onError { error ->
            scope.launch(Dispatchers.Main) {
                flutterApi?.newSessionError(subscriptionHandle, error.message ?: "") {}
            }
        }

        sessionOnErrorSubscriptions[subscriptionHandle] = subscription
    }

    override fun sessionUploadFile(
        handle: Long,
        bytes: ByteArray,
        metadata: GenericFileMetadata,
        callback: (Result<String>) -> Unit
    ) {
        val session = sessions[handle]
        if (session == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error", "Invalid session handle $handle", ""
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            val token = session.uploadFile(
                bytes, com.talkjs.core.GenericFileMetadata(filename = metadata.filename)
            )
            callback(Result.success(token))
        }
    }

    override fun sessionUploadImage(
        handle: Long,
        bytes: ByteArray,
        metadata: ImageFileMetadata,
        callback: (Result<String>) -> Unit
    ) {
        val session = sessions[handle]
        if (session == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error", "Invalid session handle $handle", ""
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            val token = session.uploadImage(
                bytes, com.talkjs.core.ImageFileMetadata(
                    filename = metadata.filename,
                    width = metadata.width?.toInt(),
                    height = metadata.height?.toInt(),
                )
            )
            callback(Result.success(token))
        }
    }

    override fun sessionUploadVideo(
        handle: Long,
        bytes: ByteArray,
        metadata: VideoFileMetadata,
        callback: (Result<String>) -> Unit
    ) {
        val session = sessions[handle]
        if (session == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error", "Invalid session handle $handle", ""
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            val token = session.uploadVideo(
                bytes, com.talkjs.core.VideoFileMetadata(
                    filename = metadata.filename,
                    width = metadata.width?.toInt(),
                    height = metadata.height?.toInt(),
                    duration = metadata.duration,
                )
            )
            callback(Result.success(token))
        }
    }

    override fun sessionUploadAudio(
        handle: Long,
        bytes: ByteArray,
        metadata: AudioFileMetadata,
        callback: (Result<String>) -> Unit
    ) {
        val session = sessions[handle]
        if (session == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error", "Invalid session handle $handle", ""
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            val token = session.uploadAudio(
                bytes, com.talkjs.core.AudioFileMetadata(
                    filename = metadata.filename,
                    duration = metadata.duration,
                )
            )
            callback(Result.success(token))
        }
    }

    override fun sessionUploadVoice(
        handle: Long,
        bytes: ByteArray,
        metadata: VoiceRecordingFileMetadata,
        callback: (Result<String>) -> Unit
    ) {
        val session = sessions[handle]
        if (session == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error", "Invalid session handle $handle", ""
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            val token = session.uploadVoice(
                bytes, com.talkjs.core.VoiceRecordingFileMetadata(
                    filename = metadata.filename,
                    duration = metadata.duration,
                )
            )
            callback(Result.success(token))
        }
    }

    // ConversationListSubscription
    override fun conversationListSubscriptionDeleteHandle(handle: Long) {
        println("Kotlin: conversationListSubscriptionDeleteHandle $handle")

        conversationListSubscriptions.remove(handle)
    }

    override fun conversationListSubscriptionLoadMore(
        handle: Long, count: Long?, callback: (Result<Unit>) -> Unit
    ) {
        val subscription = conversationListSubscriptions[handle]
        if (subscription == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid conversation list subscription handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            subscription.loadMore(count?.toInt())
            callback(Result.success(Unit))
        }
    }

    override fun conversationListSubscriptionUnsubscribe(handle: Long) {
        val subscription = conversationListSubscriptions[handle] ?: throw FlutterError(
            "null-error",
            "Invalid conversation list subscription handle $handle",
            "",
        )

        subscription.unsubscribe()
    }

    // ErrorSubscription
    override fun sessionOnErrorDeleteHandle(handle: Long) {
        println("Kotlin: sessionOnErrorDeleteHandle $handle")

        sessionOnErrorSubscriptions.remove(handle)
    }

    override fun sessionOnErrorUnsubscribe(handle: Long) {
        val subscription = sessionOnErrorSubscriptions[handle] ?: throw FlutterError(
            "null-error",
            "Invalid error subscription handle $handle",
            "",
        )

        subscription.unsubscribe()
    }

    // User
    override fun userDeleteHandle(handle: Long) {
        println("Kotlin: userDeleteHandle $handle")

        users.remove(handle)
    }

    override fun userGet(
        handle: Long, callback: (Result<String?>) -> Unit
    ) {
        val ref = users[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid user handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            val snapshot = ref.get()
            callback(Result.success(snapshot?.let { jsonFormat.encodeToString(it) }))
        }
    }

    override fun userSet(
        handle: Long,
        name: String?,
        custom: Map<String, String?>?,
        locale: String?,
        photoUrl: String?,
        role: String?,
        welcomeMessage: String?,
        email: List<String>?,
        phone: List<String>?,
        pushTokens: Map<String, Boolean?>?,
        callback: (Result<Unit>) -> Unit,
    ) {
        val ref = users[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid user handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.set(
                name = name,
                custom = custom,
                locale = locale,
                photoUrl = photoUrl,
                role = role,
                welcomeMessage = welcomeMessage,
                email = email,
                phone = phone,
                pushTokens = pushTokens,
            )
            callback(Result.success(Unit))
        }
    }

    override fun userCreateIfNotExists(
        handle: Long,
        name: String,
        custom: Map<String, String>?,
        locale: String?,
        photoUrl: String?,
        role: String?,
        welcomeMessage: String?,
        email: List<String>?,
        phone: List<String>?,
        pushTokens: Map<String, Boolean>?,
        callback: (Result<Unit>) -> Unit,
    ) {
        val ref = users[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid user handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.createIfNotExists(
                name = name,
                custom = custom,
                locale = locale,
                photoUrl = photoUrl,
                role = role,
                welcomeMessage = welcomeMessage,
                email = email,
                phone = phone,
                pushTokens = pushTokens,
            )
            callback(Result.success(Unit))
        }
    }

    override fun userDeleteFields(
        handle: Long, fields: List<String>, callback: (Result<Unit>) -> Unit
    ) {
        val ref = users[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid user handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.deleteFields(*fields.toTypedArray())
            callback(Result.success(Unit))
        }
    }

    override fun userSubscribe(handle: Long, subscriptionHandle: Long) {
        val ref = users[handle] ?: throw FlutterError(
            "null-error",
            "Invalid user handle $handle",
            "",
        )

        val subscription = ref.subscribe { snapshot ->
            scope.launch(Dispatchers.Main) {
                flutterApi?.newUserSnapshot(
                    subscriptionHandle,
                    snapshot?.let { jsonFormat.encodeToString(it) },
                ) {}
            }
        }

        userSubscriptions[subscriptionHandle] = subscription

        scope.launch {
            try {
                subscription.connected.await()
                scope.launch(Dispatchers.Main) {
                    flutterApi?.userSubscriptionConnectedResolve(subscriptionHandle) {}
                }
            } catch (e: Exception) {
                scope.launch(Dispatchers.Main) {
                    flutterApi?.userSubscriptionConnectedReject(
                        subscriptionHandle, e.message ?: ""
                    ) {}
                }
            }
        }

        scope.launch {
            try {
                subscription.terminated.await()
                scope.launch(Dispatchers.Main) {
                    flutterApi?.userSubscriptionTerminatedResolve(subscriptionHandle) {}
                }
            } catch (e: Exception) {
                scope.launch(Dispatchers.Main) {
                    flutterApi?.userSubscriptionTerminatedReject(
                        subscriptionHandle, e.message ?: ""
                    ) {}
                }
            }
        }
    }

    override fun userSubscribeOnline(handle: Long, subscriptionHandle: Long) {
        val ref = users[handle] ?: throw FlutterError(
            "null-error",
            "Invalid user handle $handle",
            "",
        )

        val subscription = ref.subscribeOnline { snapshot ->
            scope.launch(Dispatchers.Main) {
                flutterApi?.newUserOnlineSnapshot(
                    subscriptionHandle,
                    snapshot?.let { jsonFormat.encodeToString(it) },
                ) {}
            }
        }

        userOnlineSubscriptions[subscriptionHandle] = subscription

        scope.launch {
            try {
                subscription.connected.await()
                scope.launch(Dispatchers.Main) {
                    flutterApi?.userOnlineSubscriptionConnectedResolve(subscriptionHandle) {}
                }
            } catch (e: Exception) {
                scope.launch(Dispatchers.Main) {
                    flutterApi?.userOnlineSubscriptionConnectedReject(
                        subscriptionHandle, e.message ?: ""
                    ) {}
                }
            }
        }

        scope.launch {
            try {
                subscription.terminated.await()
                scope.launch(Dispatchers.Main) {
                    flutterApi?.userOnlineSubscriptionTerminatedResolve(subscriptionHandle) {}
                }
            } catch (e: Exception) {
                scope.launch(Dispatchers.Main) {
                    flutterApi?.userOnlineSubscriptionTerminatedReject(
                        subscriptionHandle, e.message ?: ""
                    ) {}
                }
            }
        }
    }

    // UserSubscription
    override fun userSubscriptionDeleteHandle(handle: Long) {
        println("Kotlin: userSubscriptionDeleteHandle $handle")

        userSubscriptions.remove(handle)
    }

    override fun userSubscriptionUnsubscribe(handle: Long) {
        val subscription = userSubscriptions[handle] ?: throw FlutterError(
            "null-error",
            "Invalid user subscription handle $handle",
            "",
        )

        subscription.unsubscribe()
    }

    // UserOnlineSubscription
    override fun userOnlineSubscriptionDeleteHandle(handle: Long) {
        println("Kotlin: userOnlineSubscriptionDeleteHandle $handle")

        userOnlineSubscriptions.remove(handle)
    }

    override fun userOnlineSubscriptionUnsubscribe(handle: Long) {
        val subscription = userOnlineSubscriptions[handle] ?: throw FlutterError(
            "null-error",
            "Invalid user online subscription handle $handle",
            "",
        )

        subscription.unsubscribe()
    }

    // Conversation
    override fun conversationDeleteHandle(handle: Long) {
        println("Kotlin: conversationDeleteHandle $handle")

        conversations.remove(handle)
    }

    override fun conversationGet(
        handle: Long, callback: (Result<String?>) -> Unit
    ) {
        val ref = conversations[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid conversation handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            val snapshot = ref.get()
            callback(
                Result.success(snapshot?.let { jsonFormat.encodeToString(it) })
            )
        }
    }

    override fun conversationSet(
        handle: Long,
        subject: String?,
        photoUrl: String?,
        welcomeMessages: List<String>?,
        custom: Map<String, String?>?,
        accessJson: String?,
        notifyJson: String?,
        callback: (Result<Unit>) -> Unit,
    ) {
        val ref = conversations[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid conversation handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.set(
                subject = subject,
                photoUrl = photoUrl,
                welcomeMessages = welcomeMessages,
                custom = custom,
                access = accessJson?.let { jsonFormat.decodeFromString(it) },
                notify = notifyJson?.let { jsonFormat.decodeFromString(it) },
            )
            callback(Result.success(Unit))
        }
    }

    override fun conversationCreateIfNotExists(
        handle: Long,
        subject: String?,
        photoUrl: String?,
        welcomeMessages: List<String>?,
        custom: Map<String, String>?,
        accessJson: String?,
        notifyJson: String?,
        callback: (Result<Unit>) -> Unit,
    ) {
        val ref = conversations[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid conversation handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.createIfNotExists(
                subject = subject,
                photoUrl = photoUrl,
                welcomeMessages = welcomeMessages,
                custom = custom,
                access = accessJson?.let { jsonFormat.decodeFromString(it) },
                notify = notifyJson?.let { jsonFormat.decodeFromString(it) },
            )
            callback(Result.success(Unit))
        }
    }

    override fun conversationDeleteFields(
        handle: Long, fields: List<String>, callback: (Result<Unit>) -> Unit
    ) {
        val ref = conversations[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid conversation handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.deleteFields(*fields.toTypedArray())
            callback(Result.success(Unit))
        }
    }

    override fun conversationMarkAsRead(
        handle: Long, callback: (Result<Unit>) -> Unit
    ) {
        val ref = conversations[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid conversation handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.markAsRead()
            callback(Result.success(Unit))
        }
    }

    override fun conversationMarkAsUnread(
        handle: Long, callback: (Result<Unit>) -> Unit
    ) {
        val ref = conversations[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid conversation handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.markAsUnread()
            callback(Result.success(Unit))
        }
    }

    override fun conversationMarkAsTyping(
        handle: Long, callback: (Result<Unit>) -> Unit
    ) {
        val ref = conversations[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid conversation handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.markAsTyping()
            callback(Result.success(Unit))
        }
    }

    override fun conversationParticipant(handle: Long, user: String): Long {
        val conversation = conversations[handle] ?: throw FlutterError(
            "null-error",
            "Invalid conversation handle $handle",
            "",
        )

        val ref = conversation.participant(user)

        val participantHandle = nextId
        nextId += 1

        participants[participantHandle] = ref

        return participantHandle
    }

    override fun conversationMessage(handle: Long, messageId: String): Long {
        val conversation = conversations[handle] ?: throw FlutterError(
            "null-error",
            "Invalid conversation handle $handle",
            "",
        )

        val ref = conversation.message(messageId)

        val messageHandle = nextId
        nextId += 1

        messages[messageHandle] = ref

        return messageHandle
    }

    override fun conversationSend(
        handle: Long,
        text: String,
        custom: Map<String, String>?,
        referencedMessage: String?,
        callback: (Result<MessageRefBuildData>) -> Unit,
    ) {
        val conversation = conversations[handle]
        if (conversation == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid conversation handle $handle",
                        "",
                    )
                )
            )
            return
        }

        val messageHandle = nextId
        nextId += 1

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            val ref = conversation.send(
                text = text,
                custom = custom,
                referencedMessage = referencedMessage,
            )

            messages[messageHandle] = ref

            callback(
                Result.success(
                    MessageRefBuildData(
                        handle = messageHandle,
                        id = ref.id,
                        conversationId = ref.conversationId,
                    )
                )
            )
        }
    }

    override fun conversationSendMessage(
        handle: Long,
        contentJson: String,
        custom: Map<String, String>?,
        referencedMessage: String?,
        callback: (Result<MessageRefBuildData>) -> Unit,
    ) {
        val conversation = conversations[handle]
        if (conversation == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid conversation handle $handle",
                        "",
                    )
                )
            )
            return
        }

        val messageHandle = nextId
        nextId += 1

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            val ref = conversation.send(
                content = jsonFormat.decodeFromString(contentJson),
                custom = custom,
                referencedMessage = referencedMessage,
            )

            messages[messageHandle] = ref

            callback(
                Result.success(
                    MessageRefBuildData(
                        handle = messageHandle,
                        id = ref.id,
                        conversationId = ref.conversationId,
                    )
                )
            )
        }
    }

    override fun conversationSubscribe(handle: Long, subscriptionHandle: Long) {
        val ref = conversations[handle] ?: throw FlutterError(
            "null-error",
            "Invalid conversation handle $handle",
            "",
        )

        val subscription = ref.subscribe { snapshot ->
            scope.launch(Dispatchers.Main) {
                flutterApi?.newConversationSnapshot(
                    subscriptionHandle,
                    snapshot?.let { jsonFormat.encodeToString(it) },
                ) {}
            }
        }

        conversationSubscriptions[subscriptionHandle] = subscription

        scope.launch {
            try {
                subscription.connected.await()
                scope.launch(Dispatchers.Main) {
                    flutterApi?.conversationSubscriptionConnectedResolve(subscriptionHandle) {}
                }
            } catch (e: Exception) {
                scope.launch(Dispatchers.Main) {
                    flutterApi?.conversationSubscriptionConnectedReject(
                        subscriptionHandle, e.message ?: ""
                    ) {}
                }
            }
        }

        scope.launch {
            try {
                subscription.terminated.await()
                scope.launch(Dispatchers.Main) {
                    flutterApi?.conversationSubscriptionTerminatedResolve(subscriptionHandle) {}
                }
            } catch (e: Exception) {
                scope.launch(Dispatchers.Main) {
                    flutterApi?.conversationSubscriptionTerminatedReject(
                        subscriptionHandle, e.message ?: ""
                    ) {}
                }
            }
        }
    }

    override fun conversationSubscribeMessages(handle: Long, subscriptionHandle: Long) {
        val ref = conversations[handle] ?: throw FlutterError(
            "null-error",
            "Invalid conversation handle $handle",
            "",
        )

        val subscription = ref.subscribeMessages { snapshot, loadedAll ->
            scope.launch(Dispatchers.Main) {
                flutterApi?.newMessageSnapshot(
                    subscriptionHandle,
                    snapshot?.let { jsonFormat.encodeToString(it) },
                    loadedAll,
                ) {}
            }
        }

        messageSubscriptions[subscriptionHandle] = subscription

        scope.launch {
            try {
                subscription.connected.await()
                scope.launch(Dispatchers.Main) {
                    flutterApi?.messageSubscriptionConnectedResolve(subscriptionHandle) {}
                }
            } catch (e: Exception) {
                scope.launch(Dispatchers.Main) {
                    flutterApi?.messageSubscriptionConnectedReject(
                        subscriptionHandle, e.message ?: ""
                    ) {}
                }
            }
        }

        scope.launch {
            try {
                subscription.terminated.await()
                scope.launch(Dispatchers.Main) {
                    flutterApi?.messageSubscriptionTerminatedResolve(subscriptionHandle) {}
                }
            } catch (e: Exception) {
                scope.launch(Dispatchers.Main) {
                    flutterApi?.messageSubscriptionTerminatedReject(
                        subscriptionHandle, e.message ?: ""
                    ) {}
                }
            }
        }
    }

    override fun conversationSubscribeParticipants(handle: Long, subscriptionHandle: Long) {
        val ref = conversations[handle] ?: throw FlutterError(
            "null-error",
            "Invalid conversation handle $handle",
            "",
        )

        val subscription = ref.subscribeParticipants { snapshot, loadedAll ->
            scope.launch(Dispatchers.Main) {
                flutterApi?.newParticipantSnapshot(
                    subscriptionHandle,
                    snapshot?.let { jsonFormat.encodeToString(it) },
                    loadedAll,
                ) {}
            }
        }

        participantSubscriptions[subscriptionHandle] = subscription

        scope.launch {
            try {
                subscription.connected.await()
                scope.launch(Dispatchers.Main) {
                    flutterApi?.participantSubscriptionConnectedResolve(subscriptionHandle) {}
                }
            } catch (e: Exception) {
                scope.launch(Dispatchers.Main) {
                    flutterApi?.participantSubscriptionConnectedReject(
                        subscriptionHandle, e.message ?: ""
                    ) {}
                }
            }
        }

        scope.launch {
            try {
                subscription.terminated.await()
                scope.launch(Dispatchers.Main) {
                    flutterApi?.participantSubscriptionTerminatedResolve(subscriptionHandle) {}
                }
            } catch (e: Exception) {
                scope.launch(Dispatchers.Main) {
                    flutterApi?.participantSubscriptionTerminatedReject(
                        subscriptionHandle, e.message ?: ""
                    ) {}
                }
            }
        }
    }

    override fun conversationSubscribeTyping(handle: Long, subscriptionHandle: Long) {
        val ref = conversations[handle] ?: throw FlutterError(
            "null-error",
            "Invalid conversation handle $handle",
            "",
        )

        val subscription = ref.subscribeTyping { snapshot ->
            scope.launch(Dispatchers.Main) {
                flutterApi?.newTypingSnapshot(
                    subscriptionHandle,
                    snapshot?.let { jsonFormat.encodeToString(it) },
                ) {}
            }
        }

        typingSubscriptions[subscriptionHandle] = subscription

        scope.launch {
            try {
                subscription.connected.await()
                scope.launch(Dispatchers.Main) {
                    flutterApi?.typingSubscriptionConnectedResolve(subscriptionHandle) {}
                }
            } catch (e: Exception) {
                scope.launch(Dispatchers.Main) {
                    flutterApi?.typingSubscriptionConnectedReject(
                        subscriptionHandle, e.message ?: ""
                    ) {}
                }
            }
        }

        scope.launch {
            try {
                subscription.terminated.await()
                scope.launch(Dispatchers.Main) {
                    flutterApi?.typingSubscriptionTerminatedResolve(subscriptionHandle) {}
                }
            } catch (e: Exception) {
                scope.launch(Dispatchers.Main) {
                    flutterApi?.typingSubscriptionTerminatedReject(
                        subscriptionHandle, e.message ?: ""
                    ) {}
                }
            }
        }
    }

    // ConversationSubscription
    override fun conversationSubscriptionDeleteHandle(handle: Long) {
        println("Kotlin: conversationSubscriptionDeleteHandle $handle")

        conversationSubscriptions.remove(handle)
    }

    override fun conversationSubscriptionUnsubscribe(handle: Long) {
        val subscription = conversationSubscriptions[handle] ?: throw FlutterError(
            "null-error",
            "Invalid conversation subscription handle $handle",
            "",
        )

        subscription.unsubscribe()
    }

    // MessageSubscription
    override fun messageSubscriptionDeleteHandle(handle: Long) {
        println("Kotlin: messageSubscriptionDeleteHandle $handle")

        messageSubscriptions.remove(handle)
    }

    override fun messageSubscriptionLoadMore(
        handle: Long, count: Long?, callback: (Result<Unit>) -> Unit
    ) {
        val subscription = messageSubscriptions[handle]
        if (subscription == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid message subscription handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            subscription.loadMore(count?.toInt())
            callback(Result.success(Unit))
        }
    }

    override fun messageSubscriptionUnsubscribe(handle: Long) {
        val subscription = messageSubscriptions[handle] ?: throw FlutterError(
            "null-error",
            "Invalid message subscription handle $handle",
            "",
        )

        subscription.unsubscribe()
    }

    // ParticipantSubscription
    override fun participantSubscriptionDeleteHandle(handle: Long) {
        println("Kotlin: participantSubscriptionDeleteHandle $handle")

        participantSubscriptions.remove(handle)
    }

    override fun participantSubscriptionLoadMore(
        handle: Long, count: Long?, callback: (Result<Unit>) -> Unit
    ) {
        val subscription = participantSubscriptions[handle]
        if (subscription == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid participant subscription handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            subscription.loadMore(count?.toInt())
            callback(Result.success(Unit))
        }
    }

    override fun participantSubscriptionUnsubscribe(handle: Long) {
        val subscription = participantSubscriptions[handle] ?: throw FlutterError(
            "null-error",
            "Invalid participant subscription handle $handle",
            "",
        )

        subscription.unsubscribe()
    }

    // TypingSubscription
    override fun typingSubscriptionDeleteHandle(handle: Long) {
        println("Kotlin: typingSubscriptionDeleteHandle $handle")

        typingSubscriptions.remove(handle)
    }

    override fun typingSubscriptionUnsubscribe(handle: Long) {
        val subscription = typingSubscriptions[handle] ?: throw FlutterError(
            "null-error",
            "Invalid typing subscription handle $handle",
            "",
        )

        subscription.unsubscribe()
    }

    // Participant
    override fun participantDeleteHandle(handle: Long) {
        println("Kotlin: participantDeleteHandle $handle")

        participants.remove(handle)
    }

    override fun participantGet(
        handle: Long, callback: (Result<String?>) -> Unit
    ) {
        val ref = participants[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid participant handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            val snapshot = ref.get()
            callback(
                Result.success(snapshot?.let { jsonFormat.encodeToString(it) })
            )
        }
    }

    override fun participantSet(
        handle: Long,
        accessJson: String?,
        notifyJson: String?,
        callback: (Result<Unit>) -> Unit,
    ) {
        val ref = participants[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid participant handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.set(
                access = accessJson?.let { jsonFormat.decodeFromString(it) },
                notify = notifyJson?.let { jsonFormat.decodeFromString(it) },
            )
            callback(Result.success(Unit))
        }
    }

    override fun participantEdit(
        handle: Long,
        accessJson: String?,
        notifyJson: String?,
        callback: (Result<Unit>) -> Unit,
    ) {
        val ref = participants[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid participant handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.edit(
                access = accessJson?.let { jsonFormat.decodeFromString(it) },
                notify = notifyJson?.let { jsonFormat.decodeFromString(it) },
            )
            callback(Result.success(Unit))
        }
    }

    override fun participantCreateIfNotExists(
        handle: Long,
        accessJson: String?,
        notifyJson: String?,
        callback: (Result<Unit>) -> Unit,
    ) {
        val ref = participants[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid participant handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.createIfNotExists(
                access = accessJson?.let { jsonFormat.decodeFromString(it) },
                notify = notifyJson?.let { jsonFormat.decodeFromString(it) },
            )
            callback(Result.success(Unit))
        }
    }

    override fun participantDeleteFields(
        handle: Long, fields: List<String>, callback: (Result<Unit>) -> Unit
    ) {
        val ref = participants[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid participant handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.deleteFields(*fields.toTypedArray())
            callback(Result.success(Unit))
        }
    }

    override fun participantDelete(
        handle: Long, callback: (Result<Unit>) -> Unit
    ) {
        val ref = participants[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid participant handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.delete()
            callback(Result.success(Unit))
        }
    }

    // Message
    override fun messageDeleteHandle(handle: Long) {
        println("Kotlin: messageDeleteHandle $handle")

        messages.remove(handle)
    }

    override fun messageGet(
        handle: Long, callback: (Result<String?>) -> Unit
    ) {
        val ref = messages[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid message handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            val snapshot = ref.get()
            callback(
                Result.success(snapshot?.let { jsonFormat.encodeToString(it) })
            )
        }
    }

    override fun messageEdit(
        handle: Long,
        text: String?,
        custom: Map<String, String?>?,
        callback: (Result<Unit>) -> Unit,
    ) {
        val ref = messages[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid message handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.edit(
                text = text,
                custom = custom,
            )
            callback(Result.success(Unit))
        }
    }

    override fun messageEditMessage(
        handle: Long,
        contentJson: String,
        custom: Map<String, String?>?,
        callback: (Result<Unit>) -> Unit,
    ) {
        val ref = messages[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid message handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.edit(
                content = jsonFormat.decodeFromString(contentJson),
                custom = custom,
            )
            callback(Result.success(Unit))
        }
    }

    override fun messageDeleteFields(
        handle: Long, fields: List<String>, callback: (Result<Unit>) -> Unit
    ) {
        val ref = messages[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid message handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.deleteFields(*fields.toTypedArray())
            callback(Result.success(Unit))
        }
    }

    override fun messageDelete(
        handle: Long, callback: (Result<Unit>) -> Unit
    ) {
        val ref = messages[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid message handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.delete()
            callback(Result.success(Unit))
        }
    }

    override fun messageReaction(handle: Long, emoji: String): Long {
        val message = messages[handle] ?: throw FlutterError(
            "null-error",
            "Invalid message handle $handle",
            "",
        )

        val ref = message.reaction(emoji)

        val reactionHandle = nextId
        nextId += 1

        reactions[reactionHandle] = ref

        return reactionHandle
    }

    // Reaction
    override fun reactionDeleteHandle(handle: Long) {
        println("Kotlin: reactionDeleteHandle $handle")

        reactions.remove(handle)
    }

    override fun reactionAdd(
        handle: Long, callback: (Result<Unit>) -> Unit
    ) {
        val ref = reactions[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid reaction handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.add()
            callback(Result.success(Unit))
        }
    }

    override fun reactionRemove(
        handle: Long, callback: (Result<Unit>) -> Unit
    ) {
        val ref = reactions[handle]
        if (ref == null) {
            callback(
                Result.failure(
                    FlutterError(
                        "null-error",
                        "Invalid reaction handle $handle",
                        "",
                    )
                )
            )
            return
        }

        scope.launch(start = CoroutineStart.UNDISPATCHED) {
            ref.remove()
            callback(Result.success(Unit))
        }
    }
}

class TalkjsCoreFlutterPlugin : FlutterPlugin {
    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val api = PigeonApiImplementation()
        CoreHostApi.setUp(binding.binaryMessenger, api)
        TestHostApi.setUp(binding.binaryMessenger, TestHostApiImpl())
        flutterApi = CoreFlutterApi(binding.binaryMessenger)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        CoreHostApi.setUp(binding.binaryMessenger, null)
        TestHostApi.setUp(binding.binaryMessenger, null)
        flutterApi = null
    }
}
