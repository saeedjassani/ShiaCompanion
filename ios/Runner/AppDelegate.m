#include "AppDelegate.h"
#include "GeneratedPluginRegistrant.h"
@import WatchConnectivity;

static NSString *const kAppGroupID = @"group.com.developer110.shiacompanion";
static NSString *const kWatchUpdatedAtKey = @"sc_watch_updated_at";

@interface AppDelegate () <FlutterStreamHandler, WCSessionDelegate>

@property(nonatomic, copy) FlutterEventSink proximityEventSink;
/// Last content dictionary handed to the watch (without the timestamp), used to avoid
/// burning the daily complication-transfer budget on unchanged data.
@property(nonatomic, copy) NSDictionary *lastWatchContent;

- (void)pushSnapshotToWatchForced:(BOOL)force;

@end

@implementation AppDelegate

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  if (@available(iOS 10.0, *)) {
    [UNUserNotificationCenter currentNotificationCenter].delegate = (id<UNUserNotificationCenterDelegate>) self;
  }
  if (@available(iOS 9.0, *)) {
    if ([WCSession isSupported]) {
      WCSession *session = [WCSession defaultSession];
      session.delegate = self;
      [session activateSession];
      // Catches the case where the watch missed an earlier push (out of range, watch
      // app reinstalled) — a no-op when the snapshot is unchanged.
      [[NSNotificationCenter defaultCenter]
          addObserver:self
             selector:@selector(pushSnapshotToWatchOnForeground)
                 name:UIApplicationDidBecomeActiveNotification
               object:nil];
    }
  }
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

- (void)pushSnapshotToWatchOnForeground {
  [self pushSnapshotToWatchForced:NO];
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
  __weak __typeof(self) weakSelf = self;
  [homeWidgetsChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
    if ([@"saveWidgetData" isEqualToString:call.method]) {
      if (![call.arguments isKindOfClass:[NSDictionary class]]) {
        result([FlutterError errorWithCode:@"invalid_arguments"
                                   message:@"Widget data must be a dictionary."
                                   details:nil]);
        return;
      }

      NSUserDefaults *defaults =
          [[NSUserDefaults alloc] initWithSuiteName:kAppGroupID];
      NSDictionary *values = (NSDictionary *)call.arguments;
      for (id key in values) {
        id value = values[key];
        if ([key isKindOfClass:[NSString class]] && value != nil &&
            value != [NSNull null]) {
          [defaults setObject:[value description] forKey:(NSString *)key];
        }
      }
      [defaults synchronize];
      // App group containers are not shared with watchOS, so the watch app and its
      // complication only ever see data that is explicitly pushed over WatchConnectivity.
      [weakSelf pushSnapshotToWatchForced:NO];
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

// MARK: - Watch snapshot

/// Keys mirrored to the watch. Must stay in sync with `WatchDataKeys` in
/// "ShiaCompanion Watch App/PrayerDataStore.swift".
+ (NSArray<NSString *> *)watchSnapshotKeys {
  static NSArray<NSString *> *keys;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    NSMutableArray<NSString *> *mutableKeys = [@[
      @"sc_prayer_location",
      @"sc_prayer_schedule",
      @"sc_prayer_name",
      @"sc_prayer_time",
      @"sc_prayer_date",
      @"sc_prayer_secondary_name",
      @"sc_prayer_secondary_time",
      @"sc_daily_prayer_schedule",
    ] mutableCopy];
    for (NSInteger index = 1; index <= 6; index++) {
      [mutableKeys addObject:[NSString stringWithFormat:@"sc_daily_prayer_name_%ld", (long)index]];
      [mutableKeys addObject:[NSString stringWithFormat:@"sc_daily_prayer_time_%ld", (long)index]];
    }
    keys = [mutableKeys copy];
  });
  return keys;
}

/// The current snapshot read back out of the app group container, timestamp excluded.
- (NSDictionary<NSString *, NSString *> *)watchSnapshotContent {
  NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kAppGroupID];
  NSMutableDictionary<NSString *, NSString *> *content = [NSMutableDictionary dictionary];
  for (NSString *key in [AppDelegate watchSnapshotKeys]) {
    NSString *value = [defaults stringForKey:key];
    if (value != nil) {
      content[key] = value;
    }
  }
  return content;
}

- (NSDictionary *)watchPayloadFromContent:(NSDictionary *)content {
  NSMutableDictionary *payload = [content mutableCopy];
  payload[kWatchUpdatedAtKey] = @([[NSDate date] timeIntervalSince1970] * 1000.0);
  return payload;
}

/// Pushes the latest snapshot to the paired watch.
///
/// `force` bypasses the unchanged-content check (used on activation and watch state
/// changes, where the watch may simply not have received the previous push).
- (void)pushSnapshotToWatchForced:(BOOL)force {
  if (@available(iOS 9.0, *)) {
    if (![WCSession isSupported]) {
      return;
    }
    WCSession *session = [WCSession defaultSession];
    if (session.activationState != WCSessionActivationStateActivated) {
      return;
    }
    if (!session.isPaired || !session.isWatchAppInstalled) {
      return;
    }

    NSDictionary *content = [self watchSnapshotContent];
    if (content.count == 0) {
      return;
    }

    BOOL contentChanged =
        self.lastWatchContent == nil || ![content isEqualToDictionary:self.lastWatchContent];
    if (!contentChanged && !force) {
      return;
    }
    self.lastWatchContent = content;

    NSDictionary *payload = [self watchPayloadFromContent:content];

    NSError *contextError = nil;
    if (![session updateApplicationContext:payload error:&contextError]) {
      NSLog(@"WCSession updateApplicationContext failed: %@", contextError.localizedDescription);
    }

    // Complication transfers are budgeted (~50/day), so only spend one when the data
    // actually differs from what the watch was last told.
    if (contentChanged && session.isComplicationEnabled) {
      BOOL hasBudget = YES;
      if (@available(iOS 10.0, *)) {
        hasBudget = session.remainingComplicationUserInfoTransfers > 0;
      }
      if (hasBudget) {
        [session transferCurrentComplicationUserInfo:payload];
      }
    }
  }
}

// MARK: - WCSessionDelegate
- (void)session:(nonnull WCSession *)session activationDidCompleteWithState:(WCSessionActivationState)activationState error:(nullable NSError *)error {
  if (error) {
    NSLog(@"WCSession activation failed: %@", error.localizedDescription);
    return;
  }
  if (activationState == WCSessionActivationStateActivated) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self pushSnapshotToWatchForced:YES];
    });
  }
}

- (void)sessionWatchStateDidChange:(nonnull WCSession *)session {
  dispatch_async(dispatch_get_main_queue(), ^{
    [self pushSnapshotToWatchForced:YES];
  });
}

- (void)sessionReachabilityDidChange:(nonnull WCSession *)session {
  if (session.isReachable) {
    dispatch_async(dispatch_get_main_queue(), ^{
      [self pushSnapshotToWatchForced:NO];
    });
  }
}

/// The watch app pulls a fresh snapshot on launch; answer with whatever the app group
/// currently holds so it never has to wait for the next background delivery.
- (void)session:(nonnull WCSession *)session
    didReceiveMessage:(nonnull NSDictionary<NSString *, id> *)message
         replyHandler:(nonnull void (^)(NSDictionary<NSString *, id> *_Nonnull))replyHandler {
  if (![message[@"request"] isEqual:@"snapshot"]) {
    replyHandler(@{});
    return;
  }

  dispatch_async(dispatch_get_main_queue(), ^{
    NSDictionary *content = [self watchSnapshotContent];
    replyHandler([self watchPayloadFromContent:content]);
  });
}

- (void)sessionDidBecomeInactive:(nonnull WCSession *)session {}

- (void)sessionDidDeactivate:(nonnull WCSession *)session {
  self.lastWatchContent = nil;
  [[WCSession defaultSession] activateSession];
}

@end
