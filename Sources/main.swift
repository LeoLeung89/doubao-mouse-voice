import AppKit
import ApplicationServices
import ServiceManagement

final class App: NSObject, NSApplicationDelegate {
    var status: NSStatusItem!
    var tap: CFMachPort?
    var source: CFRunLoopSource?
    var timer: Timer?
    var origin = CGPoint.zero
    var mouseDown = false
    var moved = false
    var keyDown = false
    var enabled = true
    let threshold: TimeInterval = 0.6
    let distance: CGFloat = 10
    var keyCode: CGKeyCode { UserDefaults.standard.object(forKey: "optionKey") == nil ? 58 : CGKeyCode(UserDefaults.standard.integer(forKey: "optionKey")) }

    func applicationDidFinishLaunching(_ notification: Notification) {
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.title = "🎙鼠标"
        if #available(macOS 13.0, *) {
            do { if SMAppService.mainApp.status == .notRegistered { try SMAppService.mainApp.register() } }
            catch { NSLog("Login item registration failed: %@", error.localizedDescription) }
        }
        makeMenu()
        if !CGPreflightListenEventAccess() { _ = CGRequestListenEventAccess() }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        startTap()
    }
    func makeMenu() {
        let menu = NSMenu()
        let state = NSMenuItem(title: enabled ? "暂停监听" : "恢复监听", action: #selector(toggle), keyEquivalent: "")
        state.target = self; menu.addItem(state)
        let info = NSMenuItem(title: "长按 0.6 秒 → 按住\(keyCode == 61 ? "右" : "左") Option", action: nil, keyEquivalent: "")
        info.isEnabled = false; menu.addItem(info)
        let choose = NSMenuItem(title: "切换为\(keyCode == 61 ? "左" : "右") Option", action: #selector(switchOption), keyEquivalent: "")
        choose.target = self; menu.addItem(choose)
        if #available(macOS 13.0, *) {
            let login = NSMenuItem(title: SMAppService.mainApp.status == .enabled ? "登录时启动：已开启" : "登录时启动：未开启或等待批准", action: #selector(enableLogin), keyEquivalent: "")
            login.target = self; menu.addItem(login)
        }
        let help = NSMenuItem(title: "使用说明与权限…", action: #selector(showHelp), keyEquivalent: "")
        help.target = self; menu.addItem(help)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self; menu.addItem(quit)
        status.menu = menu
        status.button?.title = enabled ? "🎙鼠标" : "🎙暂停"
    }
    func startTap() {
        let mask = (1 << CGEventType.leftMouseDown.rawValue) | (1 << CGEventType.leftMouseUp.rawValue) | (1 << CGEventType.leftMouseDragged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            let app = Unmanaged<App>.fromOpaque(refcon).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                app.reset(); if let tap = app.tap { CGEvent.tapEnable(tap: tap, enable: true) }
            } else { app.handle(type, event) }
            return Unmanaged.passUnretained(event)
        }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: CGEventMask(mask), callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else {
            enabled = false; makeMenu(); showHelp(); return
        }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }
    func handle(_ type: CGEventType, _ event: CGEvent) {
        guard enabled else { return }
        switch type {
        case .leftMouseDown:
            reset(); mouseDown = true; origin = event.location
            timer = Timer(timeInterval: threshold, repeats: false) { [weak self] _ in
                guard let self, self.mouseDown, !self.moved else { return }
                self.sendKey(true); self.keyDown = true
            }
            RunLoop.main.add(timer!, forMode: .common)
        case .leftMouseDragged:
            let p = event.location
            if hypot(p.x - origin.x, p.y - origin.y) > distance { moved = true; timer?.invalidate() }
        case .leftMouseUp: reset()
        default: break
        }
    }
    func sendKey(_ down: Bool) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: down) else { return }
        event.flags = down ? .maskAlternate : []
        event.post(tap: .cghidEventTap)
    }
    func reset() {
        timer?.invalidate(); timer = nil
        if keyDown { sendKey(false); keyDown = false }
        mouseDown = false; moved = false
    }
    @objc func switchOption() { reset(); UserDefaults.standard.set(keyCode == 61 ? 58 : 61, forKey: "optionKey"); makeMenu() }
    @objc func enableLogin() {
        if #available(macOS 13.0, *) {
            do { try SMAppService.mainApp.register() } catch { NSLog("Login item: %@", error.localizedDescription) }
            makeMenu()
        }
    }
    @objc func toggle() {
        if tap == nil { enabled = true; startTap() } else { enabled.toggle(); reset() }
        makeMenu()
    }
    @objc func showHelp() {
        let alert = NSAlert()
        alert.messageText = "鼠标长按豆包语音"
        alert.informativeText = "1. 工具默认模拟左 Option；如豆包使用右 Option，请在菜单栏切换。\n2. 在系统设置 → 隐私与安全性中，允许本工具的输入监控和辅助功能；也要允许豆包使用麦克风。\n3. 选择文字输入框，鼠标左键按住 0.6 秒后说话，松开结束。长按前移动超过 10 点会取消触发。\n\n若授权后仍不生效，退出本工具并重新打开。"
        alert.addButton(withTitle: "好")
        alert.runModal()
    }
    @objc func quitApp() { reset(); NSApp.terminate(nil) }
    func applicationWillTerminate(_ notification: Notification) { reset() }
}
let app = NSApplication.shared
let delegate = App()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
