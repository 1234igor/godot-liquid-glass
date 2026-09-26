import AppKit
import SwiftUI

private enum DemoMetrics {
    static let window = CGSize(width: 1200, height: 800)
    static let glass = CGSize(width: 440, height: 96)
    static let bottomInset: CGFloat = 102
    static let cornerRadius: CGFloat = 34
}

private enum GlassVariant: String, CaseIterable {
    case regular
    case clear
    case regularTinted = "regular-tinted"
    case clearTinted = "clear-tinted"
    case identity

    static let selected: GlassVariant = {
        let argument = CommandLine.arguments.dropFirst().first { argument in
            GlassVariant(rawValue: argument) != nil
        }
        let stored = UserDefaults.standard.string(forKey: "GlassVariant")
        return GlassVariant(rawValue: argument ?? stored ?? "regular") ?? .regular
    }()

    var title: String {
        switch self {
        case .regular: "Regular"
        case .clear: "Clear"
        case .regularTinted: "Regular Tinted"
        case .clearTinted: "Clear Tinted"
        case .identity: "Identity"
        }
    }

    var material: SwiftUI.Glass {
        let coral = Color(red: 1.0, green: 0.22, blue: 0.28)
        switch self {
        case .regular:
            return SwiftUI.Glass.regular.interactive()
        case .clear:
            return SwiftUI.Glass.clear.interactive()
        case .regularTinted:
            return SwiftUI.Glass.regular.tint(coral).interactive()
        case .clearTinted:
            return SwiftUI.Glass.clear.tint(coral).interactive()
        case .identity:
            return SwiftUI.Glass.identity
        }
    }

    var needsLocalizedDimming: Bool {
        self == .clear || self == .clearTinted
    }
}

private enum DemoBackground: String, CaseIterable {
    case harbour
    case cityNight = "city-night"
    case prism
    case facade

    static let selected: DemoBackground = {
        let argument = CommandLine.arguments.dropFirst().first { argument in
            DemoBackground(rawValue: argument) != nil
        }
        let stored = UserDefaults.standard.string(forKey: "GlassBackground")
        return DemoBackground(rawValue: argument ?? stored ?? "harbour") ?? .harbour
    }()

    var title: String {
        switch self {
        case .harbour: "Harbour"
        case .cityNight: "City Night"
        case .prism: "Prism"
        case .facade: "Facade"
        }
    }
}

private final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}

@main
private struct LiquidGlassReferenceApp {
    @MainActor private static var appDelegate: AppDelegate?
    @MainActor private static var window: NSWindow?

    @MainActor static func main() {
        let application = NSApplication.shared
        let appDelegate = AppDelegate()
        application.delegate = appDelegate
        self.appDelegate = appDelegate
        application.setActivationPolicy(.regular)

        let content = DemoView(
            variant: GlassVariant.selected,
            background: DemoBackground.selected
        )
        .frame(width: DemoMetrics.window.width, height: DemoMetrics.window.height)
        .ignoresSafeArea()
        let styleMask: NSWindow.StyleMask = [.titled, .closable, .fullSizeContentView]
        let frame = CGRect(origin: .zero, size: DemoMetrics.window)
        let contentRect = NSWindow.contentRect(forFrameRect: frame, styleMask: styleMask)
        let window = NSWindow(
            contentRect: contentRect,
            styleMask: styleMask,
            backing: .buffered,
            defer: false
        )
        window.title = "Liquid Glass Reference - \(GlassVariant.selected.title) - \(DemoBackground.selected.title)"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        let hostingView = NSHostingView(rootView: content)
        hostingView.sizingOptions = []
        window.contentView = hostingView
        window.setFrame(frame, display: false)
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window

        application.activate(ignoringOtherApps: true)
        application.run()
    }
}

private struct DemoView: View {
    let variant: GlassVariant
    let background: DemoBackground

    private var backdrop: NSImage {
        guard let url = Bundle.module.url(forResource: background.rawValue, withExtension: "png"),
              let image = NSImage(contentsOf: url) else {
            fatalError("missing packaged \(background.rawValue).png")
        }
        return image
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            Image(nsImage: backdrop)
                .resizable()
                .scaledToFill()
                .frame(width: DemoMetrics.window.width, height: DemoMetrics.window.height)
                .clipped()

            PlaybackGlass(variant: variant)
                .frame(width: DemoMetrics.glass.width, height: DemoMetrics.glass.height)
                .padding(.bottom, DemoMetrics.bottomInset)
        }
    }
}

private struct PlaybackGlass: View {
    let variant: GlassVariant

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.18))
                    .frame(width: 56, height: 56)

                PlayGlyph()
                    .fill(.white)
                    .frame(width: 18, height: 22)
                    .offset(x: 1)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("Glass Horizon")
                    .font(.system(size: 17, weight: .semibold))
                Text("Harbour Sessions")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }

            Spacer(minLength: 12)

            EqualizerGlyph()
                .frame(width: 28, height: 25)

            Text("3:42")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.white.opacity(0.88))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            if variant.needsLocalizedDimming {
                RoundedRectangle(cornerRadius: DemoMetrics.cornerRadius)
                    .fill(.black.opacity(0.18))
            }
        }
        .glassEffect(variant.material, in: .rect(cornerRadius: DemoMetrics.cornerRadius))
    }
}

private struct PlayGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct EqualizerGlyph: View {
    private let heights: [CGFloat] = [10, 20, 15, 25]

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(Array(heights.enumerated()), id: \.offset) { _, height in
                Capsule()
                    .fill(.white.opacity(0.9))
                    .frame(width: 4, height: height)
            }
        }
    }
}
