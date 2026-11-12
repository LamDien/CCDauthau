import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AdConfigPlugin") {
      let channel = FlutterMethodChannel(
        name: "vn.ccdauthau/ad_config",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        if call.method == "getAdConfig" {
          let bannerUnitId = Bundle.main.object(
            forInfoDictionaryKey: "CcDauThauAdMobBannerId"
          ) as? String
          result(["bannerUnitId": bannerUnitId as Any])
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
  }
}
