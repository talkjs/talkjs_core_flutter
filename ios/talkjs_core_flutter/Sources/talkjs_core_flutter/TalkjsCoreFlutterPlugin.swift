import Flutter

var flutterApi: CoreFlutterApi?

public class TalkjsCoreFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    flutterApi = CoreFlutterApi(binaryMessenger: registrar.messenger())
    CoreHostApiSetup.setUp(
      binaryMessenger: registrar.messenger(),
      api: HostApiImpl(),
    )
    registrar.publish(TalkjsCoreFlutterPlugin())
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    CoreHostApiSetup.setUp(
      binaryMessenger: registrar.messenger(),
      api: nil,
    )
    flutterApi = nil
  }
}
