package com.navapp

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.os.Bundle
import android.util.Log
import androidx.appcompat.app.AppCompatActivity
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import ai.nextbillion.kits.directions.models.DirectionsRoute
import ai.nextbillion.kits.geojson.Point
import ai.nextbillion.maps.location.modes.RenderMode
import ai.nextbillion.navigation.core.navigation.NavEngineConfig
import ai.nextbillion.navigation.core.navigation.NavigationConstants
import ai.nextbillion.navigation.core.navigator.NavProgress
import ai.nextbillion.navigation.core.navigator.ProgressChangeListener
import ai.nextbillion.navigation.ui.NavViewConfig
import ai.nextbillion.navigation.ui.NavigationView
import ai.nextbillion.navigation.ui.OnNavigationReadyCallback
import ai.nextbillion.navigation.ui.listeners.NavigationListener
import ai.nextbillion.navigation.ui.listeners.RouteListener
import ai.nextbillion.navigation.ui.utils.StatusBarUtils
import android.widget.Button
import com.facebook.react.bridge.WritableMap
import com.facebook.react.bridge.Arguments
import com.facebook.react.modules.core.DeviceEventManagerModule
import java.util.*

class NavigationActivity : AppCompatActivity(), OnNavigationReadyCallback, NavigationListener, 
    ProgressChangeListener, RouteListener, StatusBarUtils.OnWindowInsetsChange {
    
    private lateinit var navigationView: NavigationView
    private lateinit var homeButton: Button
    private var destinationLat: Double = 0.0
    private var destinationLng: Double = 0.0
    private var route: DirectionsRoute? = null
    private var isPausedByUser = false
    private var units: String = "metric"
    
    companion object {
        private var isPausedByUserStatic = false
        private var savedRoute: DirectionsRoute? = null
        private var savedDestinationLat: Double = 0.0
        private var savedDestinationLng: Double = 0.0
        private var savedProgress: Double = 0.0
        private var savedRemainingDistance: Double = 0.0
        private var savedRemainingDuration: Double = 0.0
    }
    
    fun setPausedByUser(paused: Boolean) {
        isPausedByUser = paused
        isPausedByUserStatic = paused
    }
    
    fun resumeNavigation() {
        Log.d("NavigationActivity", "resumeNavigation called, isPausedByUserStatic: $isPausedByUserStatic")
        if (isPausedByUserStatic) {
            isPausedByUser = false
            isPausedByUserStatic = false
            Log.d("NavigationActivity", "Resetting pause flags and bringing activity to foreground")
            // Send event that navigation is resumed
            sendEvent("NavigationResumed")
            // Bring this activity back to foreground
            val intent = Intent(this, NavigationActivity::class.java)
            // Pass the saved route data
            if (savedRoute != null) {
                intent.putExtra("route", savedRoute)
                intent.putExtra("destination_lat", savedDestinationLat)
                intent.putExtra("destination_lng", savedDestinationLng)
                Log.d("NavigationActivity", "Passing saved route data to resumed activity")
            }
            intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
            intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
            intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
            startActivity(intent)
        } else {
            Log.d("NavigationActivity", "Not paused by user, no action needed")
        }
    }
    
    private fun sendEvent(eventName: String, params: WritableMap? = null) {
        try {
            val reactContext = applicationContext as? com.facebook.react.ReactApplication
            reactContext?.reactNativeHost?.reactInstanceManager?.currentReactContext?.let { context ->
                context.getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
                    .emit(eventName, params)
            }
        } catch (e: Exception) {
            Log.e("NavigationActivity", "Error sending event: $eventName", e)
        }
    }
    
    private val permissions = arrayOf(
        Manifest.permission.ACCESS_FINE_LOCATION,
        Manifest.permission.ACCESS_COARSE_LOCATION
    )
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d("NavigationActivity", "onCreate called")
        
        try {
            setContentView(R.layout.activity_navigation)
            Log.d("NavigationActivity", "Layout set successfully")
            
            // Get destination coordinates
            destinationLat = intent.getDoubleExtra("destination_lat", 0.0)
            destinationLng = intent.getDoubleExtra("destination_lng", 0.0)
            units = intent.getStringExtra("units") ?: "metric"
            Log.d("NavigationActivity", "Destination: $destinationLat, $destinationLng, Units: $units")
            
            // Get route if passed
            route = intent.getSerializableExtra("route") as? DirectionsRoute
            Log.d("NavigationActivity", "Route received: ${route != null}")
            
            // Save route data for resume functionality
            if (route != null) {
                savedRoute = route
                savedDestinationLat = destinationLat
                savedDestinationLng = destinationLng
                Log.d("NavigationActivity", "Route data saved for resume")
            } else if (savedRoute != null) {
                // Restore saved route data for resume
                route = savedRoute
                destinationLat = savedDestinationLat
                destinationLng = savedDestinationLng
                Log.d("NavigationActivity", "Route data restored from saved state")
            }
            
            navigationView = findViewById(R.id.navigation_view)
            Log.d("NavigationActivity", "NavigationView found: ${navigationView != null}")
            
            homeButton = findViewById(R.id.home_button)
            Log.d("NavigationActivity", "HomeButton found: ${homeButton != null}")
            
            // Set up home button click listener
            homeButton.setOnClickListener {
                Log.d("NavigationActivity", "Home button pressed - pausing navigation")
                // Set flags immediately to prevent premature navigation finish
                isPausedByUser = true
                isPausedByUserStatic = true
                Log.d("NavigationActivity", "Flags set - isPausedByUser: $isPausedByUser, isPausedByUserStatic: $isPausedByUserStatic")
                // Send event that navigation is paused but still running
                sendEvent("NavigationPaused")
                // Return to MainActivity (React Native app) while keeping NavigationActivity alive
                val intent = Intent(this, MainActivity::class.java)
                intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                startActivity(intent)
                Log.d("NavigationActivity", "Intent started to return to MainActivity")
            }
            
            navigationView.onCreate(savedInstanceState)
            Log.d("NavigationActivity", "NavigationView onCreate called")
            
            // Set up status bar
            StatusBarUtils.transparentStatusBar(this, this)
            if (navigationView.isNightTheme()) {
                StatusBarUtils.setDarkMode(this)
            } else {
                StatusBarUtils.setLightMode(this)
            }
            Log.d("NavigationActivity", "Status bar configured")
            
            // Request permissions
            requestPermissions()
            Log.d("NavigationActivity", "Permission request initiated")
            
        } catch (e: Exception) {
            Log.e("NavigationActivity", "Error in onCreate", e)
            throw e
        }
    }
    
    private fun requestPermissions() {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_FINE_LOCATION) 
            != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, permissions, 200)
        } else {
            initializeNavigation()
        }
    }
    
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 200) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                initializeNavigation()
            } else {
                Log.e("NavigationActivity", "Location permission denied")
                finish()
            }
        }
    }
    
    private fun initializeNavigation() {
        navigationView.initialize(this)
    }
    
    override fun onNavigationReady(isRunning: Boolean) {
        Log.d("NavigationActivity", "Navigation ready, isRunning: $isRunning, units: $units")
        
        val navConfig = NavEngineConfig.builder().build()
        val viewConfigBuilder = NavViewConfig.builder()
            .navigationListener(this)
            .progressChangeListener(this)
            .routeListener(this)
            .shouldSimulateRoute(true)
            .showSpeedometer(true)
            .locationLayerRenderMode(RenderMode.GPS)
            .navConfig(navConfig)
        
        // Set route if available
        route?.let { 
            viewConfigBuilder.route(it)
        }
        
        navigationView.startNavigation(viewConfigBuilder.build())
    }
    
    // NavigationListener methods
    override fun onCancelNavigation() {
        Log.d("NavigationActivity", "Navigation cancelled, isPausedByUser: $isPausedByUser, isPausedByUserStatic: $isPausedByUserStatic")
        if (!isPausedByUserStatic) {
            Log.d("NavigationActivity", "Sending NavigationStopped event and finishing")
            sendEvent("NavigationStopped")
            finish()
        } else {
            Log.d("NavigationActivity", "Navigation cancelled but paused by user, not finishing")
        }
    }
    
    override fun onNavigationFinished() {
        Log.d("NavigationActivity", "Navigation finished, isPausedByUser: $isPausedByUser, isPausedByUserStatic: $isPausedByUserStatic")
        Log.d("NavigationActivity", "Navigation finished - checking pause flags before deciding action")
        
        // Double-check the static flag to ensure we have the most current state
        if (!isPausedByUserStatic) {
            Log.d("NavigationActivity", "Sending NavigationStopped event and finishing")
            sendEvent("NavigationStopped")
            finish()
        } else {
            Log.d("NavigationActivity", "Navigation finished but paused by user, not finishing - keeping activity alive")
            // Don't call finish() - keep the activity alive for resume
        }
    }
    
    override fun onNavigationRunning() {
        Log.d("NavigationActivity", "Navigation running")
        sendEvent("NavigationStarted")
    }
    
    // ProgressChangeListener methods
    override fun onProgressChange(location: Location, navProgress: NavProgress) {
        val distanceRemaining = navProgress.distanceRemaining
        val distanceText = if (units == "imperial") {
            val miles = distanceRemaining * 0.000621371 // Convert meters to miles
            String.format("%.2f mi", miles)
        } else {
            val km = distanceRemaining / 1000.0 // Convert meters to kilometers
            String.format("%.2f km", km)
        }
        Log.d("NavigationActivity", "Progress: $distanceText remaining")
        // Save progress for resume functionality
        savedProgress = navProgress.fractionTraveled
        savedRemainingDistance = navProgress.distanceRemaining
        savedRemainingDuration = navProgress.durationRemaining
    }
    
    override fun allowRerouteFrom(location: Location): Boolean {
        return true
    }
    
    // RouteListener methods
    override fun onOffRoute(point: Point) {
        Log.d("NavigationActivity", "Off route at: $point")
    }
    
    override fun onRerouteAlong(directionsRoute: DirectionsRoute) {
        Log.d("NavigationActivity", "Rerouting along new route")
    }
    
    override fun onFailedReroute(error: String) {
        Log.e("NavigationActivity", "Failed to reroute: $error")
    }
    
    override fun onArrival(navProgress: NavProgress, waypointIndex: Int) {
        Log.d("NavigationActivity", "Arrived at waypoint $waypointIndex")
    }
    
    override fun onUserInTunnel(inTunnel: Boolean) {
        Log.d("NavigationActivity", "User in tunnel: $inTunnel")
    }
    
    override fun shouldShowArriveDialog(navProgress: NavProgress, waypointIndex: Int): Boolean {
        return false
    }
    
    override fun customArriveDialog(navProgress: NavProgress, waypointIndex: Int): com.google.android.material.bottomsheet.BottomSheetDialog? {
        return null
    }
    
    // StatusBarUtils.OnWindowInsetsChange
    override fun onApplyWindowInsets(windowInsets: android.view.WindowInsets) {
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.KITKAT_WATCH) {
            navigationView.fitSystemWindow(windowInsets)
        }
    }
    
    // Activity lifecycle methods
    override fun onStart() {
        super.onStart()
        navigationView.onStart()
    }
    
    override fun onResume() {
        super.onResume()
        navigationView.onResume()
    }
    
    override fun onPause() {
        super.onPause()
        Log.d("NavigationActivity", "onPause called, isPausedByUser: $isPausedByUser, isPausedByUserStatic: $isPausedByUserStatic")
        // Always pause navigation view - we'll resume it when needed
        navigationView.onPause()
        if (isPausedByUserStatic) {
            Log.d("NavigationActivity", "Navigation paused by user - will resume when brought to foreground")
        } else {
            Log.d("NavigationActivity", "Navigation paused normally")
        }
    }
    
    override fun onStop() {
        super.onStop()
        Log.d("NavigationActivity", "onStop called, isPausedByUser: $isPausedByUser, isPausedByUserStatic: $isPausedByUserStatic")
        // Always stop navigation view - we'll resume it when needed
        navigationView.onStop()
        if (isPausedByUserStatic) {
            Log.d("NavigationActivity", "Navigation stopped by user - will resume when brought to foreground")
        } else {
            Log.d("NavigationActivity", "Navigation stopped normally")
        }
    }
    
    override fun onLowMemory() {
        super.onLowMemory()
        navigationView.onLowMemory()
    }
    
    override fun onBackPressed() {
        if (!navigationView.onBackPressed()) {
            super.onBackPressed()
        }
    }
    
    override fun onSaveInstanceState(outState: Bundle) {
        navigationView.onSaveInstanceState(outState)
        super.onSaveInstanceState(outState)
    }
    
    override fun onRestoreInstanceState(savedInstanceState: Bundle) {
        super.onRestoreInstanceState(savedInstanceState)
        navigationView.onRestoreInstanceState(savedInstanceState)
    }
    
    override fun onDestroy() {
        navigationView.onDestroy()
        super.onDestroy()
    }
}

