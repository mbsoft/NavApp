import Foundation
import UIKit
import React

@objc(ReactNativeNextBillionNavigation)
class ReactNativeNextBillionNavigation: NSObject, RCTBridgeModule {
    
    // MARK: - RCTBridgeModule
    
    @objc
    static func moduleName() -> String {
        return "ReactNativeNextBillionNavigation"
    }
    
    @objc
    static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    // MARK: - React Native Methods
    
    @objc
    func testModule(_ resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        resolver("iOS module is working!")
    }
    
    @objc
    func launchNavigation(_ destination: NSArray, options: NSDictionary?, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        guard let destinationArray = destination as? [Double], destinationArray.count >= 2 else {
            rejecter("INVALID_DESTINATION", "Destination must be an array with at least 2 elements [lat, lng]", nil)
            return
        }
        
        let lat = destinationArray[0]
        let lng = destinationArray[1]
        
        print("iOS: Launching NextBillion.ai navigation to: \(lat), \(lng)")
        
        // For now, just show a simple alert to test the module is working
        // TODO: Implement full NextBillion.ai navigation
        DispatchQueue.main.async {
            let alert = UIAlertController(
                title: "Navigation Started", 
                message: "iOS navigation to \(lat), \(lng) - NextBillion.ai SDK integration needed", 
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,
               let rootController = keyWindow.rootViewController {
                rootController.present(alert, animated: true)
            }
            
            resolver(nil)
        }
    }
    
    @objc
    func dismissNavigation(_ resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        print("iOS: Dismissing navigation")
        resolver(nil)
    }
}