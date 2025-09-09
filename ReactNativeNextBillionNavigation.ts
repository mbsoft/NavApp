import { NativeModules, Platform } from 'react-native';

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

export interface NavigationModule {
  launchNavigation(destination: [number, number], options?: NavigationOptions): Promise<void>;
  dismissNavigation(): Promise<void>;
  resumeNavigation(): Promise<void>;
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

// Events are not currently supported in this implementation
export const navigationEventEmitter = null;

