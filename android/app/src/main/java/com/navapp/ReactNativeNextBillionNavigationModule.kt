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
import ai.nextbillion.kits.geojson.Point
import ai.nextbillion.navigation.ui.NBNavigation
import retrofit2.Call
import retrofit2.Callback
import retrofit2.Response

class ReactNativeNextBillionNavigationModule(reactContext: ReactApplicationContext) : ReactContextBaseJavaModule(reactContext) {
    
    override fun getName(): String {
        return "ReactNativeNextBillionNavigation"
    }
    
    @ReactMethod
    fun launchNavigation(destination: ReadableArray, options: ReadableMap?, promise: Promise) {
        try {
            val activity = reactApplicationContext.currentActivity
            if (activity == null) {
                promise.reject("NO_ACTIVITY", "No current activity available")
                return
            }
            
            // Extract destination coordinates
            val lat = destination.getDouble(0)
            val lng = destination.getDouble(1)
            
            Log.d("NavigationModule", "Launching NextBillion.ai navigation to: $lat, $lng")
            
            // Create destination point
            val destinationPoint = Point.fromLngLat(lng, lat)
            
            // For now, use a default origin (in a real app, you'd get the current location)
            val originPoint = Point.fromLngLat(-77.04012393951416, 38.9111117447887) // Default origin
            
            // Fetch route using NextBillion.ai SDK
            fetchRoute(originPoint, destinationPoint, activity, promise)
            
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
                activity.finish()
            }
            promise.resolve(null)
        } catch (e: Exception) {
            promise.reject("DISMISS_ERROR", e.message, e)
        }
    }
    
    private fun fetchRoute(origin: Point, destination: Point, activity: Activity, promise: Promise) {
        Log.d("NavigationModule", "Fetching route from $origin to $destination")
        
        NBNavigation.fetchRoute(origin, destination, object : Callback<DirectionsResponse> {
            override fun onResponse(call: Call<DirectionsResponse>, response: Response<DirectionsResponse>) {
                if (response.isSuccessful && response.body() != null && !response.body()!!.routes().isEmpty()) {
                    val route = response.body()!!.routes()[0]
                    Log.d("NavigationModule", "Route fetched successfully: ${route.distance()}m, ${route.duration()}s")
                    
                    // Launch navigation activity with the route
                    val intent = Intent(activity, NavigationActivity::class.java)
                    intent.putExtra("route", route)
                    intent.putExtra("destination_lat", destination.latitude())
                    intent.putExtra("destination_lng", destination.longitude())
                    
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
                promise.reject("ROUTE_ERROR", errorMessage, t)
            }
        })
    }
    
    private fun sendEvent(eventName: String, params: WritableMap? = null) {
        reactApplicationContext
            .getJSModule(DeviceEventManagerModule.RCTDeviceEventEmitter::class.java)
            .emit(eventName, params)
    }
}
