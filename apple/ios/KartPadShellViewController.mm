#import "KartPadShellViewController.h"

#import "KartPadCoreBridge.h"
#import "KartPadMenuButton.h"
#import "SunPadGameOverlay.h"
#import "SunPadInputMixer.h"

#import <Metal/Metal.h>
#import <QuartzCore/CAMetalLayer.h>

@interface KartPadMetalSurface : UIView
@end

@implementation KartPadMetalSurface
+ (Class)layerClass {
    return CAMetalLayer.class;
}
@end

@interface KartPadShellViewController () <SunPadGameOverlayDelegate>
@end

@implementation KartPadShellViewController {
    KartPadMetalSurface *_metalSurface;
    SunPadGameOverlay *_overlay;
}

- (void)loadView {
    // The scene owns the view's eventual size. UIScreen bounds may describe the
    // physical iPad orientation instead of this scene's requested orientation.
    self.view = [[UIView alloc] initWithFrame:CGRectZero];
    self.view.backgroundColor = UIColor.blackColor;

    _metalSurface = [[KartPadMetalSurface alloc] initWithFrame:self.view.bounds];
    _metalSurface.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                     UIViewAutoresizingFlexibleHeight;
    _metalSurface.backgroundColor = UIColor.blackColor;
    CAMetalLayer *metalLayer = (CAMetalLayer *)_metalSurface.layer;
    metalLayer.device = MTLCreateSystemDefaultDevice();
    metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
    metalLayer.framebufferOnly = YES;
    [self.view addSubview:_metalSurface];

    UILabel *status = [[UILabel alloc] initWithFrame:CGRectZero];
    status.translatesAutoresizingMaskIntoConstraints = NO;
    status.text = KartPadCoreIntegrationSummary();
    status.textColor = [UIColor colorWithWhite:1.0 alpha:0.60];
    status.font = [UIFont systemFontOfSize:17.0 weight:UIFontWeightSemibold];
    status.accessibilityLabel = @"KartPad mobile core integration surface";
    [_metalSurface addSubview:status];
    [NSLayoutConstraint activateConstraints:@[
        [status.centerXAnchor constraintEqualToAnchor:_metalSurface.centerXAnchor],
        [status.centerYAnchor constraintEqualToAnchor:_metalSurface.centerYAnchor],
    ]];

    _overlay = [[SunPadGameOverlay alloc] initWithFrame:self.view.bounds];
    _overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                UIViewAutoresizingFlexibleHeight;
    _overlay.backgroundColor = UIColor.clearColor;
    _overlay.delegate = self;
    [self.view addSubview:_overlay];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    KartPadConfigureMenuButton(KartPadFindMenuButton(_overlay));
    [self.view bringSubviewToFront:_overlay];
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? UIInterfaceOrientationMaskAll : UIInterfaceOrientationMaskLandscape;
}

- (BOOL)shouldAutorotate {
    return YES;
}

- (UIInterfaceOrientation)preferredInterfaceOrientationForPresentation {
    return UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad ? [super preferredInterfaceOrientationForPresentation] : UIInterfaceOrientationLandscapeRight;
}

- (BOOL)prefersHomeIndicatorAutoHidden {
    return YES;
}

- (void)clearTransientInput {
    [[SunPadInputMixer sharedMixer] clearInputFromTouch:YES];
}

- (void)resumeAfterForeground {
    if (_overlay.superview != self.view) {
        [_overlay removeFromSuperview];
        _overlay.frame = self.view.bounds;
        [self.view addSubview:_overlay];
    }
    _overlay.hidden = NO;
    _overlay.alpha = 1.0;
    [self.view bringSubviewToFront:_overlay];
    [_overlay refreshControllerVisibility];
    [_overlay applySettings];
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.view bringSubviewToFront:self->_overlay];
        [self->_overlay setNeedsLayout];
    });
}

- (void)showIntegrationAlert:(NSString *)title {
    [self clearTransientInput];
    UIAlertController *alert =
        [UIAlertController alertControllerWithTitle:title
                                            message:@"This shell action is present and input-safe; its KartPad core service is the next integration step."
                                     preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
                                              style:UIAlertActionStyleDefault
                                            handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)gameOverlayRequestsGameDataChange:(SunPadGameOverlay *)overlay {
    (void)overlay;
    [self showIntegrationAlert:@"Import or Reimport Game Data"];
}

- (void)gameOverlayRequestsGameDataFolderImport:(SunPadGameOverlay *)overlay {
    (void)overlay;
    [self showIntegrationAlert:@"Import from This Installation's Folder"];
}

- (void)gameOverlayRequestsGameDataRemoval:(SunPadGameOverlay *)overlay {
    (void)overlay;
    [self showIntegrationAlert:@"Remove Stored Game Data"];
}

- (void)gameOverlayRequestsControllerMapping:(SunPadGameOverlay *)overlay {
    (void)overlay;
    [self showIntegrationAlert:@"Controller Button Mapping"];
}

- (NSString *)gameOverlayDiagnosticContext:(SunPadGameOverlay *)overlay {
    (void)overlay;
    return @"product=KartPad\nsurface=UIKit+CAMetalLayer\ncore=integration\nprivateDataIncluded=false";
}

- (NSString *)gameOverlayPerformanceProfile:(SunPadGameOverlay *)overlay {
    (void)overlay;
    return @"mobile-shell-integration";
}

@end
