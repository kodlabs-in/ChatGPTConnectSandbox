# ChatGPTConnectSandbox

A small SwiftUI app for validating [ChatGPTConnect](https://github.com/kodlabs-in/ChatGPTConnect)
on physical iPhone and iPad devices.

The app demonstrates:

- Browser-based ChatGPT OAuth with PKCE
- Device-local session restoration and sign-out
- Live subscription model discovery
- Model-aware reasoning selection
- Streamed chat responses, cancellation, errors, request IDs, and token usage
- An adaptive SwiftUI chat interface for iPhone and iPad

The dependency is pinned to the exact public package release recorded in `Package.resolved`; it
does not use a relative local package path.

## Run

1. Open `ChatGPTConnectSandbox.xcodeproj` in Xcode.
2. Select a connected physical iPhone or iPad.
3. Build and run the `ChatGPTConnectSandbox` scheme.
4. Sign in with your own ChatGPT account.
5. Confirm the live model selection and send a message.

No OpenAI API key is required. Each installation uses the signed-in user's own ChatGPT/Codex
access. ChatGPTConnect is an experimental, unofficial compatibility package; read its
[supportability notes](https://github.com/kodlabs-in/ChatGPTConnect/blob/main/docs/SUPPORTABILITY.md)
before using it in a distributed product.

## Development checks

```bash
make format
make check
```

The repository intentionally excludes Xcode `xcuserdata`, Derived Data, package build caches, and
other machine-specific files.
