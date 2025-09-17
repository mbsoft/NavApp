# NextBillion.ai Navigation Integration

This project integrates NextBillion.ai Navigation SDK for both iOS and Android platforms with full turn-by-turn navigation support.

## Setup Instructions

### iOS Setup

1. **Add NextBillion.ai SDK to iOS project using Carthage:**
   - Create `ios/Cartfile` with NextBillion.ai dependencies
   - Run `carthage update` to download frameworks
   - Manually add `.xcframework` files to Xcode project

2. **Cartfile contents:**
   ```
   binary "https://github.com/nextbillion-ai/nextbillion-map-ios/releases/download/v1/carthage/Nbmap.json" ~> 1.1.5
   binary "https://github.com/nextbillion-ai/nextbillion-turf-ios/releases/download/v1/carthage/Turf.json" ~> 2.0.0
   binary "https://github.com/nextbillion-ai/nextbillion-navigation-ios/releases/download/v1/carthage/NbmapCoreNavigation.json" ~> 2.3.0
   binary "https://github.com/nextbillion-ai/nextbillion-navigation-ios/releases/download/v1/carthage/NbmapNavigation.json" ~> 2.3.0
   ```

3. **Run Carthage update:**
   ```bash
   cd ios && carthage update
   ```

4. **Add location permissions to Info.plist:**
   ```xml
   <key>NSLocationWhenInUseUsageDescription</key>
   <string>This app needs location access for navigation</string>
   <key>NSLocationAlwaysAndWhenInUseUsageDescription</key>
   <string>This app needs location access for navigation</string>
   ```

5. **Disable New Architecture (if needed):**
   ```xml
   <key>RCTNewArchEnabled</key>
   <false/>
   ```

### Android Setup

1. **Add NextBillion.ai SDK to Android project:**
   - Update `android/app/build.gradle` to include the SDK dependencies

2. **Add to build.gradle:**
   ```gradle
   dependencies {
       // NextBillion.ai Navigation SDK
       implementation 'ai.nextbillion:nb-navigation-android:2.2.0'
       
       // Material Design components (required for NavigationView)
       implementation 'com.google.android.material:material:1.12.0'
       implementation 'androidx.appcompat:appcompat:1.7.0'
       implementation 'androidx.constraintlayout:constraintlayout:2.2.1'
   }
   ```

3. **Add location permissions to AndroidManifest.xml:**
   ```xml
   <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
   <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />
   <uses-permission android:name="android.permission.ACCESS_BACKGROUND_LOCATION" />
   <uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
   <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
   ```

4. **Initialize SDK in MainApplication.kt:**
   ```kotlin
   override fun onCreate() {
       super.onCreate()
       
       // Initialize NextBillion.ai SDK with your API key
       Nextbillion.getInstance(applicationContext, "YOUR_API_KEY")
       
       loadReactNative(this)
   }
   ```

5. **Disable New Architecture (if needed):**
   ```properties
   # In android/gradle.properties
   newArchEnabled=false
   ```

## Usage

The app now includes a "Start Navigation" button that will:
- Calculate a real route using NextBillion.ai Directions API
- Launch full turn-by-turn navigation using NextBillion.ai NavigationView
- Use a default origin (Washington DC) and navigate to Times Square, New York
- Support both car and truck navigation modes
- Include simulation mode for testing
- Show live progress updates and navigation instructions

## Implementation Details

### Android Implementation

**Critical Requirements:**
- NavigationActivity must extend `AppCompatActivity` (not `Activity`)
- Material Design dependencies are required for NavigationView
- SDK must be initialized in MainApplication.kt
- New Architecture must be disabled for compatibility

**Key Files:**
- `android/app/src/main/java/com/navapp/ReactNativeNextBillionNavigationModule.kt` - Native module
- `android/app/src/main/java/com/navapp/NavigationActivity.kt` - Navigation activity
- `android/app/src/main/res/layout/activity_navigation.xml` - NavigationView layout
- `android/app/src/main/java/com/navapp/MainApplication.kt` - SDK initialization

**Route Calculation:**
- Uses `NBNavigation.fetchRoute()` to calculate real routes
- Passes calculated route to NavigationActivity
- Supports origin and destination points

### iOS Implementation

**Key Files:**
- `ios/NavApp/ReactNativeNextBillionNavigation/ReactNativeNextBillionNavigationModule.swift` - Native module
- `ios/NavApp/ReactNativeNextBillionNavigation/ReactNativeNextBillionNavigationModule.m` - Objective-C bridge
- `ios/Cartfile` - Carthage dependencies

## API Reference

### ReactNativeNextBillionNavigation

#### Methods

- `launchNavigation(destination: [number, number], options?: NavigationOptions): Promise<void>`
  - Launches navigation to the specified destination
  - destination: [latitude, longitude] tuple
  - options: Optional navigation configuration

- `dismissNavigation(): Promise<void>`
  - Dismisses the current navigation session


#### NavigationOptions

```typescript
interface NavigationOptions {
  mode?: 'car' | 'truck';
  simulate?: boolean;
  truckSize?: {
    width: number;
    length: number;
    height: number;
  };
  truckWeight?: number;
  units?: 'imperial' | 'metric';
}
```

## Troubleshooting

### Common Issues

1. **Android: "Please ensure that the provided Context is a valid FragmentActivity"**
   - Solution: Make sure NavigationActivity extends `AppCompatActivity`

2. **Android: NavigationView not found or crashes**
   - Solution: Add Material Design dependencies to build.gradle

3. **iOS: Module not linked errors**
   - Solution: Disable New Architecture (`RCTNewArchEnabled=false`)

4. **Route calculation fails**
   - Solution: Ensure API key is properly set in MainApplication.kt

### Debug Logging

The implementation includes comprehensive logging:
- `NavigationModule` - Route calculation and module operations
- `NavigationActivity` - Activity lifecycle and navigation events

## Localization Customization

### iOS Localization Override

The NextBillion Navigation framework uses binary localization files that may need to be modified to override default text. For example, to change "RE-CENTRE" to "RECENTER":

1. **Locate the framework's localization files:**
   ```bash
   find ios/Carthage/Build -name "Localizable.strings" -path "*/NbmapNavigation.framework/*"
   ```

2. **Backup the original files:**
   ```bash
   cp ios/Carthage/Build/NbmapNavigation.xcframework/ios-arm64_x86_64-simulator/NbmapNavigation.framework/Base.lproj/Localizable.strings ios/Carthage/Build/NbmapNavigation.xcframework/ios-arm64_x86_64-simulator/NbmapNavigation.framework/Base.lproj/Localizable.strings.backup
   ```

3. **Modify the binary plist files using plutil:**
   ```bash
   # For simulator build
   plutil -replace RESUME -string "RECENTER" ios/Carthage/Build/NbmapNavigation.xcframework/ios-arm64_x86_64-simulator/NbmapNavigation.framework/Base.lproj/Localizable.strings
   
   # For device build
   plutil -replace RESUME -string "RECENTER" ios/Carthage/Build/NbmapNavigation.xcframework/ios-arm64/NbmapNavigation.framework/Base.lproj/Localizable.strings
   ```

4. **Clean and rebuild the project:**
   ```bash
   cd ios && xcodebuild clean -workspace NavApp.xcworkspace -scheme NavApp
   npx react-native run-ios
   ```

**Important Notes:**
- These changes are local to your Carthage build and will be lost when updating the framework
- Document any localization changes for team members
- Consider creating a script to automate this process
- The framework uses binary plist files, so `plutil` is required for modifications

### Android Localization

Android localization can be handled through standard Android string resources in `android/app/src/main/res/values/strings.xml`:

```xml
<resources>
    <string name="resume">RECENTER</string>
</resources>
```

## Notes

- Both platforms now use the full NextBillion.ai Navigation SDK
- Android implementation includes real route calculation and full NavigationView
- iOS implementation uses Carthage for dependency management
- Location permissions are required for both platforms
- The app supports simulation mode for testing without real GPS
- iOS localization requires modifying framework binary files due to framework architecture
