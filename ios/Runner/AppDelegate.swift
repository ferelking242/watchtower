import UIKit
import Flutter
// IMPORTANT: Libmtorrentserver n'est PAS importé ici au niveau module.
// Cause du crash iOS 15 : le runtime Go démarre ses goroutines (SIGURG preemption)
// via dyld AU DÉMARRAGE, avant que la Dart VM de Flutter s'initialise.
// Les deux utilisent SIGURG → conflit → abort().
// Fix : dlopen() appelé APRÈS l'init Flutter dans le channel handler.
import Darwin   // dlopen / dlsym / dlerror
import AVFoundation
import MediaPlayer
import app_links

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        // ── CRITICAL: guard prevents crash at boot when window/rootViewController is nil.
        // The original used "as!" (force-cast) which crashes if the window isn't ready yet.
        guard let controller = window?.rootViewController as? FlutterViewController else {
            PluginSafeRegistrar.safeRegister(with: self)
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        // ── Libmtorrentserver (Go torrent daemon) ─────────────────────────────────
        let torrentChannel = FlutterMethodChannel(
            name: "com.watchtower.app.libmtorrentserver",
            binaryMessenger: controller.binaryMessenger
        )
        torrentChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "start":
                let args      = call.arguments as? [String: Any]
                let configStr = (args?["config"] as? String) ?? "{}"

                // Lazy-load the framework AFTER Flutter is initialised so the Go
                // runtime's SIGURG preemption goroutines don't race with the Dart VM.
                // The framework lives in Frameworks/ (embedded by Xcode) so dyld
                // has already mapped it; dlopen just returns the existing handle
                // without re-running +load, avoiding any double-init.
                let fwPath = Bundle.main.bundlePath
                    + "/Frameworks/Libmtorrentserver.framework/Libmtorrentserver"
                guard let handle = dlopen(fwPath, RTLD_NOW | RTLD_LOCAL) else {
                    let msg = dlerror().map { String(cString: $0) } ?? "dlopen failed"
                    result(FlutterError(code: "MT_LOAD", message: msg, details: fwPath))
                    return
                }
                guard let sym = dlsym(handle, "LibmtorrentserverStart") else {
                    result(FlutterError(code: "MT_SYM", message: "LibmtorrentserverStart not found", details: nil))
                    return
                }

                typealias MTStartFn = @convention(c) (
                    UnsafePointer<CChar>?,
                    UnsafeMutablePointer<Int>?,
                    UnsafeMutableRawPointer?
                ) -> Bool

                let startFn = unsafeBitCast(sym, to: MTStartFn.self)
                let mPort   = UnsafeMutablePointer<Int>.allocate(capacity: 1)
                defer { mPort.deallocate() }

                let nsConfig = configStr as NSString
                if startFn(nsConfig.utf8String, mPort, nil) {
                    result(mPort.pointee)
                } else {
                    result(FlutterError(code: "MT_ERR", message: "LibmtorrentserverStart returned false", details: nil))
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // ── binary_utils (native iOS paths + jailbreak detection) ─────────────────
        let binaryChannel = FlutterMethodChannel(
            name: "com.watchtower.app.binary_utils",
            binaryMessenger: controller.binaryMessenger
        )
        binaryChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {

            case "getNativeLibraryDir":
                // iOS has no nativeLibraryDir: return the app bundle path
                result(Bundle.main.bundlePath)

            case "getFilesDir":
                let dir = (try? FileManager.default.url(
                    for: .applicationSupportDirectory, in: .userDomainMask,
                    appropriateFor: nil, create: true
                ).path) ?? NSTemporaryDirectory()
                result(dir)

            case "chmod":
                if let args = call.arguments as? [String: Any],
                   let path = args["path"] as? String {
                    try? FileManager.default.setAttributes(
                        [.posixPermissions: NSNumber(value: 0o755)], ofItemAtPath: path)
                }
                result(nil)

            case "isJailbroken":
                // Detection for Dopamine / Procursus / Sileo / rootless / rooted
                let jbPaths = [
                    "/var/jb",
                    "/etc/apt",
                    "/bin/bash",
                    "/usr/sbin/sshd",
                    "/var/lib/cydia",
                    "/Applications/Cydia.app",
                    "/Applications/Sileo.app",
                ]
                result(jbPaths.contains { FileManager.default.fileExists(atPath: $0) })

            case "getPhysicalMemoryMB":
                // Returns total physical RAM in megabytes.
                // Used by DeviceCapabilities.dart to tier cache limits per device class.
                result(Int(ProcessInfo.processInfo.physicalMemory / 1024 / 1024))

            case "isCharging":
                // Drives the library auto-update "only while charging"
                // restriction. Reading the state enables battery monitoring.
                let device = UIDevice.current
                device.isBatteryMonitoringEnabled = true
                let state = device.batteryState
                result(state == .charging || state == .full)

            case "getYtDlpPath":
                // Rootless (Dopamine/Fugu15): prefix /var/jb
                // Rooted (Unc0ver/Checkra1n): standard paths
                let paths = [
                    "/var/jb/usr/local/bin/zeusdl",
                    "/var/jb/usr/bin/zeusdl",
                    "/var/jb/usr/local/bin/yt-dlp",
                    "/var/jb/usr/bin/yt-dlp",
                    "/usr/local/bin/zeusdl",
                    "/usr/bin/zeusdl",
                    "/usr/local/bin/yt-dlp",
                    "/usr/bin/yt-dlp",
                ]
                result(paths.first { FileManager.default.fileExists(atPath: $0) } as Any)

            case "extractAssetBinary":
                guard
                    let args = call.arguments as? [String: Any],
                    let assetKey = args["asset"] as? String,
                    let destPath = args["dest"] as? String
                else {
                    result(FlutterError(code: "ARGS", message: "asset and dest required", details: nil))
                    return
                }
                DispatchQueue.global(qos: .utility).async {
                    do {
                        let fm = FileManager.default
                        if fm.fileExists(atPath: destPath) {
                            DispatchQueue.main.async { result(destPath) }
                            return
                        }
                        let key = FlutterDartProject.lookupKey(forAsset: assetKey)
                        guard let srcPath = Bundle.main.path(forResource: key, ofType: nil) else {
                            DispatchQueue.main.async {
                                result(FlutterError(code: "NOT_FOUND",
                                    message: "Asset not in bundle: \(assetKey)", details: nil))
                            }
                            return
                        }
                        let destURL = URL(fileURLWithPath: destPath)
                        try fm.createDirectory(at: destURL.deletingLastPathComponent(),
                                               withIntermediateDirectories: true)
                        try fm.copyItem(atPath: srcPath, toPath: destPath)
                        try fm.setAttributes([.posixPermissions: NSNumber(value: 0o755)],
                                             ofItemAtPath: destPath)
                        DispatchQueue.main.async { result(destPath) }
                    } catch {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "IO", message: error.localizedDescription, details: nil))
                        }
                    }
                }

            case "runProcess":
                guard let args = call.arguments as? [String: Any],
                      let path = args["path"] as? String
                else {
                    result(FlutterError(code: "NO_PATH", message: "path required", details: nil))
                    return
                }
                let processArgs = args["args"] as? [String] ?? []
                let envOverrides = args["env"] as? [String: String] ?? [:]
                DispatchQueue.global(qos: .userInitiated).async {
                    let allArgs = [path] + processArgs
                    var argv = allArgs.map { strdup($0) }
                    argv.append(nil)
                    defer { argv.dropLast().forEach { free($0) } }
                    var envDict = ProcessInfo.processInfo.environment
                    envDict.merge(envOverrides) { _, new in new }
                    var envp = envDict.map { strdup("\($0.key)=\($0.value)") }
                    envp.append(nil)
                    defer { envp.dropLast().forEach { free($0) } }
                    var outPipe = [Int32](repeating: 0, count: 2)
                    var errPipe = [Int32](repeating: 0, count: 2)
                    guard pipe(&outPipe) == 0, pipe(&errPipe) == 0 else {
                        DispatchQueue.main.async {
                            result(FlutterError(code: "PIPE_ERR", message: "pipe() failed", details: nil))
                        }
                        return
                    }
                    var actions: posix_spawn_file_actions_t?
                    posix_spawn_file_actions_init(&actions)
                    posix_spawn_file_actions_adddup2(&actions, outPipe[1], STDOUT_FILENO)
                    posix_spawn_file_actions_adddup2(&actions, errPipe[1], STDERR_FILENO)
                    posix_spawn_file_actions_addclose(&actions, outPipe[0])
                    posix_spawn_file_actions_addclose(&actions, errPipe[0])
                    var pid: pid_t = 0
                    let spawnErr = posix_spawn(&pid, path, &actions, nil, &argv, &envp)
                    posix_spawn_file_actions_destroy(&actions)
                    close(outPipe[1])
                    close(errPipe[1])
                    guard spawnErr == 0 else {
                        close(outPipe[0])
                        close(errPipe[0])
                        DispatchQueue.main.async {
                            result(FlutterError(code: "EXEC_ERR",
                                message: String(cString: strerror(spawnErr)), details: nil))
                        }
                        return
                    }
                    let outFH = FileHandle(fileDescriptor: outPipe[0], closeOnDealloc: true)
                    let errFH = FileHandle(fileDescriptor: errPipe[0], closeOnDealloc: true)
                    let output = (String(data: outFH.readDataToEndOfFile(), encoding: .utf8) ?? "")
                               + (String(data: errFH.readDataToEndOfFile(), encoding: .utf8) ?? "")
                    var status: Int32 = 0
                    waitpid(pid, &status, 0)
                    let code = (status & 0x7f) == 0 ? Int((status >> 8) & 0xff) : -1
                    DispatchQueue.main.async {
                        result(["exitCode": code, "output": output, "via": "posix_spawn"])
                    }
                }

            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // ── Plugin executor stub (iOS — Python not available) ──────────────────────
        // iOS has no libpython or script.py. Register the channel anyway to avoid
        // MissingPluginException in shared Dart code.
        let pluginChannel = FlutterMethodChannel(
            name: "com.watchtower.app.plugin",
            binaryMessenger: controller.binaryMessenger
        )
        pluginChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            result(FlutterError(
                code: "PLATFORM_NOT_SUPPORTED",
                message: "Python plugin execution is not available on iOS.",
                details: nil
            ))
        }

        // ── Plugin storage (UserDefaults) ──────────────────────────────────────────
        let storageChannel = FlutterMethodChannel(
            name: "com.watchtower.app.storage",
            binaryMessenger: controller.binaryMessenger
        )
        storageChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            let defaults = UserDefaults.standard
            let args = call.arguments as? [String: Any]
            let key = "wtplugin_\(args?["key"] as? String ?? "")"
            switch call.method {
            case "get":
                result(defaults.string(forKey: key) as Any)
            case "set":
                defaults.set(args?["value"] as? String ?? "", forKey: key)
                result(nil)
            case "delete":
                defaults.removeObject(forKey: key)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // ── Volume-key navigation (reader) ─────────────────────────────────────────
        // iOS exposes no key-down callback for the hardware volume buttons, so we
        // observe the audio session's output volume instead: a change means a
        // button was pressed. We immediately restore the previous level so the
        // device volume never actually moves, and the direction is forwarded to
        // the reader over the same channel the Android side uses.
        let volumeEventChannel = FlutterEventChannel(
            name: "com.watchtower.app.volume_keys",
            binaryMessenger: controller.binaryMessenger
        )
        let volumeEventStreamHandler = VolumeKeyStreamHandler()
        volumeEventChannel.setStreamHandler(volumeEventStreamHandler)

        let volumeMethodChannel = FlutterMethodChannel(
            name: "com.watchtower.app.volume_keys",
            binaryMessenger: controller.binaryMessenger
        )
        volumeMethodChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
            switch call.method {
            case "setEnabled":
                let args    = call.arguments as? [String: Any]
                let enabled = (args?["enabled"] as? Bool) ?? false
                volumeEventStreamHandler.setEnabled(enabled)
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // ── Register all Flutter plugins (wrapped in ObjC exception handler) ───────
        // A duplicate plugin registration throws NSInvalidArgumentException and
        // crashes the process with SIGABRT. PluginSafeRegistrar catches the exception
        // so the app can continue with all plugins that registered successfully.
        // Root cause: stale Pods directory (pubspec.yaml updated but `pod install`
        // not re-run, leaving old and new versions of the same pod on disk).
        // Fix: run `cd ios && pod install --repo-update` to regenerate Podfile.lock.
        PluginSafeRegistrar.safeRegister(with: self)

        // ── Handle deep links present at launch ────────────────────────────────────
        // IMPORTANT: call super BEFORE returning so Flutter's engine lifecycle
        // completes normally. Returning `true` directly (without super) would skip
        // Flutter's post-didFinishLaunching setup and leave the engine half-initialised.
        let superResult = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        if let url = AppLinks.shared.getLink(launchOptions: launchOptions) {
            AppLinks.shared.handleLink(url: url)
        }
        return superResult
    }

    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        AppLinks.shared.handleLink(url: url)
        return super.application(app, open: url, options: options)
    }
}

/// Bridges iOS hardware volume buttons to the reader's page navigation.
///
/// The system gives no key event for volume buttons, so we watch
/// `AVAudioSession.outputVolume` and treat every change as one press. The
/// volume is restored right away, so the physical level is unchanged.
class VolumeKeyStreamHandler: NSObject, FlutterStreamHandler {
    private var sink: FlutterEventSink?
    private var enabled = false
    private var volumeView: MPVolumeView?
    private var lastVolume: Float = 0

    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        sink = events
        return nil
    }

    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        sink = nil
        setEnabled(false)
        return nil
    }

    func setEnabled(_ value: Bool) {
        if value == enabled { return }
        enabled = value

        let session = AVAudioSession.sharedInstance()
        try? session.setActive(true)

        if value {
            lastVolume = session.outputVolume
            // MPVolumeView is only needed to programmatically reset the volume.
            if volumeView == nil {
                volumeView = MPVolumeView(frame: .zero)
            }
            session.addObserver(
                self,
                forKeyPath: "outputVolume",
                options: [.new],
                context: nil
            )
        } else {
            session.removeObserver(self, forKeyPath: "outputVolume")
            volumeView?.removeFromSuperview()
            volumeView = nil
        }
    }

    override func observeValue(
        forKeyPath keyPath: String?,
        of object: Any?,
        change: [NSKeyValueChangeKey: Any]?,
        context: UnsafeMutableRawPointer?
    ) {
        guard keyPath == "outputVolume", enabled else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
            return
        }

        let newVolume = (change?[.newKey] as? NSNumber)?.floatValue
            ?? AVAudioSession.sharedInstance().outputVolume

        // Ignore the echo of our own restore.
        if abs(newVolume - lastVolume) < 0.0001 { return }

        let direction = newVolume > lastVolume ? 1 : -1
        let previous  = lastVolume
        lastVolume = newVolume

        restoreVolume(previous)
        sink?(direction)
    }

    private func restoreVolume(_ level: Float) {
        guard let slider = volumeView?.subviews.compactMap({ $0 as? UISlider }).first else { return }
        DispatchQueue.main.async { [weak self] in
            slider.value = level
            self?.lastVolume = level
        }
    }
}
