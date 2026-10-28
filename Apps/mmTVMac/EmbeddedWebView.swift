import SwiftUI
import WebKit
import DesignSystem

/// Constrained WKWebView host for open frontends (HA Lovelace, Jellyfin Web).
struct EmbeddedWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: config)
        view.navigationDelegate = context.coordinator
        view.allowsBackForwardNavigationGestures = true
        view.setValue(false, forKey: "drawsBackground")
        view.load(URLRequest(url: url))
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        if nsView.url != url {
            nsView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {}
}

struct EmbeddedWebChrome: View {
    let title: String
    let url: URL
    let footnote: String
    let onClose: () -> Void
    let onOpenExternally: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Button(action: onClose) {
                    Label("返回", systemImage: "arrow.left")
                }
                .buttonStyle(.bordered)
                Text(title).font(.system(size: 18, weight: .medium))
                Text(url.absoluteString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(TVTheme.muted)
                    .lineLimit(1)
                Spacer()
                Button("系统浏览器打开", action: onOpenExternally)
                    .font(.system(size: 13))
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .background(TVTheme.panel)

            EmbeddedWebView(url: url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(footnote)
                .font(.system(size: 11))
                .foregroundStyle(TVTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 28)
                .padding(.vertical, 10)
                .background(TVTheme.background)
        }
        .background(TVTheme.background)
    }
}
