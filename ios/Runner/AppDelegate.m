#include "AppDelegate.h"
#include "GeneratedPluginRegistrant.h"

@interface AppDelegate () <FlutterStreamHandler>

@property(nonatomic, copy) FlutterEventSink proximityEventSink;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  if (@available(iOS 10.0, *)) {
    [UNUserNotificationCenter currentNotificationCenter].delegate = (id<UNUserNotificationCenterDelegate>) self;
  }
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void)didInitializeImplicitFlutterEngine:(NSObject<FlutterImplicitEngineBridge>*)engineBridge {
  [GeneratedPluginRegistrant registerWithRegistry:engineBridge.pluginRegistry];
  [self configureHomeWidgetChannelWithMessenger:engineBridge.applicationRegistrar.messenger];
  [self configureProximitySensorChannelsWithMessenger:engineBridge.applicationRegistrar.messenger];
}

- (void)configureHomeWidgetChannelWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
  FlutterMethodChannel *homeWidgetsChannel =
      [FlutterMethodChannel methodChannelWithName:@"shia_companion/home_widgets"
                                  binaryMessenger:messenger];
  [homeWidgetsChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
    if ([@"saveWidgetData" isEqualToString:call.method]) {
      if (![call.arguments isKindOfClass:[NSDictionary class]]) {
        result([FlutterError errorWithCode:@"invalid_arguments"
                                   message:@"Widget data must be a dictionary."
                                   details:nil]);
        return;
      }

      NSUserDefaults *defaults =
          [[NSUserDefaults alloc] initWithSuiteName:@"group.com.developer110.shiacompanion"];
      NSDictionary *values = (NSDictionary *)call.arguments;
      for (id key in values) {
        id value = values[key];
        if ([key isKindOfClass:[NSString class]] && value != nil &&
            value != [NSNull null]) {
          [defaults setObject:[value description] forKey:(NSString *)key];
        }
      }
      [defaults synchronize];
      result(nil);
      return;
    }

    if ([@"refreshWidgets" isEqualToString:call.method]) {
      if (@available(iOS 14.0, *)) {
        Class widgetCenterClass = NSClassFromString(@"WidgetKit.WidgetCenter");
        SEL sharedCenterSelector = NSSelectorFromString(@"sharedCenter");
        SEL reloadAllTimelinesSelector = NSSelectorFromString(@"reloadAllTimelines");

        if (widgetCenterClass &&
            [widgetCenterClass respondsToSelector:sharedCenterSelector]) {
          id widgetCenter =
              [widgetCenterClass performSelector:sharedCenterSelector];
          if ([widgetCenter respondsToSelector:reloadAllTimelinesSelector]) {
            [widgetCenter performSelector:reloadAllTimelinesSelector];
          }
        }
      }
      result(nil);
      return;
    }

    result(FlutterMethodNotImplemented);
  }];
}

- (void)configureProximitySensorChannelsWithMessenger:
    (NSObject<FlutterBinaryMessenger> *)messenger {
  FlutterMethodChannel *methodChannel =
      [FlutterMethodChannel methodChannelWithName:@"shia_companion/proximity_sensor"
                                  binaryMessenger:messenger];
  [methodChannel setMethodCallHandler:^(FlutterMethodCall *call,
                                        FlutterResult result) {
    if (![@"isAvailable" isEqualToString:call.method]) {
      result(FlutterMethodNotImplemented);
      return;
    }

    UIDevice *device = UIDevice.currentDevice;
    BOOL wasEnabled = device.proximityMonitoringEnabled;
    device.proximityMonitoringEnabled = YES;
    BOOL isAvailable = device.proximityMonitoringEnabled;
    if (!wasEnabled) {
      device.proximityMonitoringEnabled = NO;
    }
    result(@(isAvailable));
  }];

  FlutterEventChannel *eventChannel = [FlutterEventChannel
      eventChannelWithName:@"shia_companion/proximity_sensor_events"
           binaryMessenger:messenger];
  [eventChannel setStreamHandler:self];
}

- (FlutterError *)onListenWithArguments:(id)arguments
                              eventSink:(FlutterEventSink)events {
  UIDevice *device = UIDevice.currentDevice;
  device.proximityMonitoringEnabled = YES;
  if (!device.proximityMonitoringEnabled) {
    events([FlutterError errorWithCode:@"sensor_unavailable"
                               message:@"This device does not have a proximity sensor."
                               details:nil]);
    return nil;
  }

  self.proximityEventSink = events;
  [[NSNotificationCenter defaultCenter]
      addObserver:self
         selector:@selector(proximityStateDidChange:)
             name:UIDeviceProximityStateDidChangeNotification
           object:device];
  events(@(device.proximityState));
  return nil;
}

- (FlutterError *)onCancelWithArguments:(id)arguments {
  [[NSNotificationCenter defaultCenter]
      removeObserver:self
                name:UIDeviceProximityStateDidChangeNotification
              object:UIDevice.currentDevice];
  self.proximityEventSink = nil;
  UIDevice.currentDevice.proximityMonitoringEnabled = NO;
  return nil;
}

- (void)proximityStateDidChange:(NSNotification *)notification {
  if (self.proximityEventSink) {
    self.proximityEventSink(@(UIDevice.currentDevice.proximityState));
  }
}

@end
