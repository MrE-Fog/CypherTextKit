import CypherMessaging

@available(macOS 12, iOS 15, *)
public protocol Plugin {
    static var pluginIdentifier: String { get }
    
    func onRekey(withUser: Username, deviceId: DeviceId, messenger: CypherMessenger) async throws
    func onDeviceRegisteryRequest(_ config: UserDeviceConfig, messenger: CypherMessenger) async throws
    func onReceiveMessage(_ message: ReceivedMessageContext) async throws -> ProcessMessageAction?
    func onSendMessage(_ message: SentMessageContext) async throws -> SendMessageAction?
    func createPrivateChatMetadata(withUser otherUser: Username, messenger: CypherMessenger) async throws -> Document
    func createContactMetadata(for username: Username, messenger: CypherMessenger) async throws -> Document
    func onMessageChange(_ message: AnyChatMessage)
    func onCreateContact(_ contact: DecryptedModel<ContactModel>, messenger: CypherMessenger)
    func onCreateConversation(_ conversation: AnyConversation)
    func onCreateChatMessage(_ conversation: AnyChatMessage)
    func onContactIdentityChange(username: Username, messenger: CypherMessenger)
    func onP2PClientOpen(_ client: P2PClient, messenger: CypherMessenger)
    func onP2PClientClose(messenger: CypherMessenger)
}

@available(macOS 12, iOS 15, *)
extension Plugin {
    public var pluginIdentifier: String { Self.pluginIdentifier }
}

@available(macOS 12, iOS 15, *)
extension Contact {
    public func withMetadata<P: Plugin, C: Codable, Result>(
        ofType type: C.Type,
        forPlugin plugin: P.Type,
        run: (inout C) throws -> Result
    ) throws -> Result {
        let pluginStorage = self.metadata[plugin.pluginIdentifier] ?? Document()
        var metadata = try BSONDecoder().decode(type, fromPrimitive: pluginStorage)
        let result = try run(&metadata)
        self.metadata[plugin.pluginIdentifier] = try BSONEncoder().encode(metadata)
        
        return result
    }
    
    public func modifyMetadata<P: Plugin, C: Codable, Result>(
        ofType type: C.Type,
        forPlugin plugin: P.Type,
        run: (inout C) throws -> Result
    ) async throws -> Result {
        let result = try withMetadata(ofType: type, forPlugin: plugin, run: run)
        
        try await self.save()
        return result
    }
}

@available(macOS 12, iOS 15, *)
extension AnyConversation {
    public func withMetadata<P: Plugin, C: Codable, Result>(
        ofType type: C.Type,
        forPlugin plugin: P.Type,
        run: (inout C) throws -> Result
    ) throws -> Result {
        let pluginStorage = self.conversation.metadata[plugin.pluginIdentifier] ?? Document()
        var metadata = try BSONDecoder().decode(type, fromPrimitive: pluginStorage)
        let result = try run(&metadata)
        self.conversation.metadata[plugin.pluginIdentifier] = try BSONEncoder().encode(metadata)
        
        return result
    }
    
    public func modifyMetadata<P: Plugin, C: Codable, Result>(
        ofType type: C.Type,
        forPlugin plugin: P.Type,
        run: (inout C) throws -> Result
    ) async throws -> Result {
        let result = try withMetadata(ofType: type, forPlugin: plugin, run: run)
        try await self.save()
        return result
    }
}

@available(macOS 12, iOS 15, *)
extension CypherMessenger {
    public func withCustomConfig<P: Plugin, C: Codable, Result>(
        ofType type: C.Type,
        forPlugin plugin: P.Type,
        run: @escaping (C) async throws -> Result
    ) async throws -> Result {
        let customConfig = try await readCustomConfig()
        let pluginStorage = customConfig[plugin.pluginIdentifier] ?? Document()
        let metadata = try BSONDecoder().decode(type, fromPrimitive: pluginStorage)
        return try await run(metadata)
    }
    
    public func modifyCustomConfig<P: Plugin, C: Codable, Result>(
        ofType type: C.Type,
        forPlugin plugin: P.Type,
        run: @escaping (inout C) async throws -> Result
    ) async throws -> Result {
        var customConfig = try await readCustomConfig()
        let pluginStorage = customConfig[plugin.pluginIdentifier] ?? Document()
        var metadata = try BSONDecoder().decode(type, fromPrimitive: pluginStorage)
        let result = try await run(&metadata)
        customConfig[plugin.pluginIdentifier] = try BSONEncoder().encode(metadata)
        try await self.writeCustomConfig(customConfig)
        return result
    }
}
