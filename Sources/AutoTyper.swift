import SwiftUI
import AppKit
import ApplicationServices
import Carbon

private enum Palette {
    static let background = Color(red: 0.97, green: 0.96, blue: 0.94)
    static let panel = Color.white
    static let accent = Color(red: 0.84, green: 0.28, blue: 0.13)
    static let muted = Color(red: 0.42, green: 0.43, blue: 0.44)
    static let ink = Color(red: 0.14, green: 0.16, blue: 0.17)
    static let rail = Color(red: 0.10, green: 0.13, blue: 0.14)
}

private extension Character {
    var isASCIIAlpha: Bool { unicodeScalars.count == 1 && unicodeScalars.first!.value < 128 && isLetter }
    var isUppercase: Bool { String(self) != String(self).lowercased() }
}

enum RunState: Equatable {
    case ready, countdown(Int), typing, paused, finished, stopped
}

@MainActor
final class TyperModel: ObservableObject {
    @Published var text = ""
    @Published var wpm = 60.0
    @Published var mistakes = true
    @Published var mistakeRate = 2.0
    @Published var naturalPauses = true
    @Published var progress = 0
    @Published var state: RunState = .ready
    @Published var notice = "Paste text, choose a pace, then press Start."

    private var runTask: Task<Void, Never>?
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private let hotKeyID = EventHotKeyID(signature: OSType(0x41545950), id: 1)

    init() { installEmergencyHotKey() }

    var characterCount: Int { text.count }
    var estimatedSeconds: Int {
        guard wpm > 0 else { return 0 }
        return Int(ceil(Double(characterCount) * 12 / wpm))
    }
    var statusLabel: String {
        switch state {
        case .ready: "READY"
        case .countdown: "GET READY"
        case .typing: "TYPING"
        case .paused: "PAUSED"
        case .finished: "COMPLETE"
        case .stopped: "STOPPED"
        }
    }
    var isBusy: Bool {
        switch state {
        case .countdown, .typing, .paused: true
        default: false
        }
    }

    func start() {
        guard !isBusy else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            notice = "Add some text to begin."
            return
        }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        guard AXIsProcessTrustedWithOptions(options) else {
            notice = "Allow AutoTyper in System Settings → Privacy & Security → Accessibility, then try again."
            return
        }
        let snapshot = Array(text)
        progress = 0
        state = .countdown(5)
        notice = "Switch to your destination and click where the text should appear."
        runTask = Task { [weak self] in
            guard let self else { return }
            for remaining in stride(from: 5, through: 1, by: -1) {
                self.state = .countdown(remaining)
                try? await Task.sleep(for: .seconds(1))
                if Task.isCancelled { return }
            }
            guard NSWorkspace.shared.frontmostApplication?.bundleIdentifier != Bundle.main.bundleIdentifier else {
                self.state = .stopped
                self.notice = "Choose another app's text field before the countdown ends."
                return
            }
            self.state = .typing
            self.notice = "Typing into the active app. ⌃⌥⌘ Esc stops immediately."
            await self.type(snapshot)
        }
    }

    func pauseOrResume() {
        switch state {
        case .typing:
            state = .paused
            notice = "Paused. Return focus to the destination before resuming."
        case .paused:
            state = .typing
            notice = "Typing resumed."
        default: break
        }
    }

    func stop() {
        guard isBusy else { return }
        runTask?.cancel()
        runTask = nil
        state = .stopped
        notice = "Stopped. You can edit the text and start again."
    }

    private func waitWhilePaused() async -> Bool {
        while state == .paused {
            try? await Task.sleep(for: .milliseconds(60))
            if Task.isCancelled { return false }
        }
        return !Task.isCancelled
    }

    private func type(_ characters: [Character]) async {
        var index = 0
        var burstMultiplier = 1.0
        var burstRemaining = 0
        while index < characters.count {
            guard await waitWhilePaused() else { return }
            if burstRemaining == 0 {
                burstRemaining = Int.random(in: 4...18)
                burstMultiplier = Double.random(in: 0.80...1.22)
            }
            burstRemaining -= 1

            let character = characters[index]
            // Only introduce a typo when its correction can be made entirely with Backspace.
            if mistakes, character.isASCIIAlpha, Double.random(in: 0..<100) < mistakeRate,
               let wrong = nearbyKey(for: character) {
                post(character: wrong)
                let delayed = Int.random(in: 0...2)
                let lookAhead = min(delayed, characters.count - index - 1)
                var typedAhead = 0
                if lookAhead > 0 {
                    for offset in 1...lookAhead {
                        let next = characters[index + offset]
                        guard next != "\n" && next != "\r" else { break }
                        guard await sleep(milliseconds: delay(for: next, burst: burstMultiplier)) else { return }
                        post(character: next)
                        typedAhead += 1
                    }
                }
                guard await sleep(milliseconds: Double.random(in: 100...430)) else { return }
                for _ in 0...typedAhead {
                    postBackspace()
                    guard await sleep(milliseconds: Double.random(in: 45...110)) else { return }
                }
                post(character: character)
                if typedAhead > 0 {
                    for offset in 1...typedAhead {
                        post(character: characters[index + offset])
                        guard await sleep(milliseconds: Double.random(in: 35...85)) else { return }
                    }
                }
                index += typedAhead + 1
            } else {
                post(character: character)
                index += 1
            }
            progress = index
            if index < characters.count {
                let last = characters[index - 1]
                var delayMS = delay(for: last, burst: burstMultiplier)
                if naturalPauses {
                    if ".!?".contains(last) { delayMS += Double.random(in: 250...750) }
                    else if ",;:".contains(last) { delayMS += Double.random(in: 100...330) }
                    else if last == "\n" { delayMS += Double.random(in: 250...850) }
                    else if index % Int.random(in: 30...65) == 0 { delayMS += Double.random(in: 300...1000) }
                }
                guard await sleep(milliseconds: delayMS) else { return }
            }
        }
        state = .finished
        notice = "Finished typing \(characters.count) characters."
        runTask = nil
    }

    private func delay(for character: Character, burst: Double) -> Double {
        let baseline = 12_000 / max(wpm, 1)
        let jitter = Double.random(in: 0.68...1.34)
        return max(18, baseline * burst * jitter)
    }

    private func sleep(milliseconds: Double) async -> Bool {
        try? await Task.sleep(for: .milliseconds(Int(max(1, milliseconds))))
        if Task.isCancelled { return false }
        return await waitWhilePaused()
    }

    private func nearbyKey(for character: Character) -> Character? {
        let neighbors: [Character: String] = [
            "a":"sqw", "b":"vgn", "c":"xvd", "d":"sfer", "e":"wrsd", "f":"dgrt",
            "g":"fhty", "h":"gjyu", "i":"uokj", "j":"huki", "k":"jlio", "l":"kop",
            "m":"njk", "n":"bhjm", "o":"ipkl", "p":"ol", "q":"wa", "r":"etdf",
            "s":"awed", "t":"ryfg", "u":"yihj", "v":"cfgb", "w":"qeas", "x":"zcs",
            "y":"tugh", "z":"asx"
        ]
        let lower = Character(character.lowercased())
        guard let options = neighbors[lower], let replacement = options.randomElement() else { return nil }
        return character.isUppercase ? Character(replacement.uppercased()) : replacement
    }

    private func post(character: Character) {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        if character == "\n" || character == "\r" {
            CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: true)?.post(tap: .cghidEventTap)
            CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: false)?.post(tap: .cghidEventTap)
            return
        }
        let units = Array(String(character).utf16)
        for down in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: down) else { continue }
            units.withUnsafeBufferPointer { buffer in
                event.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress!)
            }
            event.post(tap: .cghidEventTap)
        }
    }

    private func postBackspace() {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }
        CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true)?.post(tap: .cghidEventTap)
        CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false)?.post(tap: .cghidEventTap)
    }

    private func installEmergencyHotKey() {
        let callback: EventHandlerUPP = { _, event, userData in
            guard let userData else { return noErr }
            let model = Unmanaged<TyperModel>.fromOpaque(userData).takeUnretainedValue()
            Task { @MainActor in model.stop() }
            return noErr
        }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), callback, 1, &eventType,
                            Unmanaged.passUnretained(self).toOpaque(), &hotKeyHandler)
        // Control + Option + Command + Escape, available while another app has focus.
        RegisterEventHotKey(UInt32(kVK_Escape), UInt32(controlKey | optionKey | cmdKey),
                            hotKeyID, GetApplicationEventTarget(), 0, &hotKey)
    }
}

private struct BrandIcon: View {
    var body: some View {
        if let url = Bundle.main.url(forResource: "AutoTyper", withExtension: "png"), let icon = NSImage(contentsOf: url) {
            Image(nsImage: icon).resizable().aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "character.cursor.ibeam").foregroundStyle(Palette.accent)
        }
    }
}

struct AutoTyperView: View {
    @StateObject private var model = TyperModel()
    var body: some View {
        HStack(spacing: 0) {
            sidebar
            VStack(spacing: 0) {
                HStack {
                    Text("Workspace").foregroundStyle(Palette.muted)
                    Text("/").foregroundStyle(.gray.opacity(0.4))
                    Text("New session").fontWeight(.medium)
                    Spacer()
                    Label("On your Mac", systemImage: "desktopcomputer").foregroundStyle(Palette.muted)
                }.font(.system(size: 12)).padding(.horizontal, 28).frame(height: 56)
                Divider()
                HStack(alignment: .top, spacing: 0) {
                    editor
                    Divider()
                    settings
                }
                Divider()
                runBar
            }.background(Palette.background)
        }
        .foregroundStyle(Palette.ink)
        .preferredColorScheme(.light)
        .overlay {
            if case .countdown(let seconds) = model.state {
                ZStack {
                    Color.black.opacity(0.48)
                    VStack(spacing: 18) {
                        Text("GET READY").font(.system(size: 11, weight: .bold)).tracking(2).foregroundStyle(Palette.accent)
                        Text("\(seconds)").font(.system(size: 88, weight: .light, design: .rounded)).monospacedDigit()
                        Text("Click your destination").font(.system(size: 24, weight: .semibold))
                        Text("Typing begins when the countdown ends.").foregroundStyle(Palette.muted)
                        Button("Cancel countdown", action: model.stop).buttonStyle(SecondaryButton())
                    }.padding(40).frame(width: 410).background(Palette.background, in: RoundedRectangle(cornerRadius: 22))
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 660)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 9) {
                BrandIcon().frame(width: 34, height: 34)
                Text("AutoTyper").font(.system(size: 17, weight: .semibold))
            }.padding(.top, 24).padding(.bottom, 38)
            Text("WORKSPACE").font(.system(size: 10, weight: .semibold)).tracking(1.5).foregroundStyle(.white.opacity(0.4)).padding(.bottom, 12)
            Label("Typing studio", systemImage: "square.and.pencil")
                .font(.system(size: 13, weight: .medium)).padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
            Spacer()
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: "keyboard").font(.system(size: 23)).foregroundStyle(Color(red: 0.98, green: 0.64, blue: 0.43))
                Text("Find your flow.").font(.system(size: 17, weight: .medium))
                Text("Your words, at your pace.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
            }.padding(.bottom, 30)
            Divider().overlay(.white.opacity(0.1))
            HStack { Text("DESKTOP"); Spacer(); Text("v0.3") }
                .font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1).foregroundStyle(.white.opacity(0.45)).padding(.top, 18)
        }.padding(20).frame(width: 180).frame(maxHeight: .infinity).foregroundStyle(.white).background(Palette.rail)
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Make room for your words.").font(.system(size: 28, weight: .semibold)).tracking(-0.8)
                Text("Add your text. Set the rhythm. We'll take it from here.").font(.system(size: 12)).foregroundStyle(Palette.muted)
            }.padding(.bottom, 4)
            VStack(spacing: 0) {
                HStack {
                    Label("Draft", systemImage: "doc.text").font(.system(size: 12, weight: .medium))
                    Spacer()
                    Text("PLAIN TEXT").font(.system(size: 9, weight: .medium, design: .monospaced)).tracking(1).foregroundStyle(Palette.muted)
                }.padding(16)
                Divider()
                ZStack(alignment: .topLeading) {
                    if model.text.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Start with a few words…").font(.system(size: 22, design: .serif))
                            Text("Paste your draft here, or write something new.")
                                .font(.system(size: 13)).foregroundStyle(Palette.muted)
                        }.padding(22).allowsHitTesting(false)
                    }
                    TextEditor(text: $model.text).scrollContentBackground(.hidden)
                        .font(.system(size: 16)).lineSpacing(7).padding(16).disabled(model.isBusy)
                }.frame(maxHeight: .infinity)
                Divider()
                HStack {
                    Text("\(model.text.split(whereSeparator: { $0.isWhitespace }).count) words")
                    Text("·")
                    Text("\(model.characterCount) characters")
                    Spacer()
                    Button("Clear", action: { model.text = "" }).buttonStyle(.plain).disabled(model.isBusy || model.text.isEmpty)
                }.font(.system(size: 11)).foregroundStyle(Palette.muted).padding(14)
            }.background(.white, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.black.opacity(0.08)))
            HStack(spacing: 8) {
                Image(systemName: "cursorarrow.click")
                Text("You'll have 5 seconds to select your destination.")
            }.font(.system(size: 11)).foregroundStyle(Palette.muted)
        }.padding(26).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var settings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 23) {
                Text("SESSION SETTINGS").font(.system(size: 10, weight: .semibold)).tracking(1.3).foregroundStyle(Palette.muted)
                VStack(alignment: .leading, spacing: 12) {
                    Text("Typing speed").font(.system(size: 13, weight: .medium))
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(Int(model.wpm))").font(.system(size: 48, weight: .light)).monospacedDigit()
                        Text("words / min").font(.system(size: 12)).foregroundStyle(Palette.muted)
                    }
                    Slider(value: $model.wpm, in: 15...150, step: 1).tint(Palette.accent)
                    HStack { Text("15 · Slow"); Spacer(); Text("150 · Fast") }.font(.system(size: 10)).foregroundStyle(Palette.muted)
                    HStack(spacing: 6) {
                        preset("Relaxed", 35)
                        preset("Balanced", 60)
                        preset("Quick", 100)
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 14) {
                    Toggle("Mistakes & fixes", isOn: $model.mistakes).toggleStyle(.switch).tint(Palette.accent).font(.system(size: 12, weight: .medium))
                    Text("A few slips. A quick correction. A more natural rhythm.").font(.system(size: 11)).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
                    if model.mistakes {
                        HStack { Text("Frequency"); Spacer(); Text("\(model.mistakeRate, specifier: "%.1f")%").monospacedDigit() }.font(.system(size: 11))
                        Slider(value: $model.mistakeRate, in: 0.5...6, step: 0.5).tint(Palette.accent)
                    }
                }
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Natural pauses", isOn: $model.naturalPauses).toggleStyle(.switch).tint(Palette.accent).font(.system(size: 12, weight: .medium))
                    Text("A breath between sentences and paragraphs.").font(.system(size: 11)).foregroundStyle(Palette.muted)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label("Estimated duration", systemImage: "clock").font(.system(size: 11)).foregroundStyle(Palette.muted)
                    Text(model.characterCount == 0 ? "—" : "\(model.estimatedSeconds / 60)m \(model.estimatedSeconds % 60)s")
                        .font(.system(size: 24, weight: .medium)).monospacedDigit()
                    Text("Plus pauses and corrections").font(.system(size: 10)).foregroundStyle(Palette.muted)
                }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(Color.black.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
            }.padding(22)
        }.frame(width: 270).background(Color.white.opacity(0.45))
    }

    private func preset(_ name: String, _ speed: Double) -> some View {
        Button(name) { model.wpm = speed }
            .font(.system(size: 10, weight: .medium)).buttonStyle(.plain)
            .padding(.vertical, 8).frame(maxWidth: .infinity)
            .background(model.wpm == speed ? Palette.accent.opacity(0.1) : .white, in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(model.wpm == speed ? Palette.accent : Palette.muted)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.black.opacity(0.07)))
    }

    private var runBar: some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 7) {
                    Circle().fill(model.isBusy ? Palette.accent : Color(red: 0.23, green: 0.48, blue: 0.38)).frame(width: 6, height: 6)
                    Text(model.statusLabel).font(.system(size: 10, weight: .semibold)).tracking(1)
                    if model.isBusy { Text("\(model.progress) / \(model.characterCount)").font(.system(size: 10)).foregroundStyle(Palette.muted) }
                }
                Text(model.notice).font(.system(size: 11)).foregroundStyle(Palette.muted).lineLimit(2)
                Text("Emergency stop  ⌃⌥⌘ Esc").font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 8)
            if model.isBusy {
                Button(model.state == .paused ? "Resume" : "Pause", action: model.pauseOrResume)
                    .buttonStyle(SecondaryButton()).disabled({ if case .countdown = model.state { return true }; return false }())
                Button("Stop", action: model.stop).buttonStyle(PrimaryButton())
            } else {
                Button(action: model.start) { Label("Start typing", systemImage: "play.fill") }
                    .buttonStyle(PrimaryButton()).disabled(model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }.padding(.horizontal, 26).padding(.vertical, 18).background(.white)
    }
}

private struct PrimaryButton: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
            .padding(.vertical, 13).padding(.horizontal, 22)
            .background(Palette.accent.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 8))
            .opacity(isEnabled ? 1 : 0.4)
    }
}
private struct SecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium)).foregroundStyle(Palette.ink)
            .padding(.vertical, 12).padding(.horizontal, 18)
            .background(Color.black.opacity(configuration.isPressed ? 0.09 : 0.04), in: RoundedRectangle(cornerRadius: 8))
    }
}

@main
struct AutoTyperApp: App {
    var body: some Scene {
        WindowGroup { AutoTyperView() }
            .windowStyle(.hiddenTitleBar)
            .windowResizability(.contentMinSize)
            .defaultSize(width: 1100, height: 760)
    }
}
