#import "LeancloudPlugin.h"
#if __has_include(<leancloud_official_plugin/leancloud_official_plugin-Swift.h>)
#import <leancloud_official_plugin/leancloud_official_plugin-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "leancloud_official_plugin-Swift.h"
#endif

@implementation LeancloudPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftLeancloudPlugin registerWithRegistrar:registrar];
}
@end
