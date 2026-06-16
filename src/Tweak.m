#import <mach-o/dyld.h>
#import <string.h>
#import <UIKit/UIKit.h>
#import "TweakHTTP.h"
#import "TweakUI.h"
#import "TweakCrypto.h"

@interface _TxLG7 : NSObject
+ (instancetype)sharedInstance;
- (void)_tlA0:(NSString *)email key:(NSString *)key completion:(void (^)(BOOL, NSString *))completion;
@end

@interface ThetaCrackGestureHandler : NSObject
+ (instancetype)sharedHandler;
- (void)handleLongPress:(UILongPressGestureRecognizer *)gr;
@end

static UIWindow *g_welcomeWindow = nil;

static uintptr_t findImageBase(const char *partialName) {
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (name && strstr(name, partialName))
            return _dyld_get_image_vmaddr_slide(i);
    }
    return 0;
}

static void autoActivateIfNeeded(void) {
    static BOOL called = NO;
    if (called) return;

    Class cls = NSClassFromString(@"_TxLG7");
    if (!cls) return;
    id shared = [cls sharedInstance];
    if (!shared) return;

    called = YES;
    NSString *email = [NSString stringWithFormat:@"%@@jailbreak.land", randomHexString(8)];
    NSString *key = randomHexString(16);

    [shared _tlA0:email key:key completion:^(BOOL success, NSString *result) {
    }];
}

@implementation ThetaCrackGestureHandler
+ (instancetype)sharedHandler {
    static ThetaCrackGestureHandler *instance = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ instance = [[self alloc] init]; });
    return instance;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gr {
    if (gr.state == UIGestureRecognizerStateBegan) {
        autoActivateIfNeeded();
    }
}
@end

static void installActivationGesture(void) {
    UIWindow *keyWindow = nil;
    for (UIWindow *window in [UIApplication sharedApplication].windows) {
        if (window.isKeyWindow) {
            keyWindow = window;
            break;
        }
    }
    if (!keyWindow) return;

    UILongPressGestureRecognizer *gr = [[UILongPressGestureRecognizer alloc]
                                        initWithTarget:[ThetaCrackGestureHandler sharedHandler]
                                        action:@selector(handleLongPress:)];
    gr.numberOfTouchesRequired = 3;
    gr.minimumPressDuration = 2.0;
    [keyWindow addGestureRecognizer:gr];
}

static void showWelcomeAlertIfNeeded(void) {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if ([defaults boolForKey:@"ThetaCrackWelcomeShown"]) {
        installActivationGesture();
        return;
    }
    if (g_welcomeWindow) return;

    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"ThetaCrack"
                                                                   message:@"welcome to the ThetaCrack by t.me/jailbreakland\n\nUse any credentials on the login page and it works."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [defaults setBool:YES forKey:@"ThetaCrackWelcomeShown"];
        [defaults synchronize];
        g_welcomeWindow = nil;
    }]];

    g_welcomeWindow = [[UIWindow alloc] initWithFrame:[UIScreen mainScreen].bounds];
    g_welcomeWindow.windowLevel = UIWindowLevelAlert;
    UIViewController *root = [[UIViewController alloc] init];
    g_welcomeWindow.rootViewController = root;
    [g_welcomeWindow makeKeyAndVisible];
    [root presentViewController:alert animated:YES completion:^{
        autoActivateIfNeeded();
    }];
}

__attribute__((constructor))
static void thetaBypassInit(void) {
    if (!findImageBase("Theta")) return;
    installThetaHTTPHook();
    installThetaUIHook();

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
                                                      object:nil
                                                       queue:[NSOperationQueue mainQueue]
                                                  usingBlock:^(NSNotification *note) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            showWelcomeAlertIfNeeded();
        });
    }];
}
