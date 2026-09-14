//
//  ContentView.swift
//  ChatGPTConnectSandbox
//
//  Created by Prince on 13/09/26.
//

import ChatGPTConnect
import SwiftUI

struct ContentView: View {
  @State private var viewModel = SandboxViewModel()

  var body: some View {
    Group {
      if viewModel.isRestoringSession {
        ProgressView("Restoring ChatGPT session…")
      } else if let account = viewModel.account {
        ChatView(account: account, viewModel: viewModel)
      } else {
        LoginView(viewModel: viewModel)
      }
    }
    .task {
      await viewModel.restoreSession()
    }
    .alert(
      "Something went wrong",
      isPresented: errorPresentation,
      actions: {
        Button("OK") {
          viewModel.errorMessage = nil
        }
      },
      message: {
        Text(viewModel.errorMessage ?? "Please try again.")
      }
    )
  }

  private var errorPresentation: Binding<Bool> {
    Binding(
      get: { viewModel.errorMessage != nil },
      set: { isPresented in
        if !isPresented {
          viewModel.errorMessage = nil
        }
      }
    )
  }
}
