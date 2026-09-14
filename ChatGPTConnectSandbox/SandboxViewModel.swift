import ChatGPTConnect
import Foundation
import Observation

@MainActor
@Observable
final class SandboxViewModel {
  private static let preferredModelID = "gpt-5.6-luna"

  private static let instructions = """
    You are ChatGPT in a small native Apple-platform test application. Be helpful, accurate, and \
    concise. Use plain text unless formatting materially improves the answer.
    """

  var account: ChatGPTAccount?
  var authorization: ChatGPTBrowserAuthorization?
  var models: [ChatGPTModel] = []
  var selectedModelID = ""
  var selectedReasoningEffortID = ""
  var messages: [ChatGPTMessage] = []
  var draft = ""
  var errorMessage: String?
  var isRestoringSession = true
  var isLoggingIn = false
  var isLoadingModels = false
  var isResponding = false
  var latestUsage: ChatGPTTokenUsage?

  @ObservationIgnored private let client: ChatGPTConnectClient
  @ObservationIgnored private var didRestoreSession = false
  @ObservationIgnored private var conversationID = UUID()
  @ObservationIgnored private var loginTask: Task<Void, Never>?
  @ObservationIgnored private var responseTask: Task<Void, Never>?

  init(
    client: ChatGPTConnectClient = ChatGPTConnectClient(
      configuration: ChatGPTConnectConfiguration(
        keychainService: "in.kodlabs.ChatGPTConnectSandbox.browser-oauth"
      )
    )
  ) {
    self.client = client
  }

  func restoreSession() async {
    guard !didRestoreSession else {
      return
    }
    didRestoreSession = true
    defer { isRestoringSession = false }
    do {
      account = try await client.restoreSession()
      if account != nil {
        await loadModels()
      }
    } catch {
      present(error)
    }
  }

  func startLogin() {
    guard loginTask == nil else {
      return
    }
    errorMessage = nil
    isLoggingIn = true
    loginTask = Task { [weak self] in
      await self?.performLogin()
    }
  }

  func cancelLogin() {
    loginTask?.cancel()
    authorization = nil
  }

  func browserPresentationDismissed() {
    guard account == nil else {
      return
    }
    cancelLogin()
  }

  func loadModels() async {
    guard account != nil, !isLoadingModels else {
      return
    }
    isLoadingModels = true
    defer { isLoadingModels = false }
    do {
      let availableModels = try await client.availableModels()
      try selectInitialModel(from: availableModels)
    } catch {
      present(error)
    }
  }

  func selectModel(id: String) {
    guard let model = models.first(where: { $0.id == id }) else {
      return
    }
    selectedModelID = model.id
    selectRecommendedReasoning(for: model)
  }

  func selectReasoningEffort(id: String) {
    guard selectedModel?.supportedReasoningEfforts.contains(where: { $0.id == id }) == true else {
      return
    }
    selectedReasoningEffortID = id
  }

  func signOut() async {
    let activeResponse = responseTask
    activeResponse?.cancel()
    await activeResponse?.value

    do {
      try await client.signOut()
      account = nil
      models = []
      selectedModelID = ""
      selectedReasoningEffortID = ""
      resetConversation()
    } catch {
      present(error)
    }
  }

  func sendMessage() {
    let prompt = draft.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !prompt.isEmpty, !isResponding else {
      return
    }
    guard let model = selectedModel else {
      present(ChatGPTConnectError.invalidRequest("Select an available model first."))
      return
    }

    errorMessage = nil
    latestUsage = nil
    messages.append(ChatGPTMessage(role: .user, text: prompt))
    draft = ""

    let request = makeResponseRequest(model: model)
    let assistantID = UUID()
    messages.append(ChatGPTMessage(id: assistantID, role: .assistant, text: ""))
    isResponding = true
    responseTask = Task { [weak self] in
      await self?.receiveResponse(request, assistantID: assistantID)
    }
  }

  func stopResponse() {
    responseTask?.cancel()
  }

  func resetConversation() {
    guard !isResponding else {
      return
    }
    messages = []
    latestUsage = nil
    conversationID = UUID()
  }

  private func performLogin() async {
    defer {
      isLoggingIn = false
      loginTask = nil
    }

    do {
      let pendingAuthorization = try await client.beginBrowserLogin()
      try Task.checkCancellation()
      authorization = pendingAuthorization
      account = try await client.completeBrowserLogin(pendingAuthorization)
      authorization = nil
      await loadModels()
    } catch is CancellationError {
      authorization = nil
    } catch {
      authorization = nil
      present(error)
    }
  }

  private func selectInitialModel(from availableModels: [ChatGPTModel]) throws {
    guard let firstModel = availableModels.first else {
      throw ChatGPTConnectError.invalidResponse
    }
    models = availableModels
    let initialModel =
      availableModels.first { $0.id == selectedModelID }
      ?? availableModels.first { $0.id == Self.preferredModelID }
      ?? firstModel
    selectModel(id: initialModel.id)
  }

  private func selectRecommendedReasoning(for model: ChatGPTModel) {
    let efforts = model.supportedReasoningEfforts
    if efforts.contains(where: { $0.id == selectedReasoningEffortID }) {
      return
    }
    let recommended = model.defaultReasoningEffort?.rawValue
    selectedReasoningEffortID =
      efforts.first(where: { $0.id == recommended })?.id
      ?? efforts.first?.id
      ?? ""
  }

  private func makeResponseRequest(model: ChatGPTModel) -> ChatGPTResponseRequest {
    ChatGPTResponseRequest(
      model: model.id,
      instructions: Self.instructions,
      messages: messages,
      conversationID: conversationID,
      reasoningEffort: selectedReasoningEffort,
      reasoningSummary: model.supportsReasoningSummary ? .auto : nil,
      textVerbosity: model.supportsTextVerbosity ? model.defaultTextVerbosity : nil
    )
  }

  private func receiveResponse(
    _ request: ChatGPTResponseRequest,
    assistantID: UUID
  ) async {
    do {
      let stream = try await client.streamResponse(request)
      for try await event in stream {
        try Task.checkCancellation()
        apply(event, to: assistantID)
      }
      finishResponse()
    } catch is CancellationError {
      removeEmptyAssistantMessage(assistantID)
      finishResponse()
    } catch {
      removeEmptyAssistantMessage(assistantID)
      finishResponse()
      present(error)
    }
  }

  private func apply(_ event: ChatGPTStreamEvent, to assistantID: UUID) {
    switch event {
    case .responseStarted:
      break
    case .textDelta(let text):
      append(text, to: assistantID)
    case .completed(let metadata):
      latestUsage = metadata.usage
    }
  }
}

private extension SandboxViewModel {
  private func append(_ text: String, to messageID: UUID) {
    guard let index = messages.firstIndex(where: { $0.id == messageID }) else {
      return
    }
    let message = messages[index]
    messages[index] = ChatGPTMessage(
      id: message.id,
      role: message.role,
      text: message.text + text
    )
  }

  private func removeEmptyAssistantMessage(_ messageID: UUID) {
    guard let index = messages.firstIndex(where: { $0.id == messageID }) else {
      return
    }
    if messages[index].text.isEmpty {
      messages.remove(at: index)
    }
  }

  private func finishResponse() {
    isResponding = false
    responseTask = nil
  }

  private func present(_ error: any Error) {
    let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    guard let requestID = (error as? ChatGPTConnectError)?.requestID else {
      errorMessage = description
      return
    }
    errorMessage = "\(description)\n\nRequest ID: \(requestID)"
  }

}

extension SandboxViewModel {
  var selectedModel: ChatGPTModel? {
    models.first { $0.id == selectedModelID }
  }

  var selectedReasoningEffort: ChatGPTReasoningEffort? {
    selectedModel?.supportedReasoningEfforts
      .first { $0.id == selectedReasoningEffortID }?
      .effort
  }

  var canSend: Bool {
    selectedModel != nil
      && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      && !isResponding
  }
}
