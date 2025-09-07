#import <React/RCTBridgeModule.h>

@interface RCT_EXTERN_MODULE(ReactNativeNextBillionNavigation, NSObject)

RCT_EXTERN_METHOD(launchNavigation:(NSArray *)destination
                  options:(NSDictionary *)options
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(dismissNavigation:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject)

@end