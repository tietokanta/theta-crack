#import "TweakUI.h"
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

@interface _Cx00C7 : NSObject
- (void)setTitle:(NSString *)title;
- (void)setLinkDetail:(NSString *)detail;
- (void)setUrlString:(NSString *)url;
@end

@interface _TxSV0 : UIViewController
- (void)setLinkItems:(NSArray *)items;
- (void)theta_viewDidLoad;
- (UIView *)theta_tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section;
@end

static void (*orig_viewDidLoad)(id, SEL);

static void hooked_viewDidLoad(id self, SEL _cmd) {
    orig_viewDidLoad(self, _cmd);

    Class linkItemClass = NSClassFromString(@"_Cx00C7");
    if (linkItemClass) {
        id item = [[linkItemClass alloc] init];
        [item setTitle:@"Join t.me/jailbreakland"];
        [item setLinkDetail:@"Get support and updates on Telegram."];
        [item setUrlString:@"https://t.me/jailbreakland"];
        [self setLinkItems:@[item]];
    }
}

static UIView *(*orig_viewForFooter)(id, SEL, UITableView *, NSInteger);

static UIView *hooked_viewForFooter(id self, SEL _cmd, UITableView *tableView, NSInteger section) {
    UIView *footer = orig_viewForFooter(self, _cmd, tableView, section);
    if (!footer) return nil;

    for (UIView *subview in footer.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            NSString *text = label.text;
            if ([text containsString:@"@objc_msgSend"] || [text containsString:@"Made with"]) {
                NSString *versionPart = @"";
                NSRange newline = [text rangeOfString:@"\n"];
                if (newline.location != NSNotFound) {
                    versionPart = [text substringFromIndex:newline.location];
                }
                label.text = [NSString stringWithFormat:@"Cracked with 💻 by @jailbreakland%@", versionPart];
            }
            break;
        }
    }
    return footer;
}

void installThetaUIHook(void) {
    Class cls = NSClassFromString(@"_TxSV0");
    if (!cls) return;

    SEL viewDidLoadSel = @selector(viewDidLoad);
    SEL thetaViewDidLoadSel = @selector(theta_viewDidLoad);

    Method viewDidLoadMethod = class_getInstanceMethod(cls, viewDidLoadSel);
    if (viewDidLoadMethod) {
        orig_viewDidLoad = (void (*)(id, SEL))method_getImplementation(viewDidLoadMethod);
        if (!class_getInstanceMethod(cls, thetaViewDidLoadSel)) {
            class_addMethod(cls, thetaViewDidLoadSel, (IMP)hooked_viewDidLoad, method_getTypeEncoding(viewDidLoadMethod));
        }
        method_exchangeImplementations(viewDidLoadMethod, class_getInstanceMethod(cls, thetaViewDidLoadSel));
    }

    SEL footerSel = @selector(tableView:viewForFooterInSection:);
    SEL thetaFooterSel = @selector(theta_tableView:viewForFooterInSection:);

    Method footerMethod = class_getInstanceMethod(cls, footerSel);
    if (footerMethod) {
        orig_viewForFooter = (UIView *(*)(id, SEL, UITableView *, NSInteger))method_getImplementation(footerMethod);
        if (!class_getInstanceMethod(cls, thetaFooterSel)) {
            class_addMethod(cls, thetaFooterSel, (IMP)hooked_viewForFooter, method_getTypeEncoding(footerMethod));
        }
        method_exchangeImplementations(footerMethod, class_getInstanceMethod(cls, thetaFooterSel));
    }
}
