/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import { StatusBar, StyleSheet, useColorScheme, View, TouchableOpacity, Text, Alert, TextInput, FlatList, ActivityIndicator, AppState, NativeEventEmitter, NativeModules } from 'react-native';
import {
  SafeAreaProvider,
} from 'react-native-safe-area-context';
import React, { useState, useEffect, useCallback } from 'react';
import Geolocation from '@react-native-community/geolocation';
import ReactNativeNextBillionNavigation from './ReactNativeNextBillionNavigation';

function App() {
  const isDarkMode = useColorScheme() === 'dark';

  return (
    <SafeAreaProvider>
      <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
      <AppContent />
    </SafeAreaProvider>
  );
}

interface PlaceResult {
  id: string;
  title: string;
  address: {
    label: string;
  };
  position: {
    lat: number;
    lng: number;
  };
}

function AppContent() {
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState<PlaceResult[]>([]);
  const [isSearching, setIsSearching] = useState(false);
  const [selectedDestination, setSelectedDestination] = useState<PlaceResult | null>(null);
  const [showResults, setShowResults] = useState(false);
  
  // Geolocation state
  const [currentLocation, setCurrentLocation] = useState<{ lat: number; lng: number } | null>(null);
  const [isLocationLoading, setIsLocationLoading] = useState(true);
  const [locationPermissionGranted, setLocationPermissionGranted] = useState(false);
  const [currentAddress, setCurrentAddress] = useState<string | null>(null);
  const [isReverseGeocoding, setIsReverseGeocoding] = useState(false);
  
  // Navigation state
  const [isNavigationRunning, setIsNavigationRunning] = useState(false);
  const [navigationMode, setNavigationMode] = useState<'car' | 'truck'>('car');
  const [simulateRoute, setSimulateRoute] = useState(true);
  
  // Truck parameters
  const [truckHeight, setTruckHeight] = useState('400'); // Default 4m in cm
  const [truckWidth, setTruckWidth] = useState('250');   // Default 2.5m in cm
  const [truckLength, setTruckLength] = useState('1200'); // Default 12m in cm
  const [truckWeight, setTruckWeight] = useState('5000'); // Default 5000kg
  const [isTruckParamsExpanded, setIsTruckParamsExpanded] = useState(false);
  
  // Route parameters
  const [isRouteParamsExpanded, setIsRouteParamsExpanded] = useState(false);
  const [routeAvoidances, setRouteAvoidances] = useState<string[]>([]);
  const [routeType, setRouteType] = useState<'shortest' | 'fastest'>('fastest');

  // Default fallback location - moved outside to avoid dependency issues
  const defaultLocation = React.useMemo(() => ({ lat: 38.9111117447887, lng: -77.04012393951416 }), []);

  // Reverse geocoding function to get address from coordinates
  const reverseGeocode = useCallback(async (lat: number, lng: number): Promise<string | null> => {
    try {
      setIsReverseGeocoding(true);
      const apiKey = 'YOUR_API_KEY';
      const url = `https://api.nextbillion.io/revgeocode?at=${lat},${lng}&key=${apiKey}`;
      
      console.log('Making reverse geocoding request to:', url);
      
      const response = await fetch(url);
      const data = await response.json();
      
      console.log('Reverse geocoding response:', data);
      
      if (data.items && data.items.length > 0) {
        let address = data.items[0].address?.label || data.items[0].title;
        
        // Remove country and zip code from address
        if (address && typeof address === 'string') {
          console.log('Original address:', address);
          const parts = address.split(',');
          if (parts.length > 1) {
            // Remove the last part (country) and rejoin
            let filteredParts = parts.slice(0, -1);
            
            // Remove zip code from the last remaining part (look for pattern like "OH 43017")
            if (filteredParts.length > 0) {
              const lastPart = filteredParts[filteredParts.length - 1].trim();
              console.log('Last part before zip removal:', lastPart);
              
              // Remove zip code pattern (state code followed by 5 digits) - more flexible pattern
              // Try multiple patterns to catch different formats
              let cleanedPart = lastPart;
              
              // Pattern 1: " OH 43017" or " OH 43017-1234"
              cleanedPart = cleanedPart.replace(/\s+[A-Z]{2}\s+\d{5}(-\d{4})?$/, '').trim();
              
              // Pattern 2: "OH 43017" (no leading space)
              cleanedPart = cleanedPart.replace(/[A-Z]{2}\s+\d{5}(-\d{4})?$/, '').trim();
              
              // Pattern 3: Just 5 digits at the end
              cleanedPart = cleanedPart.replace(/\s+\d{5}(-\d{4})?$/, '').trim();
              console.log('Last part after zip removal:', cleanedPart);
              
              filteredParts[filteredParts.length - 1] = cleanedPart;
            }
            
            address = filteredParts.join(',').trim();
            console.log('Final cleaned address:', address);
          }
        }
        
        console.log('Reverse geocoded address (country removed):', address);
        return address;
      }
      
      return null;
    } catch (error) {
      console.error('Reverse geocoding error:', error);
      return null;
    } finally {
      setIsReverseGeocoding(false);
    }
  }, []);

  // Get current location using geolocation
  const getCurrentLocation = useCallback(async () => {
    setIsLocationLoading(true);
    
    Geolocation.getCurrentPosition(
      async (position) => {
        const { latitude, longitude } = position.coords;
        setCurrentLocation({ lat: latitude, lng: longitude });
        setLocationPermissionGranted(true);
        console.log('Location obtained:', { lat: latitude, lng: longitude });
        
        // Get address from coordinates using reverse geocoding
        const address = await reverseGeocode(latitude, longitude);
        setCurrentAddress(address);
        setIsLocationLoading(false);
      },
      (error) => {
        console.warn('Geolocation error:', error);
        setLocationPermissionGranted(false);
        setCurrentLocation(null);
        setIsLocationLoading(false);
        
        // Show user-friendly error message
        if (error.code === 1) {
          Alert.alert(
            'Location Permission Required',
            'Please enable location permissions in your device settings to use your current location for navigation.',
            [{ text: 'OK' }]
          );
        } else {
          Alert.alert(
            'Location Unavailable',
            'Unable to get your current location. Using default location instead.',
            [{ text: 'OK' }]
          );
        }
      },
      {
        enableHighAccuracy: true,
        timeout: 15000,
        maximumAge: 10000,
      }
    );
  }, []);

  // Request location permission and get current location on component mount
  useEffect(() => {
    getCurrentLocation();
  }, [getCurrentLocation]);

  // Get address for default location when no current location is available
  useEffect(() => {
    if (!currentLocation && !isLocationLoading) {
      reverseGeocode(defaultLocation.lat, defaultLocation.lng).then(address => {
        if (address) {
          setCurrentAddress(address);
        }
      });
    }
  }, [currentLocation, isLocationLoading, defaultLocation.lat, defaultLocation.lng, reverseGeocode]);

  // Dismiss navigation function
  const dismissNavigation = useCallback(async () => {
    try {
      if (ReactNativeNextBillionNavigation && isNavigationRunning) {
        await (ReactNativeNextBillionNavigation as any).dismissNavigation();
        setIsNavigationRunning(false);
        console.log('Navigation dismissed successfully');
      }
    } catch (error) {
      console.error('Error dismissing navigation:', error);
      // Still set state to false even if dismiss fails
      setIsNavigationRunning(false);
    }
  }, [isNavigationRunning]);

  // Show navigation function - resumes existing navigation session
  const showNavigation = useCallback(async () => {
    try {
      if (!ReactNativeNextBillionNavigation) {
        Alert.alert('Module Error', 'ReactNativeNextBillionNavigation module is not available');
        return;
      }

      if (!isNavigationRunning) {
        Alert.alert('Navigation Error', 'No navigation session to resume');
        return;
      }

      await (ReactNativeNextBillionNavigation as any).resumeNavigation();
      console.log('Navigation resumed successfully');
    } catch (error) {
      console.error('Error resuming navigation:', error);
      Alert.alert('Navigation Error', `Failed to resume navigation: ${error}`);
    }
  }, [isNavigationRunning]);

  // Handle app state changes - keep navigation running when returning to app
  useEffect(() => {
    const handleAppStateChange = (nextAppState: string) => {
      console.log('App state changed to:', nextAppState);
      // Don't automatically dismiss navigation when app becomes active
      // Let the user control navigation with Stop/Show buttons
    };

    const subscription = AppState.addEventListener('change', handleAppStateChange);
    
    return () => {
      subscription?.remove();
    };
  }, []);

  // Listen for navigation events from Android
  useEffect(() => {
    const eventEmitter = new NativeEventEmitter(NativeModules.ReactNativeNextBillionNavigation);
    
    const navigationStartedListener = eventEmitter.addListener('NavigationStarted', () => {
      console.log('Navigation started event received');
      setIsNavigationRunning(true);
    });
    
    const navigationPausedListener = eventEmitter.addListener('NavigationPaused', () => {
      console.log('Navigation paused event received - keeping navigation state as running');
      // Keep navigation state as running when paused
      setIsNavigationRunning(true);
    });
    
    const navigationStoppedListener = eventEmitter.addListener('NavigationStopped', () => {
      console.log('Navigation stopped event received');
      setIsNavigationRunning(false);
    });
    
    return () => {
      navigationStartedListener.remove();
      navigationPausedListener.remove();
      navigationStoppedListener.remove();
    };
  }, []);

  const searchPlaces = useCallback(async (query: string) => {
    if (query.length < 3) {
      setSearchResults([]);
      setShowResults(false);
      return;
    }

    setIsSearching(true);
    try {
      // Use current location if available, otherwise fall back to default
      const originLocation = currentLocation || defaultLocation;
      
      const apiKey = 'YOUR_API_KEY'; // Using the same API key from Info.plist
      const url = `https://api.nextbillion.io/discover?key=${apiKey}&q=${encodeURIComponent(query)}&at=${originLocation.lat},${originLocation.lng}&limit=5`;
      
      const response = await fetch(url);
      const data = await response.json();
      
      if (data.items && Array.isArray(data.items)) {
        const places: PlaceResult[] = data.items.map((item: any) => ({
          id: item.id || Math.random().toString(),
          title: item.title || 'Unknown Place',
          address: {
            label: item.address?.label || ''
          },
          position: {
            lat: item.position?.lat || 0,
            lng: item.position?.lng || 0,
          }
        }));
        setSearchResults(places);
        setShowResults(true);
      }
    } catch (error) {
      console.error('Search error:', error);
      Alert.alert('Search Error', 'Failed to search places');
    } finally {
      setIsSearching(false);
    }
  }, [currentLocation, defaultLocation]);

  useEffect(() => {
    const timeoutId = setTimeout(() => {
      searchPlaces(searchQuery);
    }, 300); // Debounce search by 300ms

    return () => clearTimeout(timeoutId);
  }, [searchQuery, searchPlaces]);

  const handlePlaceSelect = (place: PlaceResult) => {
    setSelectedDestination(place);
    setSearchQuery(''); // Clear the search input
    setSearchResults([]); // Clear the search results
    setShowResults(false);
  };

  const handleNavigationPress = async () => {
    try {
      console.log('ReactNativeNextBillionNavigation module:', ReactNativeNextBillionNavigation);
      
      if (!ReactNativeNextBillionNavigation) {
        Alert.alert('Module Error', 'ReactNativeNextBillionNavigation module is not available');
        return;
      }

      // Use current location as origin, fall back to default if not available
      const originLocation = currentLocation || defaultLocation;
      const origin = [originLocation.lat, originLocation.lng];
      
      // Use selected destination or default destination
      const destination: [number, number] = selectedDestination 
        ? [selectedDestination.position.lat, selectedDestination.position.lng]
        : [40.7580, -73.9855]; // Default: Times Square, New York

      const options = {
        mode: navigationMode,
        simulate: simulateRoute,
        units: 'imperial' as const,
        origin: origin,
        routeType: routeType,
        avoidances: routeAvoidances,
        ...(navigationMode === 'truck' && {
          truckSize: [truckHeight, truckWidth, truckLength],
          truckWeight: parseInt(truckWeight, 10),
        }),
      };

      await (ReactNativeNextBillionNavigation as any).launchNavigation(origin, destination, options);
      console.log('Navigation launched successfully');
    } catch (error) {
      Alert.alert('Navigation Error', `Failed to launch navigation: ${error}`);
      setIsNavigationRunning(false);
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.content}>
        <Text style={styles.title}>NavApp</Text>
        <Text style={styles.subtitle}>NextBillion.ai Navigation Demo</Text>
        
        {/* Search Box */}
        <View style={styles.searchContainer}>
          <TextInput
            style={styles.searchInput}
            placeholder="Search for destination..."
            value={searchQuery}
            onChangeText={setSearchQuery}
            onFocus={() => setShowResults(searchQuery.length >= 3 && searchResults.length > 0)}
          />
          {isSearching && (
            <ActivityIndicator style={styles.searchLoader} size="small" color="#007AFF" />
          )}
        </View>

        {/* Search Results */}
        {showResults && searchResults.length > 0 && (
          <View style={styles.resultsContainer}>
            <FlatList
              data={searchResults}
              keyExtractor={(item) => item.id}
              renderItem={({ item }) => (
                <TouchableOpacity
                  style={styles.resultItem}
                  onPress={() => handlePlaceSelect(item)}
                >
                  <Text style={styles.resultName}>{item.title}</Text>
                  <Text style={styles.resultAddress}>{item.address.label}</Text>
                </TouchableOpacity>
              )}
              style={styles.resultsList}
            />
          </View>
        )}

        {/* Location Status Display */}
        <View style={styles.locationStatusContainer}>
          <Text style={styles.locationStatusLabel}>Origin:</Text>
          {isLocationLoading ? (
            <View style={styles.locationLoadingContainer}>
              <ActivityIndicator size="small" color="#007AFF" />
              <Text style={styles.locationLoadingText}>Getting location...</Text>
            </View>
          ) : locationPermissionGranted ? (
            <View style={styles.locationSuccessContainer}>
              <Text style={styles.locationSuccessText}>✓ {currentAddress || 'Location acquired'}</Text>
            </View>
          ) : (
            <View style={styles.locationErrorContainer}>
              <Text style={styles.locationErrorText}>Location permission denied</Text>
              <TouchableOpacity style={styles.retryButton} onPress={requestLocationPermission}>
                <Text style={styles.retryButtonText}>Try Again</Text>
              </TouchableOpacity>
            </View>
          )}
        </View>

        {/* Selected Destination Display */}
        {selectedDestination && (
          <View style={styles.selectedOriginContainer}>
            <Text style={styles.selectedOriginLabel}>Destination:</Text>
            <Text style={styles.selectedOriginText}>{selectedDestination.title}</Text>
          </View>
        )}

        {/* Navigation Mode Selector */}
        <View style={styles.modeSelectorContainer}>
          <Text style={styles.modeSelectorLabel}>Navigation Mode:</Text>
          <View style={styles.modeSelectorButtons}>
            <TouchableOpacity
              style={[
                styles.modeButton,
                navigationMode === 'car' && styles.modeButtonSelected
              ]}
              onPress={() => setNavigationMode('car')}
            >
              <Text style={[
                styles.modeButtonText,
                navigationMode === 'car' && styles.modeButtonTextSelected
              ]}>
                🚗 Car
              </Text>
            </TouchableOpacity>
            <TouchableOpacity
              style={[
                styles.modeButton,
                navigationMode === 'truck' && styles.modeButtonSelected
              ]}
              onPress={() => setNavigationMode('truck')}
            >
              <Text style={[
                styles.modeButtonText,
                navigationMode === 'truck' && styles.modeButtonTextSelected
              ]}>
                🚛 Truck
              </Text>
            </TouchableOpacity>
          </View>
          
          {/* Simulate Route Checkbox */}
          <View style={styles.simulateContainer}>
            <TouchableOpacity
              style={styles.checkboxContainer}
              onPress={() => setSimulateRoute(!simulateRoute)}
            >
              <View style={[
                styles.checkbox,
                simulateRoute && styles.checkboxSelected
              ]}>
                {simulateRoute && <Text style={styles.checkmark}>✓</Text>}
              </View>
              <Text style={styles.checkboxLabel}>Simulate Route</Text>
            </TouchableOpacity>
          </View>
        </View>

        {/* Truck Parameters - Only show when truck mode is selected */}
        {navigationMode === 'truck' && (
          <View style={styles.truckParamsContainer}>
            <TouchableOpacity 
              style={styles.truckParamsHeader}
              onPress={() => setIsTruckParamsExpanded(!isTruckParamsExpanded)}
            >
              <Text style={styles.truckParamsLabel}>Truck Parameters:</Text>
              <Text style={styles.truckParamsToggle}>
                {isTruckParamsExpanded ? '▼' : '▶'}
              </Text>
            </TouchableOpacity>
            
            {isTruckParamsExpanded && (
              <>
                {/* Dimensions Row */}
                <View style={styles.truckDimensionsRow}>
                  <View style={styles.truckInputContainer}>
                    <Text style={styles.truckInputLabel}>Height (cm)</Text>
                    <TextInput
                      style={styles.truckInput}
                      value={truckHeight}
                      onChangeText={setTruckHeight}
                      keyboardType="numeric"
                      placeholder="400"
                      maxLength={4}
                    />
                  </View>
                  <View style={styles.truckInputContainer}>
                    <Text style={styles.truckInputLabel}>Width (cm)</Text>
                    <TextInput
                      style={styles.truckInput}
                      value={truckWidth}
                      onChangeText={setTruckWidth}
                      keyboardType="numeric"
                      placeholder="250"
                      maxLength={4}
                    />
                  </View>
                  <View style={styles.truckInputContainer}>
                    <Text style={styles.truckInputLabel}>Length (cm)</Text>
                    <TextInput
                      style={styles.truckInput}
                      value={truckLength}
                      onChangeText={setTruckLength}
                      keyboardType="numeric"
                      placeholder="1200"
                      maxLength={4}
                    />
                  </View>
                </View>
                
                {/* Weight Row */}
                <View style={styles.truckWeightRow}>
                  <View style={styles.truckInputContainer}>
                    <Text style={styles.truckInputLabel}>Weight (kg)</Text>
                    <TextInput
                      style={styles.truckInput}
                      value={truckWeight}
                      onChangeText={setTruckWeight}
                      keyboardType="numeric"
                      placeholder="5000"
                      maxLength={6}
                    />
                  </View>
                </View>
                
                <Text style={styles.truckParamsNote}>
                  Max: Height 1000cm, Width 5000cm, Length 5000cm, Weight 100000kg
                </Text>
              </>
            )}
          </View>
        )}

        {/* Route Parameters - Always visible */}
        <View style={styles.routeParamsContainer}>
          <TouchableOpacity 
            style={styles.routeParamsHeader}
            onPress={() => setIsRouteParamsExpanded(!isRouteParamsExpanded)}
          >
            <Text style={styles.routeParamsLabel}>Route Parameters:</Text>
            <Text style={styles.routeParamsToggle}>
              {isRouteParamsExpanded ? '▼' : '▶'}
            </Text>
          </TouchableOpacity>
          
          {isRouteParamsExpanded && (
            <>
              {/* Route Type Selector */}
              <View style={styles.routeTypeContainer}>
                <Text style={styles.routeTypeLabel}>Route Type:</Text>
                <View style={styles.routeTypeButtons}>
                  <TouchableOpacity
                    style={[
                      styles.routeTypeButton,
                      routeType === 'fastest' && styles.routeTypeButtonSelected
                    ]}
                    onPress={() => setRouteType('fastest')}
                  >
                    <Text style={[
                      styles.routeTypeButtonText,
                      routeType === 'fastest' && styles.routeTypeButtonTextSelected
                    ]}>
                      Fastest
                    </Text>
                  </TouchableOpacity>
                  <TouchableOpacity
                    style={[
                      styles.routeTypeButton,
                      routeType === 'shortest' && styles.routeTypeButtonSelected
                    ]}
                    onPress={() => setRouteType('shortest')}
                  >
                    <Text style={[
                      styles.routeTypeButtonText,
                      routeType === 'shortest' && styles.routeTypeButtonTextSelected
                    ]}>
                      Shortest
                    </Text>
                  </TouchableOpacity>
                </View>
              </View>
              
              {/* Route Avoidances */}
              <View style={styles.avoidancesContainer}>
                <Text style={styles.avoidancesLabel}>Avoid:</Text>
                <View style={styles.avoidancesGrid}>
                  {['highway', 'uturn', 'toll', 'ferry', 'left_turn', 'right_turn'].map((avoidance) => (
                    <TouchableOpacity
                      key={avoidance}
                      style={[
                        styles.avoidanceButton,
                        routeAvoidances.includes(avoidance) && styles.avoidanceButtonSelected
                      ]}
                      onPress={() => {
                        if (routeAvoidances.includes(avoidance)) {
                          setRouteAvoidances(routeAvoidances.filter(item => item !== avoidance));
                        } else {
                          setRouteAvoidances([...routeAvoidances, avoidance]);
                        }
                      }}
                    >
                      <Text style={[
                        styles.avoidanceButtonText,
                        routeAvoidances.includes(avoidance) && styles.avoidanceButtonTextSelected
                      ]}>
                        {avoidance.replace('_', ' ').replace(/\b\w/g, l => l.toUpperCase())}
                      </Text>
                    </TouchableOpacity>
                  ))}
                </View>
              </View>
            </>
          )}
        </View>

        
        {isNavigationRunning ? (
          <View style={styles.navigationControlsContainer}>
            <View style={styles.buttonRow}>
              <TouchableOpacity style={styles.showButton} onPress={showNavigation}>
                <Text style={styles.buttonText}>Show Navigation</Text>
              </TouchableOpacity>
              <TouchableOpacity style={styles.dismissButton} onPress={dismissNavigation}>
                <Text style={styles.buttonText}>Stop Navigation</Text>
              </TouchableOpacity>
            </View>
          </View>
        ) : (
          <TouchableOpacity style={styles.navigationButton} onPress={handleNavigationPress}>
            <Text style={styles.buttonText}>Start Navigation</Text>
          </TouchableOpacity>
        )}
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f5f5f5',
  },
  content: {
    flex: 1,
    justifyContent: 'center',
    alignItems: 'center',
    padding: 12,
  },
  title: {
    fontSize: 28,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 6,
  },
  subtitle: {
    fontSize: 14,
    color: '#666',
    marginBottom: 12,
    textAlign: 'center',
  },
  searchContainer: {
    width: '100%',
    marginBottom: 12,
    position: 'relative',
  },
  searchInput: {
    backgroundColor: 'white',
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 20,
    paddingHorizontal: 16,
    paddingVertical: 12,
    fontSize: 15,
    elevation: 2,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 1,
    },
    shadowOpacity: 0.22,
    shadowRadius: 2.22,
  },
  searchLoader: {
    position: 'absolute',
    right: 15,
    top: 15,
  },
  resultsContainer: {
    width: '100%',
    maxHeight: 180,
    backgroundColor: 'white',
    borderRadius: 8,
    elevation: 5,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    marginBottom: 12,
  },
  resultsList: {
    maxHeight: 180,
  },
  resultItem: {
    padding: 12,
    borderBottomWidth: 1,
    borderBottomColor: '#f0f0f0',
  },
  resultName: {
    fontSize: 15,
    fontWeight: '600',
    color: '#333',
    marginBottom: 4,
  },
  resultAddress: {
    fontSize: 13,
    color: '#666',
  },
  modeSelectorContainer: {
    backgroundColor: '#f8f9fa',
    padding: 12,
    borderRadius: 8,
    marginBottom: 12,
    width: '100%',
  },
  modeSelectorLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: '#007AFF',
    marginBottom: 8,
  },
  modeSelectorButtons: {
    flexDirection: 'row',
    gap: 8,
  },
  modeButton: {
    flex: 1,
    backgroundColor: 'white',
    paddingVertical: 10,
    paddingHorizontal: 12,
    borderRadius: 6,
    borderWidth: 2,
    borderColor: '#e0e0e0',
    alignItems: 'center',
  },
  modeButtonSelected: {
    backgroundColor: '#007AFF',
    borderColor: '#007AFF',
  },
  modeButtonText: {
    fontSize: 14,
    fontWeight: '600',
    color: '#666',
  },
  modeButtonTextSelected: {
    color: 'white',
  },
  simulateContainer: {
    marginTop: 12,
    alignItems: 'flex-start',
  },
  checkboxContainer: {
    flexDirection: 'row',
    alignItems: 'center',
  },
  checkbox: {
    width: 20,
    height: 20,
    borderWidth: 2,
    borderColor: '#007AFF',
    borderRadius: 4,
    marginRight: 8,
    alignItems: 'center',
    justifyContent: 'center',
    backgroundColor: 'white',
  },
  checkboxSelected: {
    backgroundColor: '#007AFF',
    borderColor: '#007AFF',
  },
  checkmark: {
    color: 'white',
    fontSize: 14,
    fontWeight: 'bold',
  },
  checkboxLabel: {
    fontSize: 14,
    color: '#333',
    fontWeight: '500',
  },
  truckParamsContainer: {
    backgroundColor: '#f0f8ff',
    padding: 12,
    borderRadius: 8,
    marginBottom: 12,
    width: '100%',
    borderWidth: 1,
    borderColor: '#007AFF',
  },
  truckParamsHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  truckParamsLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: '#007AFF',
  },
  truckParamsToggle: {
    fontSize: 16,
    color: '#007AFF',
    fontWeight: 'bold',
  },
  truckDimensionsRow: {
    flexDirection: 'row',
    gap: 8,
    marginBottom: 10,
  },
  truckWeightRow: {
    flexDirection: 'row',
    gap: 8,
    marginBottom: 8,
  },
  truckInputContainer: {
    flex: 1,
  },
  truckInputLabel: {
    fontSize: 11,
    fontWeight: '500',
    color: '#666',
    marginBottom: 4,
  },
  truckInput: {
    backgroundColor: 'white',
    borderWidth: 1,
    borderColor: '#ddd',
    borderRadius: 4,
    paddingHorizontal: 8,
    paddingVertical: 6,
    fontSize: 13,
    textAlign: 'center',
  },
  truckParamsNote: {
    fontSize: 10,
    color: '#666',
    fontStyle: 'italic',
    textAlign: 'center',
  },
  routeParamsContainer: {
    backgroundColor: '#f0f8ff',
    padding: 12,
    borderRadius: 8,
    marginBottom: 12,
    width: '100%',
    borderWidth: 1,
    borderColor: '#007AFF',
  },
  routeParamsHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 10,
  },
  routeParamsLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: '#007AFF',
  },
  routeParamsToggle: {
    fontSize: 16,
    color: '#007AFF',
    fontWeight: 'bold',
  },
  routeTypeContainer: {
    marginBottom: 12,
  },
  routeTypeLabel: {
    fontSize: 12,
    fontWeight: '600',
    color: '#007AFF',
    marginBottom: 8,
  },
  routeTypeButtons: {
    flexDirection: 'row',
    gap: 8,
  },
  routeTypeButton: {
    flex: 1,
    backgroundColor: 'white',
    paddingVertical: 8,
    paddingHorizontal: 12,
    borderRadius: 6,
    borderWidth: 1,
    borderColor: '#ddd',
    alignItems: 'center',
  },
  routeTypeButtonSelected: {
    backgroundColor: '#007AFF',
    borderColor: '#007AFF',
  },
  routeTypeButtonText: {
    fontSize: 13,
    fontWeight: '600',
    color: '#666',
  },
  routeTypeButtonTextSelected: {
    color: 'white',
  },
  avoidancesContainer: {
    marginBottom: 8,
  },
  avoidancesLabel: {
    fontSize: 12,
    fontWeight: '600',
    color: '#007AFF',
    marginBottom: 8,
  },
  avoidancesGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 6,
  },
  avoidanceButton: {
    backgroundColor: 'white',
    paddingVertical: 6,
    paddingHorizontal: 10,
    borderRadius: 15,
    borderWidth: 1,
    borderColor: '#ddd',
  },
  avoidanceButtonSelected: {
    backgroundColor: '#007AFF',
    borderColor: '#007AFF',
  },
  avoidanceButtonText: {
    fontSize: 11,
    fontWeight: '500',
    color: '#666',
  },
  avoidanceButtonTextSelected: {
    color: 'white',
  },
  locationStatusContainer: {
    backgroundColor: '#f8f9fa',
    padding: 8,
    borderRadius: 8,
    marginBottom: 12,
    width: '100%',
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  locationStatusLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: '#007AFF',
  },
  locationStatusText: {
    fontSize: 12,
    color: '#333',
    flex: 1,
  },
  locationLoadingContainer: {
    flexDirection: 'row',
    alignItems: 'center',
    flex: 1,
  },
  retryButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 10,
    paddingVertical: 5,
    borderRadius: 12,
    marginLeft: 8,
  },
  retryButtonText: {
    color: 'white',
    fontSize: 11,
    fontWeight: '600',
  },
  selectedOriginContainer: {
    backgroundColor: '#e8f4fd',
    padding: 8,
    borderRadius: 8,
    marginBottom: 0,
    width: '100%',
  },
  selectedOriginLabel: {
    fontSize: 13,
    fontWeight: '600',
    color: '#007AFF',
    marginBottom: 4,
  },
  selectedOriginText: {
    fontSize: 14,
    color: '#333',
  },
  navigationControlsContainer: {
    width: '100%',
    alignItems: 'center',
  },
  buttonRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    width: '100%',
    gap: 12,
  },
  navigationButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 24,
    paddingVertical: 12,
    borderRadius: 20,
    elevation: 3,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
  },
  showButton: {
    backgroundColor: '#34C759',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 20,
    elevation: 3,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    flex: 1,
  },
  dismissButton: {
    backgroundColor: '#FF3B30',
    paddingHorizontal: 16,
    paddingVertical: 12,
    borderRadius: 20,
    elevation: 3,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    flex: 1,
  },
  buttonText: {
    color: 'white',
    fontSize: 16,
    fontWeight: '600',
  },
});

export default App;
