import Flutter
import UIKit

// iOS push-notification bridge for Firebase Messaging.
//
// Without this AppDelegate code the app would launch and run perfectly on
// iOS — but it would NEVER register for Apple Push Notifications, so:
//   • Apple never gives the app an APNs device token
//   • firebase_messaging has nothing to exchange with FCM
//   • the server can't send pushes (no FCM token on file)
//
// That's the difference between "Android pushes work, iOS pushes don't" —
// the default Flutter template wires up Android FCM automatically but
// leaves iOS for the developer to enable here.
@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 1. Use the FlutterAppDelegate as the UNUserNotificationCenter
    //    delegate so notification taps + foreground presentation route
    //    back to the firebase_messaging plugin. FlutterAppDelegate already
    //    conforms to UNUserNotificationCenterDelegate.
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self
    }

    // 2. Ask iOS to give us an APNs device token. This MUST be called
    //    even though the Dart side also calls FirebaseMessaging
    //    .requestPermission — the Dart permission call alone does not
    //    trigger the underlying registerForRemoteNotifications. Once
    //    Apple responds with the APNs token, the firebase_messaging
    //    plugin captures it via the swizzled didRegisterForRemoteNotifications
    //    and exchanges it for an FCM registration token.
    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
