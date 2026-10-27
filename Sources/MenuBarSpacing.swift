import AppKit
import SwiftUI

@MainActor
final class SpacingModel: ObservableObject {
    @Published var spacing: Double = 16 { didSet { if spacing != oldValue { draftChanged() } } }
    @Published var padding: Double = 16 { didSet { if padding != oldValue { draftChanged() } } }
    @Published var saved: SpacingValues = .systemDefault
    @Published var readable = false
    @Published var message: String?
    @Published var isError = false
    @Published var previous: SpacingValues?
    @Published var showHelp = false
    @Published var draftTouched = false
    @Published var previewRunning = false
    private let preferences: SpacingPreferences
    private var loadingControls = false
    private var previewProcess: Process?

    let majorVersion: Int
    static func supportsAdjustment(on major: Int) -> Bool { (14...27).contains(major) }
    var supported: Bool { Self.supportsAdjustment(on: majorVersion) }
    var limitedCompatibility: Bool { majorVersion == 27 }
    var draft: SpacingValues { .init(spacing: Int(spacing), padding: Int(padding)) }
    var changed: Bool { readable && draftTouched && draft != saved }
    var canApply: Bool { supported && changed }

    init(preferences: SpacingPreferences = SpacingPreferences(),
         majorVersion: Int = ProcessInfo.processInfo.operatingSystemVersion.majorVersion) {
        self.preferences = preferences
        self.majorVersion = majorVersion
        reload(announce: false)
    }

    private func draftChanged() {
        guard !loadingControls else { return }
        draftTouched = true
        message = nil
    }

    private func setControls(_ values: SpacingValues) {
        loadingControls = true
        defer { loadingControls = false }
        // Defaults are only used to draw a preview, not written until Apply is clicked.
        spacing = Double(min(32, max(4, values.spacing ?? 16)))
        padding = Double(min(32, max(4, values.padding ?? 16)))
        draftTouched = false
    }

    func reload(announce: Bool = true) {
        do {
            saved = try preferences.read()
            readable = true
            setControls(saved)
            if announce { message = "已重新读取当前设置。"; isError = false }
        } catch {
            readable = false
            message = error.localizedDescription
            isError = true
        }
    }

    func preset(_ value: Int) {
        spacing = Double(value)
        padding = Double(value)
        message = nil
    }

    func save(_ values: SpacingValues, text: String) {
        guard supported || values == .systemDefault else { message = SpacingError.unsupported.localizedDescription; isError = true; return }
        do {
            previous = try preferences.write(values)
            saved = try preferences.read()
            readable = true
            setControls(saved)
            message = text
            isError = false
            if previewRunning { stopPreview(); startPreview() }
        } catch {
            message = error.localizedDescription
            isError = true
            if let actual = try? preferences.read() { saved = actual; setControls(actual) }
            else { readable = false }
        }
    }

    func apply() {
        save(draft, text: limitedCompatibility
             ? "已保存。重新打开对应的第三方应用后观察效果；系统图标可能不变。"
             : "已保存。重新打开对应的菜单栏应用，或注销后重新登录，查看效果。")
    }
    func restore() { save(.systemDefault, text: "已移除自定义值。重新打开对应应用后，查看系统默认效果。") }
    func undo() {
        guard let previous else { return }
        save(previous, text: "已撤销上次修改。重新打开对应应用后查看效果。")
    }

    func startPreview() {
        guard previewProcess == nil, let executable = Bundle.main.executableURL else { return }
        let process = Process()
        let output = Pipe()
        process.executableURL = executable
        process.arguments = ["--preview-status-items"]
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { [weak self] finished in
            let data = output.fileHandleForReading.readDataToEndOfFile()
            let measured = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
            DispatchQueue.main.async {
                guard let self, self.previewProcess === finished else { return }
                self.previewProcess = nil
                self.previewRunning = false
                if finished.terminationStatus == 0,
                   let width = measured?["symbolWidth"] as? Double, width > 0 {
                    self.message = "测试已结束：双箭头图标占用 \(Int(width)) 点宽度，仅代表本工具的示例。"
                    self.isError = false
                } else {
                    self.message = "测试图标未完成测量，可再次尝试。已保存的设置未改变。"
                    self.isError = true
                }
            }
        }
        do {
            try process.run()
            previewProcess = process
            previewRunning = true
            message = "右上角已显示 MBS 和双箭头测试图标，使用已保存的设置，30 秒后自动收起。"
            isError = false
        } catch {
            message = "无法启动菜单栏测试：\(error.localizedDescription)"
            isError = true
        }
    }

    func stopPreview() {
        guard let process = previewProcess else { return }
        previewProcess = nil
        previewRunning = false
        if process.isRunning { process.terminate() }
    }
}

struct SpacingView: View {
    @ObservedObject var model: SpacingModel
    @Environment(\.colorScheme) private var scheme
    private let blue = Color(red: 0.18, green: 0.38, blue: 0.88)

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    if model.limitedCompatibility { compatibilityNote }
                    preview
                    controls
                    explanation
                }
                .padding(28)
            }
            Divider()
            footer
        }
        .frame(minWidth: 600, minHeight: 720)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(blue)
        .sheet(isPresented: $model.showHelp) { help }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 15) {
            Image(systemName: "arrow.left.and.right.righttriangle.left.righttriangle.right")
                .font(.system(size: 25, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 55, height: 55)
                .background(LinearGradient(colors: [blue, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 16))
            VStack(alignment: .leading, spacing: 6) {
                Text("菜单栏间距").font(.system(size: 27, weight: .bold))
                Text("把常用图标，靠近一点。  v1.1").font(.system(size: 13)).foregroundStyle(.secondary)
            }
            Spacer()
            Text("macOS \(model.majorVersion)")
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 10).padding(.vertical, 6)
                .background(.quaternary, in: Capsule())
        }
    }

    private var compatibilityNote: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label("macOS 27 · 第三方图标兼容模式", systemImage: "info.circle.fill")
                .font(.system(size: 12, weight: .semibold))
            Text("可调整读取这些设置的第三方图标。Wi-Fi、电池、时钟等系统图标可能不变；留白参数也可能不影响外观。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(blue.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
    }

    private var preview: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("效果预览", systemImage: "menubar.rectangle")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Text("示意 · 以实际效果为准").font(.system(size: 10)).foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Image(systemName: "apple.logo").font(.system(size: 16))
                Text("访达").font(.system(size: 12, weight: .semibold))
                Spacer(minLength: 8)
                HStack(spacing: model.spacing * 0.5) {
                    ForEach(["sparkles", "magnifyingglass", "wifi", "speaker.wave.2.fill", "battery.100"], id: \.self) { name in
                        Image(systemName: name)
                            .font(.system(size: 14, weight: .medium))
                            .frame(width: name == "battery.100" ? 23 : 18)
                            .padding(.horizontal, model.padding * 0.15)
                    }
                }
                Text("09:41").font(.system(size: 12, weight: .medium, design: .rounded)).padding(.leading, 6)
            }
            .frame(height: 42)
            .padding(.horizontal, 15)
            .background(scheme == .dark ? Color.white.opacity(0.10) : Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 11))
            HStack(spacing: 5) {
                Circle().fill(model.readable ? Color.green : Color.orange).frame(width: 5, height: 5)
                Text("当前已保存：\(model.readable ? model.saved.description : "读取失败")")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .background(LinearGradient(colors: [blue.opacity(0.10), Color.cyan.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(blue.opacity(0.12)))
        .animation(.easeInOut(duration: 0.15), value: model.spacing)
        .animation(.easeInOut(duration: 0.15), value: model.padding)
    }

    private var controls: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("快捷选择").font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                Spacer()
                ForEach(Array(zip(["紧凑", "适中", "宽松"], [8, 12, 20])), id: \.1) { title, value in
                    Button { model.preset(value) } label: {
                        Text(title).font(.system(size: 12, weight: .medium))
                            .frame(width: 62, height: 30)
                            .background(model.spacing == Double(value) && model.padding == Double(value) ? blue.opacity(0.13) : Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
                            .foregroundStyle(model.spacing == Double(value) && model.padding == Double(value) ? blue : .primary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(title)预设，间距和留白均为\(value)")
                }
            }
            adjustment(title: "图标间距", subtitle: "调整相邻图标之间的距离", value: $model.spacing)
            Divider()
            adjustment(title: "选中区域留白", subtitle: "调整图标选中区域两侧的留白", value: $model.padding)
        }
        .padding(20)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.65), in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).strokeBorder(Color.secondary.opacity(0.12)))
        .disabled(!model.supported || !model.readable)
    }

    private func adjustment(title: String, subtitle: String, value: Binding<Double>) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 14, weight: .semibold))
                    Text(subtitle).font(.system(size: 11)).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(Int(value.wrappedValue))").font(.system(size: 19, weight: .semibold, design: .rounded))
                    .monospacedDigit().foregroundStyle(blue)
                    .frame(width: 42, height: 35)
                    .background(blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                Stepper(title, value: value, in: 4...32, step: 1).labelsHidden().fixedSize()
            }
            Slider(value: value, in: 4...32, step: 1).accessibilityLabel(title)
            HStack {
                Text("更紧凑"); Spacer(); Text("更宽松")
            }.font(.system(size: 10)).foregroundStyle(.tertiary)
        }
    }

    private var explanation: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !model.supported {
                Label(SpacingError.unsupported.localizedDescription, systemImage: "exclamationmark.triangle")
                    .foregroundStyle(.orange)
            } else if let message = model.message {
                Label(message, systemImage: model.isError ? "exclamationmark.circle" : "checkmark.circle.fill")
                    .foregroundStyle(model.isError ? Color.orange : Color.green)
            } else {
                Label("拖动滑块只更新预览，点击“应用间距”后才会保存。", systemImage: "slider.horizontal.3")
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle")
                Text(model.limitedCompatibility
                     ? "先应用，再用“菜单栏实测”查看本工具的真实图标；其他应用需分别重新打开。设置后无需常驻。"
                     : "保存后重新打开对应应用，或注销后重新登录。设置后无需常驻，仅调整右侧图标。")
                    .fixedSize(horizontal: false, vertical: true)
            }.foregroundStyle(.secondary)
        }
        .font(.system(size: 11))
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            Button("恢复系统默认") { model.restore() }
                .disabled(!model.readable || model.saved == .systemDefault)
            Menu {
                Button("重新读取当前设置") { model.reload() }
                Button("撤销上次修改") { model.undo() }.disabled(model.previous == nil || !model.supported)
                Divider()
                Button("如何让设置生效？") { model.showHelp = true }
            } label: {
                Image(systemName: "ellipsis.circle")
            }.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("更多操作")
            Spacer()
            Button(model.previewRunning ? "收起测试图标" : "菜单栏实测") {
                if model.previewRunning { model.stopPreview(); model.message = "已收起测试图标。" }
                else { model.startPreview() }
            }.disabled(!model.supported || !model.readable)
            Button("应用间距") { model.apply() }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!model.canApply)
        }
        .padding(.horizontal, 28).padding(.vertical, 17)
    }

    private var help: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label("让新的间距生效", systemImage: "info.circle.fill").font(.title2.bold())
            Text("1. 选择一个档位，或拖动两个滑块，再点击“应用间距”。")
            Text("2. 退出并重新打开带有菜单栏图标的应用，例如网盘、音乐或其他常驻工具。")
            Text("3. 点击“菜单栏实测”，右上角会出现使用已保存设置的 MBS 和双箭头示例，30 秒后自动收起。测试不修改设置。")
            if model.limitedCompatibility {
                Text("macOS 27 上仅验证了传统 AppKit 测试图标。系统图标和其他类型的图标可能忽略这些设置；注销或重启也不保证能改变它们。建议先调整“图标间距”，留白不一定改变占用宽度。")
                    .foregroundStyle(.secondary)
            } else {
                Text("若仍未变化，可保存工作后退出登录，再重新登录。")
            }
            Divider()
            Text("恢复系统默认会移除这两个自定义值。预览中的 16 仅用于示意，并不代表所有系统的默认值。此工具只修改当前用户在本机的菜单栏设置，关闭后设置仍然保留。")
                .font(.callout).foregroundStyle(.secondary)
            Text("macOS 14–26 沿用原有方式；macOS 27 提供有限兼容。使用系统隐藏偏好设置，后续系统升级可能影响效果。")
                .font(.caption).foregroundStyle(.secondary)
            HStack { Spacer(); Button("知道了") { model.showHelp = false }.keyboardShortcut(.defaultAction) }
        }
        .padding(28).frame(width: 470)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    var window: NSWindow?
    let model = SpacingModel()
    func applicationDidFinishLaunching(_ notification: Notification) {
        let appMenu = NSMenu()
        let mainMenu = NSMenu()
        let item = NSMenuItem()
        item.submenu = appMenu
        mainMenu.addItem(item)
        appMenu.addItem(withTitle: "关于菜单栏间距", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "隐藏菜单栏间距", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h")
        appMenu.addItem(withTitle: "退出菜单栏间距", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        NSApplication.shared.mainMenu = mainMenu

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 620, height: 800),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "菜单栏间距"
        window.titlebarAppearsTransparent = true
        window.contentMinSize = NSSize(width: 600, height: 720)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SpacingView(model: model))
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
        self.window = window
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) { model.stopPreview() }
}

@main
enum Main {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--self-test") {
            do { try runSelfCheck(); try runModelChecks(); print("PASS: preferences, read-back, defaults, undo, macOS 27 behavior, and future-version guard") }
            catch { fputs("FAIL: \(error)\n", stderr); exit(1) }
            return
        }
        if CommandLine.arguments.contains("--preview-status-items") {
            LiveMenuBarPreview.run()
            return
        }
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { application.run() }
    }
}
