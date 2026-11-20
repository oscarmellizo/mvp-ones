import Flutter
import Photos
import PhotosUI
import UniformTypeIdentifiers

final class OnesPhotoLibraryPicker: NSObject, FlutterPlugin, PHPickerViewControllerDelegate {
  private var pendingResult: FlutterResult?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "ones/photo_library", binaryMessenger: registrar.messenger())
    let instance = OnesPhotoLibraryPicker()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "pickImages" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard #available(iOS 14.0, *) else {
      result(FlutterError(code: "unsupported_ios", message: "Photos picker requires iOS 14 or later.", details: nil))
      return
    }
    guard pendingResult == nil,
          let viewController = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow })?.rootViewController else {
      result(FlutterError(code: "picker_unavailable", message: "Photos picker is already open or unavailable.", details: nil))
      return
    }

    let limit = (call.arguments as? [String: Any])?["limit"] as? Int ?? 15
    var configuration = PHPickerConfiguration(photoLibrary: .shared())
    configuration.filter = .images
    configuration.selectionLimit = max(1, min(limit, 15))
    configuration.preferredAssetRepresentationMode = .current

    let picker = PHPickerViewController(configuration: configuration)
    picker.delegate = self
    pendingResult = result
    viewController.present(picker, animated: true)
  }

  @available(iOS 14.0, *)
  func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
    picker.dismiss(animated: true)
    guard !results.isEmpty else {
      finish([])
      return
    }

    let group = DispatchGroup()
    let lock = NSLock()
    var selected: [Int: [String: String]] = [:]

    for (index, item) in results.enumerated() {
      let provider = item.itemProvider
      let originalName = provider.suggestedName ?? "photo-\(UUID().uuidString).jpg"
      let type = provider.registeredTypeIdentifiers.first(where: {
        UTType($0)?.conforms(to: .image) == true
      })
      guard let type else { continue }

      group.enter()
      provider.loadFileRepresentation(forTypeIdentifier: type) { source, _ in
        defer { group.leave() }
        guard let source else { return }

        let basename = URL(fileURLWithPath: originalName).lastPathComponent
        let safeName = basename.replacingOccurrences(of: "/", with: "_")
        let destination = FileManager.default.temporaryDirectory
          .appendingPathComponent("ones-\(UUID().uuidString)-\(safeName)")
        do {
          try FileManager.default.copyItem(at: source, to: destination)
          lock.lock()
          selected[index] = ["name": basename, "path": destination.path]
          lock.unlock()
        } catch {
          return
        }
      }
    }

    group.notify(queue: .main) {
      let output = selected.keys.sorted().compactMap { selected[$0] }
      self.finish(output)
    }
  }

  private func finish(_ value: Any) {
    let callback = pendingResult
    pendingResult = nil
    callback?(value)
  }
}
