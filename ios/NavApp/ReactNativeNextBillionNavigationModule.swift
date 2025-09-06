import Foundation
import NbmapNavigation
import NbmapCoreNavigation
import CoreLocation
import React

@objc(ReactNativeNextBillionNavigation)
class ReactNativeNextBillionNavigation: NSObject, RCTBridgeModule {
    private var navigationViewController: NavigationViewController?
    
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
        resolver("Module is working!")
    }
    
    @objc
    func launchNavigation(_ destination: NSArray, options: NSDictionary?, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        guard let destinationArray = destination as? [Double], destinationArray.count >= 2 else {
            rejecter("INVALID_DESTINATION", "Destination must be an array with at least 2 elements [lat, lng]", nil)
            return
        }
        
        let lat = destinationArray[0]
        let lng = destinationArray[1]
        
        // Create destination location
        let destinationLocation = CLLocation(latitude: lat, longitude: lng)
        
        // For now, use current location as origin (in a real app, you'd get actual current location)
        let originLocation = CLLocation(latitude: 40.6895, longitude: -74.1745) // Default origin
        
        // Create navigation route options
        let routeOptions = NavigationRouteOptions(origin: originLocation, destination: destinationLocation)
        routeOptions.profileIdentifier = .car
        routeOptions.includesAlternativeRoutes = true
        routeOptions.distanceMeasurementSystem = .metric
        routeOptions.shapeFormat = .polyline6
        
        // Calculate route
        Directions.shared.calculate(routeOptions) { [weak self] routes, error in
            guard let strongSelf = self else { 
                rejecter("MODULE_ERROR", "Module reference lost", nil)
                return 
            }
            
            if let error = error {
                rejecter("ROUTE_ERROR", "Failed to calculate route: \(error.localizedDescription)", error)
                return
            }
            
            guard let routes = routes, !routes.isEmpty else {
                rejecter("NO_ROUTES", "No routes found", nil)
                return
            }
            
            // Create navigation service
            let navigationService = NBNavigationService(routes: routes, routeIndex: 0, simulating: .inTunnels)
            let navigationOptions = NavigationOptions(navigationService: navigationService)
            
            // Create navigation view controller
            let navigationVC = NavigationViewController(for: routes, navigationOptions: navigationOptions)
            navigationVC.modalPresentationStyle = .fullScreen
            navigationVC.delegate = strongSelf
            
            // Store view controller reference
            strongSelf.navigationViewController = navigationVC
            
            // Present navigation
            DispatchQueue.main.async {
                strongSelf.presentNavigationViewController(navigationVC)
                resolver(nil)
            }
        }
    }
    
    @objc
    func dismissNavigation(_ resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        DispatchQueue.main.async { [weak self] in
            if let navigationViewController = self?.navigationViewController {
                navigationViewController.dismiss(animated: true) {
                    self?.navigationViewController = nil
                    resolver(nil)
                }
            } else {
                resolver(nil)
            }
        }
    }
    
    // MARK: - Helpers
    
    @MainActor
    private func presentNavigationViewController(_ navigationVC: NavigationViewController) {
        // Get the key window and find the actual app root controller
        guard let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,
              let rootController = keyWindow.rootViewController else {
            print("❌ No root controller found")
            return
        }
        
        // If the root controller already has a modal presented, dismiss it first
        if let presentedModal = rootController.presentedViewController {
            presentedModal.dismiss(animated: false) {
                rootController.present(navigationVC, animated: true)
            }
        } else {
            rootController.present(navigationVC, animated: true)
        }
    }
}

// MARK: - Navigation Delegate

extension ReactNativeNextBillionNavigation: NavigationViewControllerDelegate {
    func navigationViewController(_ navigationViewController: NavigationViewController, didArriveAt waypoint: Waypoint) {
        print("Navigation arrived at waypoint: \(waypoint)")
    }
    
    func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        print("Navigation dismissed, canceled: \(canceled)")
        self.navigationViewController = nil
    }
    
    func navigationViewController(_ navigationViewController: NavigationViewController, didFailToRerouteWith error: Error) {
        print("Navigation failed to reroute: \(error)")
    }
}