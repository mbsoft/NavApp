import Foundation
import UIKit
import React
import Nbmap
import NbmapCoreNavigation
import NbmapNavigation
import ActivityKit
import BackgroundTasks


// Live Activity Attributes
struct ETAAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var eta: String
        var instruction: String
        var remainingDistance: String
        var progressPercentage: Int
        var isNavigating: Bool
    }
    
    var destination: String
}

// Live Activity Manager
@available(iOS 16.2, *)
class LiveActivityManager: ObservableObject {
    private var currentActivity: Activity<ETAAttributes>?
    
    var isActivityActive: Bool {
        return currentActivity != nil
    }
    
    func startLiveActivity(destination: String, eta: String, instruction: String, remainingDistance: String, progressPercentage: Int = 0) {
        print("🔴 LiveActivityManager: ===== STARTING LIVE ACTIVITY =====")
        print("🔴 LiveActivityManager: Attempting to start Live Activity")
        print("🔴 LiveActivityManager: Destination: \(destination), ETA: \(eta)")
        print("🔴 LiveActivityManager: Instruction: \(instruction)")
        print("🔴 LiveActivityManager: Remaining Distance: \(remainingDistance)")
        
        // Check Live Activities authorization
        let authStatus = ActivityAuthorizationInfo().areActivitiesEnabled
        print("🔴 LiveActivityManager: Live Activities authorization status: \(authStatus)")
        
        if !authStatus {
            print("🔴 LiveActivityManager: Live Activities not authorized")
            print("🔴 LiveActivityManager: Please search 'Live Activities' in Settings and enable for NavApp")
            return
        }
        
        // Check if we have permission to request activities
        Task {
            let status = await ActivityAuthorizationInfo().areActivitiesEnabled
            print("🔴 LiveActivityManager: Live Activities enabled status: \(status)")
            
            if !status {
                print("🔴 LiveActivityManager: Live Activities not enabled. Please go to Settings > Privacy & Security > Live Activities and enable for NavApp")
                return
            }
        }
        
        print("🔴 LiveActivityManager: Live Activities are enabled, proceeding...")
        print("🔴 LiveActivityManager: Current Live Activities count: \(Activity<ETAAttributes>.activities.count)")
        
        stopLiveActivity()
        
        let attributes = ETAAttributes(destination: destination)
        let contentState = ETAAttributes.ContentState(
            eta: eta,
            instruction: instruction,
            remainingDistance: remainingDistance,
            progressPercentage: progressPercentage,
            isNavigating: true
        )
        
        do {
            // Try without pushType first (simulator-friendly)
            let activity = try Activity<ETAAttributes>.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: nil),
                pushType: nil
            )
            currentActivity = activity
            print("🔴 LiveActivityManager: Live Activity started successfully")
            print("🔴 LiveActivityManager: Activity ID: \(activity.id)")
            print("🔴 LiveActivityManager: Activity state: \(activity.activityState)")
            print("🔴 LiveActivityManager: Total activities now: \(Activity<ETAAttributes>.activities.count)")
        } catch {
            print("🔴 LiveActivityManager: Failed to start Live Activity: \(error)")
            print("🔴 LiveActivityManager: Error details: \(error.localizedDescription)")
            print("🔴 LiveActivityManager: Error type: \(type(of: error))")
        }
    }
    
    func updateLiveActivity(eta: String, instruction: String, remainingDistance: String, progressPercentage: Int = 0) {
        guard let activity = currentActivity else { return }
        
        let contentState = ETAAttributes.ContentState(
            eta: eta,
            instruction: instruction,
            remainingDistance: remainingDistance,
            progressPercentage: progressPercentage,
            isNavigating: true
        )
        
        Task {
            await activity.update(.init(state: contentState, staleDate: nil))
        }
    }
    
    func stopLiveActivity() {
        guard let activity = currentActivity else { return }
        
        let contentState = ETAAttributes.ContentState(
            eta: "",
            instruction: "Navigation completed",
            remainingDistance: "",
            progressPercentage: 100,
            isNavigating: false
        )
        
        Task {
            await activity.end(.init(state: contentState, staleDate: nil), dismissalPolicy: .immediate)
        }
        
        currentActivity = nil
    }
}

@objc(ReactNativeNextBillionNavigation)
class ReactNativeNextBillionNavigation: NSObject, RCTBridgeModule, NavigationViewControllerDelegate, NavigationServiceDelegate {
    
    private var navigationViewController: NavigationViewController?
    private var navigationService: NBNavigationService?
    private var maneuverTimer: Timer?
    @objc var bridge: RCTBridge?
    
    // Live Activity Manager
    private var liveActivityManager: Any?
    
    // Background task handling
    private var backgroundTaskIdentifier: UIBackgroundTaskIdentifier = .invalid
    private var isNavigationActive = false
    private var backgroundRefreshTimer: Timer?
    private var navigationServiceMonitorTimer: Timer?
    
    override init() {
        super.init()
        setupAppLifecycleMonitoring()
        setupCustomLocalization()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopBackgroundRefreshTimer()
        stopNavigationServiceMonitor()
        endBackgroundTask()
    }
    
    
    // MARK: - RCTBridgeModule
    
    @objc
    static func moduleName() -> String {
        return "ReactNativeNextBillionNavigation"
    }
    
    @objc
    static func requiresMainQueueSetup() -> Bool {
        return true
    }
    
    private func sendEvent(eventName: String, params: [String: Any]? = nil) {
        guard let bridge = bridge else { return }
        bridge.eventDispatcher().sendAppEvent(withName: eventName, body: params)
    }
    
    private func setupNavigationServiceListener() {
        guard let navigationService = navigationService else { 
            print("🔴 NavigationModule: No navigation service available for listener setup")
            return 
        }
        
        print("🔴 NavigationModule: Setting up navigation service listener")
        // Start a timer to periodically check navigation status
        maneuverTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            print("🔴 NavigationModule: Timer fired, checking navigation status")
            self?.checkNavigationStatus()
        }
        print("🔴 NavigationModule: Timer started")
    }
    
    private func formatDistanceImperial(distanceInMeters: Int) -> String {
        let metersToYards: Double = 1.09361
        let metersToMiles: Double = 0.000621371
        
        if distanceInMeters < 1609 { // Less than 1 mile
            let yards = Int(Double(distanceInMeters) * metersToYards)
            if yards < 100 {
                return "\(yards) yards"
            } else {
                return "\(yards) yards"
            }
        } else {
            let miles = Double(distanceInMeters) * metersToMiles
            if miles < 10 {
                return String(format: "%.1f miles", miles)
            } else {
                return String(format: "%.0f miles", miles)
            }
        }
    }
    
    private func checkNavigationStatus() {
        guard let navigationService = navigationService else { return }
        
        // Get current location and route progress from the navigation service
        let location = navigationService.locationManager.location
        let routeProgress = navigationService.routeProgress
        
        guard let currentLocation = location else { return }
        
        // Get current step information
        let currentStep = routeProgress.currentLegProgress.currentStepProgress.step
        let stepDistance = routeProgress.currentLegProgress.currentStepProgress.distanceRemaining
        let stepDuration = routeProgress.currentLegProgress.currentStepProgress.durationRemaining
        
        // Extract maneuver type and direction from RouteStep
        let maneuverType = currentStep.maneuverType.rawValue
        let maneuverDirection = currentStep.maneuverDirection.rawValue
        
        // Get the actual maneuver instruction from the RouteStep
        var instruction = "Continue on current route"
        let distanceInMeters = Int(stepDistance)
        
        // Try to get the actual instruction from the RouteStep
      if let firstInstruction = currentStep.instructionsDisplayedAlongStep?.first,
         let primaryInstruction = firstInstruction.primaryInstruction,
         let stepInstruction = primaryInstruction.instruction,
         !stepInstruction.isEmpty {
          
          instruction = stepInstruction
          
      } else {
          // Fallback to distance-based instruction if no step instruction available
          let imperialDistance = formatDistanceImperial(distanceInMeters: distanceInMeters)
          
          if distanceInMeters < 50 {
              instruction = "In \(imperialDistance), continue straight"
          } else if distanceInMeters < 200 {
              instruction = "Continue straight for \(imperialDistance)"
          } else if distanceInMeters < 500 {
              instruction = "Continue on current route for \(imperialDistance)"
          } else {
              instruction = "Continue on current route"
          }
      }
        
        // Convert distance to imperial for display
        let distanceInMiles = Double(stepDistance) * 0.000621371
        
        // Calculate ETA in 24-hour format
        let etaDate = Date().addingTimeInterval(routeProgress.durationRemaining)
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let etaString = formatter.string(from: etaDate)
        
        // Format remaining distance
        let remainingDistanceInMiles = routeProgress.distanceRemaining * 0.000621371
        let remainingDistanceString = formatDistanceImperial(distanceInMeters: Int(routeProgress.distanceRemaining))
        
        // Calculate progress percentage
        let totalDistance = routeProgress.distanceRemaining + routeProgress.distanceTraveled
        let progressPercentage = totalDistance > 0 ? Int((routeProgress.distanceTraveled / totalDistance) * 100) : 0
        
        // Update Live Activity if available
        if #available(iOS 16.2, *) {
            print("🔴 NavigationModule: iOS 16.2+ available, checking Live Activity manager")
            if let manager = liveActivityManager as? LiveActivityManager {
                print("🔴 NavigationModule: Live Activity manager found")
                // Check if this is the first update (start Live Activity)
                if !manager.isActivityActive {
                    print("🔴 NavigationModule: Starting new Live Activity")
                    manager.startLiveActivity(
                        destination: "Destination",
                        eta: etaString,
                        instruction: instruction,
                        remainingDistance: remainingDistanceString,
                        progressPercentage: progressPercentage
                    )
                } else {
                    print("🔴 NavigationModule: Updating existing Live Activity")
                    manager.updateLiveActivity(
                        eta: etaString,
                        instruction: instruction,
                        remainingDistance: remainingDistanceString,
                        progressPercentage: progressPercentage
                    )
                }
            } else {
                print("🔴 NavigationModule: Live Activity manager not found")
            }
        } else {
            print("🔴 NavigationModule: iOS version too old for Live Activities")
        }
        
        // Send maneuver instruction to React Native
        let maneuverData: [String: Any] = [
            "instruction": instruction,
            "distance": distanceInMiles,
            "duration": stepDuration,
            "maneuverType": maneuverType,
            "maneuverDirection": maneuverDirection,
            "location": [
                "latitude": currentLocation.coordinate.latitude,
                "longitude": currentLocation.coordinate.longitude,
                "altitude": currentLocation.altitude,
                "course": currentLocation.course,
                "speed": currentLocation.speed
            ],
            "routeProgress": [
                "distanceRemaining": routeProgress.distanceRemaining,
                "durationRemaining": routeProgress.durationRemaining,
                "fractionTraveled": routeProgress.fractionTraveled
            ]
        ]
        
        sendEvent(eventName: "NavigationManeuver", params: maneuverData)
    }
    
    private func cleanupNavigationServiceListener() {
        maneuverTimer?.invalidate()
        maneuverTimer = nil
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
        let avoidances = (options["avoidances"] as? [String]) ?? []
        let truckSize = (options["truckSize"] as? [String]) ?? []
        let truckWeight = (options["truckWeight"] as? Int) ?? 0
        
        let lat = destinationArray[0]
        let lng = destinationArray[1]
        let destinationCoordinate = CLLocationCoordinate2D(latitude: lat, longitude: lng)
        
        let olat = originArray[0]
        let olng = originArray[1]
        let originCoordinate = CLLocationCoordinate2D(latitude: olat, longitude: olng)

        print("iOS: Launching NextBillion.ai navigation to: \(lat), \(lng) with mode: \(mode), units: \(units), avoidances: \(avoidances), truckSize: \(truckSize), truckWeight: \(truckWeight)")
        
        DispatchQueue.main.async {
            self.startNavigation(from: originCoordinate, to: destinationCoordinate, simulate: simulate, mode: mode, units: units, avoidances: avoidances, truckSize: truckSize, truckWeight: truckWeight, resolver: resolver, rejecter: rejecter)
        }
    }
    
    private func startNavigation(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D, simulate: Bool, mode: String, units: String, avoidances: [String], truckSize: [String], truckWeight: Int, resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        // Get current location (for demo purposes, using a default location)
        let originLocation = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
        let destinationLocation = CLLocation(latitude: destination.latitude, longitude: destination.longitude)
        
        // Create route options
        let options = NavigationRouteOptions(origin: originLocation, destination: destinationLocation)
        // Set navigation mode based on the selected mode
        switch mode {
        case "truck":
            options.profileIdentifier = NBNavigationMode.truck
        case "bike":
            options.profileIdentifier = NBNavigationMode.bike
        case "pedestrian":
            // Use bike mode as closest approximation to pedestrian routing
            // since NBNavigationMode.pedestrian is not available in the SDK
            options.profileIdentifier = NBNavigationMode.bike
            print("iOS: Using bike mode as approximation for pedestrian routing (pedestrian mode not available in SDK)")
        default:
            options.profileIdentifier = NBNavigationMode.car
        }
        options.includesAlternativeRoutes = true
        options.distanceMeasurementSystem = (units == "imperial") ? .imperial : .metric
        options.departureTime = Int(Date().timeIntervalSince1970)
        options.locale = Locale.autoupdatingCurrent
        options.mapOption = .valhalla
        options.shapeFormat = .polyline6
        options.avoid = avoidances
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
        
        // Add avoidances
        print("iOS: Avoidances: \(avoidances)")
        // Note: NextBillion.ai iOS SDK specific avoidances configuration
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
            navigationService.simulationSpeedMultiplier = 10
            navigationService.delegate = self
            // Store navigation service reference for background listening
            self.navigationService = navigationService
            
            // Set navigation as active and start background task
            self.isNavigationActive = true
            self.startBackgroundTask()
            self.startNavigationServiceMonitor()
            
            // Initialize the NavigationViewController
            let navigationViewController = NavigationViewController(for: routes, navigationOptions: navigationOptions)
            navigationViewController.modalPresentationStyle = .fullScreen
            navigationViewController.routeLineTracksTraversal = true
            
            // Set delegate to handle navigation events
            navigationViewController.delegate = self
            
            // Add custom UI element to return to home screen
            self.addCustomUI(to: navigationViewController)
            
            self.navigationViewController = navigationViewController
            
            // Set up navigation service listener for background maneuver updates
            self.setupNavigationServiceListener()
            
            // Initialize Live Activity Manager (will start in checkNavigationStatus)
            if #available(iOS 16.2, *) {
                print("🔴 NavigationModule: Initializing Live Activity Manager")
                if liveActivityManager == nil {
                    liveActivityManager = LiveActivityManager()
                    print("🔴 NavigationModule: Live Activity Manager created")
                } else {
                    print("🔴 NavigationModule: Live Activity Manager already exists")
                }
            } else {
                print("🔴 NavigationModule: iOS version too old for Live Activities")
            }
            
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
            // Clean up navigation service listener
            self.cleanupNavigationServiceListener()
            self.navigationService = nil
            self.navigationViewController = nil
            
            // Set navigation as inactive and end background task
            self.isNavigationActive = false
            self.endBackgroundTask()
            
            // Stop Live Activity when navigation stops
            if #available(iOS 16.2, *) {
                if let manager = self.liveActivityManager as? LiveActivityManager {
                    manager.stopLiveActivity()
                }
            }
            
            resolver(nil)
                }
            } else {
                resolver(nil)
            }
        }
    }
    
    @objc(resumeNavigation:rejecter:)
    func resumeNavigation(_ resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        print("iOS: Resuming navigation")
        
        DispatchQueue.main.async {
            if let navVC = self.navigationViewController {
                // Show the navigation view if it was hidden
                navVC.view.isHidden = false
                
                if let keyWindow = UIApplication.shared.windows.first(where: { $0.isKeyWindow }) ?? UIApplication.shared.windows.first,
                   let rootController = keyWindow.rootViewController {
                    rootController.present(navVC, animated: true) {
                        resolver(nil)
                    }
                } else {
                    rejecter("PRESENTATION_ERROR", "Could not present navigation view", nil)
                }
            } else {
                rejecter("NO_NAVIGATION", "No navigation session to resume", nil)
            }
        }
    }
    
    @objc(hideNavigation:rejecter:)
    func hideNavigation(_ resolver: @escaping RCTPromiseResolveBlock, rejecter: @escaping RCTPromiseRejectBlock) {
        print("iOS: Hiding navigation (keeping it running in background)")
        
        DispatchQueue.main.async {
            if let navVC = self.navigationViewController {
                navVC.dismiss(animated: true) {
                    // Navigation continues running in background
                    resolver(nil)
                }
            } else {
                rejecter("NO_NAVIGATION", "No navigation session to hide", nil)
            }
        }
    }
    
    private func addCustomUI(to navigationViewController: NavigationViewController) {
        // Create a custom button to return to home screen
        let homeButton = UIButton(type: .system)
        homeButton.setTitle("🏠", for: .normal)
        homeButton.setTitleColor(.white, for: .normal)
        homeButton.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        homeButton.layer.cornerRadius = 20
        homeButton.titleLabel?.font = UIFont.systemFont(ofSize: 20, weight: .bold)
        homeButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Add action to dismiss navigation and return to home
        homeButton.addTarget(self, action: #selector(returnToHome), for: .touchUpInside)
        
        // Add button to navigation view
        navigationViewController.view.addSubview(homeButton)
        
        // Position button in top-right corner with safe area
        NSLayoutConstraint.activate([
            homeButton.topAnchor.constraint(equalTo: navigationViewController.view.safeAreaLayoutGuide.topAnchor, constant: 20),
            homeButton.trailingAnchor.constraint(equalTo: navigationViewController.view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            homeButton.widthAnchor.constraint(equalToConstant: 40),
            homeButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    @objc private func returnToHome() {
        print("iOS: Returning to home screen while keeping navigation running")
        
        DispatchQueue.main.async {
            if let navVC = self.navigationViewController {
                // Just dismiss the view controller without calling dismissNavigation
                // This keeps the navigation session alive in the background
                navVC.dismiss(animated: true) {
                    print("iOS: Navigation view dismissed but navigation continues running in background")
                    // Send event to React Native to update the UI state
                    self.sendEvent(eventName: "NavigationHidden")
                }
            }
        }
    }
    
    // MARK: - Background Task Handling
    
    private func startBackgroundTask() {
        print("🔴 NavigationModule: Starting background task")
        backgroundTaskIdentifier = UIApplication.shared.beginBackgroundTask(withName: "NavigationTask") { [weak self] in
            print("🔴 NavigationModule: Background task expired - restarting")
            self?.endBackgroundTask()
            // Restart background task if navigation is still active
            if self?.isNavigationActive == true {
                self?.startBackgroundTask()
            }
        }
        
        // Start background refresh timer to keep the task alive
        startBackgroundRefreshTimer()
    }
    
    private func startBackgroundRefreshTimer() {
        backgroundRefreshTimer?.invalidate()
        backgroundRefreshTimer = Timer.scheduledTimer(withTimeInterval: 20.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isNavigationActive else { return }
            
            print("🔴 NavigationModule: Refreshing background task")
            self.endBackgroundTask()
            self.startBackgroundTask()
            
            // Also ensure navigation service keeps running
            if let navigationService = self.navigationService {
                print("🔴 NavigationModule: Ensuring navigation service continues in background")
                // Call start() to ensure the service keeps running
                navigationService.start()
            }
        }
    }
    
    private func stopBackgroundRefreshTimer() {
        backgroundRefreshTimer?.invalidate()
        backgroundRefreshTimer = nil
    }
    
    private func startNavigationServiceMonitor() {
        navigationServiceMonitorTimer?.invalidate()
        navigationServiceMonitorTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self = self, self.isNavigationActive else { return }
            
            if let navigationService = self.navigationService {
                print("🔴 NavigationModule: Ensuring navigation service continues running")
                // Call start() to ensure the service keeps running
                navigationService.start()
            }
        }
    }
    
    private func stopNavigationServiceMonitor() {
        navigationServiceMonitorTimer?.invalidate()
        navigationServiceMonitorTimer = nil
    }
    
    private func endBackgroundTask() {
        if backgroundTaskIdentifier != .invalid {
            print("🔴 NavigationModule: Ending background task")
            UIApplication.shared.endBackgroundTask(backgroundTaskIdentifier)
            backgroundTaskIdentifier = .invalid
        }
        stopBackgroundRefreshTimer()
        stopNavigationServiceMonitor()
    }
    
    private func setupCustomLocalization() {
        // Override the RESUME string to show "RECENTER" instead of "RE-CENTRE"
        // This method sets up custom localization by overriding the string in UserDefaults
        let customStrings = ["RESUME": "RECENTER"]
        UserDefaults.standard.set(customStrings, forKey: "CustomLocalizedStrings")
    }
    
    private func setupAppLifecycleMonitoring() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }
    
    @objc private func appDidEnterBackground() {
        print("🔴 NavigationModule: App entered background - navigation active: \(isNavigationActive)")
        if isNavigationActive {
            // Ensure navigation continues in background
            startBackgroundTask()
            
            // Keep navigation service running
            if let navigationService = navigationService {
                print("🔴 NavigationModule: Ensuring navigation service continues in background")
                
                // Force the navigation service to continue running
                // by ensuring it doesn't pause when app goes to background
                DispatchQueue.main.async {
                    print("🔴 NavigationModule: Ensuring navigation service continues in background")
                    // Call start() to ensure the service keeps running
                    navigationService.start()
                }
            }
        }
    }
    
    @objc private func appWillEnterForeground() {
        print("🔴 NavigationModule: App will enter foreground - navigation active: \(isNavigationActive)")
        if isNavigationActive {
            // Refresh background task when returning to foreground
            endBackgroundTask()
            startBackgroundTask()
        }
    }
    
    // MARK: - NavigationServiceDelegate
    
    func navigationService(_ service: NavigationService, didArriveAt waypoint: Waypoint) {
        print("🔴 NavigationModule: Arrived at destination - clearing Live Activity")
        
        // Clear Live Activity when navigation completes
        if #available(iOS 16.2, *) {
            if let manager = self.liveActivityManager as? LiveActivityManager {
                manager.stopLiveActivity()
            }
        }
        
        // Set navigation as inactive and end background task
        self.isNavigationActive = false
        self.endBackgroundTask()
        
        // Send event to React Native
        self.sendEvent(eventName: "NavigationStopped")
    }
    
    // MARK: - NavigationViewControllerDelegate
    
    func navigationViewControllerDidDismiss(_ navigationViewController: NavigationViewController, byCanceling canceled: Bool) {
        print("iOS: Navigation view controller dismissed, canceled: \(canceled)")
        
        if canceled {
            // User pressed the Exit button within the navigation module
            print("iOS: Navigation canceled by user - stopping navigation completely")
            
            // Stop the navigation service after a delay to ensure dismissal completes
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 2.0) {
                navigationViewController.navigationService.stop()
            }
            
            // Set navigation as inactive and end background task
            self.isNavigationActive = false
            self.endBackgroundTask()
            
            // Stop Live Activity when navigation stops
            if #available(iOS 16.2, *) {
                if let manager = self.liveActivityManager as? LiveActivityManager {
                    manager.stopLiveActivity()
                }
            }
            
            // Dismiss the navigation view controller to return to home screen
            DispatchQueue.main.async {
                navigationViewController.dismiss(animated: true) {
                    print("iOS: Navigation view controller dismissed after Exit button press")
                }
            }
            
            // Clean up navigation service listener
            self.cleanupNavigationServiceListener()
            self.navigationService = nil
            
            // Stop Live Activity
            if #available(iOS 16.2, *) {
                if let manager = liveActivityManager as? LiveActivityManager {
                    manager.stopLiveActivity()
                }
            }
            
            self.sendEvent(eventName: "NavigationStopped")
            self.navigationViewController = nil
        } else {
            // Navigation completed normally
            print("iOS: Navigation completed normally")
            
            // Clean up navigation service listener
            self.cleanupNavigationServiceListener()
            self.navigationService = nil
            
            // Stop Live Activity
            if #available(iOS 16.2, *) {
                if let manager = liveActivityManager as? LiveActivityManager {
                    manager.stopLiveActivity()
                }
            }
            
            self.sendEvent(eventName: "NavigationStopped")
            self.navigationViewController = nil
        }
    }
}
