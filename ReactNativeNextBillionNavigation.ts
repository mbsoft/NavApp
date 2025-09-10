import { NativeModules, Platform, NativeEventEmitter } from 'react-native';

export interface NavigationOptions {
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

export interface ManeuverData {
  instruction: string;
  distance: number;
  duration: number;
  maneuverType: string;
  maneuverDirection: string;
  location: {
    latitude: number;
    longitude: number;
    altitude: number;
    course: number;
    speed: number;
  };
  routeProgress: {
    distanceRemaining: number;
    durationRemaining: number;
    fractionTraveled: number;
  };
}

export interface NavigationModule {
  launchNavigation(destination: [number, number], options?: NavigationOptions): Promise<void>;
  dismissNavigation(): Promise<void>;
  resumeNavigation(): Promise<void>;
  hideNavigation(): Promise<void>;
}

const { ReactNativeNextBillionNavigation } = NativeModules;

const LINKING_ERROR =
  `The package 'react-native-nextbillion-navigation' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", android: "- You have enabled autolinking in your build.gradle file\n" }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

export default ReactNativeNextBillionNavigation
  ? ReactNativeNextBillionNavigation as NavigationModule
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

// Event emitter for navigation events
export const navigationEventEmitter = ReactNativeNextBillionNavigation
  ? new NativeEventEmitter(ReactNativeNextBillionNavigation)
  : null;

// Event types
export const NavigationEvents = {
  NavigationHidden: 'NavigationHidden',
  NavigationStopped: 'NavigationStopped',
  NavigationManeuver: 'NavigationManeuver',
} as const;

