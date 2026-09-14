import ChatGPTConnect
import SwiftUI

struct ChatView: View {
  let account: ChatGPTAccount
  @Bindable var viewModel: SandboxViewModel

  @State private var isShowingAccount = false

  var body: some View {
    NavigationStack {
      ZStack {
        Color(.systemGroupedBackground)
          .ignoresSafeArea()

        Group {
          if viewModel.messages.isEmpty {
            EmptyConversationView()
          } else {
            MessageList(
              messages: viewModel.messages,
              isResponding: viewModel.isResponding
            )
          }
        }
      }
      .toolbar {
        ToolbarItem(placement: .topBarLeading) {
          Button {
            viewModel.resetConversation()
          } label: {
            Label("New Chat", systemImage: "square.and.pencil")
          }
          .disabled(viewModel.messages.isEmpty || viewModel.isResponding)
        }

        ToolbarItem(placement: .topBarTrailing) {
          Button {
            isShowingAccount = true
          } label: {
            Label("Account", systemImage: "person.crop.circle")
          }
        }
      }
      .safeAreaInset(edge: .bottom) {
        ComposerView(viewModel: viewModel)
      }
      .sheet(isPresented: $isShowingAccount) {
        AccountView(account: account, viewModel: viewModel)
          .presentationDetents([.medium, .large])
      }
    }
  }
}

private struct EmptyConversationView: View {
  var body: some View {
    VStack(spacing: 16) {
      Image(systemName: "sparkles")
        .font(.system(size: 34, weight: .medium))
        .foregroundStyle(.tint)
        .frame(width: 72, height: 72)
        .background(.tint.opacity(0.12), in: Circle())
        .accessibilityHidden(true)

      VStack(spacing: 6) {
        Text("How can I help?")
          .font(.title2.bold())
        Text("Ask anything below. The reply will appear as it streams.")
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
      }
    }
    .padding(32)
  }
}

private struct MessageList: View {
  let messages: [ChatGPTMessage]
  let isResponding: Bool

  private let bottomID = "conversation-bottom"

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(spacing: 14) {
          ForEach(messages) { message in
            MessageBubble(
              message: message,
              isStreaming: isStreaming(message)
            )
          }
          Color.clear
            .frame(height: 1)
            .id(bottomID)
        }
        .frame(maxWidth: 760)
        .padding(.horizontal, 16)
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
      }
      .scrollDismissesKeyboard(.interactively)
      .onChange(of: messages.last?.text) {
        withAnimation(.easeOut(duration: 0.2)) {
          proxy.scrollTo(bottomID, anchor: .bottom)
        }
      }
    }
  }

  private func isStreaming(_ message: ChatGPTMessage) -> Bool {
    isResponding && message.id == messages.last?.id && message.role == .assistant
  }
}

private struct MessageBubble: View {
  let message: ChatGPTMessage
  let isStreaming: Bool

  private var isUser: Bool {
    message.role == .user
  }

  var body: some View {
    HStack(alignment: .bottom) {
      if isUser {
        Spacer(minLength: 48)
      }

      VStack(alignment: .leading, spacing: 8) {
        if message.text.isEmpty, isStreaming {
          ProgressView()
            .controlSize(.small)
        } else {
          Text(message.text)
            .textSelection(.enabled)
        }
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .foregroundStyle(isUser ? Color.white : Color.primary)
      .background(
        isUser ? Color.accentColor : Color(.secondarySystemBackground),
        in: RoundedRectangle(cornerRadius: 18)
      )

      if !isUser {
        Spacer(minLength: 48)
      }
    }
  }
}

private struct ComposerView: View {
  @Bindable var viewModel: SandboxViewModel
  @FocusState private var isInputFocused: Bool

  var body: some View {
    HStack(alignment: .bottom, spacing: 10) {
      TextField("Message", text: $viewModel.draft, axis: .vertical)
        .focused($isInputFocused)
        .lineLimit(1...6)
        .textFieldStyle(.plain)
        .padding(.leading, 8)
        .padding(.vertical, 10)
        .submitLabel(.send)
        .onSubmit(submit)

      if viewModel.isResponding {
        ComposerButton(
          title: "Stop response",
          systemImage: "stop.fill",
          isEnabled: true,
          action: viewModel.stopResponse
        )
      } else {
        ComposerButton(
          title: "Send message",
          systemImage: "arrow.up",
          isEnabled: viewModel.canSend,
          action: submit
        )
      }
    }
    .padding(6)
    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 24))
    .overlay {
      RoundedRectangle(cornerRadius: 24)
        .stroke(.separator.opacity(0.35), lineWidth: 0.5)
    }
    .shadow(color: .black.opacity(0.06), radius: 12, y: 4)
    .frame(maxWidth: 760)
    .padding(.horizontal, 12)
    .padding(.top, 8)
    .padding(.bottom, 10)
    .frame(maxWidth: .infinity)
    .background(.bar)
    .toolbar {
      ToolbarItemGroup(placement: .keyboard) {
        Spacer()
        Button("Done") {
          isInputFocused = false
        }
      }
    }
  }

  private func submit() {
    guard viewModel.canSend else {
      return
    }
    viewModel.sendMessage()
    isInputFocused = false
  }
}

private struct ComposerButton: View {
  let title: String
  let systemImage: String
  let isEnabled: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: systemImage)
        .font(.system(size: 15, weight: .bold))
        .foregroundStyle(isEnabled ? Color.white : Color.secondary)
        .frame(width: 38, height: 38)
        .background(isEnabled ? Color.accentColor : Color(.tertiarySystemFill), in: Circle())
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
    .accessibilityLabel(title)
  }
}

private struct AccountView: View {
  let account: ChatGPTAccount
  @Bindable var viewModel: SandboxViewModel

  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      Form {
        Section("Account") {
          LabeledContent("Email", value: account.email ?? "Unavailable")
          LabeledContent("Plan", value: account.plan ?? "Unavailable")
        }

        ModelSelectionSection(viewModel: viewModel)

        Section {
          Button("Sign Out", role: .destructive) {
            Task {
              await viewModel.signOut()
              dismiss()
            }
          }
        }
      }
      .navigationTitle("Connection")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done", action: dismiss.callAsFunction)
        }
      }
    }
  }
}

private struct ModelSelectionSection: View {
  @Bindable var viewModel: SandboxViewModel

  var body: some View {
    Section("Live model catalog") {
      if viewModel.isLoadingModels, viewModel.models.isEmpty {
        ProgressView("Loading available models…")
      } else if viewModel.models.isEmpty {
        ContentUnavailableView(
          "No models loaded",
          systemImage: "exclamationmark.arrow.triangle.2.circlepath"
        )
        refreshButton
      } else {
        Picker("Model", selection: modelSelection) {
          ForEach(viewModel.models) { model in
            Text(model.displayName).tag(model.id)
          }
        }

        if let model = viewModel.selectedModel {
          modelDetails(model)
        }

        if let model = viewModel.selectedModel, !model.supportedReasoningEfforts.isEmpty {
          Picker("Reasoning", selection: reasoningSelection) {
            ForEach(model.supportedReasoningEfforts) { option in
              Text(option.effort.rawValue.capitalized).tag(option.id)
            }
          }
        }

        refreshButton
      }
    }
  }

  private var modelSelection: Binding<String> {
    Binding(
      get: { viewModel.selectedModelID },
      set: { viewModel.selectModel(id: $0) }
    )
  }

  private var reasoningSelection: Binding<String> {
    Binding(
      get: { viewModel.selectedReasoningEffortID },
      set: { viewModel.selectReasoningEffort(id: $0) }
    )
  }

  private var refreshButton: some View {
    Button("Refresh Models", systemImage: "arrow.clockwise") {
      Task {
        await viewModel.loadModels()
      }
    }
    .disabled(viewModel.isLoadingModels)
  }

  @ViewBuilder
  private func modelDetails(_ model: ChatGPTModel) -> some View {
    if let description = model.description {
      Text(description)
        .font(.footnote)
        .foregroundStyle(.secondary)
    }
    Text(model.id)
      .font(.caption.monospaced())
      .foregroundStyle(.secondary)
      .textSelection(.enabled)
  }
}
