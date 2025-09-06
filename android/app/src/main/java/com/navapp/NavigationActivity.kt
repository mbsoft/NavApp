package com.navapp

import android.Manifest
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
import java.util.*

class NavigationActivity : AppCompatActivity(), OnNavigationReadyCallback, NavigationListener, 
    ProgressChangeListener, RouteListener, StatusBarUtils.OnWindowInsetsChange {
    
    private lateinit var navigationView: NavigationView
    private var destinationLat: Double = 0.0
    private var destinationLng: Double = 0.0
    private var route: DirectionsRoute? = null
    
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
            Log.d("NavigationActivity", "Destination: $destinationLat, $destinationLng")
            
            // Get route if passed
            route = intent.getSerializableExtra("route") as? DirectionsRoute
            Log.d("NavigationActivity", "Route received: ${route != null}")
            
            navigationView = findViewById(R.id.navigation_view)
            Log.d("NavigationActivity", "NavigationView found: ${navigationView != null}")
            
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
        Log.d("NavigationActivity", "Navigation ready, isRunning: $isRunning")
        
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
        Log.d("NavigationActivity", "Navigation cancelled")
        finish()
    }
    
    override fun onNavigationFinished() {
        Log.d("NavigationActivity", "Navigation finished")
        finish()
    }
    
    override fun onNavigationRunning() {
        Log.d("NavigationActivity", "Navigation running")
    }
    
    // ProgressChangeListener methods
    override fun onProgressChange(location: Location, navProgress: NavProgress) {
        Log.d("NavigationActivity", "Progress: ${navProgress.distanceRemaining}m remaining")
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
        navigationView.onPause()
    }
    
    override fun onStop() {
        super.onStop()
        navigationView.onStop()
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
