import Flutter

var flutterApi: CoreFlutterApi?

public class TalkjsCoreFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    flutterApi = CoreFlutterApi(binaryMessenger: registrar.messenger())
    CoreHostApiSetup.setUp(
      binaryMessenger: registrar.messenger(),
      api: HostApiImpl(),
    )
    TestHostApiSetup.setUp(
      binaryMessenger: registrar.messenger(),
      api: TestHostApiImpl(),
    )
    registrar.publish(TalkjsCoreFlutterPlugin())
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    CoreHostApiSetup.setUp(
      binaryMessenger: registrar.messenger(),
      api: nil,
    )
    TestHostApiSetup.setUp(
      binaryMessenger: registrar.messenger(),
      api: nil,
    )
    flutterApi = nil
  }
}
