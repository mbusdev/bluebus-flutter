import UIKit
import UserNotifications
import Flutter
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as? UNUserNotificationCenterDelegate
    }
  
    if let googleMapsAPIKey = Bundle.main.object(forInfoDictionaryKey: "GMapApiKey") as? String {
      GMSServices.provideAPIKey(googleMapsAPIKey)
    } else {
      fatalError("Google Maps API key not found")
    }
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
