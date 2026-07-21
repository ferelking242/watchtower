#import <Foundation/Foundation.h>
#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN

/// Wraps GeneratedPluginRegistrant.register(with:) in an ObjC @try/@catch block.
///
/// Flutter throws an NSException ("A plugin named 'X' has already been registered.")
/// when a plugin class name appears twice in GeneratedPluginRegistrant — for example
/// when a stale Pods directory or a dependency conflict causes the same plugin to be
/// compiled into two separate pods, both of which try to call
/// -[FlutterEngine registrarForPlugin:] with the same key.
///
/// Swift cannot catch ObjC exceptions with a normal do/catch, so this ObjC helper
/// bridges the gap and converts the hard crash (SIGABRT) into a logged warning,
/// allowing the app to continue with all successfully-registered plugins.
@interface PluginSafeRegistrar : NSObject

/// Returns YES if registration completed without any exception, NO if an ObjC
/// exception was caught (in which case the exception is logged to NSLog).
+ (BOOL)safeRegisterWith:(NSObject<FlutterPluginRegistry> *)registry;

@end

NS_ASSUME_NONNULL_END
