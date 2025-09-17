import Foundation
import UIKit
import React
import Nbmap
import NbmapCoreNavigation
import NbmapNavigation

// Custom Home Button for Navigation
class HomeButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)
        print("🏠 HOME_BUTTON: init(frame:) called")
        setupButton()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        print("🏠 HOME_BUTTON: init(coder:) called")
        setupButton()
    }
    
    private func setupButton() {
        print("🏠 HOME_BUTTON: setupButton called")
        setTitle("🏠", for: .normal)
        setTitleColor(.white, for: .normal)
        backgroundColor = UIColor.systemBlue
        layer.cornerRadius = 25
        titleLabel?.font = UIFont.systemFont(ofSize: 24)
        translatesAutoresizingMaskIntoConstraints = false
        
        // Add shadow for better visibility
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowOpacity = 0.3
        layer.shadowRadius = 4
        
        // Set size constraints
        widthAnchor.constraint(equalToConstant: 50).isActive = true
        heightAnchor.constraint(equalToConstant: 50).isActive = true
        
        print("🏠 HOME_BUTTON: HomeButton created with frame: \(frame)")
    }
    
    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        print("🏠 HOME_BUTTON: moved to superview: \(superview != nil)")
    }
}

// Custom Navigation View Controller with Home Button
class CustomNavigationViewController: NavigationViewController {
    private var homeButton: HomeButton?
    private var homeButtonAction: (() -> Void)?
    
    func addHomeButton(action: @escaping () -> Void) {
        print("🏠 CUSTOM_NAV: addHomeButton called")
        self.homeButtonAction = action
        setupHomeButton()
    }
    
    private func setupHomeButton() {
        guard homeButton == nil else { 
            print("🏠 CUSTOM_NAV: Home button already exists, skipping setup")
            return 
        }
        
        print("🏠 CUSTOM_NAV: Setting up home button in custom navigation controller")
        
        let homeButton = HomeButton()
        self.homeButton = homeButton
        
        homeButton.addTarget(self, action: #selector(homeButtonPressed), for: .touchUpInside)
        
        view.addSubview(homeButton)
        view.bringSubviewToFront(homeButton)
        
        NSLayoutConstraint.activate([
            homeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            homeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
        
        homeButton.layer.zPosition = 1000
        
        print("🏠 CUSTOM_NAV: Home button added to custom navigation controller")
    }
    
    @objc private func homeButtonPressed() {
        print("iOS: Home button pressed in custom navigation controller")
        homeButtonAction?()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("🏠 CUSTOM_NAV: viewDidLoad called")
        
        // Try to configure map style early
        configureMapStyle()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        print("🏠 CUSTOM_NAV: viewDidAppear called")
        
        // Configure map style to match Android
        configureMapStyle()
        
        // Ensure home button is visible after view appears
        if homeButton == nil {
            print("🏠 CUSTOM_NAV: Home button is nil, setting up now")
            setupHomeButton()
        } else {
            print("🏠 CUSTOM_NAV: Home button already exists")
        }
    }
    
    private func configureMapStyle() {
        print("🗺️ CUSTOM_NAV: Configuring map style to match Android")
        
        // Set the same map style URL as defined in Android strings.xml
        let styleURL = URL(string: "https://api.nextbillion.io/tt/style/1/style/22.2.1-9?map=2/basic_street-light&traffic_incidents=2/incidents_light&traffic_flow=2/flow_relative-light")
        
        if let mapView = self.mapView {
            print("🗺️ CUSTOM_NAV: Setting map style URL: \(styleURL?.absoluteString ?? "nil")")
            mapView.styleURL = styleURL
        } else {
            print("⚠️ CUSTOM_NAV: MapView not found, will retry in 0.5 seconds")
            // Retry after a short delay if mapView is not yet available
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self.configureMapStyle()
            }
        }
    }
}

@objc(ReactNativeNextBillionNavigation)
class ReactNativeNextBillionNavigation: NSObject, RCTBridgeModule {
    
    private var navigationViewController: NavigationViewController?
    private var homeButton: HomeButton?
    
    // MARK: - RCTBridgeModule
    
    @objc
    static func moduleName() -> String {
        print("🚀 MODULE: ReactNativeNextBillionNavigation module initialized")
        return "ReactNativeNextBillionNavigation"
    }
    
    @objc
    static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    // MARK: - React Native Methods
    
    @objc
    func testModule(_ resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        print("🧪 TEST: testModule called")
        resolver("iOS module is working!")
    }
    
    @objc
    func launchNavigation(destination: NSArray, options: NSDictionary?, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        print("🚀 NAVIGATION: launchNavigation called with origin: \(origin), destination: \(destination)")
        
        guard let originArray = origin as? [Double], originArray.count >= 2 else {
            print("❌ NAVIGATION: Invalid origin array")
            rejecter("INVALID_ORIGIN", "Origin must be an array with at least 2 elements [lat, lng]", nil)
            return
        }
        
        guard let destinationArray = destination as? [Double], destinationArray.count >= 2 else {
            print("❌ NAVIGATION: Invalid destination array")
            rejecter("INVALID_DESTINATION", "Destination must be an array with at least 2 elements [lat, lng]", nil)
            return
        }
        
        let originLat = originArray[0]
        let originLng = originArray[1]
        let originCoordinate = CLLocationCoordinate2D(latitude: originLat, longitude: originLng)
        
        let destLat = destinationArray[0]
        let destLng = destinationArray[1]
        let destinationCoordinate = CLLocationCoordinate2D(latitude: destLat, longitude: destLng)
        
        print("📍 NAVIGATION: Coordinates - Origin: \(originCoordinate), Destination: \(destinationCoordinate)")
        
        print("iOS: Launching NextBillion.ai navigation from: \(originLat), \(originLng) to: \(destLat), \(destLng)")
        
        // Use the provided origin coordinates
        print("iOS: Using provided origin: \(originLat), \(originLng)")
        
        DispatchQueue.main.async {
            self.startNavigation(from: originCoordinate, to: destinationCoordinate, resolver: resolver, rejecter: rejecter)
        }
    }
    
    private func startNavigation(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        // Create route options with the provided origin
        let routeOptions = NavigationRouteOptions(origin: origin, destination: destination)
        routeOptions.profileIdentifier = .automobile
        routeOptions.includesAlternativeRoutes = true
        routeOptions.shouldSimulateRoute = true
        
        print("iOS: Calculating route from \(origin.latitude), \(origin.longitude) to \(destination.latitude), \(destination.longitude)")
        
        // Fetch route
        Directions.shared.calculate(routeOptions) { [weak self] (session, result) in
            switch result {
            case .success(let response):
                guard let route = response.routes?.first else {
                    DispatchQueue.main.async {
                        rejecter("NO_ROUTE", "No route found", nil)
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self?.presentNavigationViewController(with: route)
                    resolver(nil)
                }
                
            case .failure(let error):
                DispatchQueue.main.async {
                    rejecter("ROUTE_ERROR", "Failed to calculate route: \(error.localizedDescription)", error)
                }
            }
        }
    }
    
    private func presentNavigationViewController(with route: Route) {
        print("🎯 NAVIGATION: presentNavigationViewController called with route")
        
        // Create navigation service
        print("⚙️ NAVIGATION: Creating navigation service")
        let navigationService = NBNavigationService(route: route, routeIndex: 0, routeOptions: route.routeOptions)
        
        // Create navigation options with simulation enabled (like Android)
        print("⚙️ NAVIGATION: Creating navigation options")
        let navigationOptions = NavigationOptions(navigationService: navigationService)
        navigationOptions.simulatesLocation = true // Enable simulation like Android's shouldSimulateRoute(true)
        navigationOptions.simulatesHeading = true
        
        // Create custom navigation view controller
        print("🏠 NAVIGATION: Creating CustomNavigationViewController")
        let navVC = CustomNavigationViewController(for: route, navigationOptions: navigationOptions)
        navVC.modalPresentationStyle = .fullScreen
        
        // Add home button with action
        print("🔘 NAVIGATION: Adding home button to navigation controller")
        navVC.addHomeButton { [weak self] in
            print("🏠 NAVIGATION: Home button action triggered")
            self?.homeButtonPressed()
        }
        
        // Store reference
        self.navigationViewController = navVC
        print("💾 NAVIGATION: Stored navigation view controller reference")
        
        // Present navigation view controller
        print("📱 NAVIGATION: Presenting navigation view controller")
        if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,
           let rootController = keyWindow.rootViewController {
            rootController.present(navVC, animated: true) {
                print("✅ NAVIGATION: Navigation view controller presented successfully")
            }
        }
    }
    
    private func setupHomeButton(in navigationViewController: NavigationViewController) {
        print("iOS: Setting up home button")
        
        // Create home button
        let homeButton = HomeButton()
        self.homeButton = homeButton
        
        // Add target for button press
        homeButton.addTarget(self, action: #selector(homeButtonPressed), for: .touchUpInside)
        
        // Add button to navigation view controller's main view
        navigationViewController.view.addSubview(homeButton)
        print("iOS: Home button added to navigation view controller")
        
        // Bring button to front to ensure it's visible
        navigationViewController.view.bringSubviewToFront(homeButton)
        
        // Position button in top-right corner
        NSLayoutConstraint.activate([
            homeButton.topAnchor.constraint(equalTo: navigationViewController.view.safeAreaLayoutGuide.topAnchor, constant: 20),
            homeButton.trailingAnchor.constraint(equalTo: navigationViewController.view.trailingAnchor, constant: -20)
        ])
        
        // Make sure button is visible and on top
        homeButton.isHidden = false
        homeButton.alpha = 1.0
        homeButton.layer.zPosition = 1000 // Ensure it's on top
        
        print("iOS: Home button setup complete - isHidden: \(homeButton.isHidden), alpha: \(homeButton.alpha), zPosition: \(homeButton.layer.zPosition)")
        print("iOS: Navigation view bounds: \(navigationViewController.view.bounds)")
        print("iOS: Home button frame: \(homeButton.frame)")
    }
    
    private func homeButtonPressed() {
        print("iOS: Home button pressed - returning to home screen")
        
        // Dismiss navigation and return to home
        DispatchQueue.main.async {
            if let navVC = self.navigationViewController {
                navVC.dismiss(animated: true) {
                    self.navigationViewController = nil
                    self.homeButton = nil
                    print("iOS: Navigation dismissed, returned to home screen")
                }
            }
        }
    }
    
    @objc
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
    
    @objc
    func resumeNavigation(_ resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        print("iOS: Resuming navigation")
        
        DispatchQueue.main.async {
            if let navVC = self.navigationViewController {
                // Navigation is already running, bring it to foreground
                if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,
                   let rootController = keyWindow.rootViewController {
                    rootController.present(navVC, animated: true) {
                        resolver(nil)
                    }
                } else {
                    resolver(nil)
                }
            } else {
                // No navigation running
                rejecter("NO_NAVIGATION", "No navigation session to resume", nil)
            }
        }
    }
}