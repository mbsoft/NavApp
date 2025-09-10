package com.navapp

import com.facebook.react.bridge.*
import com.facebook.react.modules.core.DeviceEventManagerModule
import android.content.Context
import android.app.Activity
import android.content.Intent
import android.os.Bundle
import android.util.Log
import ai.nextbillion.kits.directions.models.DirectionsResponse
import ai.nextbillion.kits.directions.models.DirectionsRoute
import ai.nextbillion.kits.directions.models.RouteRequestParams
import ai.nextbillion.kits.geojson.Point
import ai.nextbillion.navigation.ui.NBNavigation
import ai.nextbillion.navigation.core.routefetcher.RequestParamConsts
import ai.nextbillion.navigation.core.routefetcher.RouteFetcher
import retrofit2.Call
import retrofit2.Callback
import retrofit2.Response

class ReactNativeNextBillionNavigationModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
    
    override fun getName(): String {
        return "ReactNativeNextBillionNavigation"
    }
    
    @ReactMethod
    fun launchNavigation(origin: ReadableArray, destination: ReadableArray, options: ReadableMap?, promise: Promise) {
        try {
            val activity = reactApplicationContext.currentActivity
            if (activity == null) {
                promise.reject("NO_ACTIVITY", "No current activity available")
                return
            }

            // Extract origin coordinates
            val originLat = origin.getDouble(0)
            val originLng = origin.getDouble(1)

            // Extract destination coordinates
            val destLat = destination.getDouble(0)
            val destLng = destination.getDouble(1)

            // Extract units and mode settings from options
            val units = options?.getString("units") ?: "metric"
            val mode = options?.getString("mode") ?: "car"
            
            // Extract truck parameters if mode is truck
            val truckSize = if (mode == "truck") {
                val truckSizeArray = options?.getArray("truckSize")
                if (truckSizeArray != null && truckSizeArray.size() >= 3) {
                    listOf(
                        truckSizeArray.getString(0) ?: "400",
                        truckSizeArray.getString(1) ?: "250", 
                        truckSizeArray.getString(2) ?: "1200"
                    )
                } else {
                    listOf("400", "250", "1200") // Default values
                }
            } else null
            
            val truckWeight = if (mode == "truck") {
                options?.getInt("truckWeight") ?: 5000
            } else null
            
            // Extract route parameters
            val routeType = options?.getString("routeType") ?: "fastest"
            val shouldSimulate = options?.getBoolean("simulate") ?: true
            val avoidances = if (options?.hasKey("avoidances") == true) {
                val avoidancesArray = options.getArray("avoidances")
                if (avoidancesArray != null) {
                    val avoidancesList = mutableListOf<String>()
                    for (i in 0 until avoidancesArray.size()) {
                        avoidancesList.add(avoidancesArray.getString(i) ?: "")
                    }
                    avoidancesList.filter { it.isNotEmpty() }
                } else {
                    emptyList()
                }
            } else {
                emptyList()
            }
            
            Log.d("NavigationModule", "Launching NextBillion.ai navigation from: $originLat, $originLng to: $destLat, $destLng with units: $units, mode: $mode, truckSize: $truckSize, truckWeight: $truckWeight, routeType: $routeType, avoidances: $avoidances, simulate: $shouldSimulate")

            // Create origin and destination points
            val originPoint = Point.fromLngLat(originLng, originLat)
            val destinationPoint = Point.fromLngLat(destLng, destLat)

            // Fetch route using NextBillion.ai SDK
            fetchRoute(originPoint, destinationPoint, activity, promise, units, mode, truckSize, truckWeight, routeType, avoidances, shouldSimulate)

        } catch (e: Exception) {
            Log.e("NavigationModule", "Error launching navigation", e)
            promise.reject("NAVIGATION_ERROR", e.message, e)
        }
    }
    
    @ReactMethod
    fun dismissNavigation(promise: Promise) {
        try {
            val activity = reactApplicationContext.currentActivity
            if (activity != null && activity is NavigationActivity) {
                // Mark as not paused by user so it will send NavigationStopped event
                activity.setPausedByUser(false)
                activity.finish()
            }
            promise.resolve(null)
        } catch (e: Exception) {
            promise.reject("DISMISS_ERROR", e.message, e)
        }
    }
    
    @ReactMethod
    fun resumeNavigation(promise: Promise) {
        try {
            val activity = reactApplicationContext.currentActivity
            if (activity != null && activity is NavigationActivity) {
                // If we're already in NavigationActivity, just call resume
                activity.resumeNavigation()
            } else {
                // If we're in MainActivity, bring NavigationActivity to foreground
                val context = reactApplicationContext
                val intent = Intent(context, NavigationActivity::class.java)
                intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                intent.addFlags(Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                intent.addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
                intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
                context.startActivity(intent)
            }
            promise.resolve(null)
        } catch (e: Exception) {
            Log.e("NavigationModule", "Error resuming navigation", e)
            promise.reject("RESUME_ERROR", e.message, e)
        }
    }
    
    private fun fetchRoute(origin: Point, destination: Point, activity: Activity, promise: Promise, units: String, mode: String, truckSize: List<String>?, truckWeight: Int?, routeType: String, avoidances: List<String>, shouldSimulate: Boolean) {
        Log.d("NavigationModule", "Fetching route from $origin to $destination with units: $units, mode: $mode, truckSize: $truckSize, truckWeight: $truckWeight, routeType: $routeType, avoidances: $avoidances, simulate: $shouldSimulate")
        
        // Create route request with custom parameters including units and mode
        val paramsBuilder = RouteRequestParams.builder()
            .mode(when (mode) {
                "truck" -> RequestParamConsts.MODE_TRUCK
                "bike" -> RequestParamConsts.MODE_CAR // Map bike to car mode as fallback
                "pedestrian" -> RequestParamConsts.MODE_CAR // Map pedestrian to car mode as fallback
                else -> RequestParamConsts.MODE_CAR
            })
            .overview(RequestParamConsts.OVERVIEW_FALSE)
            .language("en")
            .origin(origin)
            .destination(destination)
            .option(RequestParamConsts.FLEXIBLE)
            .departureTime((System.currentTimeMillis() / 1000).toInt())
            .unit(if (units == "imperial") RequestParamConsts.IMPERIAL else RequestParamConsts.METRIC)
        
        // Add route type
        val routeTypeParam = if (routeType == "shortest") RequestParamConsts.SHORTEST_TYPE else RequestParamConsts.FASTEST_TYPE
        paramsBuilder.routeType(routeTypeParam)
        
        // Add avoidances if any
        if (avoidances.isNotEmpty()) {
            paramsBuilder.avoid(avoidances)
        }
        
        // Add truck parameters if mode is truck
        if (mode == "truck") {
            truckSize?.let { paramsBuilder.truckSize(it) }
            truckWeight?.let { paramsBuilder.truckWeight(it) }
        }
        
        val params = paramsBuilder.build()
        
        // Log detailed route parameters for debugging
        Log.d("NavigationModule", "=== ROUTE PARAMETERS ===")
        val actualMode = when (mode) {
            "truck" -> RequestParamConsts.MODE_TRUCK
            "bike" -> RequestParamConsts.MODE_CAR
            "pedestrian" -> {
                Log.w("NavigationModule", "Pedestrian mode not supported in Android SDK, using car mode as fallback")
                RequestParamConsts.MODE_CAR
            }
            else -> RequestParamConsts.MODE_CAR
        }
        Log.d("NavigationModule", "Mode: $actualMode (requested: $mode)")
        Log.d("NavigationModule", "Units: ${if (units == "imperial") RequestParamConsts.IMPERIAL else RequestParamConsts.METRIC}")
        Log.d("NavigationModule", "Route Type: $routeTypeParam")
        Log.d("NavigationModule", "Avoidances: $avoidances")
        Log.d("NavigationModule", "Origin: $origin")
        Log.d("NavigationModule", "Destination: $destination")
        Log.d("NavigationModule", "Overview: ${RequestParamConsts.OVERVIEW_FULL}")
        Log.d("NavigationModule", "Language: en")
        Log.d("NavigationModule", "Alternatives: true")
        Log.d("NavigationModule", "Departure Time: ${(System.currentTimeMillis() / 1000).toInt()}")
        Log.d("NavigationModule", "Alt Count: 2")
        if (mode == "truck") {
            Log.d("NavigationModule", "Truck Size: $truckSize")
            Log.d("NavigationModule", "Truck Weight: $truckWeight")
        }
        Log.d("NavigationModule", "========================")

        RouteFetcher.getRoute(params, object : Callback<DirectionsResponse> {
            override fun onResponse(call: Call<DirectionsResponse>, response: Response<DirectionsResponse>) {
                if (response.isSuccessful && response.body() != null && !response.body()!!.routes().isEmpty()) {
                    val route = response.body()!!.routes()[0]
                    Log.d("NavigationModule", "Route fetched successfully: ${route.distance()}m, ${route.duration()}s with units: $units")
                    
                    // Launch navigation activity with the route and units
                    val intent = Intent(activity, NavigationActivity::class.java)
                    intent.putExtra("route", route)
                    intent.putExtra("destination_lat", destination.latitude())
                    intent.putExtra("destination_lng", destination.longitude())
                    intent.putExtra("units", units)
                    intent.putExtra("should_simulate", shouldSimulate)
                    
                    activity.startActivity(intent)
                    promise.resolve(null)
                } else {
                    val errorMessage = "Failed to fetch route: ${response.message()}"
                    Log.e("NavigationModule", errorMessage)
                    promise.reject("ROUTE_ERROR", errorMessage)
                }
            }

            override fun onFailure(call: Call<DirectionsResponse>, t: Throwable) {
                val errorMessage = "Route fetch failed: ${t.message}"
                Log.e("NavigationModule", errorMessage, t)
                promise.reject("ROUTE_ERROR", errorMessage)
            }
        })
    }
    
    private fun sendEvent(eventName: String, params: WritableMap? = null) {
        reactApplicationContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(eventName, params)
    }
}
