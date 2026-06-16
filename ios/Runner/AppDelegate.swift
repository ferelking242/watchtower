import UIKit
  import Flutter
  import Libmtorrentserver
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
          let args = call.arguments as? [String: Any]
          let config = args?["config"] as? String
          var error: NSError?
          let mPort = UnsafeMutablePointer<Int>.allocate(capacity: MemoryLayout<Int>.stride)
          defer { mPort.deallocate() }
          if LibmtorrentserverStart(config, mPort, &error) {
            result(mPort.pointee)
          } else {
            result(FlutterError(code: "ERROR", message: error.debugDescription, details: nil))
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
  