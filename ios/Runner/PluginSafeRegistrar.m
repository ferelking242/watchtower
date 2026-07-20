#import "PluginSafeRegistrar.h"
#import "GeneratedPluginRegistrant.h"

@implementation PluginSafeRegistrar

+ (BOOL)safeRegisterWithRegistry:(NSObject<FlutterPluginRegistry> *)registry {
    @try {
        [GeneratedPluginRegistrant registerWithRegistry:registry];
        return YES;
    } @catch (NSException *exception) {
        // "A plugin named 'X' has already been registered." — this happens when
        // a Pods directory mismatch (stale cache, dependency conflict, or a package
        // rename e.g. rust_lib_mangayomi → rust_lib_watchtower) causes the same
        // iOS plugin class name to appear twice in GeneratedPluginRegistrant.
        // The second registration attempt throws NSInvalidArgumentException.
        // We log the problem clearly and let the app continue; all plugins that
        // registered BEFORE the conflict are functional.
        NSLog(@"[PluginSafeRegistrar] ⚠️ Plugin registration exception caught — "
              @"name=%@ reason=%@\n"
              @"This usually means a stale Pods directory or a duplicate iOS plugin "
              @"class name. Run `cd ios && pod install --repo-update` to fix.",
              exception.name, exception.reason);
        return NO;
    }
}

@end
