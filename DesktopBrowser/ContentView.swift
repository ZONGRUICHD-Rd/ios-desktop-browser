import SwiftUI

struct ContentView: View {
    @StateObject private var model = BrowserModel()
    @FocusState private var addressFocused: Bool

    var body: some View {
        NavigationStack {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: model.currentURL?.scheme == "https" ? "lock.fill" : "lock.open.fill")
                    .foregroundStyle(.secondary)
                    .font(.caption)
                TextField("输入网址或搜索", text: $model.addressText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .focused($addressFocused)
                    .onSubmit {
                        model.loadAddress(model.addressText)
                        addressFocused = false
                    }
                if !model.addressText.isEmpty {
                    Button {
                        model.addressText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                if model.isLoading {
                    Button { model.stop() } label: {
                        Image(systemName: "xmark")
                    }
                } else {
                    Button { model.reload() } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.horizontal, 12)
            .padding(.top, 8)
            if model.isLoading {
                ProgressView(value: model.estimatedProgress)
                    .progressViewStyle(.linear)
                    .padding(.horizontal, 12)
                    .padding(.top, 4)
            }
            DesktopWebView(model: model)
                .ignoresSafeArea(.keyboard, edges: .bottom)
            HStack(spacing: 0) {
                toolbarButton("chevron.left", disabled: !model.canGoBack) { model.goBack() }
                toolbarButton("chevron.right", disabled: !model.canGoForward) { model.goForward() }
                toolbarButton("house", disabled: false) { model.goHome() }
                Spacer()
                Button {
                    model.toggleDesktopMode()
                } label: {
                    Label(model.desktopMode ? "桌面版" : "手机版", systemImage: model.desktopMode ? "desktopcomputer" : "iphone")
                        .font(.caption)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(model.desktopMode ? Color.blue.opacity(0.15) : Color(.secondarySystemBackground))
                        .foregroundStyle(model.desktopMode ? .blue : .primary)
                        .clipShape(Capsule())
                }
                Spacer()
                if let url = model.currentURL {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .padding(.horizontal, 12)
                }
                Button {
                    model.reload()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .padding(.horizontal, 12)
            }
            .font(.title3)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))
            .overlay(Divider(), alignment: .top)
        }
        }
        .navigationTitle(model.pageTitle.isEmpty ? "桌面浏览器" : model.pageTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func toolbarButton(_ systemName: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
        }
        .disabled(disabled)
        .opacity(disabled ? 0.35 : 1)
        .padding(.horizontal, 12)
    }
}

#Preview {
    ContentView()
}
