#include "AppDelegate.h"
#include "GeneratedPluginRegistrant.h"

// @import Firebase;
#if __has_include(<WidgetKit/WidgetKit.h>)
@import WidgetKit;
#endif
@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  [GeneratedPluginRegistrant registerWithRegistry:self];
  FlutterViewController *controller = (FlutterViewController *)self.window.rootViewController;
  FlutterMethodChannel *homeWidgetsChannel =
      [FlutterMethodChannel methodChannelWithName:@"shia_companion/home_widgets"
                                  binaryMessenger:controller.binaryMessenger];
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
#if __has_include(<WidgetKit/WidgetKit.h>)
      if (@available(iOS 14.0, *)) {
        [[WidgetCenter sharedCenter] reloadAllTimelines];
      }
#endif
      result(nil);
      return;
    }

    result(FlutterMethodNotImplemented);
  }];
    // [FIRApp configure];
  if (@available(iOS 10.0, *)) {
    [UNUserNotificationCenter currentNotificationCenter].delegate = (id<UNUserNotificationCenterDelegate>) self;
  }
  // Override point for customization after application launch.
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end
