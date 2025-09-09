import Foundation
import UIKit
import React
import Nbmap
import NbmapCoreNavigation
import NbmapNavigation

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
    
    @objc(testModule:rejecter:)
    func testModule(_ resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        resolver("iOS module is working!")
    }
    
    @objc(launchNavigation:destination:options:resolver:rejecter:)
    func launchNavigation(_ origin: NSArray, _ destination: NSArray, options: NSDictionary, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        guard let destinationArray = destination as? [Double], destinationArray.count >= 2 else {
            rejecter("INVALID_DESTINATION", "Destination must be an array with at least 2 elements [lat, lng]", nil)
            return
        }

        guard let originArray = origin as? [Double], originArray.count >= 2 else {
            rejecter("INVALID_ORIGIN", "Origin must be an array with at least 2 elements [lat, lng]", nil)
            return
        }
        
        let simulate = (options["simulate"] as? Bool) ?? false
        let mode = (options["mode"] as? String) ?? "car"
        let units = (options["units"] as? String) ?? "imperial"
        let routeType = (options["routeType"] as? String) ?? "fastest"
        let avoidances = (options["avoidances"] as? [String]) ?? []
        let truckSize = (options["truckSize"] as? [String]) ?? []
        let truckWeight = (options["truckWeight"] as? Int) ?? 0
        
        let lat = destinationArray[0]
        let lng = destinationArray[1]
        let destinationCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        
        let olat = originArray[0]
        let olng = originArray[1]
        let originCoordinate = CLLocationCoordinate2D(latitude: olat, longitude: olng)

        print("iOS: Launching NextBillion.ai navigation to: \(lat), \(lng) with mode: \(mode), units: \(units), routeType: \(routeType), avoidances: \(avoidances), truckSize: \(truckSize), truckWeight: \(truckWeight)")
        
        DispatchQueue.main.async {
            self.startNavigation(from: originCoordinate, to: destinationCoordinate, simulate: simulate, mode: mode, units: units, routeType: routeType, avoidances: avoidances, truckSize: truckSize, truckWeight: truckWeight, resolver: resolver, rejecter: rejecter)
        }
    }
    
    private func startNavigation(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, simulate: Bool, mode: String, units: String, routeType: String, avoidances: [String], truckSize: [String], truckWeight: Int, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        // Get current location (for demo purposes, using a default location)
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        
        // Create route options
        let options = NavigationRouteOptions(origin: originLocation, destination: destinationLocation)
        options.profileIdentifier = (mode == "truck") ? NBNavigationMode.truck : NBNavigationMode.car
        options.includesAlternativeRoutes = true
        options.distanceMeasurementSystem = (units == "imperial") ? .imperial : .metric
        options.departureTime = Int(Date().timeIntervalSince1970)
        options.locale = Locale.autoupdatingCurrent
        options.mapOption = .valhalla
        options.shapeFormat = .polyline6

        // Add truck parameters if mode is truck
        if mode == "truck" && !truckSize.isEmpty && truckWeight > 0 {
            // Convert truck size from string array to appropriate format
            if truckSize.count >= 3 {
                let height = Int(Double(truckSize[0]) ?? 400.0)
                let width = Int(Double(truckSize[1]) ?? 250.0)
                let length = Int(Double(truckSize[2]) ?? 1200.0)
                options.truckSize = [height, width, length]
                options.truckWeight = truckWeight
                print("iOS: Truck parameters - Size: \(truckSize), Weight: \(truckWeight)")
            }
        }
        
        // Add route type and avoidances
        print("iOS: Route type: \(routeType), Avoidances: \(avoidances)")
        // Note: NextBillion.ai iOS SDK specific route type and avoidances configuration
        // would need to be implemented based on the SDK documentation
        
        // Fetch route
        Directions.shared.calculate(options) { [weak self] routes, error in
            guard let self = self else { return }
            
            guard error == nil else {
                rejecter("ROUTE_ERROR", "Failed to calculate route: \(error?.localizedDescription ?? "Unknown error")", error)
                return
            }
            
            guard let routes = routes else {
                rejecter("NO_ROUTE", "No route found", nil)
                return
            }
            
            // Create navigation service
            let simMode: SimulationMode = simulate ? .always : .inTunnels
            let navigationService = NBNavigationService(routes: routes, routeIndex: 0, simulating: simMode)
            let navigationOptions = NavigationOptions(navigationService: navigationService)
            
            // Initialize the NavigationViewController
            let navigationViewController = NavigationViewController(for: routes, navigationOptions: navigationOptions)
            navigationViewController.modalPresentationStyle = .fullScreen
            navigationViewController.routeLineTracksTraversal = true
            
            self.navigationViewController = navigationViewController
            
            // Present navigation view controller
            if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,
               let rootController = keyWindow.rootViewController {
                rootController.present(navigationViewController, animated: true) {
                    resolver(nil)
                }
            } else {
                rejecter("PRESENTATION_ERROR", "Could not present navigation view", nil)
            }
        }
    }
    
    @objc(dismissNavigation:rejecter:)
    func dismissNavigation(_ resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        print("iOS: Dismissing navigation")
        
        DispatchQueue.main.async {
            if let navVC = self.navigationViewController {
                navVC.dismiss(animated: true) {
                    self.navigationViewController = nil
                    resolver(nil)
                }
            } else {
                resolver(nil)
            }
        }
    }
}
