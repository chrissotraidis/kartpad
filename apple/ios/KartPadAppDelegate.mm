#import <UIKit/UIKit.h>

#import "KartPadShellViewController.h"
#import "SunPadDiagnostics.h"
#import "KartPadSystemDiagnostics.h"

@interface KartPadAppDelegate : UIResponder <UIApplicationDelegate>
@end

@interface KartPadSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property(nonatomic, strong) UIWindow *window;
@end

static void KartPadRequestLandscapeGeometry(UIWindow *window) {
    UIViewController *rootViewController = window.rootViewController;
    [rootViewController setNeedsUpdateOfSupportedInterfaceOrientations];

    UIWindowScene *windowScene = window.windowScene;
    if (windowScene == nil)
        return;
    UIWindowSceneGeometryPreferencesIOS *preferences =
        [[UIWindowSceneGeometryPreferencesIOS alloc]
            initWithInterfaceOrientations:UIInterfaceOrientationMaskLandscape];
    [windowScene requestGeometryUpdateWithPreferences:preferences
                                         errorHandler:^(NSError *error) {
        NSLog(@"[KartPad] landscape geometry request failed: %@", error);
    }];
}

@implementation KartPadAppDelegate

- (UIInterfaceOrientationMask)application:(UIApplication *)application
    supportedInterfaceOrientationsForWindow:(UIWindow *)window {
    (void)application;
    (void)window;
    return UIInterfaceOrientationMaskLandscape;
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    (void)application;
    (void)launchOptions;
    KartPadSystemDiagnosticsStart();
    SunPadDiagnosticsStart();
    return YES;
}

- (UISceneConfiguration *)application:(UIApplication *)application
    configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession
                                    options:(UISceneConnectionOptions *)options {
    (void)application;
    (void)options;
    UISceneConfiguration *configuration =
        [[UISceneConfiguration alloc] initWithName:@"KartPad Configuration"
                                       sessionRole:connectingSceneSession.role];
    configuration.delegateClass = KartPadSceneDelegate.class;
    return configuration;
}

@end

@implementation KartPadSceneDelegate

- (void)scene:(UIScene *)scene
    willConnectToSession:(UISceneSession *)session
                options:(UISceneConnectionOptions *)connectionOptions {
    (void)session;
    (void)connectionOptions;
    if (![scene isKindOfClass:UIWindowScene.class])
        return;
    self.window = [[UIWindow alloc] initWithWindowScene:(UIWindowScene *)scene];
    self.window.rootViewController = [[KartPadShellViewController alloc] init];
    [self.window makeKeyAndVisible];
    dispatch_async(dispatch_get_main_queue(), ^{
        KartPadRequestLandscapeGeometry(self.window);
    });
}

- (void)sceneWillResignActive:(UIScene *)scene {
    (void)scene;
    [(KartPadShellViewController *)self.window.rootViewController clearTransientInput];
}

- (void)sceneDidBecomeActive:(UIScene *)scene {
    (void)scene;
    KartPadRequestLandscapeGeometry(self.window);
    [(KartPadShellViewController *)self.window.rootViewController resumeAfterForeground];
}

@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil,
                                 NSStringFromClass(KartPadAppDelegate.class));
    }
}
