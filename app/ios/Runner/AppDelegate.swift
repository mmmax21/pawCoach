import Flutter
import UIKit
import workmanager_apple

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 周日晚周报任务：iOS 要求在启动返回前注册 BGTaskScheduler 的处理器（M2 简报第 9 节）。
    WorkmanagerPlugin.registerPeriodicTask(
      withIdentifier: "weekly_report_task",
      earliestBeginInSeconds: NSNumber(value: 7 * 24 * 3600)
    )
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}
