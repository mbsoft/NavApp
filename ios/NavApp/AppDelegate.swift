import UIKit
import React

@main
class AppDelegate: UIResponder, UIApplicationDelegate, RCTBridgeDelegate {
    var window: UIWindow?
    var bridge: RCTBridge?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        
        // Initialize React Native bridge
        bridge = RCTBridge(delegate: self, launchOptions: launchOptions)
        
        // Create root view controller
        let rootViewController = UIViewController()
        let rootView = RCTRootView(
            bridge: bridge!,
            moduleName: "NavApp",
            initialProperties: nil
        )
        
        rootViewController.view = rootView
        rootView.backgroundColor = UIColor.systemBackground
        
        // Set up window
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = rootViewController
        window?.makeKeyAndVisible()
        
        return true
    }
    
    // MARK: - RCTBridgeDelegate
    
    func sourceURL(for bridge: RCTBridge!) -> URL! {
        #if DEBUG
        return RCTBundleURLProvider.sharedSettings().jsBundleURL(forBundleRoot: "index")
        #else
        return Bundle.main.url(forResource: "main", withExtension: "jsbundle")
        #endif
    }
}
