#include "AppDelegate.h"
#include "GeneratedPluginRegistrant.h"

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

@end
