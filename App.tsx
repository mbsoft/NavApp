/**
 * Sample React Native App
 * https://github.com/facebook/react-native
 *
 * @format
 */

import { NewAppScreen } from '@react-native/new-app-screen';
import { StatusBar, StyleSheet, useColorScheme, View, TouchableOpacity, Text, Alert } from 'react-native';
import {
  SafeAreaProvider,
  useSafeAreaInsets,
} from 'react-native-safe-area-context';
import ReactNativeNextBillionNavigation, { navigationEventEmitter } from './ReactNativeNextBillionNavigation';

function App() {
  const isDarkMode = useColorScheme() === 'dark';

  return (
    <SafeAreaProvider>
      <StatusBar barStyle={isDarkMode ? 'light-content' : 'dark-content'} />
      <AppContent />
    </SafeAreaProvider>
  );
}

function AppContent() {
  const safeAreaInsets = useSafeAreaInsets();

  const handleNavigationPress = async () => {
    try {
      console.log('ReactNativeNextBillionNavigation module:', ReactNativeNextBillionNavigation);
      
      if (!ReactNativeNextBillionNavigation) {
        Alert.alert('Module Error', 'ReactNativeNextBillionNavigation module is not available');
        return;
      }

      // Example destination: Times Square, New York
      const destination: [number, number] = [40.7580, -73.9855];

      const options = {
        mode: 'car' as const,
        simulate: true,
        units: 'imperial' as const,
      };

      await ReactNativeNextBillionNavigation.launchNavigation(destination, options);
    } catch (error) {
      Alert.alert('Navigation Error', `Failed to launch navigation: ${error}`);
    }
  };

  return (
    <View style={styles.container}>
      <View style={styles.content}>
        <Text style={styles.title}>NavApp</Text>
        <Text style={styles.subtitle}>NextBillion.ai Navigation Demo</Text>
        
        <TouchableOpacity style={styles.navigationButton} onPress={handleNavigationPress}>
          <Text style={styles.buttonText}>Start Navigation</Text>
        </TouchableOpacity>
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
    padding: 20,
  },
  title: {
    fontSize: 32,
    fontWeight: 'bold',
    color: '#333',
    marginBottom: 10,
  },
  subtitle: {
    fontSize: 16,
    color: '#666',
    marginBottom: 40,
    textAlign: 'center',
  },
  navigationButton: {
    backgroundColor: '#007AFF',
    paddingHorizontal: 30,
    paddingVertical: 15,
    borderRadius: 25,
    elevation: 3,
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
  },
  buttonText: {
    color: 'white',
    fontSize: 18,
    fontWeight: '600',
  },
});

export default App;
