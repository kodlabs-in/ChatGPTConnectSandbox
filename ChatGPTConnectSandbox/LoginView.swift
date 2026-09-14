import ChatGPTConnect
import SwiftUI

struct LoginView: View {
  @Bindable var viewModel: SandboxViewModel

  var body: some View {
    NavigationStack {
      VStack(spacing: 28) {
        Spacer()
        Image(systemName: "bubble.left.and.bubble.right.fill")
          .font(.system(size: 58))
          .foregroundStyle(.tint)
          .accessibilityHidden(true)

        VStack(spacing: 10) {
          Text("ChatGPTConnect")
            .font(.largeTitle.bold())
          Text(
            "Sign in with your own ChatGPT subscription. "
              + "Your session stays in this device's Keychain."
          )
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        }

        Button(action: viewModel.startLogin) {
          HStack {
            if viewModel.isLoggingIn {
              ProgressView()
            }
            Text(viewModel.isLoggingIn ? "Waiting for ChatGPT…" : "Login with ChatGPT")
          }
          .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(viewModel.isLoggingIn)

        Text("ChatGPT opens securely in Safari. No API key or application server is used.")
          .font(.footnote)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.center)
        Spacer()
      }
      .frame(maxWidth: 520)
      .padding(28)
      .frame(maxWidth: .infinity)
      .background(Color(.systemGroupedBackground))
      .sheet(
        item: $viewModel.authorization,
        onDismiss: viewModel.browserPresentationDismissed
      ) { authorization in
        ChatGPTLoginSafariView(
          authorization: authorization,
          onDismiss: viewModel.cancelLogin
        )
        .ignoresSafeArea()
      }
    }
  }
}
