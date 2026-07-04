import UIKit
  import Flutter
  // IMPORTANT: Libmtorrentserver n'est PAS importé ici.
  // Cause du crash iOS 15 : le runtime Go démarre ses goroutines (SIGURG preemption)
  // via dyld AU DÉMARRAGE, avant que la Dart VM de Flutter s'initialise.
  // Les deux utilisent SIGURG → conflit → abort().
  // Fix : dlopen() appelé APRÈS l'init Flutter dans le channel handler.
  import Darwin   // dlopen / dlsym / dlerror
  import app_links

  @main
  @objc class AppDelegate: FlutterAppDelegate {
    override func application(
      _ application: UIApplication,
      didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

      // ── CRITICAL FIX: guard previent crash au boot quand window ou rootViewController est nil
      // L'original utilisait "as!" (force-cast) qui crash si la fenetre n'est pas prete.
      guard let controller = window?.rootViewController as? FlutterViewController else {
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
      }

      // ── Libmtorrentserver (daemon torrent Go) ──────────────────────────────────
      let torrentChannel = FlutterMethodChannel(
        name: "com.watchtower.app.libmtorrentserver",
        binaryMessenger: controller.binaryMessenger
      )
      torrentChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "start":
          let args      = call.arguments as? [String: Any]
          let configStr = (args?["config"] as? String) ?? "{}"

          // Lazy-load : le framework est dans PrivateLibraries/ (pas Frameworks/)
          // pour que dyld ne le charge PAS au boot (évite le conflit SIGURG Go ↔ Dart VM).
          let fwPath = Bundle.main.bundlePath
            + "/PrivateLibraries/Libmtorrentserver.framework/Libmtorrentserver"
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
            result(FlutterError(code: "MT_ERR", message: "LibmtorrentserverStart retourned false", details: nil))
          }

        default:
          result(FlutterMethodNotImplemented)
        }
      }

      // ── binary_utils (chemins natifs iOS + detection jailbreak) ───────────────
      let binaryChannel = FlutterMethodChannel(
        name: "com.watchtower.app.binary_utils",
        binaryMessenger: controller.binaryMessenger
      )
      binaryChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {

        case "getNativeLibraryDir":
          // iOS n'a pas de nativeLibraryDir: on retourne le bundle de l'app
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
          // Detection Dopamine / Procursus / Sileo / rootless / rooted
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

        case "getYtDlpPath":
          // Rootless (Dopamine/Fugu15): prefixe /var/jb
          // Rooted (Unc0ver/Checkra1n): chemins standards
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

      // ── Plugin executor stub (iOS — Python non disponible) ────────────────────
      // Sur iOS il n'y a pas de libpython ni de script.py. On enregistre quand même
      // le channel pour éviter MissingPluginException dans le code Dart commun.
      let pluginChannel = FlutterMethodChannel(
        name: "com.watchtower.app.plugin",
        binaryMessenger: controller.binaryMessenger
      )
      pluginChannel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        result(FlutterError(
          code: "PLATFORM_NOT_SUPPORTED",
          message: "L'exécution Python des plugins n'est pas disponible sur iOS.",
          details: nil
        ))
      }

      // ── Plugin storage (UserDefaults) ─────────────────────────────────────────
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

      GeneratedPluginRegistrant.register(with: self)

      if let url = AppLinks.shared.getLink(launchOptions: launchOptions) {
        AppLinks.shared.handleLink(url: url)
        return true
      }

      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
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
  