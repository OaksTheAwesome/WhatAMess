#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <WAMTweakInterfaces.h>

/*=====================
  A NOTE FROM THE DEV
=======================

Welcome to my really crummy first attempt at a tweak! Made with iOS 16 in mind, iOS 17 NathanLR and iOS 15 afterwards.
Honestly proabably (definitely) isn't the most optimized thing ever but, hey, it works.
OaksTheAwesome 2026 blah blah blah. If I fall off the face of the Earth feel free to port this/update this, etc.
It's open source after all.

Here be dragons!*/


/* ===================
  PREFERENCE THINGS 
==================== */

#define kPrefsChangedNotification @"com.oakstheawesome.whatamessprefs/prefsChanged"
#define kPrefsPlistPathRootless @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs.plist"
#define kPrefsPlistPathRootfull  @"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs.plist"

static void logToFile(NSString *message) {
    NSString *log = [NSString stringWithFormat:@"%@\n", message];
    NSString *path = @"/var/jb/var/mobile/Library/WhatAMess.log";
    NSFileHandle *handle = [NSFileHandle fileHandleForWritingAtPath:path];
    if (handle) {
        [handle seekToEndOfFile];
        [handle writeData:[log dataUsingEncoding:NSUTF8StringEncoding]];
        [handle closeFile];
    } else {
        [log writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}
#define WAMLOG(fmt, ...) logToFile([NSString stringWithFormat:@"[%@] " fmt, [NSDate date], ##__VA_ARGS__])


BOOL isDarkMode();
BOOL isiOS15();
BOOL isPerContactChatBgEnabled();
BOOL isChatImageBgEnabled();
CGFloat getChatImageBlurAmount();

//Version Splash screen, make sure to bump this value so it acutally registers an update occurred.
#define kWAMTweakVersion @"1.2"
static NSString * const kWAMChangelogTitle = @"What's New in WhatAMess";
static NSString * const kWAMGitHubURL = @"https://github.com/OaksTheAwesome/WhatAMess";

static NSMutableDictionary *cachedPrefs = nil;
static BOOL gWAMIsDarkModeOnIOS15 = NO;
static BOOL gWAMChangelogShownThisLaunch = NO;
static NSString *gWAMCurrentContactName = nil;
static NSString *gWAMCurrentContactDisplayName = nil;
static NSString *gWAMTriggerNameOverride = nil;
static BOOL gWAMChatIsActiveSurface = NO;
static NSTimeInterval gWAMCacheSetAt = 0;
static BOOL gWAMConvListViewVisible = NO;
static NSString *getActiveContactNameForBg(void);
static void wamReconcileAliasForChat(NSString *chatIdentifier, NSString *displayName);
BOOL isCustomTextColorsEnabled(void);
BOOL isTweakEnabled(void);
UIColor *getTitleTextColorConvList(void);
static UIViewController *wamFindVCInHierarchy(UIViewController *vc, Class targetClass);

static id wamConversationFromTappedView(UIView *view) {
    if (!view) return nil;
    UIView *cell = view;
    while (cell && ![cell isKindOfClass:[UICollectionViewCell class]]) {
        cell = cell.superview;
    }
    if (!cell) return nil;
    UIView *p = cell.superview;
    UICollectionView *cv = nil;
    while (p) {
        if ([p isKindOfClass:[UICollectionView class]]) { cv = (UICollectionView *)p; break; }
        p = p.superview;
    }
    if (!cv) return nil;
    NSIndexPath *ip = [cv indexPathForCell:(UICollectionViewCell *)cell];
    if (!ip) return nil;
    UIResponder *r = cv.nextResponder;
    UIViewController *listVC = nil;
    while (r) {
        if ([r isKindOfClass:[UIViewController class]]) { listVC = (UIViewController *)r; break; }
        r = r.nextResponder;
    }
    if (!listVC || ![listVC respondsToSelector:@selector(conversationAtIndexPath:)]) return nil;
    IMP imp = [listVC methodForSelector:@selector(conversationAtIndexPath:)];
    id (*fn)(id, SEL, NSIndexPath *) = (void *)imp;
    return fn(listVC, @selector(conversationAtIndexPath:), ip);
}

static void wamReconcileAliasFromTappedView(UIView *view) {
    id conv = wamConversationFromTappedView(view);
    if (!conv) return;
    NSString *displayName = nil;
    NSString *cid = nil;
    Ivar ch = class_getInstanceVariable([conv class], "_chat");
    id chat = ch ? object_getIvar(conv, ch) : nil;
    if ([chat respondsToSelector:@selector(displayName)]) {
        NSString *dn = [chat performSelector:@selector(displayName)];
        if ([dn isKindOfClass:[NSString class]] && dn.length) displayName = dn;
    }
    if ([chat respondsToSelector:@selector(chatIdentifier)]) {
        NSString *c = [chat performSelector:@selector(chatIdentifier)];
        if ([c isKindOfClass:[NSString class]] && c.length) cid = c;
    }
    if (cid.length && displayName.length) {
        wamReconcileAliasForChat(cid, displayName);
    }
}

static BOOL wamNavBarShouldUseGlobals(UIView *view) {
    if (!view) return NO;
    UIView *p = view;
    int hops = 0;
    while (p && hops < 30) {
        if ([p isKindOfClass:[UINavigationBar class]]) {
            UINavigationBar *bar = (UINavigationBar *)p;
            id delegate = bar.delegate;
            UINavigationController *nav = nil;
            if ([delegate isKindOfClass:[UINavigationController class]]) {
                nav = (UINavigationController *)delegate;
            }
            UIViewController *destVC = nil;
            if (nav) {
                id<UIViewControllerTransitionCoordinator> tc = nav.transitionCoordinator;
                if (tc) {
                    destVC = [tc viewControllerForKey:UITransitionContextToViewControllerKey];
                }
                if (!destVC) destVC = nav.topViewController;
            }
            if (destVC && [destVC isKindOfClass:%c(CKConversationListCollectionViewController)]) {
                return YES;
            }
            return NO;
        }
        p = p.superview;
        hops++;
    }
    return NO;
}

static void wamForceVisualRefresh(UIView *view) {
    if (!view) return;
    Class pinnedBubbleCls = %c(CKPinnedConversationSummaryBubble);
    Class pinnedViewCls = %c(CKPinnedConversationView);
    if ((pinnedBubbleCls && [view isKindOfClass:pinnedBubbleCls]) ||
        (pinnedViewCls && [view isKindOfClass:pinnedViewCls])) {
        return;
    }
    [view tintColorDidChange];
    [view setNeedsLayout];
    [view setNeedsDisplay];
    for (UIView *sub in view.subviews) {
        wamForceVisualRefresh(sub);
    }
}

static void wamForceGlobalColorsOnConvListLabels(UIView *view) {
    if (!view) return;
    Class cellCls = %c(CKConversationListCollectionViewConversationCell);
    if ([view isKindOfClass:%c(CKLabel)]) {
        // Confirm this label is inside a conv list cell.
        UIView *p = view.superview;
        BOOL inCell = NO;
        while (p) {
            if (cellCls && [p isKindOfClass:cellCls]) { inCell = YES; break; }
            p = p.superview;
        }
        if (inCell && isCustomTextColorsEnabled()) {
            UILabel *label = (UILabel *)view;
            UIColor *target = getTitleTextColorConvList();
            if (target && ![label.textColor isEqual:target]) {
                label.textColor = target;
            }
        }
    }
    for (UIView *sub in view.subviews) {
        wamForceGlobalColorsOnConvListLabels(sub);
    }
}

@interface WAMHeartbeatTarget : NSObject
+ (instancetype)shared;
- (void)tick;
@end
@implementation WAMHeartbeatTarget {
    CADisplayLink *_link;
}
+ (instancetype)shared {
    static WAMHeartbeatTarget *s = nil;
    static dispatch_once_t o;
    dispatch_once(&o, ^{
        s = [WAMHeartbeatTarget new];
        s->_link = [CADisplayLink displayLinkWithTarget:s selector:@selector(tick)];
        s->_link.preferredFramesPerSecond = 60;  // 16ms cadence — halves the worst-case transition latency
        [s->_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    });
    return s;
}
- (void)tick {
    if (!isTweakEnabled()) return;
    NSMutableArray *winList = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                [winList addObjectsFromArray:((UIWindowScene *)scene).windows];
            }
        }
    }
    Class messagesCls = %c(CKMessagesController);
    BOOL chatIsVisible = NO;
    UIViewController *foundCtrl = nil;
    if (messagesCls) {
        for (UIWindow *w in winList) {
            UIViewController *vc = wamFindVCInHierarchy(w.rootViewController, messagesCls);
            if (vc && [vc isViewLoaded] && vc.view.window) {
                chatIsVisible = YES;
                foundCtrl = vc;
                break;
            }
        }
    }
    id conv = nil;
    if (foundCtrl) {
        Ivar cv = class_getInstanceVariable([foundCtrl class], "_currentConversation");
        conv = cv ? object_getIvar(foundCtrl, cv) : nil;
    }
    chatIsVisible = (conv != nil);
    Class listCls = %c(CKConversationListCollectionViewController);
    BOOL listInWindow = NO;
    if (listCls) {
        for (UIWindow *w in winList) {
            UIViewController *listVC = wamFindVCInHierarchy(w.rootViewController, listCls);
            if (listVC && [listVC isViewLoaded] && listVC.view.window) {
                listInWindow = YES;
                break;
            }
        }
    }
    static BOOL prevListVisible = NO;
    static NSString *prevTopVCClass = nil;
    Class navCls = %c(CKNavigationController);
    NSString *topVCClass = @"(none)";
    if (navCls && foundCtrl) {
        for (UIViewController *child in foundCtrl.childViewControllers) {
            if ([child isKindOfClass:navCls]) {
                UINavigationController *nav = (UINavigationController *)child;
                topVCClass = NSStringFromClass([nav.topViewController class]) ?: @"(nil)";
                break;
            }
        }
    }
    BOOL topVCChanged = ![topVCClass isEqualToString:prevTopVCClass];
    if (listInWindow != prevListVisible || topVCChanged) {
        WAMLOG(@"[heartbeat] listVis %d→%d topVC '%@'→'%@' (chatVisible=%d conv=%p)",
               prevListVisible, listInWindow, prevTopVCClass ?: @"(init)", topVCClass, chatIsVisible, conv);
        prevListVisible = listInWindow;
        prevTopVCClass = [topVCClass copy];
    }
    gWAMConvListViewVisible = listInWindow;
    static BOOL prevChatVisible = NO;
    BOOL stateChanged = (chatIsVisible != prevChatVisible);
    prevChatVisible = chatIsVisible;
    if (chatIsVisible) {
        gWAMChatIsActiveSurface = YES;
        return;
    }
    if (gWAMChatIsActiveSurface) {
        gWAMChatIsActiveSurface = NO;
        gWAMCurrentContactName = nil;
        gWAMCurrentContactDisplayName = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
    }
    for (UIWindow *w in winList) {
        wamForceGlobalColorsOnConvListLabels(w);
        if (stateChanged) {
            wamForceVisualRefresh(w);
        }
    }
}
@end

static UIViewController *wamFindVCInHierarchy(UIViewController *vc, Class targetClass) {
    if (!vc) return nil;
    if ([vc isKindOfClass:targetClass]) return vc;
    for (UIViewController *child in vc.childViewControllers) {
        UIViewController *found = wamFindVCInHierarchy(child, targetClass);
        if (found) return found;
    }
    if (vc.presentedViewController) {
        return wamFindVCInHierarchy(vc.presentedViewController, targetClass);
    }
    return nil;
}

static NSString *getCurrentContactName(void) {
    Class messagesCtrlClass = %c(CKMessagesController);
    if (!messagesCtrlClass) return nil;

    NSArray<UIWindow *> *windows = nil;
    if (@available(iOS 13.0, *)) {
        NSMutableArray *ws = [NSMutableArray array];
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                [ws addObjectsFromArray:((UIWindowScene *)scene).windows];
            }
        }
        windows = ws;
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if (!windows.count) windows = [UIApplication sharedApplication].windows;
#pragma clang diagnostic pop

    UIViewController *messagesCtrl = nil;
    for (UIWindow *w in windows) {
        messagesCtrl = wamFindVCInHierarchy(w.rootViewController, messagesCtrlClass);
        if (messagesCtrl) break;
    }
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    BOOL cacheFresh = gWAMCurrentContactName.length && (now - gWAMCacheSetAt) < 2.0;
    if (!messagesCtrl) {
        return cacheFresh ? gWAMCurrentContactName : nil;
    }

    Ivar cv = class_getInstanceVariable([messagesCtrl class], "_currentConversation");
    id conv = cv ? object_getIvar(messagesCtrl, cv) : nil;
    if (!conv) {
        if (!cacheFresh) {
            gWAMCurrentContactName = nil;
            gWAMCurrentContactDisplayName = nil;
        }
        return cacheFresh ? gWAMCurrentContactName : nil;
    }

    NSString *name = nil;
    NSString *cid = nil;
    Ivar ch = class_getInstanceVariable([conv class], "_chat");
    id chat = ch ? object_getIvar(conv, ch) : nil;
    if ([chat respondsToSelector:@selector(displayName)]) {
        NSString *dn = [chat performSelector:@selector(displayName)];
        if ([dn isKindOfClass:[NSString class]] && dn.length) name = dn;
    }
    if (!name.length) {
        static const char *nameIvars[] = {"_name", "_displayName", "_groupName", NULL};
        for (int i = 0; nameIvars[i]; i++) {
            Ivar v = class_getInstanceVariable([conv class], nameIvars[i]);
            if (!v) continue;
            id val = object_getIvar(conv, v);
            if ([val isKindOfClass:[NSString class]] && [(NSString *)val length]) { name = val; break; }
        }
    }
    if ([chat respondsToSelector:@selector(chatIdentifier)]) {
        NSString *c = [chat performSelector:@selector(chatIdentifier)];
        if ([c isKindOfClass:[NSString class]] && c.length) cid = c;
    }
    if (name.length) {
        if (cid.length) wamReconcileAliasForChat(cid, name);
        gWAMCurrentContactName = [name copy];
        gWAMCurrentContactDisplayName = [name copy];
        return name;
    }
    return gWAMCurrentContactName;
}

static const char kWAMOrigDateColorKey = 0;
static const char kWAMOrigTitleColorKey = 0;
static const char kWAMOrigPreviewColorKey = 0;
static const char kWAMOrigTintColorKey = 0;
static const char kWAMInputFieldBlurKey = 0;
static const char kWAMEffectExpandedKey = 0;

static UIColor *WAMPinnedBubbleLightColor = nil;
static UIColor *WAMPinnedBubbleDarkColor = nil;
static UIColor *WAMPinnedTextLightColor = nil;
static UIColor *WAMPinnedTextDarkColor = nil;
static UIColor *WAMPinnedBubbleCurrentColor = nil;
static UIColor *WAMPinnedTextCurrentColor = nil;

static void reloadPrefs() {
    NSMutableDictionary *fromDisk = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefsPlistPathRootless];
    if (!fromDisk || fromDisk.count == 0) {
        fromDisk = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefsPlistPathRootfull];
    }
    cachedPrefs = (fromDisk && fromDisk.count > 0) ? fromDisk : [NSMutableDictionary new];
}

static void reloadPrefsAndNotify() {
    reloadPrefs();
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
    });
}

static NSDictionary *loadPrefs() {
    if (!cachedPrefs) {
        reloadPrefs();
    }
    return cachedPrefs;
}

static void refreshPrefs() {
    reloadPrefs();
}

static NSString *getConvImagePath() {
    return isDarkMode()
        ? @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background_dark.jpg"
        : @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background.jpg";
}

static NSString *getDefaultChatImagePath() {
    return isDarkMode()
        ? @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background_dark.jpg"
        : @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background.jpg";
}

#define kWAMPerContactDir @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/per_contact"

static NSString *sanitizeContactName(NSString *raw) {
    if (!raw.length) return nil;
    NSCharacterSet *invalid = [NSCharacterSet characterSetWithCharactersInString:@"/:?#[]@!$&'()*+,;= \t\n\r"];
    NSArray *parts = [raw componentsSeparatedByCharactersInSet:invalid];
    return [parts componentsJoinedByString:@"_"];
}

static NSString *getPerContactImagePath(NSString *contactName, BOOL dark) {
    NSString *safe = sanitizeContactName(contactName);
    if (!safe.length) return nil;
    NSString *fileName = dark ? [NSString stringWithFormat:@"%@_dark.jpg", safe]
                              : [NSString stringWithFormat:@"%@.jpg", safe];
    return [kWAMPerContactDir stringByAppendingPathComponent:fileName];
}

static CGFloat getPerContactBlur(NSString *contactName, BOOL isDark) {
    NSString *safe = sanitizeContactName(contactName);
    if (!safe.length) return 0;
    NSDictionary *prefs = loadPrefs();
    NSDictionary *d = prefs[@"perContactBlur"];
    if (![d isKindOfClass:[NSDictionary class]]) return 0;
    id entry = d[safe];
    if ([entry isKindOfClass:[NSNumber class]]) return [(NSNumber *)entry floatValue];
    if ([entry isKindOfClass:[NSDictionary class]]) {
        NSNumber *v = ((NSDictionary *)entry)[isDark ? @"dark" : @"light"];
        return v ? v.floatValue : 0;
    }
    return 0;
}

static void setPerContactBlur(NSString *contactName, BOOL isDark, CGFloat blur) {
    NSString *safe = sanitizeContactName(contactName);
    if (!safe.length) return;
    NSString *path = kPrefsPlistPathRootless;
    NSString *dir = [path stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    if (!prefs) prefs = [NSMutableDictionary new];
    NSMutableDictionary *map = [(NSDictionary *)prefs[@"perContactBlur"] mutableCopy] ?: [NSMutableDictionary new];
    id existing = map[safe];
    NSMutableDictionary *entry;
    if ([existing isKindOfClass:[NSDictionary class]]) {
        entry = [(NSDictionary *)existing mutableCopy];
    } else if ([existing isKindOfClass:[NSNumber class]]) {
        // Migrate legacy single-value entry — preserve old value for the other mode.
        entry = [NSMutableDictionary dictionaryWithObjectsAndKeys:existing, @"light", existing, @"dark", nil];
    } else {
        entry = [NSMutableDictionary new];
    }
    entry[isDark ? @"dark" : @"light"] = @(blur);
    map[safe] = entry;
    prefs[@"perContactBlur"] = map;
    [prefs writeToFile:path atomically:YES];
    refreshPrefs();
}
/* ================================ */
//      Per Contact Override
/* ================================ */

static NSDictionary *perContactOverridesForName(NSString *contactName) {
    NSString *safe = sanitizeContactName(contactName);
    if (!safe.length) return nil;
    NSDictionary *prefs = loadPrefs();
    NSDictionary *all = prefs[@"perContactOverrides"];
    if (![all isKindOfClass:[NSDictionary class]]) return nil;
    NSDictionary *per = all[safe];
    return [per isKindOfClass:[NSDictionary class]] ? per : nil;
}

static id getPerContactOverride(NSString *contactName, NSString *key) {
    if (!key.length) return nil;
    return perContactOverridesForName(contactName)[key];
}

__attribute__((unused))
static BOOL hasPerContactOverride(NSString *contactName, NSString *key) {
    return getPerContactOverride(contactName, key) != nil;
}

static void setPerContactOverride(NSString *contactName, NSString *key, id value) {
    NSString *safe = sanitizeContactName(contactName);
    if (!safe.length || !key.length) return;
    NSString *path = kPrefsPlistPathRootless;
    NSString *dir = [path stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    if (!prefs) prefs = [NSMutableDictionary new];
    NSMutableDictionary *all = [(NSDictionary *)prefs[@"perContactOverrides"] mutableCopy] ?: [NSMutableDictionary new];
    NSMutableDictionary *per = [(NSDictionary *)all[safe] mutableCopy] ?: [NSMutableDictionary new];
    if (value) per[key] = value; else [per removeObjectForKey:key];
    if (per.count) all[safe] = per; else [all removeObjectForKey:safe];
    if (all.count) prefs[@"perContactOverrides"] = all; else [prefs removeObjectForKey:@"perContactOverrides"];
    [prefs writeToFile:path atomically:YES];
    refreshPrefs();
}

static NSString *const kWAMOverrideEnabledKey = @"_enabled";

static BOOL perContactOverridesEnabled(NSString *contactName) {
    NSDictionary *p = perContactOverridesForName(contactName);
    NSNumber *v = p[kWAMOverrideEnabledKey];
    return v ? v.boolValue : NO;
}

static void setPerContactOverridesEnabled(NSString *contactName, BOOL enabled) {
    setPerContactOverride(contactName, kWAMOverrideEnabledKey, @(enabled));
}

__attribute__((unused))
static void clearPerContactOverride(NSString *contactName, NSString *key) {
    setPerContactOverride(contactName, key, nil);
}

__attribute__((unused))
static id effectiveValueForKey(NSString *key) {
    if (!key.length) return nil;
    NSString *name = getCurrentContactName();
    if (name.length && perContactOverridesEnabled(name)) {
        id override = getPerContactOverride(name, key);
        if (override) return override;
    }
    return loadPrefs()[key];
}

__attribute__((unused))
static BOOL chatHasPerContactOverride(void) {
    NSString *name = getCurrentContactName();
    if (!name.length) return NO;
    return perContactOverridesEnabled(name);
}

/* =====================================================================
                                Chat ID System
   ===================================================================== */

static NSString *getChatAliasName(NSString *chatIdentifier) {
    NSString *safe = sanitizeContactName(chatIdentifier);
    if (!safe.length) return nil;
    NSDictionary *prefs = loadPrefs();
    NSDictionary *aliases = prefs[@"chatIdentifierAliases"];
    if (![aliases isKindOfClass:[NSDictionary class]]) return nil;
    id v = aliases[safe];
    return [v isKindOfClass:[NSString class]] ? v : nil;
}

static void setChatAliasName(NSString *chatIdentifier, NSString *displayName) {
    NSString *safe = sanitizeContactName(chatIdentifier);
    if (!safe.length || !displayName.length) return;
    NSString *path = kPrefsPlistPathRootless;
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    if (!prefs) prefs = [NSMutableDictionary new];
    NSMutableDictionary *aliases = [(NSDictionary *)prefs[@"chatIdentifierAliases"] mutableCopy]
        ?: [NSMutableDictionary new];
    aliases[safe] = displayName;
    prefs[@"chatIdentifierAliases"] = aliases;
    [prefs writeToFile:path atomically:YES];
    refreshPrefs();
}

static void migratePerChatData(NSString *fromName, NSString *toName) {
    NSString *fromSafe = sanitizeContactName(fromName);
    NSString *toSafe = sanitizeContactName(toName);
    if (!fromSafe.length || !toSafe.length) return;
    if ([fromSafe isEqualToString:toSafe]) return;
    NSString *path = kPrefsPlistPathRootless;
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    if (!prefs) return;
    BOOL dirty = NO;
    NSMutableDictionary *overrides = [(NSDictionary *)prefs[@"perContactOverrides"] mutableCopy];
    NSDictionary *fromOverrides = overrides[fromSafe];
    if ([fromOverrides isKindOfClass:[NSDictionary class]]) {
        overrides[toSafe] = fromOverrides;
        [overrides removeObjectForKey:fromSafe];
        prefs[@"perContactOverrides"] = overrides;
        dirty = YES;
    }
    NSMutableDictionary *blurMap = [(NSDictionary *)prefs[@"perContactBlur"] mutableCopy];
    id fromBlur = blurMap[fromSafe];
    if (fromBlur) {
        blurMap[toSafe] = fromBlur;
        [blurMap removeObjectForKey:fromSafe];
        prefs[@"perContactBlur"] = blurMap;
        dirty = YES;
    }
    if (dirty) {
        [prefs writeToFile:path atomically:YES];
        refreshPrefs();
    }
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *fromLight = getPerContactImagePath(fromName, NO);
    NSString *toLight = getPerContactImagePath(toName, NO);
    if (fromLight && toLight && [fm fileExistsAtPath:fromLight]) {
        [fm removeItemAtPath:toLight error:nil];
        [fm moveItemAtPath:fromLight toPath:toLight error:nil];
    }
    NSString *fromDark = getPerContactImagePath(fromName, YES);
    NSString *toDark = getPerContactImagePath(toName, YES);
    if (fromDark && toDark && [fm fileExistsAtPath:fromDark]) {
        [fm removeItemAtPath:toDark error:nil];
        [fm moveItemAtPath:fromDark toPath:toDark error:nil];
    }
}

static void wamReconcileAliasForChat(NSString *chatIdentifier, NSString *displayName) {
    if (!chatIdentifier.length || !displayName.length) return;
    NSString *prevName = getChatAliasName(chatIdentifier);
    if (prevName.length && ![prevName isEqualToString:displayName]) {
        migratePerChatData(prevName, displayName);
        setChatAliasName(chatIdentifier, displayName);
        [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
    } else if (!prevName.length) {
        setChatAliasName(chatIdentifier, displayName);
    }
}

static NSString *getActiveContactNameForBg(void) {
    if (gWAMTriggerNameOverride.length) return gWAMTriggerNameOverride;
    return getCurrentContactName();
}

static NSString *getPerContactImagePathForCurrentChat() {
    if (!isPerContactChatBgEnabled()) return nil;
    NSString *name = getActiveContactNameForBg();
    if (!name.length) return nil;
    if (!perContactOverridesEnabled(name)) return nil;
    BOOL dark = isDarkMode();
    NSString *primary = getPerContactImagePath(name, dark);
    if (primary && [[NSFileManager defaultManager] fileExistsAtPath:primary]) return primary;
    NSString *fallback = getPerContactImagePath(name, !dark);
    if (fallback && [[NSFileManager defaultManager] fileExistsAtPath:fallback]) return fallback;
    return nil;
}

static NSString *getChatImagePath() {
    NSString *perPath = getPerContactImagePathForCurrentChat();
    return perPath ?: getDefaultChatImagePath();
}

static CGFloat getEffectiveChatBgBlur() {
    if (getPerContactImagePathForCurrentChat()) {
        return getPerContactBlur(getActiveContactNameForBg(), isDarkMode());
    }
    return getChatImageBlurAmount();
}

static BOOL shouldShowAnyChatBgImage() {
    return isChatImageBgEnabled() || getPerContactImagePathForCurrentChat() != nil;
}

static NSString *WAMLastKnownTitle = nil;

/*=======================
    BOOLEAN FUNCTIONS
========================*/

BOOL isTweakEnabled() {
    NSDictionary *prefs = loadPrefs();
    return prefs[@"isEnabled"] ? [prefs[@"isEnabled"] boolValue] : YES;
}

BOOL isModernNavBarEnabled() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isModernNavBarEnabledDark" : @"isModernNavBarEnabled";
    return prefs[key] ? [prefs[key] boolValue] : YES;
}

BOOL isSeparatorsEnabled() {
    NSDictionary *prefs = loadPrefs();
    return prefs[@"isSeparatorsEnabled"] ? [prefs[@"isSeparatorsEnabled"] boolValue] : NO;
}

BOOL isSearchBgEnabled() {
    NSDictionary *prefs = loadPrefs();
    return prefs[@"isSearchBgEnabled"] ? [prefs[@"isSearchBgEnabled"] boolValue] : NO;
}

BOOL isPinnedGlowEnabled() {
    NSDictionary *prefs = loadPrefs();
    return prefs[@"isPinnedGlowEnabled"] ? [prefs[@"isPinnedGlowEnabled"] boolValue] : NO;
}

BOOL isConvColorBgEnabled() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isConvColorBgEnabledDark" : @"isConvColorBgEnabled";
    return prefs[key] ? [prefs[key] boolValue] : NO;
}

BOOL isChatColorBgEnabled() {
    NSString *key = isDarkMode() ? @"isChatColorBgEnabledDark" : @"isChatColorBgEnabled";
    id v = effectiveValueForKey(key);
    return v ? [v boolValue] : NO;
}

BOOL isConvImageBgEnabled() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isConvImageBgEnabledDark" : @"isConvImageBgEnabled";
    return prefs[key] ? [prefs[key] boolValue] : NO;
}

BOOL isChatImageBgEnabled() {
    NSString *key = isDarkMode() ? @"isChatImageBgEnabledDark" : @"isChatImageBgEnabled";
    id v = effectiveValueForKey(key);
    return v ? [v boolValue] : NO;
}

BOOL isPerContactChatBgEnabled() {
    return YES;
}

BOOL isCustomTextColorsEnabled() {
    if (chatHasPerContactOverride()) return YES;
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isCustomTextColorsEnabledDark" : @"isCustomTextColorsEnabled";
    return prefs[key] ? [prefs[key] boolValue] : NO;
}

BOOL isCustomBubbleColorsEnabled() {
    if (chatHasPerContactOverride()) return YES;
    NSString *key = isDarkMode() ? @"isCustomBubbleColorsEnabledDark" : @"isCustomBubbleColorsEnabled";
    id v = effectiveValueForKey(key);
    return v ? [v boolValue] : NO;
}

BOOL isModernMessageBarEnabled() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isModernMessageBarEnabledDark" : @"isModernMessageBarEnabled";
    return prefs[key] ? [prefs[key] boolValue] : YES;
}

static BOOL readModeBoolWithFallback(NSString *lightKey, NSString *darkKey) {
    if (isDarkMode()) {
        id v = effectiveValueForKey(darkKey);
        return v ? [v boolValue] : NO;
    }
    id light = effectiveValueForKey(lightKey);
    if (light) return [light boolValue];
    id dark = effectiveValueForKey(darkKey);
    return dark ? [dark boolValue] : NO;
}

BOOL isInputFieldCustomizationEnabled() {
    if (chatHasPerContactOverride()) return YES;
    return readModeBoolWithFallback(@"isInputFieldCustomizationEnabled", @"isInputFieldCustomizationEnabledDark");
}

BOOL isInputFieldBlurEnabled() {
    if (chatHasPerContactOverride()) return YES;
    return readModeBoolWithFallback(@"isInputFieldBlurEnabled", @"isInputFieldBlurEnabledDark");
}

BOOL isPlaceholderCustomizationEnabled() {
    if (chatHasPerContactOverride()) return YES;
    return readModeBoolWithFallback(@"isPlaceholderCustomizationEnabled", @"isPlaceholderCustomizationEnabledDark");
}

BOOL isMessageInputTextEnabled() {
    if (chatHasPerContactOverride()) return YES;
    return readModeBoolWithFallback(@"isMessageInputTextEnabled", @"isMessageInputTextEnabledDark");
}

BOOL isMessageBarButtonsEnabled() {
    if (chatHasPerContactOverride()) return YES;
    return readModeBoolWithFallback(@"isMessageBarButtonsEnabled", @"isMessageBarButtonsEnabledDark");
}

BOOL isNavBarCustomizationEnabled() {
    if (chatHasPerContactOverride()) return YES;
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isNavBarCustomizationEnabledDark" : @"isNavBarCustomizationEnabled";
    return prefs[key] ? [prefs[key] boolValue] : NO;
}

BOOL isMessageBarCustomizationEnabled() {
    if (chatHasPerContactOverride()) return YES;
    return readModeBoolWithFallback(@"isMessageBarCustomizationEnabled", @"isMessageBarCustomizationEnabledDark");
}

BOOL isCellBlurTintEnabled() {
    if (chatHasPerContactOverride()) return YES;
    id v = effectiveValueForKey(@"isCellBlurTintEnabled");
    return v ? [v boolValue] : NO;
}

BOOL isiOS17OrHigher() {
    NSOperatingSystemVersion iOS17 = {17, 0, 0};
    return [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:iOS17];
}

BOOL isiOS15() {
    NSOperatingSystemVersion iOS15 = {15, 0, 0};
    NSOperatingSystemVersion iOS16 = {16, 0, 0};
    return [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:iOS15] &&
           ![[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:iOS16];
}

static void updateDarkModeFromTraits(UITraitCollection *tc) {
    if (@available(iOS 13.0, *)) {
        gWAMIsDarkModeOnIOS15 = (tc.userInterfaceStyle == UIUserInterfaceStyleDark);
    }
}

BOOL isDarkMode() {
    if (@available(iOS 13.0, *)) {
        if (isiOS15()) {
            UIUserInterfaceStyle screenStyle = [UIScreen mainScreen].traitCollection.userInterfaceStyle;
            if (screenStyle != UIUserInterfaceStyleUnspecified) {
                return screenStyle == UIUserInterfaceStyleDark;
            }
            return gWAMIsDarkModeOnIOS15;
        }
        return [UITraitCollection currentTraitCollection].userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    return NO;
}

/*=======================
    Numeric Getters
=======================*/

CGFloat getImageBlurAmount() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"imageBlurAmountDark" : @"imageBlurAmount";
    return prefs[key] ? [prefs[key] floatValue] : 0.0;
}

CGFloat getChatImageBlurAmount() {
    NSString *key = isDarkMode() ? @"chatImageBlurAmountDark" : @"chatImageBlurAmount";
    id v = effectiveValueForKey(key);
    return v ? [v floatValue] : 0.0;
}

/*=================================
    Helper and Getter Functions
=================================*/

static UIColor *getSystemTintColor();

UIColor *colorFromHex(NSString *hexString) {
    if (!hexString || [hexString length] == 0) return nil;

    if ([hexString hasPrefix:@"#"]) {
        hexString = [hexString substringFromIndex:1];
    }

    CGFloat r, g, b, a;

    if (hexString.length == 8) {
        NSString *rStr = [hexString substringWithRange:NSMakeRange(0, 2)];
        NSString *gStr = [hexString substringWithRange:NSMakeRange(2, 2)];
        NSString *bStr = [hexString substringWithRange:NSMakeRange(4, 2)];
        NSString *aStr = [hexString substringWithRange:NSMakeRange(6, 2)];

        unsigned int rInt, gInt, bInt, aInt;
        [[NSScanner scannerWithString:rStr] scanHexInt:&rInt];
        [[NSScanner scannerWithString:gStr] scanHexInt:&gInt];
        [[NSScanner scannerWithString:bStr] scanHexInt:&bInt];
        [[NSScanner scannerWithString:aStr] scanHexInt:&aInt];

        r = rInt / 255.0;
        g = gInt / 255.0;
        b = bInt / 255.0;
        a = aInt / 255.0;
    } else if (hexString.length == 6) {
        NSString *rStr = [hexString substringWithRange:NSMakeRange(0, 2)];
        NSString *gStr = [hexString substringWithRange:NSMakeRange(2, 2)];
        NSString *bStr = [hexString substringWithRange:NSMakeRange(4, 2)];

        unsigned int rInt, gInt, bInt;
        [[NSScanner scannerWithString:rStr] scanHexInt:&rInt];
        [[NSScanner scannerWithString:gStr] scanHexInt:&gInt];
        [[NSScanner scannerWithString:bStr] scanHexInt:&bInt];

        r = rInt / 255.0;
        g = gInt / 255.0;
        b = bInt / 255.0;
        a = 1.0;
    } else {
        return nil;
    }

    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

static NSString *hexFromColor(UIColor *color) {
    if (!color) return nil;

    CGColorRef cg = color.CGColor;
    CGColorSpaceRef sRGBSpace = CGColorSpaceCreateWithName(kCGColorSpaceSRGB);
    CGColorRef converted = CGColorCreateCopyByMatchingToColorSpace(sRGBSpace, kCGRenderingIntentDefault, cg, NULL);
    CGColorSpaceRelease(sRGBSpace);

    UIColor *sRGBColor = converted ? [UIColor colorWithCGColor:converted] : color;
    if (converted) CGColorRelease(converted);

    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![sRGBColor getRed:&r green:&g blue:&b alpha:&a]) {
        CGFloat white = 0, walpha = 0;
        if ([sRGBColor getWhite:&white alpha:&walpha]) {
            r = g = b = white;
        }
    }
    r = MAX(0.0, MIN(1.0, r));
    g = MAX(0.0, MIN(1.0, g));
    b = MAX(0.0, MIN(1.0, b));
    a = MAX(0.0, MIN(1.0, a));

    int ri = (int)round(r * 255), gi = (int)round(g * 255), bi = (int)round(b * 255);
    int ai = (int)round(a * 255);
    if (ai >= 255) {
        return [NSString stringWithFormat:@"#%02X%02X%02X", ri, gi, bi];
    }
    return [NSString stringWithFormat:@"#%02X%02X%02X%02X", ri, gi, bi, ai];
}

static UIImage *loadImageUncached(NSString *path) {
    NSData *data = [NSData dataWithContentsOfFile:path];
    return data ? [UIImage imageWithData:data] : nil;
}

UIColor *getBackgroundColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"convListBackgroundColorDark" : @"convListBackgroundColor";
    return colorFromHex(prefs[key]) ?: [UIColor blackColor];
}

UIColor *getChatBackgroundColor() {
    NSString *key = isDarkMode() ? @"chatBackgroundColorDark" : @"chatBackgroundColor";
    return colorFromHex(effectiveValueForKey(key)) ?: [UIColor blackColor];
}

UIColor *getCellColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"convListCellColorDark" : @"convListCellColor";
    return colorFromHex(prefs[key]) ?: [UIColor blackColor];
}

UIColor *getTitleTextColor() {
    NSString *key = isDarkMode() ? @"titleTextColorDark" : @"titleTextColor";
    return colorFromHex(effectiveValueForKey(key)) ?: [UIColor whiteColor];
}

UIColor *getChatContactNameColor() {
    NSString *key = isDarkMode() ? @"chatContactNameColorDark" : @"chatContactNameColor";
    UIColor *c = colorFromHex(effectiveValueForKey(key));
    if (c) return c;
    return getTitleTextColor();
}

UIColor *getTitleTextColorConvList() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"titleTextColorDark" : @"titleTextColor";
    return colorFromHex(prefs[key]) ?: [UIColor whiteColor];
}

UIColor *getMessagePreviewTextColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"messagePreviewTextColorDark" : @"messagePreviewTextColor";
    return colorFromHex(prefs[key]) ?: [UIColor grayColor];
}

UIColor *getDateTimeTextColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"dateTimeTextColorDark" : @"dateTimeTextColor";
    return colorFromHex(prefs[key]) ?: [UIColor grayColor];
}

UIColor *getConversationListTitleColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"conversationListTitleColorDark" : @"conversationListTitleColor";
    return colorFromHex(prefs[key]) ?: [UIColor whiteColor];
}

UIColor *getInputFieldBackgroundColor() {
    NSString *key = isDarkMode() ? @"inputFieldBackgroundColorDark" : @"inputFieldBackgroundColor";
    return colorFromHex(effectiveValueForKey(key)) ?: [UIColor whiteColor];
}

static BOOL isAdvancedTintEnabled() {
    if (chatHasPerContactOverride()) return YES;
    NSDictionary *prefs = loadPrefs();
    return prefs[@"isAdvancedTintEnabled"] ? [prefs[@"isAdvancedTintEnabled"] boolValue] : NO;
}

static UIColor *getAdvancedTintColor(NSString *lightKey, NSString *darkKey, UIColor *fallback) {
    BOOL effective = isAdvancedTintEnabled() || chatHasPerContactOverride();
    if (!effective) return fallback;
    NSString *key = isDarkMode() ? darkKey : lightKey;
    UIColor *color = colorFromHex(effectiveValueForKey(key));
    return color ?: fallback;
}

static UIColor *getAdvancedTintColorForView(NSString *lightKey, NSString *darkKey, UIColor *fallback, UIView *view) {
    BOOL effective = isAdvancedTintEnabled() || chatHasPerContactOverride();
    if (!effective) return fallback;
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = view
            ? (view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
            : isDarkMode();
    }
    NSString *key = dark ? darkKey : lightKey;
    UIColor *color = colorFromHex(effectiveValueForKey(key));
    return color ?: fallback;
}

static UIColor *getChatAdvancedTintColor(NSString *lightKey, NSString *darkKey, UIColor *fallback) {
    BOOL effective = isAdvancedTintEnabled() || chatHasPerContactOverride();
    if (!effective) return fallback;
    NSString *key = isDarkMode() ? darkKey : lightKey;
    UIColor *color = colorFromHex(effectiveValueForKey(key));
    return color ?: fallback;
}

static UIColor *getChatAdvancedTintColorForView(NSString *lightKey, NSString *darkKey, UIColor *fallback, UIView *view) {
    BOOL effective = isAdvancedTintEnabled() || chatHasPerContactOverride();
    if (!effective) return fallback;
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = view
            ? (view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
            : isDarkMode();
    }
    NSString *key = dark ? darkKey : lightKey;
    UIColor *color = colorFromHex(effectiveValueForKey(key));
    return color ?: fallback;
}

static UIColor *getAdvancedUnreadDotColor() {
    return getAdvancedTintColor(@"advancedUnreadDotColor", @"advancedUnreadDotColorDark", getSystemTintColor());
}

static UIColor *getAdvancedSwitchTintColor() {
    if (chatHasPerContactOverride()) {
        NSString *swKey = isDarkMode() ? @"advancedSwitchTintColorDark" : @"advancedSwitchTintColor";
        id rawSw = getPerContactOverride(gWAMCurrentContactName, swKey);
        if (rawSw) {
            UIColor *c = colorFromHex(rawSw);
            if (c) return c;
        }
        NSString *stKey = isDarkMode() ? @"systemTintColorDark" : @"systemTintColor";
        id rawSt = getPerContactOverride(gWAMCurrentContactName, stKey);
        if (rawSt) {
            UIColor *c = colorFromHex(rawSt);
            if (c) return c;
        }
    }
    return getAdvancedTintColor(@"advancedSwitchTintColor", @"advancedSwitchTintColorDark", getSystemTintColor());
}

static UIColor *getAdvancedSearchFieldColor() {
    return getAdvancedTintColor(@"advancedSearchFieldColor", @"advancedSearchFieldColorDark", getSystemTintColor());
}

static UIColor *getAdvancedStatusCellColor() {
    return getAdvancedTintColor(@"advancedStatusCellColor", @"advancedStatusCellColorDark", getSystemTintColor());
}

static UIColor *getAdvancedTableLabelColor() {
    return getAdvancedTintColor(@"advancedTableLabelColor", @"advancedTableLabelColorDark", getSystemTintColor());
}

static UIColor *getAdvancedReactionGlyphColor() {
    return getChatAdvancedTintColor(@"advancedReactionGlyphColor", @"advancedReactionGlyphColorDark", getSystemTintColor());
}

static UIColor *getGlyphTintColor(void) {
    NSString *key = isDarkMode() ? @"advancedReactionGlyphColorDark" : @"advancedReactionGlyphColor";
    BOOL effective = isAdvancedTintEnabled() || chatHasPerContactOverride();
    id raw = effectiveValueForKey(key);
    if (effective && raw) {
        UIColor *explicit = colorFromHex(raw);
        if (explicit) return explicit;
    }

    UIColor *base = getSystemTintColor();
    if (!base) return [UIColor colorWithWhite:0.85 alpha:1.0];

    CGFloat h, s, b, a;
    if (![base getHue:&h saturation:&s brightness:&b alpha:&a]) return base;
    s *= 0.875;
    b = MIN(1.0, b + 0.15);
    return [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
}

UIBlurEffectStyle getInputFieldBlurStyle() {
    NSString *key = isDarkMode() ? @"inputFieldBlurStyleDark" : @"inputFieldBlurStyle";
    NSString *style = effectiveValueForKey(key) ?: @"regular";
    if ([style isEqualToString:@"light"]) return UIBlurEffectStyleLight;
    if ([style isEqualToString:@"dark"]) return UIBlurEffectStyleDark;
    if ([style isEqualToString:@"ultraThinLight"]) return UIBlurEffectStyleSystemUltraThinMaterialLight;
    if ([style isEqualToString:@"ultraThinDark"]) return UIBlurEffectStyleSystemUltraThinMaterialDark;
    return UIBlurEffectStyleRegular;
}

static BOOL isTextViewSafeForColorWrite(UITextView *tv) {
    if (!tv) return NO;
    NSAttributedString *attr = tv.attributedText;
    if (attr.length == 0) return YES;
    __block BOOL hasAttachment = NO;
    [attr enumerateAttribute:NSAttachmentAttributeName
                     inRange:NSMakeRange(0, attr.length)
                     options:0
                  usingBlock:^(id value, NSRange range, BOOL *stop) {
        if ([value isKindOfClass:[NSTextAttachment class]]) {
            hasAttachment = YES;
            *stop = YES;
        }
    }];
    return !hasAttachment;
}

static void applyInputTextColor(UITextView *tv, UIColor *color) {
    if (!tv || !color) return;

    if (!isTextViewSafeForColorWrite(tv)) return;
    tv.textColor = color;
}

static NSString *getConversationListTitle() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"conversationListTitleTextDark" : @"conversationListTitleText";
    NSString *title = prefs[key];
    return title.length > 0 ? title : @"Messages";
}

UIImage *blurImage(UIImage *image, CGFloat blurAmount) {
    if (blurAmount <= 0) return image;

    CIContext *context = [CIContext contextWithOptions:nil];
    CIImage *inputImage = [CIImage imageWithCGImage:image.CGImage];

    CIFilter *clampFilter = [CIFilter filterWithName:@"CIAffineClamp"];
    [clampFilter setValue:inputImage forKey:kCIInputImageKey];
    CIImage *clampedImage = [clampFilter outputImage];

    CIFilter *blurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
    [blurFilter setValue:clampedImage forKey:kCIInputImageKey];
    [blurFilter setValue:@(blurAmount) forKey:kCIInputRadiusKey];

    CIImage *outputImage = [blurFilter outputImage];
    CGRect extent = [inputImage extent];
    CGImageRef cgImage = [context createCGImage:outputImage fromRect:extent];

    if (!cgImage) return image;

    UIImage *blurredImage = [UIImage imageWithCGImage:cgImage scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(cgImage);
    return blurredImage;
}

static UIImage *_cachedBlurredConvImage = nil;
static NSTimeInterval _cachedBlurredConvImageTime = 0;
static BOOL _cachedBlurredConvImageWasDark = NO;

static UIImage *getBlurredConvImage() {
    BOOL currentlyDark = isDarkMode();
    NSTimeInterval now = [[NSDate date] timeIntervalSinceReferenceDate];
    if (!_cachedBlurredConvImage 
        || (now - _cachedBlurredConvImageTime) > 2.0
        || _cachedBlurredConvImageWasDark != currentlyDark) {
        UIImage *raw = loadImageUncached(getConvImagePath());
        CGFloat blur = getImageBlurAmount();
        _cachedBlurredConvImage = (raw && blur > 0) ? blurImage(raw, blur) : raw;
        _cachedBlurredConvImageTime = now;
        _cachedBlurredConvImageWasDark = currentlyDark;
    }
    return _cachedBlurredConvImage;
}

static void invalidateConvImageCache() {
    _cachedBlurredConvImage = nil;
    _cachedBlurredConvImageTime = 0;
    _cachedBlurredConvImageWasDark = NO;
}

void applyCustomTextColors(UIView *view) {
    BOOL enabled = isCustomTextColorsEnabled();

    if ([view isKindOfClass:%c(CKLabel)]) {
        UILabel *label = (UILabel *)view;
        UIColor *custom = enabled ? getTitleTextColorConvList() : nil;
        if (custom) {
            if (!objc_getAssociatedObject(label, &kWAMOrigTitleColorKey)) {
                objc_setAssociatedObject(label, &kWAMOrigTitleColorKey, label.textColor ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            label.textColor = custom;
        } else {
            id orig = objc_getAssociatedObject(label, &kWAMOrigTitleColorKey);
            if (orig && orig != [NSNull null]) label.textColor = orig;
        }
    } else if ([view isKindOfClass:%c(CKDateLabel)] || [view isKindOfClass:%c(UIDateLabel)]) {
        UILabel *label = (UILabel *)view;
        UIColor *custom = enabled ? getDateTimeTextColor() : nil;
        if (custom) {
            if (!objc_getAssociatedObject(label, &kWAMOrigDateColorKey)) {
                objc_setAssociatedObject(label, &kWAMOrigDateColorKey, label.textColor ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            label.textColor = custom;
        } else {
            id orig = objc_getAssociatedObject(label, &kWAMOrigDateColorKey);
            if (orig && orig != [NSNull null]) label.textColor = orig;
        }
    } else if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        UIColor *custom = enabled ? getMessagePreviewTextColor() : nil;
        if (custom) {
            if (!objc_getAssociatedObject(label, &kWAMOrigPreviewColorKey)) {
                objc_setAssociatedObject(label, &kWAMOrigPreviewColorKey, label.textColor ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            label.textColor = custom;
        } else {
            id orig = objc_getAssociatedObject(label, &kWAMOrigPreviewColorKey);
            if (orig && orig != [NSNull null]) label.textColor = orig;
        }
    } else if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        if (imageView.image.renderingMode == UIImageRenderingModeAlwaysTemplate ||
            imageView.image.renderingMode == UIImageRenderingModeAutomatic) {
            UIColor *custom = enabled ? getDateTimeTextColor() : nil;
            if (custom) {
                if (!objc_getAssociatedObject(imageView, &kWAMOrigTintColorKey)) {
                    objc_setAssociatedObject(imageView, &kWAMOrigTintColorKey, imageView.tintColor ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
                imageView.tintColor = custom;
            } else {
                id orig = objc_getAssociatedObject(imageView, &kWAMOrigTintColorKey);
                if (orig && orig != [NSNull null]) imageView.tintColor = orig;
            }
        }
    }

    for (UIView *subview in view.subviews) {
        applyCustomTextColors(subview);
    }
}

static UIColor *getSMSSentBubbleColor() {
    NSString *key = isDarkMode() ? @"sentSMSBubbleColorDark" : @"sentSMSBubbleColor";
    return colorFromHex(effectiveValueForKey(key)) ?: [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
}

static UIColor *getSentBubbleColor() {
    NSString *key = isDarkMode() ? @"sentBubbleColorDark" : @"sentBubbleColor";
    return colorFromHex(effectiveValueForKey(key)) ?: [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
}

static UIColor *getReceivedBubbleColor() {
    NSString *key = isDarkMode() ? @"receivedBubbleColorDark" : @"receivedBubbleColor";
    return colorFromHex(effectiveValueForKey(key)) ?: [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
}

static UIColor *getReceivedTextColor() {
    NSString *key = isDarkMode() ? @"receivedTextColorDark" : @"receivedTextColor";
    return colorFromHex(effectiveValueForKey(key));
}

static UIColor *getSentTextColor() {
    NSString *key = isDarkMode() ? @"sentTextColorDark" : @"sentTextColor";
    return colorFromHex(effectiveValueForKey(key));
}

static UIColor *getSMSSentTextColor() {
    NSString *key = isDarkMode() ? @"sentSMSTextColorDark" : @"sentSMSTextColor";
    return colorFromHex(effectiveValueForKey(key));
}

static UIColor *pickTimestampTextColor() {
    NSString *key = isDarkMode() ? @"timestampTextColorDark" : @"timestampTextColor";
    return colorFromHex(effectiveValueForKey(key));
}

static UIColor *getSystemTintColor() {
    NSString *key = isDarkMode() ? @"systemTintColorDark" : @"systemTintColor";
    return colorFromHex(effectiveValueForKey(key));
}

static UIColor *getPlaceholderTextColor() {
    NSString *key = isDarkMode() ? @"placeholderTextColorDark" : @"placeholderTextColor";
    return colorFromHex(effectiveValueForKey(key)) ?: [UIColor grayColor];
}

static NSString *getPlaceholderText() {
    NSString *key = isDarkMode() ? @"placeholderTextDark" : @"placeholderText";
    NSString *text = effectiveValueForKey(key);
    return text.length > 0 ? text : nil;
}

static UIColor *getMessageInputTextColor() {
    NSString *key = isDarkMode() ? @"messageInputTextColorDark" : @"messageInputTextColor";
    return colorFromHex(effectiveValueForKey(key)) ?: [UIColor whiteColor];
}

static UIColor *getMessageBarButtonColor() {
    NSString *key = isDarkMode() ? @"messageBarButtonColorDark" : @"messageBarButtonColor";
    return colorFromHex(effectiveValueForKey(key));
}

static UIColor *getLinkPreviewBackgroundColor() {
    NSString *key = isDarkMode() ? @"linkPreviewBackgroundColorDark" : @"linkPreviewBackgroundColor";
    return colorFromHex(effectiveValueForKey(key)) ?: [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
}

static UIColor *getLinkPreviewTextColor() {
    NSString *key = isDarkMode() ? @"linkPreviewTextColorDark" : @"linkPreviewTextColor";
    return colorFromHex(effectiveValueForKey(key)) ?: [UIColor whiteColor];
}

static UIColor *getPinnedBubbleColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"pinnedBubbleColorDark" : @"pinnedBubbleColor";
    NSString *hexColor = prefs[key];
    if (hexColor.length) return colorFromHex(hexColor);
    NSString *recvKey = isDarkMode() ? @"receivedBubbleColorDark" : @"receivedBubbleColor";
    UIColor *c = colorFromHex(prefs[recvKey]);
    if (c) return c;
    return [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
}

static UIColor *getPinnedBubbleTextColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"pinnedBubbleTextColorDark" : @"pinnedBubbleTextColor";
    NSString *hexColor = prefs[key];
    if (hexColor.length) return colorFromHex(hexColor);
    NSString *recvKey = isDarkMode() ? @"receivedTextColorDark" : @"receivedTextColor";
    return colorFromHex(prefs[recvKey]);
}

static UIColor *getNavBarTintColor() {
    NSString *key = isDarkMode() ? @"navBarTintColorDark" : @"navBarTintColor";
    return colorFromHex(effectiveValueForKey(key)) ?: getSystemTintColor();
}

static UIColor *getNavBarTintColorForView(UIView *view) {
    if (wamNavBarShouldUseGlobals(view)) {
        NSDictionary *prefs = loadPrefs();
        NSString *key = isDarkMode() ? @"navBarTintColorDark" : @"navBarTintColor";
        UIColor *c = colorFromHex(prefs[key]);
        if (c) return c;
        NSString *sysKey = isDarkMode() ? @"systemTintColorDark" : @"systemTintColor";
        return colorFromHex(prefs[sysKey]);
    }
    return getNavBarTintColor();
}

static UIColor *getMessageBarTintColor() {
    NSString *key = isDarkMode() ? @"messageBarTintColorDark" : @"messageBarTintColor";
    return colorFromHex(effectiveValueForKey(key)) ?: getSystemTintColor();
}

static UIColor *getCellBlurTintColor() {
    NSString *key = isDarkMode() ? @"cellTintColorDark" : @"cellTintColor";
    return colorFromHex(effectiveValueForKey(key)) ?: getSystemTintColor();
}

static UIColor *getSendArrowColor() {
    NSString *key = isDarkMode() ? @"sendButtonArrowColorDark" : @"sendButtonArrowColor";
    return colorFromHex(effectiveValueForKey(key)) ?: [UIColor whiteColor];
}

static UIColor *getSendButtonColor() {
    NSString *key = isDarkMode() ? @"sendButtonColorDark" : @"sendButtonColor";
    return colorFromHex(effectiveValueForKey(key)) ?: [UIColor systemBlueColor];
}

/*=======================
    Changelog Splash
=======================*/

static BOOL shouldShowChangelog(void) {
    NSDictionary *prefs = loadPrefs();
    NSString *lastSeen = prefs[@"lastSeenChangelogVersion"];
    return !lastSeen || ![lastSeen isEqualToString:kWAMTweakVersion];
}

static void markChangelogSeen(void) {
    NSString *path = kPrefsPlistPathRootless;
    NSString *dir = [path stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    if (!prefs) prefs = [NSMutableDictionary new];
    prefs[@"lastSeenChangelogVersion"] = kWAMTweakVersion;
    [prefs writeToFile:path atomically:YES];
    refreshPrefs();
}

@interface WAMGradientView : UIView
@end
@implementation WAMGradientView
+ (Class)layerClass { return [CAGradientLayer class]; }
@end

static UIImage *wamCheckerboardImage(void) {
    static UIImage *img = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        UIGraphicsBeginImageContextWithOptions(CGSizeMake(8, 8), YES, 0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.85 alpha:1.0].CGColor);
        CGContextFillRect(ctx, CGRectMake(0, 0, 8, 8));
        CGContextSetFillColorWithColor(ctx, [UIColor colorWithWhite:0.62 alpha:1.0].CGColor);
        CGContextFillRect(ctx, CGRectMake(0, 0, 4, 4));
        CGContextFillRect(ctx, CGRectMake(4, 4, 4, 4));
        img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    });
    return img;
}

static const void *kWAMSwitchOwnsTintKey = &kWAMSwitchOwnsTintKey;

static BOOL wamSwitchOwnsItsTint(UISwitch *sw) {
    return [(NSNumber *)objc_getAssociatedObject(sw, kWAMSwitchOwnsTintKey) boolValue];
}

static void wamMarkSwitchOwnsTint(UISwitch *sw) {
    objc_setAssociatedObject(sw, kWAMSwitchOwnsTintKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static UIColor *contrastingColorForBackground(UIColor *bg) {
    if (!bg) return [UIColor whiteColor];
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (![bg getRed:&r green:&g blue:&b alpha:&a]) return [UIColor whiteColor];
    CGFloat luma = 0.299 * r + 0.587 * g + 0.114 * b;
    return (luma > 0.82) ? [UIColor blackColor] : [UIColor whiteColor];
}

static UIColor *lightenedTint(UIColor *c, CGFloat amount) {
    if (!c) return c;
    CGFloat h = 0, s = 0, b = 0, a = 0;
    if (![c getHue:&h saturation:&s brightness:&b alpha:&a]) return c;
    return [UIColor colorWithHue:h
                      saturation:MAX(0, s - amount * 0.45)
                      brightness:MIN(1.0, b + amount)
                           alpha:a];
}

@interface WAMPerContactSettings : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIColorPickerViewControllerDelegate>
@property (nonatomic, copy) NSString *contactName;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) void (^onChanged)(void);
@end

@implementation WAMPerContactSettings {
    BOOL _editingDarkMode;
    NSInteger _selectedTab;

    UILabel *_titleLabel;
    UILabel *_subtitleLabel;
    UISegmentedControl *_modeSeg;
    UISegmentedControl *_tabSeg;
    UIScrollView *_scroll;
    UIView *_tabContent;

    UIView *_masterCard;
    UISwitch *_masterSwitch;
    UILabel *_masterTitleLabel;
    UILabel *_masterCaption;
    UIImageView *_masterIcon;
    CAGradientLayer *_masterGradient;

    UIView *_bgPreviewContainer;
    UIImageView *_bgPreview;
    UILabel *_bgPlaceholder;
    UILabel *_bgBlurLabel;
    UILabel *_bgBlurValueLabel;
    UISlider *_bgBlurSlider;
    UIButton *_bgChooseButton;
    UIButton *_bgRemoveButton;
    UIImage *_bgCurrentImage;
    UIImage *_bgPreviewSource;
}

+ (UIFont *)wamRoundedFontOfSize:(CGFloat)size weight:(UIFontWeight)weight {
    UIFont *base = [UIFont systemFontOfSize:size weight:weight];
    UIFontDescriptor *rounded = [base.fontDescriptor fontDescriptorWithDesign:UIFontDescriptorSystemDesignRounded];
    return rounded ? [UIFont fontWithDescriptor:rounded size:size] : base;
}

+ (NSString *)wamTabNameForIndex:(NSInteger)idx {
    switch (idx) {
        case 0: return @"Background";
        case 1: return @"Bubbles";
        case 2: return @"Message Bar";
        case 3: return @"Misc";
    }
    return @"";
}

+ (NSString *)wamTabSymbolForIndex:(NSInteger)idx {
    switch (idx) {
        case 0: return @"photo.fill";
        case 1: return @"bubble.left.and.bubble.right.fill";
        case 2: return @"keyboard.fill";
        case 3: return @"sparkles";
    }
    return @"square";
}

+ (UIColor *)wamTabTintForIndex:(NSInteger)idx {
    switch (idx) {
        case 0: return [UIColor systemBlueColor];
        case 1: return [UIColor systemPinkColor];
        case 2: return [UIColor systemTealColor];
        case 3: return [UIColor systemYellowColor];
    }
    return [UIColor labelColor];
}

+ (UIImage *)wamBakedSymbol:(NSString *)name pointSize:(CGFloat)pt weight:(UIImageSymbolWeight)weight tint:(UIColor *)tint {
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:pt weight:weight];
    UIImage *raw = [UIImage systemImageNamed:name withConfiguration:cfg];
    if (!raw) return nil;
    return [raw imageWithTintColor:tint renderingMode:UIImageRenderingModeAlwaysOriginal];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemGroupedBackgroundColor];

    _editingDarkMode = isDarkMode();
    _selectedTab = 0;

    _titleLabel = [UILabel new];
    NSString *titleSource = self.displayName.length ? self.displayName : self.contactName;
    BOOL looksLikeRawID = [titleSource hasPrefix:@"iMessage;"]
                      || [titleSource hasPrefix:@"SMS;"]
                      || [titleSource hasPrefix:@"chat"]
                      || [titleSource hasPrefix:@"+"]
                      || [titleSource containsString:@";+;chat"];
    _titleLabel.text = (titleSource.length && !looksLikeRawID)
        ? [NSString stringWithFormat:@"%@'s Chat", titleSource]
        : @"This Chat";
    _titleLabel.font = [WAMPerContactSettings wamRoundedFontOfSize:24 weight:UIFontWeightHeavy];
    _titleLabel.textAlignment = NSTextAlignmentCenter;
    _titleLabel.adjustsFontSizeToFitWidth = YES;
    _titleLabel.minimumScaleFactor = 0.7;
    _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_titleLabel];

    _subtitleLabel = [UILabel new];
    _subtitleLabel.text = [WAMPerContactSettings wamTabNameForIndex:_selectedTab];
    _subtitleLabel.font = [WAMPerContactSettings wamRoundedFontOfSize:13 weight:UIFontWeightSemibold];
    _subtitleLabel.textColor = [UIColor tertiaryLabelColor];
    _subtitleLabel.textAlignment = NSTextAlignmentCenter;
    _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_subtitleLabel];

    UIButton *done = [UIButton buttonWithType:UIButtonTypeSystem];
    [done setTitle:@"Done" forState:UIControlStateNormal];
    done.titleLabel.font = [WAMPerContactSettings wamRoundedFontOfSize:17 weight:UIFontWeightSemibold];
    [done setTitleColor:[WAMPerContactSettings wamDoneAccent] forState:UIControlStateNormal];
    done.tintColor = [WAMPerContactSettings wamDoneAccent];
    [done addTarget:self action:@selector(doneTapped) forControlEvents:UIControlEventTouchUpInside];
    done.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:done];

    UIButton *trash = [UIButton buttonWithType:UIButtonTypeSystem];
    UIImage *trashIcon = [WAMPerContactSettings wamBakedSymbol:@"trash"
                                                     pointSize:19
                                                        weight:UIImageSymbolWeightSemibold
                                                          tint:[UIColor systemRedColor]];
    [trash setImage:trashIcon forState:UIControlStateNormal];
    [trash addTarget:self action:@selector(wamResetTapped) forControlEvents:UIControlEventTouchUpInside];
    trash.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:trash];

    UIImage *sun  = [WAMPerContactSettings wamBakedSymbol:@"sun.max.fill" pointSize:14 weight:UIImageSymbolWeightSemibold tint:[UIColor systemOrangeColor]];
    UIImage *moon = [WAMPerContactSettings wamBakedSymbol:@"moon.fill"    pointSize:14 weight:UIImageSymbolWeightSemibold tint:[UIColor systemIndigoColor]];
    _modeSeg = [[UISegmentedControl alloc] initWithItems:@[sun ?: (id)@"Light", moon ?: (id)@"Dark"]];
    _modeSeg.selectedSegmentIndex = _editingDarkMode ? 1 : 0;
    [_modeSeg addTarget:self action:@selector(modeChanged) forControlEvents:UIControlEventValueChanged];
    _modeSeg.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_modeSeg];

    NSMutableArray *tabItems = [NSMutableArray new];
    for (NSInteger i = 0; i < 4; i++) {
        UIImage *img = [WAMPerContactSettings wamBakedSymbol:[WAMPerContactSettings wamTabSymbolForIndex:i]
                                                   pointSize:14
                                                      weight:UIImageSymbolWeightSemibold
                                                        tint:[WAMPerContactSettings wamTabTintForIndex:i]];
        [tabItems addObject:img ?: (id)[WAMPerContactSettings wamTabNameForIndex:i]];
    }
    _tabSeg = [[UISegmentedControl alloc] initWithItems:tabItems];
    _tabSeg.selectedSegmentIndex = 0;
    [_tabSeg addTarget:self action:@selector(tabChanged) forControlEvents:UIControlEventValueChanged];
    _tabSeg.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_tabSeg];

    _masterCard = [UIView new];
    _masterCard.layer.cornerRadius = 18;
    if (@available(iOS 13.0, *)) _masterCard.layer.cornerCurve = kCACornerCurveContinuous;
    _masterCard.clipsToBounds = NO;
    _masterCard.layer.shadowColor = [UIColor blackColor].CGColor;
    _masterCard.layer.shadowOpacity = 0.10;
    _masterCard.layer.shadowOffset = CGSizeMake(0, 3);
    _masterCard.layer.shadowRadius = 10;
    _masterCard.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_masterCard];

    _masterGradient = [CAGradientLayer layer];
    _masterGradient.startPoint = CGPointMake(0, 0);
    _masterGradient.endPoint = CGPointMake(1, 1);
    _masterGradient.cornerRadius = 18;
    if (@available(iOS 13.0, *)) _masterGradient.cornerCurve = kCACornerCurveContinuous;
    [_masterCard.layer insertSublayer:_masterGradient atIndex:0];

    _masterIcon = [UIImageView new];
    _masterIcon.translatesAutoresizingMaskIntoConstraints = NO;
    [_masterCard addSubview:_masterIcon];

    _masterTitleLabel = [UILabel new];
    _masterTitleLabel.text = @"Customize This Chat";
    _masterTitleLabel.font = [WAMPerContactSettings wamRoundedFontOfSize:15 weight:UIFontWeightSemibold];
    _masterTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [_masterCard addSubview:_masterTitleLabel];

    _masterCaption = [UILabel new];
    _masterCaption.font = [WAMPerContactSettings wamRoundedFontOfSize:11 weight:UIFontWeightMedium];
    _masterCaption.numberOfLines = 1;
    _masterCaption.translatesAutoresizingMaskIntoConstraints = NO;
    [_masterCard addSubview:_masterCaption];

    _masterSwitch = [UISwitch new];
    wamMarkSwitchOwnsTint(_masterSwitch);
    _masterSwitch.onTintColor = [WAMPerContactSettings wamMasterSwitchTrack];
    _masterSwitch.thumbTintColor = [UIColor whiteColor];
    _masterSwitch.on = perContactOverridesEnabled(self.contactName);
    [_masterSwitch addTarget:self action:@selector(wamMasterToggled:) forControlEvents:UIControlEventValueChanged];
    _masterSwitch.translatesAutoresizingMaskIntoConstraints = NO;
    [_masterCard addSubview:_masterSwitch];

    _scroll = [UIScrollView new];
    _scroll.alwaysBounceVertical = YES;
    _scroll.showsVerticalScrollIndicator = NO;
    _scroll.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    _scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:_scroll];

    UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
    [NSLayoutConstraint activateConstraints:@[
        [trash.centerYAnchor constraintEqualToAnchor:_titleLabel.centerYAnchor],
        [trash.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [trash.widthAnchor constraintEqualToConstant:36],
        [trash.heightAnchor constraintEqualToConstant:36],

        [_titleLabel.topAnchor constraintEqualToAnchor:safe.topAnchor constant:16],
        [_titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:72],
        [_titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-72],

        [_subtitleLabel.topAnchor constraintEqualToAnchor:_titleLabel.bottomAnchor constant:2],
        [_subtitleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [_subtitleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],

        [done.centerYAnchor constraintEqualToAnchor:_titleLabel.centerYAnchor],
        [done.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],

        [_modeSeg.topAnchor constraintEqualToAnchor:_subtitleLabel.bottomAnchor constant:14],
        [_modeSeg.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [_modeSeg.widthAnchor constraintEqualToConstant:140],
        [_modeSeg.heightAnchor constraintEqualToConstant:32],

        [_tabSeg.topAnchor constraintEqualToAnchor:_modeSeg.bottomAnchor constant:10],
        [_tabSeg.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:20],
        [_tabSeg.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-20],
        [_tabSeg.heightAnchor constraintEqualToConstant:36],

        [_masterCard.topAnchor constraintEqualToAnchor:_tabSeg.bottomAnchor constant:12],
        [_masterCard.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18],
        [_masterCard.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18],
        [_masterCard.heightAnchor constraintEqualToConstant:58],

        [_masterIcon.leadingAnchor constraintEqualToAnchor:_masterCard.leadingAnchor constant:14],
        [_masterIcon.centerYAnchor constraintEqualToAnchor:_masterCard.centerYAnchor],
        [_masterIcon.widthAnchor constraintEqualToConstant:22],
        [_masterIcon.heightAnchor constraintEqualToConstant:22],

        [_masterTitleLabel.leadingAnchor constraintEqualToAnchor:_masterIcon.trailingAnchor constant:10],
        [_masterTitleLabel.topAnchor constraintEqualToAnchor:_masterCard.topAnchor constant:10],
        [_masterTitleLabel.trailingAnchor constraintEqualToAnchor:_masterSwitch.leadingAnchor constant:-10],

        [_masterCaption.leadingAnchor constraintEqualToAnchor:_masterIcon.trailingAnchor constant:10],
        [_masterCaption.topAnchor constraintEqualToAnchor:_masterTitleLabel.bottomAnchor constant:0],
        [_masterCaption.trailingAnchor constraintEqualToAnchor:_masterSwitch.leadingAnchor constant:-10],

        [_masterSwitch.trailingAnchor constraintEqualToAnchor:_masterCard.trailingAnchor constant:-16],
        [_masterSwitch.centerYAnchor constraintEqualToAnchor:_masterCard.centerYAnchor],

        [_scroll.topAnchor constraintEqualToAnchor:_masterCard.bottomAnchor constant:12],
        [_scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [_scroll.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
    ]];

    [self wamRefreshMasterAppearance];
    [self loadTab];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(wamPrefsChangedExternally:)
                                                 name:kPrefsChangedNotification
                                               object:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    _masterGradient.frame = _masterCard.bounds;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
            [self wamRefreshMasterAppearance];
            [self loadTab];
        }
    }
}

+ (UIColor *)wamMasterAccent {
    return [UIColor colorWithRed:0.25 green:0.66 blue:0.56 alpha:1.0]; 
}

+ (UIColor *)wamMasterSwitchTrack {
    return [UIColor colorWithRed:0.66 green:0.88 blue:0.80 alpha:1.0];
}

+ (UIColor *)wamChooseAccent {
    return [UIColor colorWithRed:0.24 green:0.39 blue:1.00 alpha:1.0]; 
}

+ (UIColor *)wamRemoveAccent {
    return [UIColor colorWithRed:0.95 green:0.32 blue:0.36 alpha:1.0];
}

+ (UIColor *)wamDoneAccent {
    return [UIColor colorWithRed:0.25 green:0.66 blue:0.56 alpha:1.0];
}

+ (UIColor *)wamBlurSliderAccent {
    return [UIColor systemPurpleColor];
}

- (void)wamRefreshMasterAppearance {
    BOOL on = _masterSwitch.on;
    UIColor *base, *light;
    if (on) {
        base = [WAMPerContactSettings wamMasterAccent];
        light = lightenedTint(base, 0.20);
    } else {
        base = [UIColor colorWithRed:0.40 green:0.42 blue:0.46 alpha:1.0];
        light = [UIColor colorWithRed:0.58 green:0.60 blue:0.64 alpha:1.0];
    }
    _masterGradient.colors = @[(id)light.CGColor, (id)base.CGColor];

    UIColor *fg = contrastingColorForBackground(base);
    _masterTitleLabel.textColor = fg;
    _masterCaption.textColor = [fg colorWithAlphaComponent:0.85];
    _masterIcon.image = [WAMPerContactSettings wamBakedSymbol:@"person.crop.circle.badge.checkmark"
                                                    pointSize:18
                                                       weight:UIImageSymbolWeightSemibold
                                                         tint:fg];
    _masterCaption.text = on
        ? @"Settings below apply to this chat only."
        : @"Toggle on to give this chat its own settings.";
}

- (void)wamApplyGradientBackgroundToButton:(UIButton *)btn baseColor:(UIColor *)base {
    for (UIView *sub in [btn.subviews copy]) {
        if ([sub isKindOfClass:[WAMGradientView class]]) [sub removeFromSuperview];
    }
    btn.backgroundColor = [UIColor clearColor];
    btn.layer.cornerRadius = 16;
    if (@available(iOS 13.0, *)) btn.layer.cornerCurve = kCACornerCurveContinuous;
    btn.clipsToBounds = NO;
    btn.layer.shadowColor = base.CGColor;
    btn.layer.shadowOpacity = 0.22;
    btn.layer.shadowOffset = CGSizeMake(0, 4);
    btn.layer.shadowRadius = 10;

    WAMGradientView *bg = [WAMGradientView new];
    bg.userInteractionEnabled = NO;
    bg.layer.cornerRadius = 16;
    if (@available(iOS 13.0, *)) bg.layer.cornerCurve = kCACornerCurveContinuous;
    bg.layer.masksToBounds = YES;
    bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    bg.frame = btn.bounds;
    CAGradientLayer *gl = (CAGradientLayer *)bg.layer;
    UIColor *light = lightenedTint(base, 0.20);
    gl.colors = @[(id)light.CGColor, (id)base.CGColor];
    gl.startPoint = CGPointMake(0, 0);
    gl.endPoint = CGPointMake(1, 1);
    [btn insertSubview:bg atIndex:0];

    UIColor *fg = contrastingColorForBackground(base);
    [btn setTitleColor:fg forState:UIControlStateNormal];
    [btn setTitleColor:[fg colorWithAlphaComponent:0.6] forState:UIControlStateDisabled];
}

- (void)wamPrefsChangedExternally:(NSNotification *)note {
    [self wamRefreshMasterAppearance];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)wamMasterToggled:(UISwitch *)sender {
    setPerContactOverridesEnabled(self.contactName, sender.on);
    [self wamRefreshMasterAppearance];
    if (self.onChanged) self.onChanged();
    [self loadTab];
}

- (void)wamResetTapped {
    if (!self.contactName.length) return;
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Reset This Chat"
        message:[NSString stringWithFormat:@"Remove all custom settings for %@? This deletes both backgrounds, blur values, and every override. This can't be undone.", self.contactName]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    __weak typeof(self) weakSelf = self;
    [alert addAction:[UIAlertAction actionWithTitle:@"Reset" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *a) {
        [weakSelf wamPerformReset];
    }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)wamPerformReset {
    NSString *name = self.contactName;
    if (!name.length) return;
    NSString *safe = sanitizeContactName(name);

    NSString *path = kPrefsPlistPathRootless;
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:path] ?: [NSMutableDictionary new];

    NSMutableDictionary *all = [(NSDictionary *)prefs[@"perContactOverrides"] mutableCopy];
    if (safe.length && all) {
        [all removeObjectForKey:safe];
        if (all.count) prefs[@"perContactOverrides"] = all; else [prefs removeObjectForKey:@"perContactOverrides"];
    }
    NSMutableDictionary *blurMap = [(NSDictionary *)prefs[@"perContactBlur"] mutableCopy];
    if (safe.length && blurMap) {
        [blurMap removeObjectForKey:safe];
        if (blurMap.count) prefs[@"perContactBlur"] = blurMap; else [prefs removeObjectForKey:@"perContactBlur"];
    }
    [prefs writeToFile:path atomically:YES];
    refreshPrefs();

    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:getPerContactImagePath(name, NO) error:nil];
    [fm removeItemAtPath:getPerContactImagePath(name, YES) error:nil];

    _masterSwitch.on = NO;
    [self wamRefreshMasterAppearance];
    if (self.onChanged) self.onChanged();
    [self loadTab];
}

- (void)modeChanged {
    _editingDarkMode = (_modeSeg.selectedSegmentIndex == 1);
    [self loadTab];
}

- (void)tabChanged {
    _selectedTab = _tabSeg.selectedSegmentIndex;
    [self loadTab];
}

- (void)loadTab {
    _subtitleLabel.text = [WAMPerContactSettings wamTabNameForIndex:_selectedTab];

    UIView *old = _tabContent;
    UIView *content = nil;
    if (_selectedTab == 0)      content = [self buildBackgroundTab];
    else if (_selectedTab == 1) content = [self buildBubblesTab];
    else if (_selectedTab == 2) content = [self buildMessageBarTab];
    else                        content = [self buildMiscTab];
    content.translatesAutoresizingMaskIntoConstraints = NO;
    content.alpha = 0;
    [_scroll addSubview:content];
    [NSLayoutConstraint activateConstraints:@[
        [content.topAnchor constraintEqualToAnchor:_scroll.topAnchor],
        [content.bottomAnchor constraintEqualToAnchor:_scroll.bottomAnchor],
        [content.leadingAnchor constraintEqualToAnchor:_scroll.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:_scroll.trailingAnchor],
        [content.widthAnchor constraintEqualToAnchor:_scroll.widthAnchor],
    ]];
    _tabContent = content;

    [UIView animateWithDuration:0.18 animations:^{
        content.alpha = 1.0;
        old.alpha = 0.0;
    } completion:^(BOOL fin) {
        [old removeFromSuperview];
    }];
}

- (UIView *)buildPlaceholderTabWithTitle:(NSString *)t {
    UIView *root = [UIView new];
    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightLight];
    NSString *sym = (_selectedTab == 2) ? @"keyboard.fill" : @"sparkles";
    UIImageView *icon = [[UIImageView alloc] initWithImage:[UIImage systemImageNamed:sym withConfiguration:cfg]];
    icon.tintColor = [UIColor quaternaryLabelColor];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:icon];
    UILabel *l = [UILabel new];
    l.text = [NSString stringWithFormat:@"%@\nComing next.", t];
    l.numberOfLines = 0;
    l.textAlignment = NSTextAlignmentCenter;
    l.textColor = [UIColor tertiaryLabelColor];
    l.font = [WAMPerContactSettings wamRoundedFontOfSize:15 weight:UIFontWeightMedium];
    l.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:l];
    [NSLayoutConstraint activateConstraints:@[
        [icon.topAnchor constraintEqualToAnchor:root.topAnchor constant:80],
        [icon.centerXAnchor constraintEqualToAnchor:root.centerXAnchor],
        [l.topAnchor constraintEqualToAnchor:icon.bottomAnchor constant:16],
        [l.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:20],
        [l.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-20],
        [l.bottomAnchor constraintLessThanOrEqualToAnchor:root.bottomAnchor constant:-20],
        [root.heightAnchor constraintGreaterThanOrEqualToConstant:280],
    ]];
    return root;
}

- (UIView *)wamMakeCard {
    UIView *card = [UIView new];
    card.backgroundColor = [UIColor secondarySystemGroupedBackgroundColor];
    card.layer.cornerRadius = 20;
    if (@available(iOS 13.0, *)) card.layer.cornerCurve = kCACornerCurveContinuous;
    card.clipsToBounds = NO;
    card.layer.shadowColor = [UIColor blackColor].CGColor;
    card.layer.shadowOpacity = 0.06;
    card.layer.shadowOffset = CGSizeMake(0, 2);
    card.layer.shadowRadius = 10;
    card.translatesAutoresizingMaskIntoConstraints = NO;
    return card;
}

- (UIView *)wamMakeSectionHeader:(NSString *)title symbol:(NSString *)symbol tint:(UIColor *)tint {
    UIView *wrap = [UIView new];
    wrap.translatesAutoresizingMaskIntoConstraints = NO;

    UIImageSymbolConfiguration *cfg = [UIImageSymbolConfiguration configurationWithPointSize:11 weight:UIImageSymbolWeightBold];
    UIImage *raw = [UIImage systemImageNamed:symbol withConfiguration:cfg];
    UIImage *colored = [raw imageWithTintColor:tint renderingMode:UIImageRenderingModeAlwaysOriginal];
    UIImageView *icon = [[UIImageView alloc] initWithImage:colored];
    icon.translatesAutoresizingMaskIntoConstraints = NO;
    [wrap addSubview:icon];

    UILabel *l = [UILabel new];
    l.text = [title uppercaseString];
    l.font = [WAMPerContactSettings wamRoundedFontOfSize:12 weight:UIFontWeightHeavy];
    l.textColor = tint;
    l.translatesAutoresizingMaskIntoConstraints = NO;
    [wrap addSubview:l];

    [NSLayoutConstraint activateConstraints:@[
        [icon.leadingAnchor constraintEqualToAnchor:wrap.leadingAnchor],
        [icon.centerYAnchor constraintEqualToAnchor:wrap.centerYAnchor],
        [icon.widthAnchor constraintEqualToConstant:14],
        [icon.heightAnchor constraintEqualToConstant:14],
        [l.leadingAnchor constraintEqualToAnchor:icon.trailingAnchor constant:6],
        [l.centerYAnchor constraintEqualToAnchor:wrap.centerYAnchor],
        [l.trailingAnchor constraintEqualToAnchor:wrap.trailingAnchor],
        [l.topAnchor constraintEqualToAnchor:wrap.topAnchor],
        [l.bottomAnchor constraintEqualToAnchor:wrap.bottomAnchor],
    ]];
    return wrap;
}

- (UIView *)wamMakeSeparator {
    UIView *s = [UIView new];
    s.backgroundColor = [UIColor separatorColor];
    s.translatesAutoresizingMaskIntoConstraints = NO;
    [s.heightAnchor constraintEqualToConstant:0.5].active = YES;
    return s;
}

- (UIView *)buildBackgroundTab {
    UIView *root = [UIView new];

    UIView *previewHeader = [self wamMakeSectionHeader:@"Preview" symbol:@"photo" tint:[UIColor systemBlueColor]];
    [root addSubview:previewHeader];

    UIView *previewCard = [self wamMakeCard];
    [root addSubview:previewCard];

    _bgPreviewContainer = [UIView new];
    _bgPreviewContainer.backgroundColor = [UIColor tertiarySystemGroupedBackgroundColor];
    _bgPreviewContainer.layer.cornerRadius = 14;
    if (@available(iOS 13.0, *)) _bgPreviewContainer.layer.cornerCurve = kCACornerCurveContinuous;
    _bgPreviewContainer.clipsToBounds = YES;
    _bgPreviewContainer.translatesAutoresizingMaskIntoConstraints = NO;
    [previewCard addSubview:_bgPreviewContainer];

    _bgPreview = [UIImageView new];
    _bgPreview.contentMode = UIViewContentModeScaleAspectFill;
    _bgPreview.clipsToBounds = YES;
    _bgPreview.translatesAutoresizingMaskIntoConstraints = NO;
    [_bgPreviewContainer addSubview:_bgPreview];

    _bgPlaceholder = [UILabel new];
    _bgPlaceholder.text = @"No background set";
    _bgPlaceholder.font = [WAMPerContactSettings wamRoundedFontOfSize:15 weight:UIFontWeightMedium];
    _bgPlaceholder.textColor = [UIColor tertiaryLabelColor];
    _bgPlaceholder.translatesAutoresizingMaskIntoConstraints = NO;
    [_bgPreviewContainer addSubview:_bgPlaceholder];

    UIView *blurHeader = [self wamMakeSectionHeader:@"Blur" symbol:@"camera.filters" tint:[UIColor systemPurpleColor]];
    [root addSubview:blurHeader];

    UIView *blurCard = [self wamMakeCard];
    [root addSubview:blurCard];

    _bgBlurLabel = [UILabel new];
    _bgBlurLabel.text = @"Amount";
    _bgBlurLabel.font = [WAMPerContactSettings wamRoundedFontOfSize:15 weight:UIFontWeightMedium];
    _bgBlurLabel.textColor = [UIColor labelColor];
    _bgBlurLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [blurCard addSubview:_bgBlurLabel];

    _bgBlurValueLabel = [UILabel new];
    _bgBlurValueLabel.font = [UIFont monospacedDigitSystemFontOfSize:14 weight:UIFontWeightSemibold];
    _bgBlurValueLabel.textColor = [UIColor secondaryLabelColor];
    _bgBlurValueLabel.textAlignment = NSTextAlignmentRight;
    _bgBlurValueLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [blurCard addSubview:_bgBlurValueLabel];

    _bgBlurSlider = [UISlider new];
    _bgBlurSlider.minimumValue = 0;
    _bgBlurSlider.maximumValue = 100;
    _bgBlurSlider.minimumTrackTintColor = [WAMPerContactSettings wamBlurSliderAccent];
    [_bgBlurSlider addTarget:self action:@selector(blurChanged) forControlEvents:UIControlEventValueChanged];
    [_bgBlurSlider addTarget:self action:@selector(blurCommitted) forControlEvents:UIControlEventTouchUpInside];
    [_bgBlurSlider addTarget:self action:@selector(blurCommitted) forControlEvents:UIControlEventTouchUpOutside];
    _bgBlurSlider.translatesAutoresizingMaskIntoConstraints = NO;
    [blurCard addSubview:_bgBlurSlider];

    _bgChooseButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _bgChooseButton.titleLabel.font = [WAMPerContactSettings wamRoundedFontOfSize:17 weight:UIFontWeightSemibold];
    [_bgChooseButton addTarget:self action:@selector(chooseTapped) forControlEvents:UIControlEventTouchUpInside];
    _bgChooseButton.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:_bgChooseButton];
    [self wamApplyGradientBackgroundToButton:_bgChooseButton baseColor:[WAMPerContactSettings wamChooseAccent]];

    _bgRemoveButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _bgRemoveButton.titleLabel.font = [WAMPerContactSettings wamRoundedFontOfSize:16 weight:UIFontWeightSemibold];
    [_bgRemoveButton setTitle:@"Remove Background" forState:UIControlStateNormal];
    [_bgRemoveButton addTarget:self action:@selector(removeTapped) forControlEvents:UIControlEventTouchUpInside];
    _bgRemoveButton.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:_bgRemoveButton];
    [self wamApplyGradientBackgroundToButton:_bgRemoveButton baseColor:[WAMPerContactSettings wamRemoveAccent]];

    [NSLayoutConstraint activateConstraints:@[
        [previewHeader.topAnchor constraintEqualToAnchor:root.topAnchor constant:8],
        [previewHeader.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:32],

        [previewCard.topAnchor constraintEqualToAnchor:previewHeader.bottomAnchor constant:6],
        [previewCard.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:18],
        [previewCard.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-18],

        [_bgPreviewContainer.topAnchor constraintEqualToAnchor:previewCard.topAnchor constant:14],
        [_bgPreviewContainer.bottomAnchor constraintEqualToAnchor:previewCard.bottomAnchor constant:-14],
        [_bgPreviewContainer.leadingAnchor constraintEqualToAnchor:previewCard.leadingAnchor constant:14],
        [_bgPreviewContainer.trailingAnchor constraintEqualToAnchor:previewCard.trailingAnchor constant:-14],
        [_bgPreviewContainer.heightAnchor constraintEqualToConstant:200],

        [_bgPreview.topAnchor constraintEqualToAnchor:_bgPreviewContainer.topAnchor],
        [_bgPreview.bottomAnchor constraintEqualToAnchor:_bgPreviewContainer.bottomAnchor],
        [_bgPreview.leadingAnchor constraintEqualToAnchor:_bgPreviewContainer.leadingAnchor],
        [_bgPreview.trailingAnchor constraintEqualToAnchor:_bgPreviewContainer.trailingAnchor],

        [_bgPlaceholder.centerXAnchor constraintEqualToAnchor:_bgPreviewContainer.centerXAnchor],
        [_bgPlaceholder.centerYAnchor constraintEqualToAnchor:_bgPreviewContainer.centerYAnchor],

        [blurHeader.topAnchor constraintEqualToAnchor:previewCard.bottomAnchor constant:22],
        [blurHeader.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:32],

        [blurCard.topAnchor constraintEqualToAnchor:blurHeader.bottomAnchor constant:6],
        [blurCard.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:18],
        [blurCard.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-18],

        [_bgBlurLabel.topAnchor constraintEqualToAnchor:blurCard.topAnchor constant:14],
        [_bgBlurLabel.leadingAnchor constraintEqualToAnchor:blurCard.leadingAnchor constant:18],
        [_bgBlurValueLabel.centerYAnchor constraintEqualToAnchor:_bgBlurLabel.centerYAnchor],
        [_bgBlurValueLabel.trailingAnchor constraintEqualToAnchor:blurCard.trailingAnchor constant:-18],
        [_bgBlurSlider.topAnchor constraintEqualToAnchor:_bgBlurLabel.bottomAnchor constant:8],
        [_bgBlurSlider.leadingAnchor constraintEqualToAnchor:blurCard.leadingAnchor constant:18],
        [_bgBlurSlider.trailingAnchor constraintEqualToAnchor:blurCard.trailingAnchor constant:-18],
        [_bgBlurSlider.bottomAnchor constraintEqualToAnchor:blurCard.bottomAnchor constant:-14],

        [_bgChooseButton.topAnchor constraintEqualToAnchor:blurCard.bottomAnchor constant:22],
        [_bgChooseButton.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:18],
        [_bgChooseButton.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-18],
        [_bgChooseButton.heightAnchor constraintEqualToConstant:52],

        [_bgRemoveButton.topAnchor constraintEqualToAnchor:_bgChooseButton.bottomAnchor constant:6],
        [_bgRemoveButton.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:18],
        [_bgRemoveButton.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-18],
        [_bgRemoveButton.heightAnchor constraintEqualToConstant:44],
        [_bgRemoveButton.bottomAnchor constraintLessThanOrEqualToAnchor:root.bottomAnchor constant:-24],
    ]];

    [self refreshBackgroundTab];
    return root;
}

- (void)refreshBackgroundTab {
    BOOL master = perContactOverridesEnabled(self.contactName);
    NSString *imgPath = self.contactName.length ? getPerContactImagePath(self.contactName, _editingDarkMode) : nil;
    _bgCurrentImage = (imgPath && [[NSFileManager defaultManager] fileExistsAtPath:imgPath])
        ? [UIImage imageWithContentsOfFile:imgPath]
        : nil;
    _bgPreviewSource = _bgCurrentImage ? [self downsampleForPreview:_bgCurrentImage] : nil;
    BOOL hasImage = (_bgCurrentImage != nil);

    _bgBlurSlider.value = getPerContactBlur(self.contactName, _editingDarkMode);
    BOOL blurActive = hasImage && master;
    _bgBlurSlider.enabled = blurActive;
    _bgBlurSlider.alpha = blurActive ? 1.0 : 0.35;
    _bgBlurLabel.alpha = blurActive ? 1.0 : 0.35;
    _bgBlurValueLabel.alpha = blurActive ? 1.0 : 0.35;
    _bgBlurValueLabel.text = [NSString stringWithFormat:@"%.0f", _bgBlurSlider.value];

    _bgPlaceholder.hidden = hasImage;
    [self renderBgPreview];

    _bgChooseButton.enabled = master;
    _bgChooseButton.alpha = master ? 1.0 : 0.45;
    [_bgChooseButton setTitle:(hasImage ? @"Change Image" : @"Choose Image") forState:UIControlStateNormal];
    _bgRemoveButton.hidden = !hasImage;
    _bgRemoveButton.enabled = master;
    _bgRemoveButton.alpha = master ? 1.0 : 0.45;
}

- (UIImage *)downsampleForPreview:(UIImage *)src {
    CGFloat maxDim = 600;
    CGFloat scale = MIN(maxDim / src.size.width, maxDim / src.size.height);
    if (scale >= 1) return src;
    CGSize newSize = CGSizeMake(floor(src.size.width * scale), floor(src.size.height * scale));
    UIGraphicsBeginImageContextWithOptions(newSize, NO, 1.0);
    [src drawInRect:CGRectMake(0, 0, newSize.width, newSize.height)];
    UIImage *result = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return result ?: src;
}

- (void)renderBgPreview {
    UIImage *src = _bgPreviewSource ?: _bgCurrentImage;
    if (!src) { _bgPreview.image = nil; return; }
    CGFloat v = _bgBlurSlider.value;
    _bgPreview.image = (v > 0) ? blurImage(src, v) : src;
}

- (void)blurChanged {
    if (!self.contactName.length) return;
    _bgBlurValueLabel.text = [NSString stringWithFormat:@"%.0f", _bgBlurSlider.value];
    [self renderBgPreview];
}

- (void)blurCommitted {
    if (!self.contactName.length) return;
    setPerContactBlur(self.contactName, _editingDarkMode, _bgBlurSlider.value);
    if (self.onChanged) self.onChanged();
}

- (void)chooseTapped {
    UIImagePickerController *picker = [UIImagePickerController new];
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    picker.delegate = self;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)removeTapped {
    if (!self.contactName.length) return;
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:getPerContactImagePath(self.contactName, _editingDarkMode) error:nil];
    [self refreshBackgroundTab];
    if (self.onChanged) self.onChanged();
}

- (void)doneTapped {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    UIImage *img = info[UIImagePickerControllerOriginalImage];
    NSString *name = self.contactName;
    BOOL dark = _editingDarkMode;
    __weak typeof(self) weakSelf = self;
    [picker dismissViewControllerAnimated:YES completion:^{
        if (!img || !name.length) return;
        NSData *data = UIImageJPEGRepresentation(img, 0.9);
        if (!data) return;
        NSString *path = getPerContactImagePath(name, dark);
        NSString *dir = [path stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
        [data writeToFile:path atomically:YES];
        [weakSelf refreshBackgroundTab];
        if (weakSelf.onChanged) weakSelf.onChanged();
    }];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

/* ===================================================================
   Bubbles tab (and shared row/card infrastructure used by future tabs)
   =================================================================== */

static const void *kWAMRowKeyAssocKey = &kWAMRowKeyAssocKey;
static const void *kWAMRowTypeAssocKey = &kWAMRowTypeAssocKey;
static const void *kWAMRowSpecsAssocKey = &kWAMRowSpecsAssocKey;

- (NSString *)wamKeyForSpec:(NSDictionary *)spec {
    NSString *k = _editingDarkMode ? spec[@"dark"] : spec[@"light"];
    return k.length ? k : spec[@"light"];
}

- (id)wamReadValueForKey:(NSString *)key {
    if (!key.length) return nil;
    NSString *name = self.contactName;
    if (name.length) {
        id override = getPerContactOverride(name, key);
        if (override) return override;
    }
    return loadPrefs()[key];
}

- (BOOL)wamCardHasOverrideForSpecs:(NSArray<NSDictionary *> *)specs {
    for (NSDictionary *s in specs) {
        if (hasPerContactOverride(self.contactName, [self wamKeyForSpec:s])) return YES;
    }
    return NO;
}

- (UIView *)wamCardWithTitle:(NSString *)title symbol:(NSString *)symbol tint:(UIColor *)tint rowSpecs:(NSArray<NSDictionary *> *)specs {
    UIView *header = [self wamMakeSectionHeader:title symbol:symbol tint:tint];
    UIView *card = [self wamMakeCard];

    BOOL editable = perContactOverridesEnabled(self.contactName);

    UIView *prev = nil;
    for (NSDictionary *spec in specs) {
        if (prev) {
            UIView *sep = [self wamMakeSeparator];
            [card addSubview:sep];
            [NSLayoutConstraint activateConstraints:@[
                [sep.topAnchor constraintEqualToAnchor:prev.bottomAnchor],
                [sep.leadingAnchor constraintEqualToAnchor:card.leadingAnchor constant:18],
                [sep.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
            ]];
            prev = sep;
        }
        UIView *row = [self wamValueRowForSpec:spec enabled:editable];
        [card addSubview:row];
        [NSLayoutConstraint activateConstraints:@[
            [row.topAnchor constraintEqualToAnchor:prev ? prev.bottomAnchor : card.topAnchor],
            [row.leadingAnchor constraintEqualToAnchor:card.leadingAnchor],
            [row.trailingAnchor constraintEqualToAnchor:card.trailingAnchor],
        ]];
        prev = row;
    }
    [prev.bottomAnchor constraintEqualToAnchor:card.bottomAnchor].active = YES;

    UIView *wrapper = [UIView new];
    wrapper.translatesAutoresizingMaskIntoConstraints = NO;
    [wrapper addSubview:header];
    [wrapper addSubview:card];
    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:wrapper.topAnchor],
        [header.leadingAnchor constraintEqualToAnchor:wrapper.leadingAnchor constant:14],
        [card.topAnchor constraintEqualToAnchor:header.bottomAnchor constant:8],
        [card.leadingAnchor constraintEqualToAnchor:wrapper.leadingAnchor],
        [card.trailingAnchor constraintEqualToAnchor:wrapper.trailingAnchor],
        [card.bottomAnchor constraintEqualToAnchor:wrapper.bottomAnchor],
    ]];
    return wrapper;
}

- (UIView *)wamValueRowForSpec:(NSDictionary *)spec enabled:(BOOL)enabled {
    UIView *row = [UIView new];
    row.translatesAutoresizingMaskIntoConstraints = NO;

    NSString *key = [self wamKeyForSpec:spec];
    NSString *type = spec[@"type"];

    UILabel *label = [UILabel new];
    label.text = spec[@"label"];
    label.font = [WAMPerContactSettings wamRoundedFontOfSize:15 weight:UIFontWeightMedium];
    label.textColor = enabled ? [UIColor labelColor] : [UIColor tertiaryLabelColor];
    label.translatesAutoresizingMaskIntoConstraints = NO;
    [row addSubview:label];

    UIView *trailing = nil;
    if ([type isEqualToString:@"color"]) {
        UIButton *swatch = [UIButton buttonWithType:UIButtonTypeCustom];
        UIColor *current = colorFromHex([self wamReadValueForKey:key]) ?: [UIColor systemGrayColor];
        swatch.layer.cornerRadius = 14;
        if (@available(iOS 13.0, *)) swatch.layer.cornerCurve = kCACornerCurveContinuous;
        swatch.clipsToBounds = YES;
        swatch.layer.borderWidth = 0.5;
        swatch.layer.borderColor = [UIColor separatorColor].CGColor;
        swatch.translatesAutoresizingMaskIntoConstraints = NO;
        swatch.enabled = enabled;
        swatch.alpha = enabled ? 1.0 : 0.35;

        UIView *checker = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 28, 28)];
        checker.backgroundColor = [UIColor colorWithPatternImage:wamCheckerboardImage()];
        checker.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        checker.userInteractionEnabled = NO;
        [swatch insertSubview:checker atIndex:0];

        UIView *colorTop = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 28, 28)];
        colorTop.backgroundColor = current;
        colorTop.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        colorTop.userInteractionEnabled = NO;
        [swatch addSubview:colorTop];

        [swatch addTarget:self action:@selector(wamSwatchTapped:) forControlEvents:UIControlEventTouchUpInside];
        objc_setAssociatedObject(swatch, kWAMRowKeyAssocKey, key, OBJC_ASSOCIATION_COPY_NONATOMIC);
        [row addSubview:swatch];
        [NSLayoutConstraint activateConstraints:@[
            [swatch.widthAnchor constraintEqualToConstant:28],
            [swatch.heightAnchor constraintEqualToConstant:28],
        ]];
        trailing = swatch;
    } else if ([type isEqualToString:@"text"]) {
        UITextField *tf = [UITextField new];
        tf.text = [self wamReadValueForKey:key];
        tf.placeholder = spec[@"placeholder"] ?: @"Default";
        tf.font = [WAMPerContactSettings wamRoundedFontOfSize:15 weight:UIFontWeightMedium];
        tf.textAlignment = NSTextAlignmentRight;
        tf.textColor = [UIColor labelColor];
        tf.returnKeyType = UIReturnKeyDone;
        tf.autocorrectionType = UITextAutocorrectionTypeNo;
        tf.clearButtonMode = UITextFieldViewModeWhileEditing;
        tf.enabled = enabled;
        tf.alpha = enabled ? 1.0 : 0.35;
        [tf addTarget:self action:@selector(wamTextFieldCommit:) forControlEvents:UIControlEventEditingDidEnd];
        [tf addTarget:self action:@selector(wamTextFieldDismiss:) forControlEvents:UIControlEventEditingDidEndOnExit];
        objc_setAssociatedObject(tf, kWAMRowKeyAssocKey, key, OBJC_ASSOCIATION_COPY_NONATOMIC);
        tf.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:tf];
        [NSLayoutConstraint activateConstraints:@[
            [tf.widthAnchor constraintEqualToConstant:170],
        ]];
        trailing = tf;
    } else if ([type isEqualToString:@"choice"]) {
        UILabel *valLabel = [UILabel new];
        NSString *currentValue = [self wamReadValueForKey:key] ?: @"";
        valLabel.text = [self wamDisplayLabelFor:currentValue inOptions:spec[@"options"]];
        valLabel.font = [WAMPerContactSettings wamRoundedFontOfSize:15 weight:UIFontWeightMedium];
        valLabel.textColor = enabled ? [UIColor secondaryLabelColor] : [UIColor tertiaryLabelColor];
        valLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:valLabel];

        UIImageSymbolConfiguration *chevCfg = [UIImageSymbolConfiguration configurationWithPointSize:12 weight:UIImageSymbolWeightSemibold];
        UIImage *chev = [[UIImage systemImageNamed:@"chevron.right" withConfiguration:chevCfg]
                         imageWithTintColor:[UIColor tertiaryLabelColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
        UIImageView *chevView = [[UIImageView alloc] initWithImage:chev];
        chevView.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:chevView];

        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(wamChoiceRowTapped:)];
        [row addGestureRecognizer:tap];
        row.userInteractionEnabled = enabled;
        row.alpha = enabled ? 1.0 : 0.4;
        objc_setAssociatedObject(row, kWAMRowKeyAssocKey, key, OBJC_ASSOCIATION_COPY_NONATOMIC);
        objc_setAssociatedObject(row, kWAMRowSpecsAssocKey, spec[@"options"], OBJC_ASSOCIATION_COPY_NONATOMIC);

        [NSLayoutConstraint activateConstraints:@[
            [chevView.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-18],
            [chevView.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
            [valLabel.trailingAnchor constraintEqualToAnchor:chevView.leadingAnchor constant:-6],
            [valLabel.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        ]];
    } else {
        UISwitch *valSwitch = [UISwitch new];
        wamMarkSwitchOwnsTint(valSwitch);
        valSwitch.onTintColor = [WAMPerContactSettings wamMasterAccent];
        id v = [self wamReadValueForKey:key];
        valSwitch.on = v ? [v boolValue] : NO;
        valSwitch.enabled = enabled;
        valSwitch.alpha = enabled ? 1.0 : 0.5;
        [valSwitch addTarget:self action:@selector(wamValueSwitchToggled:) forControlEvents:UIControlEventValueChanged];
        objc_setAssociatedObject(valSwitch, kWAMRowKeyAssocKey, key, OBJC_ASSOCIATION_COPY_NONATOMIC);
        valSwitch.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:valSwitch];
        trailing = valSwitch;
    }

    NSMutableArray *cons = [@[
        [label.leadingAnchor constraintEqualToAnchor:row.leadingAnchor constant:18],
        [label.centerYAnchor constraintEqualToAnchor:row.centerYAnchor],
        [row.heightAnchor constraintEqualToConstant:48],
    ] mutableCopy];
    if (trailing) {
        [cons addObject:[trailing.trailingAnchor constraintEqualToAnchor:row.trailingAnchor constant:-18]];
        [cons addObject:[trailing.centerYAnchor constraintEqualToAnchor:row.centerYAnchor]];
    }
    [NSLayoutConstraint activateConstraints:cons];
    return row;
}

- (NSString *)wamDisplayLabelFor:(NSString *)value inOptions:(NSArray<NSDictionary *> *)options {
    for (NSDictionary *opt in options) {
        if ([opt[@"value"] isEqualToString:value]) return opt[@"label"];
    }
    if (options.count > 0) return options[0][@"label"];
    return @"Default";
}

- (void)wamTextFieldCommit:(UITextField *)tf {
    NSString *key = objc_getAssociatedObject(tf, kWAMRowKeyAssocKey);
    if (!key.length) return;
    setPerContactOverride(self.contactName, key, tf.text ?: @"");
    if (self.onChanged) self.onChanged();
}

- (void)wamTextFieldDismiss:(UITextField *)tf {
    [tf resignFirstResponder];
}

- (void)wamChoiceRowTapped:(UITapGestureRecognizer *)g {
    UIView *row = g.view;
    NSString *key = objc_getAssociatedObject(row, kWAMRowKeyAssocKey);
    NSArray *options = objc_getAssociatedObject(row, kWAMRowSpecsAssocKey);
    if (!key.length || ![options isKindOfClass:[NSArray class]]) return;

    NSString *currentValue = [self wamReadValueForKey:key] ?: @"";
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:nil message:nil preferredStyle:UIAlertControllerStyleActionSheet];
    __weak typeof(self) weakSelf = self;
    for (NSDictionary *opt in options) {
        NSString *value = opt[@"value"];
        NSString *title = [value isEqualToString:currentValue]
            ? [NSString stringWithFormat:@"✓  %@", opt[@"label"]]
            : opt[@"label"];
        [alert addAction:[UIAlertAction actionWithTitle:title style:UIAlertActionStyleDefault handler:^(UIAlertAction *a) {
            setPerContactOverride(weakSelf.contactName, key, value);
            if (weakSelf.onChanged) weakSelf.onChanged();
            [weakSelf loadTab];
        }]];
    }
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    alert.popoverPresentationController.sourceView = row;
    alert.popoverPresentationController.sourceRect = row.bounds;
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)wamOverrideSwitchToggled:(UISwitch *)sender {
    NSArray<NSDictionary *> *specs = objc_getAssociatedObject(sender, kWAMRowSpecsAssocKey);
    if (![specs isKindOfClass:[NSArray class]]) return;
    if (sender.on) {
        NSDictionary *prefs = loadPrefs();
        for (NSDictionary *s in specs) {
            NSString *key = [self wamKeyForSpec:s];
            id global = prefs[key];
            if ([s[@"type"] isEqualToString:@"color"]) {
                if (!global) {
                    UIColor *eff = colorFromHex(prefs[key]) ?: [UIColor systemGrayColor];
                    global = hexFromColor(eff);
                }
            } else {
                if (!global) global = @NO;
            }
            setPerContactOverride(self.contactName, key, global);
        }
    } else {
        for (NSDictionary *s in specs) {
            clearPerContactOverride(self.contactName, [self wamKeyForSpec:s]);
        }
    }
    if (self.onChanged) self.onChanged();
    [self loadTab];
}

- (void)wamValueSwitchToggled:(UISwitch *)sender {
    NSString *key = objc_getAssociatedObject(sender, kWAMRowKeyAssocKey);
    if (!key.length) return;
    setPerContactOverride(self.contactName, key, @(sender.on));
    if (self.onChanged) self.onChanged();
}

- (void)wamSwatchTapped:(UIButton *)sender {
    NSString *key = objc_getAssociatedObject(sender, kWAMRowKeyAssocKey);
    if (!key.length) return;
    UIColorPickerViewController *picker = [UIColorPickerViewController new];
    picker.delegate = self;
    picker.supportsAlpha = YES;
    picker.selectedColor = colorFromHex([self wamReadValueForKey:key]) ?: [UIColor whiteColor];
    objc_setAssociatedObject(picker, kWAMRowKeyAssocKey, key, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)colorPickerViewController:(UIColorPickerViewController *)picker didSelectColor:(UIColor *)color continuously:(BOOL)continuously {
    NSString *key = objc_getAssociatedObject(picker, kWAMRowKeyAssocKey);
    if (!key.length) return;
    setPerContactOverride(self.contactName, key, hexFromColor(color));
    if (self.onChanged) self.onChanged();
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)picker {
    NSString *key = objc_getAssociatedObject(picker, kWAMRowKeyAssocKey);
    if (key.length) {
        setPerContactOverride(self.contactName, key, hexFromColor(picker.selectedColor));
        if (self.onChanged) self.onChanged();
    }
    [self loadTab];
}

- (UIView *)buildBubblesTab {
    UIView *root = [UIView new];

    NSArray *cards = @[
        @{ @"title": @"iMessage",
           @"symbol": @"bubble.right.fill",
           @"tint": [UIColor systemCyanColor],
           @"specs": @[
               @{@"label": @"Bubble Color", @"light": @"sentBubbleColor", @"dark": @"sentBubbleColorDark", @"type": @"color"},
               @{@"label": @"Text Color",   @"light": @"sentTextColor",   @"dark": @"sentTextColorDark",   @"type": @"color"},
           ]},
        @{ @"title": @"SMS",
           @"symbol": @"message.fill",
           @"tint": [UIColor systemGreenColor],
           @"specs": @[
               @{@"label": @"Bubble Color", @"light": @"sentSMSBubbleColor", @"dark": @"sentSMSBubbleColorDark", @"type": @"color"},
               @{@"label": @"Text Color",   @"light": @"sentSMSTextColor",   @"dark": @"sentSMSTextColorDark",   @"type": @"color"},
           ]},
        @{ @"title": @"Received",
           @"symbol": @"bubble.left.fill",
           @"tint": [UIColor colorWithRed:0.91 green:0.24 blue:0.55 alpha:1.0], // #E83D8C rose-magenta
           @"specs": @[
               @{@"label": @"Bubble Color", @"light": @"receivedBubbleColor", @"dark": @"receivedBubbleColorDark", @"type": @"color"},
               @{@"label": @"Text Color",   @"light": @"receivedTextColor",   @"dark": @"receivedTextColorDark",   @"type": @"color"},
           ]},
        @{ @"title": @"Timestamps",
           @"symbol": @"clock.fill",
           @"tint": [UIColor systemGrayColor],
           @"specs": @[
               @{@"label": @"Text Color", @"light": @"timestampTextColor", @"dark": @"timestampTextColorDark", @"type": @"color"},
           ]},
        @{ @"title": @"Status Receipts",
           @"symbol": @"checkmark.message.fill",
           @"tint": [UIColor colorWithRed:0.42 green:0.36 blue:0.82 alpha:1.0], // #6B5DD2 indigo
           @"specs": @[
               @{@"label": @"Text Color", @"light": @"advancedStatusCellColor", @"dark": @"advancedStatusCellColorDark", @"type": @"color"},
           ]},
    ];

    UIView *prev = nil;
    for (NSDictionary *c in cards) {
        UIView *cardWrapper = [self wamCardWithTitle:c[@"title"] symbol:c[@"symbol"] tint:c[@"tint"] rowSpecs:c[@"specs"]];
        [root addSubview:cardWrapper];
        if (prev) {
            [cardWrapper.topAnchor constraintEqualToAnchor:prev.bottomAnchor constant:22].active = YES;
        } else {
            [cardWrapper.topAnchor constraintEqualToAnchor:root.topAnchor constant:6].active = YES;
        }
        [cardWrapper.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:18].active = YES;
        [cardWrapper.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-18].active = YES;
        prev = cardWrapper;
    }
    if (prev) {
        [prev.bottomAnchor constraintLessThanOrEqualToAnchor:root.bottomAnchor constant:-28].active = YES;
    }
    return root;
}

- (UIView *)buildMessageBarTab {
    UIView *root = [UIView new];

    NSArray *cards = @[
        @{ @"title": @"Input Field",
           @"symbol": @"character.textbox",
           @"tint": [UIColor systemMintColor],
           @"specs": @[
               @{@"label": @"Background",       @"light": @"inputFieldBackgroundColor", @"dark": @"inputFieldBackgroundColorDark", @"type": @"color"},
               @{@"label": @"Text Color",       @"light": @"messageInputTextColor",     @"dark": @"messageInputTextColorDark",     @"type": @"color"},
               @{@"label": @"Placeholder",      @"light": @"placeholderTextColor",      @"dark": @"placeholderTextColorDark",      @"type": @"color"},
               @{@"label": @"Placeholder Text", @"light": @"placeholderText",           @"dark": @"placeholderTextDark",           @"type": @"text",
                 @"placeholder": @"iMessage"},
               @{@"label": @"Blur Style",       @"light": @"inputFieldBlurStyle",       @"dark": @"inputFieldBlurStyleDark",       @"type": @"choice",
                 @"options": @[
                     @{@"value": @"regular",         @"label": @"Regular"},
                     @{@"value": @"light",           @"label": @"Light"},
                     @{@"value": @"dark",            @"label": @"Dark"},
                     @{@"value": @"ultraThinLight",  @"label": @"Ultra Thin Light"},
                     @{@"value": @"ultraThinDark",   @"label": @"Ultra Thin Dark"},
                 ]},
           ]},
        @{ @"title": @"Send Button",
           @"symbol": @"arrow.up.circle.fill",
           @"tint": [UIColor colorWithRed:1.0 green:0.48 blue:0.30 alpha:1.0], // #FF7A4D coral
           @"specs": @[
               @{@"label": @"Background", @"light": @"sendButtonColor",      @"dark": @"sendButtonColorDark",      @"type": @"color"},
               @{@"label": @"Arrow Color", @"light": @"sendButtonArrowColor", @"dark": @"sendButtonArrowColorDark", @"type": @"color"},
           ]},
        @{ @"title": @"Message Bar Tint",
           @"symbol": @"paintbrush.fill",
           @"tint": [UIColor colorWithRed:0.97 green:0.49 blue:0.28 alpha:1.0], // #F87D47 sunset orange
           @"specs": @[
               @{@"label": @"Tint Color", @"light": @"messageBarTintColor", @"dark": @"messageBarTintColorDark", @"type": @"color"},
           ]},
        @{ @"title": @"Bar Buttons",
           @"symbol": @"square.grid.2x2.fill",
           @"tint": [UIColor systemBrownColor],
           @"specs": @[
               @{@"label": @"Button Color", @"light": @"messageBarButtonColor", @"dark": @"messageBarButtonColorDark", @"type": @"color"},
           ]},
    ];

    UIView *prev = nil;
    for (NSDictionary *c in cards) {
        UIView *cardWrapper = [self wamCardWithTitle:c[@"title"] symbol:c[@"symbol"] tint:c[@"tint"] rowSpecs:c[@"specs"]];
        [root addSubview:cardWrapper];
        if (prev) {
            [cardWrapper.topAnchor constraintEqualToAnchor:prev.bottomAnchor constant:22].active = YES;
        } else {
            [cardWrapper.topAnchor constraintEqualToAnchor:root.topAnchor constant:6].active = YES;
        }
        [cardWrapper.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:18].active = YES;
        [cardWrapper.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-18].active = YES;
        prev = cardWrapper;
    }
    if (prev) {
        [prev.bottomAnchor constraintLessThanOrEqualToAnchor:root.bottomAnchor constant:-28].active = YES;
    }
    return root;
}

- (UIView *)buildMiscTab {
    UIView *root = [UIView new];

    NSArray *cards = @[
        @{ @"title": @"System Tint",
           @"symbol": @"drop.fill",
           @"tint": [UIColor colorWithRed:0.31 green:0.51 blue:0.95 alpha:1.0], // #4F82F1 sky blue
           @"specs": @[
               @{@"label": @"Accent Color", @"light": @"systemTintColor", @"dark": @"systemTintColorDark", @"type": @"color"},
           ]},
        @{ @"title": @"Navigation Bar",
           @"symbol": @"rectangle.topthird.inset.filled",
           @"tint": [UIColor colorWithRed:0.95 green:0.45 blue:0.18 alpha:1.0], // #F2742E burnt orange
           @"specs": @[
               @{@"label": @"Tint Color",    @"light": @"navBarTintColor",     @"dark": @"navBarTintColorDark",     @"type": @"color"},
               @{@"label": @"Contact Name",  @"light": @"chatContactNameColor", @"dark": @"chatContactNameColorDark", @"type": @"color"},
           ]},
        @{ @"title": @"Cell Tint",
           @"symbol": @"rectangle.stack.fill",
           @"tint": [UIColor colorWithRed:0.20 green:0.71 blue:0.50 alpha:1.0], // #34B57F forest
           @"specs": @[
               @{@"label": @"Enabled",    @"light": @"isCellBlurTintEnabled", @"type": @"bool"},
               @{@"label": @"Tint Color", @"light": @"cellTintColor", @"dark": @"cellTintColorDark", @"type": @"color"},
           ]},
        @{ @"title": @"Link Previews",
           @"symbol": @"link.circle.fill",
           @"tint": [UIColor systemTealColor],
           @"specs": @[
               @{@"label": @"Background", @"light": @"linkPreviewBackgroundColor", @"dark": @"linkPreviewBackgroundColorDark", @"type": @"color"},
               @{@"label": @"Text Color", @"light": @"linkPreviewTextColor",       @"dark": @"linkPreviewTextColorDark",       @"type": @"color"},
           ]},
        @{ @"title": @"Reactions",
           @"symbol": @"heart.fill",
           @"tint": [UIColor colorWithRed:1.00 green:0.42 blue:0.51 alpha:1.0], // #FF6B81 coral pink
           @"specs": @[
               @{@"label": @"Balloon",   @"light": @"advancedReactionBalloonColor",   @"dark": @"advancedReactionBalloonColorDark",   @"type": @"color"},
               @{@"label": @"Glyph",     @"light": @"advancedReactionGlyphColor",     @"dark": @"advancedReactionGlyphColorDark",     @"type": @"color"},
               @{@"label": @"Highlight", @"light": @"advancedReactionHighlightColor", @"dark": @"advancedReactionHighlightColorDark", @"type": @"color"},
           ]},
        @{ @"title": @"Spam Warning",
           @"symbol": @"exclamationmark.triangle.fill",
           @"tint": [UIColor colorWithRed:0.90 green:0.63 blue:0.00 alpha:1.0], // #E5A100 amber
           @"specs": @[
               @{@"label": @"Button Color", @"light": @"advancedReportJunkColor", @"dark": @"advancedReportJunkColorDark", @"type": @"color"},
           ]},
    ];

    UIView *prev = nil;
    for (NSDictionary *c in cards) {
        UIView *cardWrapper = [self wamCardWithTitle:c[@"title"] symbol:c[@"symbol"] tint:c[@"tint"] rowSpecs:c[@"specs"]];
        [root addSubview:cardWrapper];
        if (prev) {
            [cardWrapper.topAnchor constraintEqualToAnchor:prev.bottomAnchor constant:22].active = YES;
        } else {
            [cardWrapper.topAnchor constraintEqualToAnchor:root.topAnchor constant:6].active = YES;
        }
        [cardWrapper.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:18].active = YES;
        [cardWrapper.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-18].active = YES;
        prev = cardWrapper;
    }
    if (prev) {
        [prev.bottomAnchor constraintLessThanOrEqualToAnchor:root.bottomAnchor constant:-28].active = YES;
    }
    return root;
}

@end

@interface WAMChangelogViewController : UIViewController <UIAdaptivePresentationControllerDelegate>
@end

@implementation WAMChangelogViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor systemBackgroundColor];

    UIColor *brandColor = colorFromHex(@"89EED3") ?: [UIColor systemBlueColor];

    UIImageView *iconView = [[UIImageView alloc] init];
    iconView.contentMode = UIViewContentModeScaleAspectFit;
    iconView.layer.cornerRadius = 18;
    iconView.layer.masksToBounds = YES;
    iconView.translatesAutoresizingMaskIntoConstraints = NO;
    NSArray *iconPaths = @[
        @"/var/jb/Library/PreferenceBundles/WhatAMessPrefs.bundle/icon@3x.png",
        @"/Library/PreferenceBundles/WhatAMessPrefs.bundle/icon@3x.png",
    ];
    for (NSString *p in iconPaths) {
        NSData *data = [NSData dataWithContentsOfFile:p];
        if (data) { iconView.image = [UIImage imageWithData:data scale:3.0]; break; }
    }
    [self.view addSubview:iconView];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = kWAMChangelogTitle;
    titleLabel.font = [UIFont systemFontOfSize:29 weight:UIFontWeightBold];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.numberOfLines = 0;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:titleLabel];

    UILabel *versionLabel = [[UILabel alloc] init];
    versionLabel.text = [NSString stringWithFormat:@"Version %@", kWAMTweakVersion];
    versionLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightMedium];
    versionLabel.textColor = [UIColor secondaryLabelColor];
    versionLabel.textAlignment = NSTextAlignmentCenter;
    versionLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:versionLabel];

    UIScrollView *scroll = [[UIScrollView alloc] init];
    scroll.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:scroll];

    UIStackView *content = [[UIStackView alloc] init];
    content.axis = UILayoutConstraintAxisVertical;
    content.alignment = UIStackViewAlignmentFill;
    content.spacing = 8;
    content.translatesAutoresizingMaskIntoConstraints = NO;
    [scroll addSubview:content];

    UIFont *headerFont = [UIFont systemFontOfSize:20 weight:UIFontWeightSemibold];
    UIFont *bodyFont = [UIFont systemFontOfSize:17];
    UIFont *closingFont = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    UIFont *quoteFont = [UIFont italicSystemFontOfSize:14];

    NSMutableParagraphStyle *bulletStyle = [[NSMutableParagraphStyle alloc] init];
    bulletStyle.paragraphSpacing = 8;
    NSDictionary *bulletAttrs = @{
        NSFontAttributeName: bodyFont,
        NSForegroundColorAttributeName: [UIColor labelColor],
        NSParagraphStyleAttributeName: bulletStyle,
    };

    void (^addHeader)(NSString *, BOOL) = ^(NSString *text, BOOL extraTop) {
        UILabel *l = [[UILabel alloc] init];
        l.text = text;
        l.font = headerFont;
        l.numberOfLines = 0;
        [content addArrangedSubview:l];
        if (extraTop) [content setCustomSpacing:18 afterView:content.arrangedSubviews[content.arrangedSubviews.count - 2]];
        [content setCustomSpacing:6 afterView:l];
    };
    void (^addBullets)(NSString *) = ^(NSString *text) {
        UILabel *l = [[UILabel alloc] init];
        l.numberOfLines = 0;
        l.attributedText = [[NSAttributedString alloc] initWithString:text attributes:bulletAttrs];
        [content addArrangedSubview:l];
    };

    addHeader(@"New Features", NO);
    addBullets(@"• Added iOS 15 Support\n• Added color tinting to Modern NavBar and Modern MessageBar\n• This splash screen!");

    addHeader(@"Bug Fixes/Changes", YES);
    addBullets(@"• Fixed a bug where haptic/3D touching to preview a chat didn't show the selected background.\n• Made preferences automatically select the user's active light/dark mode upon first setting up the tweak.\n• And numerous more fixes for iOS 15 and all versions!");

    UILabel *thanks = [[UILabel alloc] init];
    thanks.text = @"A huge thanks to user Deakula for testing and providing crucial feedback to get this tweak on iOS 15!";
    thanks.font = [UIFont systemFontOfSize:15];
    thanks.textColor = [UIColor secondaryLabelColor];
    thanks.textAlignment = NSTextAlignmentCenter;
    thanks.numberOfLines = 0;
    [content addArrangedSubview:thanks];
    [content setCustomSpacing:24 afterView:content.arrangedSubviews[content.arrangedSubviews.count - 2]];

    UILabel *closing = [[UILabel alloc] init];
    closing.text = @"View the full changelog on GitHub";
    closing.font = closingFont;
    closing.textColor = [UIColor secondaryLabelColor];
    closing.textAlignment = NSTextAlignmentCenter;
    closing.numberOfLines = 0;
    closing.translatesAutoresizingMaskIntoConstraints = NO;

    UILabel *quote = [[UILabel alloc] init];
    quote.text = @"UIVisualEffectView my beloved";
    quote.font = quoteFont;
    quote.textColor = [UIColor tertiaryLabelColor];
    quote.textAlignment = NSTextAlignmentCenter;
    quote.numberOfLines = 0;
    quote.translatesAutoresizingMaskIntoConstraints = NO;

    UIStackView *footer = [[UIStackView alloc] initWithArrangedSubviews:@[closing, quote]];
    footer.axis = UILayoutConstraintAxisVertical;
    footer.alignment = UIStackViewAlignmentFill;
    footer.spacing = 6;
    footer.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:footer];

    UIButton *githubBtn = [UIButton buttonWithType:UIButtonTypeSystem];
    [githubBtn setTitle:@"GitHub" forState:UIControlStateNormal];
    [githubBtn setTitleColor:brandColor forState:UIControlStateNormal];
    githubBtn.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    githubBtn.backgroundColor = [UIColor tertiarySystemFillColor];
    githubBtn.layer.cornerRadius = 14;
    [githubBtn addTarget:self action:@selector(gitHubTapped) forControlEvents:UIControlEventTouchUpInside];

    UIButton *dismiss = [UIButton buttonWithType:UIButtonTypeSystem];
    [dismiss setTitle:@"Got It" forState:UIControlStateNormal];
    [dismiss setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    dismiss.titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    dismiss.backgroundColor = brandColor;
    dismiss.layer.cornerRadius = 14;
    [dismiss addTarget:self action:@selector(dismissTapped) forControlEvents:UIControlEventTouchUpInside];

    UIStackView *buttonRow = [[UIStackView alloc] initWithArrangedSubviews:@[githubBtn, dismiss]];
    buttonRow.axis = UILayoutConstraintAxisHorizontal;
    buttonRow.distribution = UIStackViewDistributionFillEqually;
    buttonRow.spacing = 12;
    buttonRow.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:buttonRow];

    [NSLayoutConstraint activateConstraints:@[
        [iconView.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:24],
        [iconView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [iconView.widthAnchor constraintEqualToConstant:72],
        [iconView.heightAnchor constraintEqualToConstant:72],

        [titleLabel.topAnchor constraintEqualToAnchor:iconView.bottomAnchor constant:14],
        [titleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [titleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],

        [versionLabel.topAnchor constraintEqualToAnchor:titleLabel.bottomAnchor constant:4],
        [versionLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [versionLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],

        [scroll.topAnchor constraintEqualToAnchor:versionLabel.bottomAnchor constant:24],
        [scroll.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [scroll.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [scroll.bottomAnchor constraintEqualToAnchor:footer.topAnchor constant:-16],

        [content.topAnchor constraintEqualToAnchor:scroll.topAnchor],
        [content.leadingAnchor constraintEqualToAnchor:scroll.leadingAnchor],
        [content.trailingAnchor constraintEqualToAnchor:scroll.trailingAnchor],
        [content.bottomAnchor constraintEqualToAnchor:scroll.bottomAnchor],
        [content.widthAnchor constraintEqualToAnchor:scroll.widthAnchor],

        [footer.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [footer.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [footer.bottomAnchor constraintEqualToAnchor:buttonRow.topAnchor constant:-16],

        [buttonRow.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:24],
        [buttonRow.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-24],
        [buttonRow.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor constant:-20],
        [buttonRow.heightAnchor constraintEqualToConstant:52],
    ]];
}

- (void)gitHubTapped {
    NSURL *url = [NSURL URLWithString:kWAMGitHubURL];
    if (url) [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (void)dismissTapped {
    markChangelogSeen();
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    markChangelogSeen();
}

@end

/*============
    HOOKS
============*/

%hook UIView

- (UIColor *)tintColor {
    if (!isTweakEnabled()) return %orig;

    {
        UIView *sp = self;
        int shops = 0;
        while (sp && shops < 30) {
            if ([sp isKindOfClass:%c(UISearchBar)] ||
                [sp isKindOfClass:%c(_UISearchBarSearchFieldBackgroundView)] ||
                [sp isKindOfClass:%c(UISearchTextField)]) {
                return %orig;
            }
            sp = sp.superview;
            shops++;
        }
    }

    {
        UIView *p = self;
        Class convListCellCls = %c(CKConversationListCollectionViewConversationCell);
        Class pinnedViewCls = %c(CKPinnedConversationView);
        Class pinnedBubbleCls = %c(CKPinnedConversationSummaryBubble);
        int hops = 0;
        while (p && hops < 30) {
            if ((convListCellCls && [p isKindOfClass:convListCellCls]) ||
                (pinnedViewCls && [p isKindOfClass:pinnedViewCls]) ||
                (pinnedBubbleCls && [p isKindOfClass:pinnedBubbleCls])) {
                NSDictionary *prefs = loadPrefs();
                NSString *key = isDarkMode() ? @"systemTintColorDark" : @"systemTintColor";
                UIColor *globalTint = colorFromHex(prefs[key]);
                if (globalTint) return globalTint;
                return %orig;
            }
            if ([p isKindOfClass:[UINavigationBar class]]) {
                if (wamNavBarShouldUseGlobals(p)) {
                    NSDictionary *prefs = loadPrefs();
                    NSString *key = isDarkMode() ? @"systemTintColorDark" : @"systemTintColor";
                    UIColor *globalTint = colorFromHex(prefs[key]);
                    if (globalTint) return globalTint;
                    return %orig;
                }
            }
            if ([p respondsToSelector:@selector(_viewControllerForAncestor)]) {
                UIViewController *vc = [p _viewControllerForAncestor];
                if (vc && [vc isKindOfClass:%c(CKConversationListCollectionViewController)]) {
                    NSDictionary *prefs = loadPrefs();
                    NSString *key = isDarkMode() ? @"systemTintColorDark" : @"systemTintColor";
                    UIColor *globalTint = colorFromHex(prefs[key]);
                    if (globalTint) return globalTint;
                    return %orig;
                }
            }
            p = p.superview;
            hops++;
        }
    }

    UIColor *customTint = getSystemTintColor();
    if (!customTint) return %orig;

    if ([self isKindOfClass:[UIImageView class]] && self.tag == 88771) return %orig;

    if ([self isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)self;
        if (imageView.image) {
            NSString *description = [imageView.image description];
            if ([description containsString:@"trash.fill"] ||
                [description containsString:@"bell.slash.fill"] ||
                [description containsString:@"checkmark.message.fill"] ||
                [description containsString:@"message.badge.fill"]) {
                return %orig;
            }
            CGSize imageSize = imageView.image.size;
            if (imageSize.height > imageSize.width && imageSize.width < 15) {
                UIView *parent = self.superview;
                int levels = 0;
                while (parent && levels < 7) {
                    if ([parent isKindOfClass:%c(CKConversationListCollectionViewConversationCell)]) return %orig;
                    parent = parent.superview;
                    levels++;
                }
            }
        }
    }

    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 7) {
        if ([parent isKindOfClass:%c(_UISearchBarSearchFieldBackgroundView)] ||
            [parent isKindOfClass:%c(UISearchBar)]) return %orig;
        if ([parent isKindOfClass:%c(UIKBVisualEffectView)] ||
            [parent isKindOfClass:%c(UIInputView)]) return %orig;
        NSString *className = NSStringFromClass([parent class]);
        if ([className containsString:@"Keyboard"] ||
            [className containsString:@"UIKBInputBackdropView"]) return %orig;
        parent = parent.superview;
        levels++;
    }

    if (!isCustomBubbleColorsEnabled()) {
        UIView *p = self.superview;
        int l = 0;
        while (p && l < 5) {
            if ([p isKindOfClass:%c(CKAggregateAcknowledgmentBalloonView)]) return %orig;
            p = p.superview;
            l++;
        }
    }

    if (isAdvancedTintEnabled()) {
        UIColor *balloonColor = getChatAdvancedTintColorForView(@"advancedReactionBalloonColor", @"advancedReactionBalloonColorDark", nil, self);
        if (balloonColor) {
            UIView *p = self.superview;
            int l = 0;
            while (p && l < 5) {
                if ([p isKindOfClass:%c(CKAggregateAcknowledgmentBalloonView)]) {
                    return balloonColor;
                }
                p = p.superview;
                l++;
            }
        }

        UIColor *contactActionColor = getAdvancedTintColorForView(@"advancedContactActionColor", @"advancedContactActionColorDark", nil, self);
        if (contactActionColor) {
            UIView *p = self.superview;
            int l = 0;
            while (p && l < 10) {
                if ([p isKindOfClass:%c(CNActionView)]) {
                    return contactActionColor;
                }
                p = p.superview;
                l++;
            }
        }

        UIColor *navButtonColor = getAdvancedTintColorForView(@"advancedNavButtonColor", @"advancedNavButtonColorDark", nil, self);
        if (navButtonColor) {
            UIView *p = self.superview;
            int l = 0;
            while (p && l < 12) {
                if ([p isKindOfClass:[UINavigationBar class]] ||
                    [p isKindOfClass:%c(UINavigationButton)] ||
                    [p isKindOfClass:%c(_UIButtonBarButton)] ||
                    [p isKindOfClass:%c(CNActionView)] ||
                    [NSStringFromClass([p class]) containsString:@"BarButton"] ||
                    [NSStringFromClass([p class]) containsString:@"NavigationButton"]) {
                    return navButtonColor;
                }
                p = p.superview;
                l++;
            }
        }
    }

    return customTint;
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) return;
    if ([self class] == [UIView class]) {
        UIColor *receivedColor = getReceivedBubbleColor();
        if (receivedColor &&
            ([self.superview isKindOfClass:%c(CKMessageAcknowledgmentPickerBarView)] ||
             [self.superview isKindOfClass:%c(CKQuickActionSaveButton)])) {
            self.backgroundColor = receivedColor;
        }
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        %orig;
        return;
    }
    if ([self class] == [UIView class]) {
        UIColor *receivedColor = getReceivedBubbleColor();
        if (receivedColor &&
            ([self.superview isKindOfClass:%c(CKMessageAcknowledgmentPickerBarView)] ||
             [self.superview isKindOfClass:%c(CKQuickActionSaveButton)])) {
            %orig(receivedColor);
            return;
        }
    }
    %orig;
}

%end

%hook CKConversationListCollectionViewController

-(void)viewWillAppear:(BOOL)animated {
    %orig;
    [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
    if (!isTweakEnabled() || !isiOS15()) return;
    [self applyCustomNavTitle];
}

-(void)viewDidAppear:(BOOL)animated {
    %orig;
    if (isTweakEnabled()) {
        [self handlePrefsChanged];
    }
    if (!isTweakEnabled() || gWAMChangelogShownThisLaunch) return;
    if (!shouldShowChangelog()) return;
    gWAMChangelogShownThisLaunch = YES;

    WAMChangelogViewController *vc = [WAMChangelogViewController new];
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    vc.presentationController.delegate = vc;
    [self presentViewController:vc animated:YES completion:nil];
}

%new
-(void)applyCustomNavTitle {
    NSString *title = getConversationListTitle();
    UIColor *titleColor = getConversationListTitleColor();

    self.navigationItem.title = title;

    if (self.navigationController) {
        if (titleColor) {
            NSDictionary *attrs = @{ NSForegroundColorAttributeName: titleColor };
            self.navigationController.navigationBar.titleTextAttributes = attrs;
            self.navigationController.navigationBar.largeTitleTextAttributes = attrs;
        } else {
            self.navigationController.navigationBar.titleTextAttributes = nil;
            self.navigationController.navigationBar.largeTitleTextAttributes = nil;
        }
    }
}


-(void)viewDidLoad {
    %orig;
    if (!isTweakEnabled()) return;

    self.view.backgroundColor = [UIColor clearColor];
    self.collectionView.backgroundColor = [UIColor clearColor];
    [self updateAllColors];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateBackground];
    });

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handlePrefsChanged)
        name:kPrefsChangedNotification
        object:nil];
}

%new
-(void)handlePrefsChanged {
    invalidateConvImageCache();
    refreshPrefs();

    [self updateBackground];
    [self updateAllColors];

    if (isiOS15()) {
        [self applyCustomNavTitle];
    } else {
        NSString *title = getConversationListTitle();
        self.navigationItem.title = @"";
        dispatch_async(dispatch_get_main_queue(), ^{
            self.navigationItem.title = title;
            for (UIView *subview in self.navigationController.navigationBar.subviews) {
                [subview setNeedsLayout];
                [subview layoutIfNeeded];
            }
        });
    }
}

%new
-(void)applyCustomColorsToCKLabelsInView:(UIView *)view {
    UIColor *custom = isCustomTextColorsEnabled() ? getTitleTextColorConvList() : nil;
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:%c(CKLabel)]) {
            UILabel *label = (UILabel *)subview;
            if (custom) {
                if (!objc_getAssociatedObject(label, &kWAMOrigTitleColorKey)) {
                    objc_setAssociatedObject(label, &kWAMOrigTitleColorKey, label.textColor ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
                label.textColor = custom;
            } else {
                id orig = objc_getAssociatedObject(label, &kWAMOrigTitleColorKey);
                if (orig && orig != [NSNull null]) label.textColor = orig;
            }
        }
        [self applyCustomColorsToCKLabelsInView:subview];
    }
}

%new
-(void)updateAllColors {
    if (!isTweakEnabled()) return;

    for (UICollectionViewCell *cell in self.collectionView.visibleCells) {
        applyCustomTextColors(cell);
        [cell setNeedsLayout];
        [cell layoutIfNeeded];
    }
}

-(void)viewDidLayoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    if (isConvImageBgEnabled() && !isConvColorBgEnabled()) {
        [self makeSubviewsTransparent:self.view];
        [self makeSubviewsTransparent:self.collectionView];
    }

    [self applyCustomColorsToCKLabelsInView:self.view];
}

%new
-(void)updateBackground {
    UIImage *bgImage = loadImageUncached(getConvImagePath());

    for (UIView *subview in [self.view.subviews copy]) {
        if (subview.tag == 1234) [subview removeFromSuperview];
    }

    if (isConvColorBgEnabled()) {
        self.view.backgroundColor = [UIColor clearColor];
        self.collectionView.backgroundColor = [UIColor clearColor];
        UIView *colorView = [[UIView alloc] initWithFrame:self.collectionView.bounds];
        colorView.backgroundColor = getBackgroundColor();
        colorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.collectionView.backgroundView = colorView;
    } else if (bgImage && isConvImageBgEnabled()) {
        CGFloat blurAmount = getImageBlurAmount();
        if (blurAmount > 0) bgImage = blurImage(bgImage, blurAmount);
        self.view.backgroundColor = [UIColor clearColor];
        self.collectionView.backgroundColor = [UIColor clearColor];

        [self.view layoutIfNeeded];

        UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.collectionView.bounds];
        imageView.image = bgImage;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.collectionView.backgroundView = imageView;

        UIImageView *mainBgView = [[UIImageView alloc] initWithFrame:self.view.bounds];
        mainBgView.image = bgImage;
        mainBgView.contentMode = UIViewContentModeScaleAspectFill;
        mainBgView.clipsToBounds = YES;
        mainBgView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        mainBgView.tag = 1234;
        [self.view insertSubview:mainBgView atIndex:0];

        [self makeSubviewsTransparent:self.view];
        [self makeSubviewsTransparent:self.collectionView];
    } else {
        self.collectionView.backgroundView = nil;
        UIColor *systemBg = [UIColor systemBackgroundColor];
        self.view.backgroundColor = systemBg;
        self.collectionView.backgroundColor = systemBg;
    }

    [self.collectionView reloadData];
    [self.view setNeedsLayout];
    [self.view layoutIfNeeded];
}

%new
-(void)makeSubviewsTransparent:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview class] == [UIView class]) {
            UIColor *bgColor = subview.backgroundColor;
            if (bgColor) {
                CGFloat red = 0, green = 0, blue = 0, alpha = 0;
                if ([bgColor getRed:&red green:&green blue:&blue alpha:&alpha]) {
                    if (red < 0.1 && green < 0.1 && blue < 0.1 && alpha > 0.5) {
                        subview.backgroundColor = [UIColor clearColor];
                    }
                }
            }
        }
        [self makeSubviewsTransparent:subview];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            invalidateConvImageCache();
            refreshPrefs();
            [self updateBackground];
            [self updateAllColors];
            [self.collectionView reloadData];
        }
    }
}


-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook CKConversationListCollectionViewConversationCell

-(instancetype)initWithFrame:(CGRect)frame {
    if (!isTweakEnabled()) return %orig(frame);
    self = %orig(frame);
    if (self) {
        if (isConvColorBgEnabled()) {
            self.contentView.backgroundColor = getCellColor();
        } else if (isConvImageBgEnabled()) {
            self.backgroundColor = [UIColor clearColor];
            self.contentView.backgroundColor = [UIColor clearColor];
            self.layer.backgroundColor = [UIColor clearColor].CGColor;
        } else {
            self.contentView.backgroundColor = [UIColor clearColor];
        }
    }
    return self;
}

-(void)setHighlighted:(BOOL)highlighted {
    %orig;
    if (!highlighted || !isTweakEnabled() || !isPerContactChatBgEnabled()) return;

    UILabel *best = nil;
    CGFloat bestSize = 0;
    NSMutableArray *queue = [NSMutableArray arrayWithObject:self.contentView];
    while (queue.count > 0) {
        UIView *view = queue[0];
        [queue removeObjectAtIndex:0];
        if ([view isKindOfClass:%c(CKLabel)] && ![view isKindOfClass:%c(CKDateLabel)]) {
            UILabel *label = (UILabel *)view;
            if (label.text.length) {
                CGFloat sz = label.font.pointSize;
                if (sz > bestSize) { bestSize = sz; best = label; }
            }
        }
        for (UIView *sub in view.subviews) [queue addObject:sub];
    }
    NSString *name = best.text;
    if (!name.length) return;
    if ([name isEqualToString:gWAMCurrentContactName]) return;
    gWAMCurrentContactName = [name copy];
    gWAMCurrentContactDisplayName = [name copy];
    gWAMCacheSetAt = [NSDate timeIntervalSinceReferenceDate];
    Class messagesCtrlClass = %c(CKMessagesController);
    NSMutableArray *winList = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                [winList addObjectsFromArray:((UIWindowScene *)scene).windows];
            }
        }
    }
    UIViewController *messagesCtrl = nil;
    for (UIWindow *w in winList) {
        messagesCtrl = wamFindVCInHierarchy(w.rootViewController, messagesCtrlClass);
        if (messagesCtrl) break;
    }
    if (messagesCtrl && [messagesCtrl respondsToSelector:@selector(updateChatBackground)]) {
        gWAMTriggerNameOverride = name;
        [messagesCtrl performSelector:@selector(updateChatBackground)];
        gWAMTriggerNameOverride = nil;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        wamReconcileAliasFromTappedView(strongSelf);
    });
}

-(void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    if (isConvColorBgEnabled()) {
        self.contentView.backgroundColor = getCellColor();
    } else if (isConvImageBgEnabled()) {
        self.backgroundColor = [UIColor clearColor];
        self.contentView.backgroundColor = [UIColor clearColor];
        self.layer.backgroundColor = [UIColor clearColor].CGColor;
    } else {
        self.contentView.backgroundColor = [UIColor clearColor];
    }

    applyCustomTextColors(self);
}

%end

%hook UILabel

- (void)setTextColor:(UIColor *)color {
    if (!isTweakEnabled() || !isCustomTextColorsEnabled()) {
        %orig;
        return;
    }

    UIView *superview = self.superview;
    BOOL isInConversationCell = NO;
    while (superview) {
        if ([superview isKindOfClass:%c(CKConversationListCollectionViewConversationCell)]) {
            isInConversationCell = YES;
            break;
        }
        superview = superview.superview;
    }

    if (isInConversationCell) {
        if ([self isKindOfClass:%c(CKLabel)]) {
            %orig(getTitleTextColorConvList());
        } else if ([self isKindOfClass:%c(CKDateLabel)]) {
            %orig(getDateTimeTextColor());
        } else if ([self isKindOfClass:%c(UIDateLabel)]) {
            %orig(getDateTimeTextColor());
        } else if ([self isKindOfClass:[UILabel class]]) {
            %orig(getMessagePreviewTextColor());
        } else {
            %orig;
        }
        return;
    }

    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            UIColor *customTint = getAdvancedStatusCellColor();
            if (customTint) { %orig(customTint); return; }
            break;
        }
        if ([parent isKindOfClass:%c(CKTranscriptLabelCell)]) {
            UIColor *timestampColor = pickTimestampTextColor();
            if (timestampColor) { %orig(timestampColor); return; }
            break;
        }
        parent = parent.superview;
        levels++;
    }

    if ([self.text isEqualToString:@"Edited"] && [self.superview isKindOfClass:%c(_UISystemBackgroundView)]) {
        UIColor *customTint = getAdvancedStatusCellColor();
        if (customTint) { %orig(customTint); return; }
    }

    if ([self.text isEqualToString:@"Edited"]) {
        UIView *parent2 = self.superview;
        int levels2 = 0;
        while (parent2 && levels2 < 7) {
            if ([parent2 isKindOfClass:%c(CKTranscriptStatusCell)]) {
                UIColor *customTint = getAdvancedStatusCellColor();
                if (customTint) { %orig(customTint); return; }
                break;
            }
            parent2 = parent2.superview;
            levels2++;
        }
    }

    %orig;
}

- (void)setText:(NSString *)text {
    %orig;
    if (!isTweakEnabled()) return;

    NSString *chatName = gWAMCurrentContactName;
    if ([self isKindOfClass:%c(CKLabel)] && text.length && chatName.length &&
        [text isEqualToString:chatName]) {
        Class avatarTitleCls = %c(CKAvatarTitleCollectionReusableView);
        Class avatarNavBarCls = %c(CKAvatarNavigationBar);
        UIView *up = self.superview;
        int hops = 0;
        BOOL inAvatarPath = NO;
        while (up && hops < 12) {
            if ((avatarTitleCls && [up isKindOfClass:avatarTitleCls]) ||
                (avatarNavBarCls && [up isKindOfClass:avatarNavBarCls])) {
                inAvatarPath = YES;
                break;
            }
            up = up.superview;
            hops++;
        }
        if (inAvatarPath) {
            UIColor *nameColor = getChatContactNameColor();
            if (nameColor) {
                if (!objc_getAssociatedObject(self, &kWAMOrigTitleColorKey)) {
                    objc_setAssociatedObject(self, &kWAMOrigTitleColorKey,
                        self.textColor ?: (id)[NSNull null],
                        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
                self.textColor = nameColor;
                NSDictionary *attrs = @{
                    NSForegroundColorAttributeName: nameColor,
                    NSFontAttributeName: self.font ?: [UIFont systemFontOfSize:UIFont.labelFontSize]
                };
                NSAttributedString *colored = [[NSAttributedString alloc]
                    initWithString:text attributes:attrs];
                self.attributedText = colored;
                [self setNeedsDisplay];
            }
        }
    }

    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 7) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            UIColor *customTint = getAdvancedStatusCellColor();
            if (customTint) {
                if (self.attributedText) {
                    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];
                    [attrString addAttribute:NSForegroundColorAttributeName value:customTint range:NSMakeRange(0, attrString.length)];
                    self.attributedText = attrString;
                } else {
                    self.textColor = customTint;
                }
            }
            break;
        }
        parent = parent.superview;
        levels++;
    }
}

- (void)didMoveToSuperview {
    %orig;
    if (!isTweakEnabled()) return;
    NSString *chatName = gWAMCurrentContactName;
    NSString *text = self.text;
    if (chatName.length && text.length && [text isEqualToString:chatName]) {
        Class avatarTitleCls = %c(CKAvatarTitleCollectionReusableView);
        Class avatarNavBarCls = %c(CKAvatarNavigationBar);
        UIView *up = self.superview;
        int hops = 0;
        BOOL inAvatarPath = NO;
        while (up && hops < 12) {
            if ((avatarTitleCls && [up isKindOfClass:avatarTitleCls]) ||
                (avatarNavBarCls && [up isKindOfClass:avatarNavBarCls])) {
                inAvatarPath = YES;
                break;
            }
            up = up.superview;
            hops++;
        }
        if (inAvatarPath) {
            UIColor *nameColor = getChatContactNameColor();
            if (nameColor) {
                if (!objc_getAssociatedObject(self, &kWAMOrigTitleColorKey)) {
                    objc_setAssociatedObject(self, &kWAMOrigTitleColorKey,
                        self.textColor ?: (id)[NSNull null],
                        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
                self.textColor = nameColor;
            }
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;

    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 7) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            UIColor *customTint = getAdvancedStatusCellColor();
            if (customTint) {
                if (self.attributedText) {
                    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];
                    [attrString addAttribute:NSForegroundColorAttributeName value:customTint range:NSMakeRange(0, attrString.length)];
                    self.attributedText = attrString;
                } else {
                    self.textColor = customTint;
                }
            }
            break;
        }
        parent = parent.superview;
        levels++;
    }
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 7) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            UIColor *customTint = getAdvancedStatusCellColor();
            if (customTint) {
                if (self.attributedText) {
                    NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];
                    [attrString addAttribute:NSForegroundColorAttributeName value:customTint range:NSMakeRange(0, attrString.length)];
                    self.attributedText = attrString;
                } else {
                    self.textColor = customTint;
                }
            }
            break;
        }
        parent = parent.superview;
        levels++;
    }
}

%end

%hook UIImageView

- (void)setTintColor:(UIColor *)color {
    if (!isTweakEnabled() || !isCustomTextColorsEnabled()) {
        %orig;
        return;
    }

    if (self.tag == 88771) {
        UIColor *dotColor = getAdvancedUnreadDotColor();
        %orig(dotColor ?: color);
        return;
    }

    UIView *superview = self.superview;
    BOOL isInConversationCell = NO;
    while (superview) {
        if ([superview isKindOfClass:%c(CKConversationListCollectionViewConversationCell)]) {
            isInConversationCell = YES;
            break;
        }
        superview = superview.superview;
    }

    if (!isInConversationCell) { %orig; return; }
    %orig(getDateTimeTextColor());
}

- (void)setImage:(UIImage *)image {
    %orig;
    if (!isTweakEnabled() || !image) return;

    UIView *parent = self.superview;
    BOOL isUnreadIndicator = NO;
    int levels = 0;

    while (parent && levels < 10) {
        if (levels < 5 && ([parent isKindOfClass:%c(CKConversationListEmbeddedStandardTableViewCell)] ||
                           (isiOS15() && [parent isKindOfClass:%c(CKConversationListCollectionViewConversationCell)]))) {
            isUnreadIndicator = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }

    if (isUnreadIndicator) {
        CGSize imageSize = image.size;
        if (imageSize.width < 20 && imageSize.height < 20) {
            UIColor *customTint = getAdvancedUnreadDotColor();
            if (customTint) {
                UIImage *tintedImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                %orig(tintedImage);
                self.tag = 88771;
                self.tintColor = customTint;
            }
        }
        return;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            if (self.tag == 88771 && self.image) {
                refreshPrefs();
                UIImage *tintedImage = [self.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                self.image = tintedImage;
                self.tintColor = getAdvancedUnreadDotColor();
            }
        }
    }
}

%end

%hook _UIBarBackground

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    if (isModernNavBarEnabled() && self.window) {
        [self ensureBlurExists];
    }

    if (self.window) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(handleNavBarPrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    }
}

%new
- (BOOL)isBottomBar {
    CGRect frameInScreen = [self convertRect:self.bounds toView:nil];
    return frameInScreen.origin.y > [UIScreen mainScreen].bounds.size.height / 2.0;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    if (isModernNavBarEnabled()) {
        BOOL hasContactView = self.window ? [self findContactViewInWindow:self.window] : NO;
        BOOL bottom = [self isBottomBar];
        [self removeSystemViews];

        UIVisualEffectView *ourBlur = nil;
        for (UIView *sub in self.subviews) {
            if ([sub isKindOfClass:[UIVisualEffectView class]]) {
                UIVisualEffectView *blurView = (UIVisualEffectView *)sub;
                if ([blurView.layer.mask isKindOfClass:[CAGradientLayer class]]) {
                    ourBlur = blurView;
                    break;
                }
            }
        }

        if (ourBlur) {
            CGRect blurFrame = self.bounds;
            blurFrame.size.height += 70;
            blurFrame.origin.y = bottom ? -70 : (hasContactView ? 1000 : 0);
            ourBlur.frame = blurFrame;

            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            CAGradientLayer *maskLayer = (CAGradientLayer *)ourBlur.layer.mask;
            maskLayer.frame = ourBlur.bounds;
            [CATransaction commit];
        } else {
            [self createOurBlur];
            for (UIView *sub in self.subviews) {
                if ([sub isKindOfClass:[UIVisualEffectView class]] &&
                    [sub.layer.mask isKindOfClass:[CAGradientLayer class]]) {
                    ourBlur = (UIVisualEffectView *)sub;
                    break;
                }
            }
        }

        if (ourBlur) [self applyModernTintOverlay:ourBlur];

        self.backgroundColor = [UIColor clearColor];
        return;
    }

    if (!isNavBarCustomizationEnabled()) return;

    UIColor *tintColor = getNavBarTintColorForView(self);
    if (!tintColor) return;

    BOOL hasContactView = self.window ? [self findContactViewInWindow:self.window] : NO;
    if (hasContactView) { self.alpha = 0.0; return; }
    self.alpha = 1.0;

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            UIVisualEffectView *blurView = (UIVisualEffectView *)subview;
            for (UIView *blurSubview in blurView.subviews) {
                if ([blurSubview isKindOfClass:%c(_UIVisualEffectSubview)]) {
                    blurSubview.backgroundColor = [UIColor clearColor];
                }
            }

            UIView *tintOverlay = nil;
            for (UIView *contentSubview in blurView.contentView.subviews) {
                if ([contentSubview class] == [UIView class] && contentSubview.backgroundColor) {
                    CGFloat r1, g1, b1, a1, r2, g2, b2, a2;
                    if ([contentSubview.backgroundColor getRed:&r1 green:&g1 blue:&b1 alpha:&a1] &&
                        [tintColor getRed:&r2 green:&g2 blue:&b2 alpha:&a2]) {
                        if (fabs(r1-r2)<0.01 && fabs(g1-g2)<0.01 && fabs(b1-b2)<0.01) {
                            tintOverlay = contentSubview;
                            break;
                        }
                    }
                }
            }

            if (!tintOverlay) {
                tintOverlay = [[UIView alloc] initWithFrame:blurView.contentView.bounds];
                tintOverlay.userInteractionEnabled = NO;
                tintOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                [blurView.contentView addSubview:tintOverlay];
            }

            tintOverlay.backgroundColor = tintColor;
            tintOverlay.frame = blurView.contentView.bounds;
        }
    }
}

- (void)addSubview:(UIView *)view {
    if (!isTweakEnabled() || !isModernNavBarEnabled()) { %orig; return; }

    BOOL hasOurBlur = NO;
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]] &&
            [sub.layer.mask isKindOfClass:[CAGradientLayer class]]) {
            hasOurBlur = YES;
            break;
        }
    }

    if (hasOurBlur && ([view isKindOfClass:[UIVisualEffectView class]] ||
                       [view isKindOfClass:[UIImageView class]])) return;
    %orig;
}

- (void)setAlpha:(CGFloat)alpha {
    if (!isTweakEnabled() || isModernNavBarEnabled()) { %orig; return; }
    %orig;
}

%new
- (BOOL)findContactViewInWindow:(UIView *)view {
    if ([view isKindOfClass:NSClassFromString(@"CNContactView")]) return YES;
    for (UIView *subview in view.subviews) {
        if ([self findContactViewInWindow:subview]) return YES;
    }
    return NO;
}

%new
- (void)removeSystemViews {
    NSMutableArray *viewsToRemove = [NSMutableArray array];
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]]) {
            UIVisualEffectView *blurView = (UIVisualEffectView *)sub;
            if (![blurView.layer.mask isKindOfClass:[CAGradientLayer class]]) {
                [viewsToRemove addObject:sub];
            }
        } else if ([sub isKindOfClass:[UIImageView class]]) {
            [viewsToRemove addObject:sub];
        }
    }
    for (UIView *view in viewsToRemove) [view removeFromSuperview];
}

%new
- (void)removeOurModernBlur {
    for (UIView *sub in [self.subviews copy]) {
        if ([sub isKindOfClass:[UIVisualEffectView class]] &&
            [sub.layer.mask isKindOfClass:[CAGradientLayer class]]) {
            [sub removeFromSuperview];
        }
    }
}

%new
- (void)ensureBlurExists {
    [self removeSystemViews];
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]] &&
            [sub.layer.mask isKindOfClass:[CAGradientLayer class]]) return;
    }
    [self createOurBlur];
}

%new
- (void)createOurBlur {
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    CGRect blurFrame = self.bounds;

    BOOL bottom = [self isBottomBar];
    blurFrame.size.height += 70;
    blurFrame.origin.y = bottom ? -70 : 0;
    blurView.frame = blurFrame;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self insertSubview:blurView atIndex:0];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CAGradientLayer *maskLayer = [CAGradientLayer layer];
    maskLayer.frame = blurView.bounds;

    if (bottom) {
        maskLayer.colors = @[
            (id)[UIColor colorWithWhite:0 alpha:0.0].CGColor,
            (id)[UIColor colorWithWhite:0 alpha:0.10].CGColor,
            (id)[UIColor colorWithWhite:0 alpha:0.55].CGColor,
            (id)[UIColor colorWithWhite:0 alpha:0.9].CGColor,
            (id)[UIColor colorWithWhite:0 alpha:1.0].CGColor
        ];
        maskLayer.locations = @[@0.0, @0.15, @0.4, @0.7, @1.0];
    } else {
        maskLayer.colors = @[
            (id)[UIColor colorWithWhite:0 alpha:1.0].CGColor,
            (id)[UIColor colorWithWhite:0 alpha:0.9].CGColor,
            (id)[UIColor colorWithWhite:0 alpha:0.55].CGColor,
            (id)[UIColor colorWithWhite:0 alpha:0.10].CGColor,
            (id)[UIColor colorWithWhite:0 alpha:0.0].CGColor
        ];
        maskLayer.locations = @[@0.0, @0.3, @0.6, @0.85, @1.0];
    }

    maskLayer.actions = @{@"position":[NSNull null], @"bounds":[NSNull null], @"frame":[NSNull null]};
    blurView.layer.mask = maskLayer;
    [CATransaction commit];
}

%new
- (void)applyModernTintOverlay:(UIVisualEffectView *)blurView {
    static NSInteger const kModernTintOverlayTag = 88991;

    UIView *existingOverlay = nil;
    for (UIView *sub in blurView.contentView.subviews) {
        if (sub.tag == kModernTintOverlayTag) { existingOverlay = sub; break; }
    }

    if (!isNavBarCustomizationEnabled()) {
        if (existingOverlay) [existingOverlay removeFromSuperview];
        return;
    }

    UIColor *tintColor = getNavBarTintColorForView(self);
    if (!tintColor) {
        if (existingOverlay) [existingOverlay removeFromSuperview];
        return;
    }

    if (!existingOverlay) {
        existingOverlay = [[UIView alloc] initWithFrame:blurView.contentView.bounds];
        existingOverlay.tag = kModernTintOverlayTag;
        existingOverlay.userInteractionEnabled = NO;
        existingOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [blurView.contentView addSubview:existingOverlay];
    }
    existingOverlay.backgroundColor = tintColor;
    existingOverlay.frame = blurView.contentView.bounds;
}

%new
- (void)handleNavBarPrefsChanged {
    refreshPrefs();
    if (isModernNavBarEnabled()) {
        [self ensureBlurExists];
    } else {
        [self removeOurModernBlur];
    }
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

%end

%hook UINavigationController

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    UIViewController *result = %orig;
    if (isTweakEnabled() && [result isKindOfClass:%c(CKMessagesController)]) {
        gWAMCurrentContactName = nil;
        gWAMCurrentContactDisplayName = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
    }
    return result;
}

- (NSArray<UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated {
    NSArray<UIViewController *> *result = %orig;
    if (isTweakEnabled() && result.count) {
        for (UIViewController *vc in result) {
            if ([vc isKindOfClass:%c(CKMessagesController)]) {
                gWAMCurrentContactName = nil;
                gWAMCurrentContactDisplayName = nil;
                break;
            }
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
    }
    return result;
}

- (NSArray<UIViewController *> *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated {
    NSArray<UIViewController *> *result = %orig;
    if (isTweakEnabled() && result.count) {
        for (UIViewController *vc in result) {
            if ([vc isKindOfClass:%c(CKMessagesController)]) {
                gWAMCurrentContactName = nil;
                gWAMCurrentContactDisplayName = nil;
                break;
            }
        }
        [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
    }
    return result;
}

%end

%hook UINavigationBar

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    if (!isModernNavBarEnabled() && isNavBarCustomizationEnabled()) {
        for (UIView *subview in self.subviews) {
            if ([NSStringFromClass([subview class]) isEqualToString:@"_UIBarBackground"]) {
                for (UIView *bgSubview in subview.subviews) {
                    NSString *bgClassName = NSStringFromClass([bgSubview class]);
                    if ([bgClassName containsString:@"ShadowView"] ||
                        [bgClassName isEqualToString:@"UIImageView"]) {
                        bgSubview.hidden = YES;
                        bgSubview.alpha = 0.0;
                    }
                }
            }
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;

    if (!isModernNavBarEnabled() && isNavBarCustomizationEnabled()) {
        for (UIView *subview in self.subviews) {
            if ([NSStringFromClass([subview class]) isEqualToString:@"_UIBarBackground"]) {
                for (UIView *bgSubview in subview.subviews) {
                    NSString *bgClassName = NSStringFromClass([bgSubview class]);
                    if ([bgClassName containsString:@"ShadowView"] ||
                        [bgClassName isEqualToString:@"UIImageView"]) {
                        bgSubview.hidden = YES;
                        bgSubview.alpha = 0.0;
                    }
                }
            }
        }
    }

    if (self.window) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(handleNavBarPrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    }
}

%new
- (void)handleNavBarPrefsChanged {
    refreshPrefs();
    [self setNeedsLayout];
    [self layoutIfNeeded];
    for (UIView *subview in self.subviews) {
        [subview setNeedsLayout];
        [subview layoutIfNeeded];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook _UINavigationBarTitleControl

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    NSString *conversationListTitle = getConversationListTitle();
    UIColor *convListTitleColor = getConversationListTitleColor();
    NSString *chatName = gWAMCurrentContactName;
    UIColor *chatNameColor = chatName.length ? getChatContactNameColor() : nil;
    UIColor *tintColor = getSystemTintColor();

    NSCharacterSet *ws = [NSCharacterSet whitespaceAndNewlineCharacterSet];
    NSString *chatTrim = [chatName stringByTrimmingCharactersInSet:ws];
    void (^handle)(UILabel *) = ^(UILabel *label) {
        NSString *labelTrim = [label.text stringByTrimmingCharactersInSet:ws];
        BOOL isChatName = chatTrim.length && [labelTrim isEqualToString:chatTrim];
        BOOL isConvListTitle = !isChatName &&
            ([labelTrim isEqualToString:@"Messages"] || [labelTrim isEqualToString:conversationListTitle]);
        UIColor *target = nil;
        if (isChatName) target = chatNameColor;
        else if (isConvListTitle) target = convListTitleColor;
        else target = tintColor;
        if (isConvListTitle) label.text = conversationListTitle;
        if (target) {
            if (!objc_getAssociatedObject(label, &kWAMOrigTitleColorKey)) {
                objc_setAssociatedObject(label, &kWAMOrigTitleColorKey, label.textColor ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            label.textColor = target;
        } else {
            id orig = objc_getAssociatedObject(label, &kWAMOrigTitleColorKey);
            if (orig && orig != [NSNull null]) label.textColor = orig;
        }
    };

    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) handle((UILabel *)sub);
        if ([sub isKindOfClass:[UIView class]]) {
            for (UIView *subview in sub.subviews) {
                if ([subview isKindOfClass:[UILabel class]]) handle((UILabel *)subview);
            }
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    if (self.window) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(handleTitlePrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    }
}

%new
- (void)handleTitlePrefsChanged {
    refreshPrefs();
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook _UICollectionViewListSeparatorView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    self.hidden = isSeparatorsEnabled();
    self.alpha = isSeparatorsEnabled() ? 0.0 : 1.0;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    self.hidden = isSeparatorsEnabled();
    self.alpha = isSeparatorsEnabled() ? 0.0 : 1.0;
}

%end

%hook _UISearchBarSearchFieldBackgroundView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    self.hidden = isSearchBgEnabled();
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    self.hidden = isSearchBgEnabled();
}

%end

%hook CKPinnedConversationView

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    if (!isTweakEnabled() || !isPerContactChatBgEnabled()) return;
    UILabel *best = nil;
    CGFloat bestSize = 0;
    NSMutableArray *queue = [NSMutableArray arrayWithObject:(UIView *)self];
    while (queue.count > 0) {
        UIView *view = queue[0];
        [queue removeObjectAtIndex:0];
        if ([view isKindOfClass:[UILabel class]] && ![view isKindOfClass:%c(CKDateLabel)]) {
            UILabel *label = (UILabel *)view;
            if (label.text.length) {
                CGFloat sz = label.font.pointSize;
                if (sz > bestSize) { bestSize = sz; best = label; }
            }
        }
        for (UIView *sub in view.subviews) [queue addObject:sub];
    }
    NSString *captured = best.text;
    if (!captured.length) return;
    if ([captured isEqualToString:gWAMCurrentContactName]) return;
    gWAMCurrentContactName = [captured copy];
    gWAMCurrentContactDisplayName = [captured copy];
    gWAMCacheSetAt = [NSDate timeIntervalSinceReferenceDate];

    Class messagesCtrlClass = %c(CKMessagesController);
    if (!messagesCtrlClass) return;
    UIViewController *messagesCtrl = nil;
    NSMutableArray *ws = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                [ws addObjectsFromArray:((UIWindowScene *)scene).windows];
            }
        }
    }
    for (UIWindow *w in ws) {
        UIViewController *vc = w.rootViewController;
        while (vc) {
            if ([vc isKindOfClass:messagesCtrlClass]) { messagesCtrl = vc; break; }
            vc = vc.presentedViewController;
        }
        if (messagesCtrl) break;
    }
    if (messagesCtrl) {
        gWAMTriggerNameOverride = captured;
        [messagesCtrl performSelector:@selector(updateChatBackground)];
        gWAMTriggerNameOverride = nil;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        wamReconcileAliasFromTappedView(strongSelf);
    });
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyPinnedGlow];

    if (self.window) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(handlePinnedGlowPrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    }
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyPinnedGlow];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%new
- (void)handlePinnedGlowPrefsChanged {
    refreshPrefs();
    if (isPinnedGlowEnabled()) {
        [self applyPinnedGlow];
    } else {
        for (UIView *sub in self.subviews) {
            if (![sub isKindOfClass:[UIImageView class]]) continue;
            UIImageView *img = (UIImageView *)sub;
            img.hidden = NO;
            img.alpha = 1.0;
        }
    }
}

%new
- (void)applyPinnedGlow {
    if (!isPinnedGlowEnabled()) return;
    for (UIView *sub in self.subviews) {
        if (![sub isKindOfClass:[UIImageView class]]) continue;
        UIImageView *img = (UIImageView *)sub;
        img.hidden = YES;
        img.alpha = 0.0;
    }
}

%end

%hook CKTranscriptCollectionViewController

- (void)viewDidLoad {
    %orig;
    self.view.backgroundColor = [UIColor clearColor];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handleTranscriptPrefsChanged)
        name:kPrefsChangedNotification
        object:nil];
}

%new
- (void)handleTranscriptPrefsChanged {
    refreshPrefs();
    UICollectionView *cv = nil;
    @try { cv = [self valueForKey:@"collectionView"]; } @catch (NSException *e) {}
    if (!cv) @try { cv = [self valueForKey:@"_collectionView"]; } @catch (NSException *e) {}
    if (cv) {
        for (UICollectionViewCell *cell in [cv.visibleCells copy]) {
            [cell setNeedsLayout];
            [cell layoutIfNeeded];
        }
        [cv reloadData];
    }
}

-(BOOL)shouldUseOpaqueMask {
    return NO;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            UICollectionView *cv = nil;
            @try { cv = [self valueForKey:@"collectionView"]; } @catch (NSException *e) {}
            if (!cv) @try { cv = [self valueForKey:@"_collectionView"]; } @catch (NSException *e) {}
            if (cv) {
                [cv reloadData];
                [cv layoutIfNeeded];
            }
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook CKGradientReferenceView

-(void)setFrame:(CGRect)arg1 {
    %orig;
    self.backgroundColor = [UIColor clearColor];
}

%end

%hook CKMessagesController

-(void)viewDidLoad {
    %orig;
    if (!isTweakEnabled()) return;

    self.view.backgroundColor = [UIColor clearColor];
    [self updateChatBackground];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handleChatPrefsChanged)
        name:kPrefsChangedNotification
        object:nil];

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handleAppDidBecomeActiveForBg)
        name:UIApplicationDidBecomeActiveNotification
        object:nil];
}

%new
-(void)handleAppDidBecomeActiveForBg {
    if (!isTweakEnabled()) return;
    [self updateChatBackground];
}


%new
-(void)handleChatPrefsChanged {
    refreshPrefs();
    [self updateChatBackground];

    id transcriptController = nil;
    @try { transcriptController = [self valueForKey:@"_transcriptController"]; } @catch (NSException *e) {}
    if (transcriptController) {
        UICollectionView *collectionView = nil;
        @try { collectionView = [transcriptController valueForKey:@"collectionView"]; } @catch (NSException *e) {}
        if (collectionView) {
            [collectionView reloadData];
            [collectionView layoutIfNeeded];
        }
    }
}

%new
-(void)forceRedrawCell:(UIView *)view {
    if ([view isKindOfClass:%c(CKGradientView)]) {
        [view setNeedsLayout];
        [view layoutIfNeeded];
    }
    if ([view isKindOfClass:%c(CKBalloonTextView)]) {
        [(CKBalloonTextView *)view updateTextColorForBalloon];
        [view setNeedsDisplay];
    }
    if ([view isKindOfClass:[UILabel class]]) {
        [view setNeedsDisplay];
    }
    for (UIView *subview in view.subviews) {
        [self forceRedrawCell:subview];
    }
}

%new
-(void)updateChatBackground {
    static const char kBgStateKey = 0;

    NSString *desiredState = nil;
    BOOL useColor = isChatColorBgEnabled();
    NSString *desiredPath = nil;

    if (useColor) {
        UIColor *c = getChatBackgroundColor();
        CGFloat r = 0, g = 0, b = 0, a = 0;
        if (c) [c getRed:&r green:&g blue:&b alpha:&a];
        desiredState = [NSString stringWithFormat:@"color:%.3f,%.3f,%.3f,%.3f", r, g, b, a];
    } else if (shouldShowAnyChatBgImage()) {
        desiredPath = getChatImagePath();
        CGFloat blur = getEffectiveChatBgBlur();
        NSDictionary *attrs = desiredPath ? [[NSFileManager defaultManager] attributesOfItemAtPath:desiredPath error:nil] : nil;
        NSTimeInterval mtime = [(NSDate *)attrs[NSFileModificationDate] timeIntervalSince1970];
        desiredState = [NSString stringWithFormat:@"img:%@|%.2f|%.0f", desiredPath ?: @"", blur, mtime];
    }

    NSString *currentState = objc_getAssociatedObject(self.view, &kBgStateKey);

    if (!desiredState && !currentState) {
        return;
    }

    if (desiredState && [desiredState isEqualToString:currentState]) {
        return;
    }

    if (!desiredState) {
        if (!isChatImageBgEnabled() && !isPerContactChatBgEnabled() && !isChatColorBgEnabled()) {
            for (UIView *sub in [self.view.subviews copy]) {
                if (sub.tag == 4321) [sub removeFromSuperview];
            }
            objc_setAssociatedObject(self.view, &kBgStateKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
        } else {
        }
        return;
    }

    for (UIView *sub in [self.view.subviews copy]) {
        if (sub.tag == 4321) [sub removeFromSuperview];
    }

    if (useColor) {
        UIView *colorView = [[UIView alloc] initWithFrame:self.view.bounds];
        colorView.backgroundColor = getChatBackgroundColor();
        colorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        colorView.tag = 4321;
        [self.view insertSubview:colorView atIndex:0];
        objc_setAssociatedObject(self.view, &kBgStateKey, desiredState, OBJC_ASSOCIATION_COPY_NONATOMIC);
        return;
    }

    UIImage *chatBgImage = loadImageUncached(desiredPath);
    if (!chatBgImage) {
        WAMLOG(@"  loaded=NO path=%@", desiredPath);
        return;
    }

    CGFloat blurAmount = getEffectiveChatBgBlur();
    if (blurAmount > 0) chatBgImage = blurImage(chatBgImage, blurAmount);

    UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    imageView.image = chatBgImage;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    imageView.tag = 4321;
    [self.view insertSubview:imageView atIndex:0];
    objc_setAssociatedObject(self.view, &kBgStateKey, desiredState, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

%new
- (NSArray *)getAllSubviews:(UIView *)view {
    NSMutableArray *allSubviews = [NSMutableArray array];
    [allSubviews addObject:view];
    for (UIView *subview in view.subviews) {
        [allSubviews addObjectsFromArray:[self getAllSubviews:subview]];
    }
    return allSubviews;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            if (isiOS15()) updateDarkModeFromTraits(self.traitCollection);
            refreshPrefs();
            [self updateChatBackground];
        }
    }
}

-(void)viewWillAppear:(BOOL)animated {
    %orig;
    if (isiOS15()) updateDarkModeFromTraits(self.traitCollection);
    gWAMChatIsActiveSurface = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
}

- (void)setCurrentConversation:(id)conversation {
    %orig;
    [self wamHandleConversationChanged:conversation];
}

- (void)_setCurrentConversation:(id)conversation {
    %orig;
    [self wamHandleConversationChanged:conversation];
}

%new
- (void)wamHandleConversationChanged:(id)conversation {
    if (!isTweakEnabled()) return;
    if (!conversation) return;
    if (!isPerContactChatBgEnabled()) return;

    NSString *name = nil;
    NSString *cid = nil;
    Ivar ch = class_getInstanceVariable([conversation class], "_chat");
    id chat = ch ? object_getIvar(conversation, ch) : nil;
    if ([chat respondsToSelector:@selector(displayName)]) {
        NSString *dn = [chat performSelector:@selector(displayName)];
        if ([dn isKindOfClass:[NSString class]] && dn.length) name = dn;
    }
    if (!name.length) {
        static const char *nameIvars[] = {"_name", "_displayName", "_groupName", NULL};
        for (int i = 0; nameIvars[i]; i++) {
            Ivar v = class_getInstanceVariable([conversation class], nameIvars[i]);
            if (!v) continue;
            id val = object_getIvar(conversation, v);
            if ([val isKindOfClass:[NSString class]] && [(NSString *)val length]) { name = val; break; }
        }
    }
    if ([chat respondsToSelector:@selector(chatIdentifier)]) {
        NSString *c = [chat performSelector:@selector(chatIdentifier)];
        if ([c isKindOfClass:[NSString class]] && c.length) cid = c;
    }
    if (!name.length) return;
    if (cid.length) wamReconcileAliasForChat(cid, name);
    gWAMCurrentContactName = [name copy];
    gWAMCurrentContactDisplayName = [name copy];
    gWAMTriggerNameOverride = name;
    [self updateChatBackground];
    gWAMTriggerNameOverride = nil;
    [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
    NSMutableArray *winList = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                [winList addObjectsFromArray:((UIWindowScene *)scene).windows];
            }
        }
    }
    for (UIWindow *w in winList) {
        UIView *navBar = nil;
        NSMutableArray *queue = [NSMutableArray arrayWithObject:w];
        while (queue.count) {
            UIView *v = queue.firstObject;
            [queue removeObjectAtIndex:0];
            if ([v isKindOfClass:[UINavigationBar class]]) { navBar = v; break; }
            [queue addObjectsFromArray:v.subviews];
        }
        if (navBar) {
            [navBar tintColorDidChange];
        }
    }
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%new
- (void)wamClearChatAndForceRefresh {
    if (gWAMChatIsActiveSurface) {
        gWAMChatIsActiveSurface = NO;
        gWAMCurrentContactName = nil;
        gWAMCurrentContactDisplayName = nil;
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
    Class listCls = %c(CKConversationListCollectionViewController);
    NSMutableArray *winList = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                [winList addObjectsFromArray:((UIWindowScene *)scene).windows];
            }
        }
    }
    for (UIWindow *w in winList) {
        if (listCls) {
            UIViewController *listVC = wamFindVCInHierarchy(w.rootViewController, listCls);
            if (listVC && [listVC respondsToSelector:@selector(handlePrefsChanged)]) {
                [listVC performSelector:@selector(handlePrefsChanged)];
            }
        }
        wamForceVisualRefresh(w);
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    %orig;
    if (!isTweakEnabled()) return;
    if (self.isMovingFromParentViewController || self.isBeingDismissed) {
        [self wamClearChatAndForceRefresh];
    }
}

- (void)didMoveToParentViewController:(UIViewController *)parent {
    %orig;
    if (!isTweakEnabled()) return;
    if (!parent) {
        [self wamClearChatAndForceRefresh];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    if (isTweakEnabled() && (self.isMovingFromParentViewController || self.isBeingDismissed)) {
        gWAMChatIsActiveSurface = NO;
        gWAMCurrentContactName = nil;
        gWAMCurrentContactDisplayName = nil;
        [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
        for (int i = 1; i <= 5; i++) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(i * 0.1 * NSEC_PER_SEC)),
                           dispatch_get_main_queue(), ^{
                [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
                Class listCls = %c(CKConversationListCollectionViewController);
                if (!listCls) return;
                NSMutableArray *winList = [NSMutableArray array];
                if (@available(iOS 13.0, *)) {
                    for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
                        if ([scene isKindOfClass:[UIWindowScene class]]) {
                            [winList addObjectsFromArray:((UIWindowScene *)scene).windows];
                        }
                    }
                }
                for (UIWindow *w in winList) {
                    UIViewController *listVC = wamFindVCInHierarchy(w.rootViewController, listCls);
                    if (listVC && [listVC respondsToSelector:@selector(handlePrefsChanged)]) {
                        [listVC performSelector:@selector(handlePrefsChanged)];
                    }
                }
            });
        }
    }
    %orig;
}

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!isTweakEnabled()) return;
    [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
    [self wamRetryBgRefresh:0];
}

%new
- (void)wamRetryBgRefresh:(int)attempt {
    if (!isTweakEnabled()) return;
    UINavigationController *nav = self.navigationController;
    if (nav && ![nav.viewControllers containsObject:self]) return;
    [self updateChatBackground];
    NSTimeInterval delay;
    if (attempt < 6)       delay = 0.05;
    else if (attempt < 21) delay = 0.2;
    else                   delay = 0.5;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf wamRetryBgRefresh:attempt + 1];
    });
}

%end

%hook CKGradientView

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) return;
    if (self.frame.size.width <= 0 || self.frame.size.height <= 0) return;

    BOOL isReaction = [self.superview isKindOfClass:objc_getClass("CKAggregateAcknowledgmentBalloonView")];
    if (isReaction) { self.hidden = YES; return; }

    UIColor *bubbleColor = getSentBubbleColor();
    UIView *parent = self.superview;
    while (parent) {
        if ([parent isKindOfClass:objc_getClass("CKColoredBalloonView")]) {
            CKColoredBalloonView *balloon = (CKColoredBalloonView *)parent;
            if (balloon.color == -1) bubbleColor = getReceivedBubbleColor();
            else if (balloon.color == 1) bubbleColor = getSentBubbleColor();
            else if (balloon.color == 0) bubbleColor = getSMSSentBubbleColor();
            break;
        }
        parent = parent.superview;
    }

    [self setColors:@[bubbleColor, bubbleColor]];
}

- (void)setColors:(NSArray *)colors {
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) { %orig; return; }

    BOOL isReaction = [self.superview isKindOfClass:objc_getClass("CKAggregateAcknowledgmentBalloonView")];
    if (isReaction) { self.hidden = YES; return; }

    UIColor *bubbleColor = getSentBubbleColor();
    UIView *parent = self.superview;
    while (parent) {
        if ([parent isKindOfClass:objc_getClass("CKColoredBalloonView")]) {
            CKColoredBalloonView *balloon = (CKColoredBalloonView *)parent;
            if (balloon.color == -1) bubbleColor = getReceivedBubbleColor();
            else if (balloon.color == 1) bubbleColor = getSentBubbleColor();
            else if (balloon.color == 0) bubbleColor = getSMSSentBubbleColor();
            break;
        }
        parent = parent.superview;
    }

    %orig(@[bubbleColor, bubbleColor]);
}

%end

%hook CKBalloonImageView

- (void)setImage:(UIImage *)image {
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !image) { %orig; return; }
    if ([self isKindOfClass:%c(CKColoredBalloonView)]) {
        CKColoredBalloonView *coloredSelf = (CKColoredBalloonView *)self;
        UIColor *targetColor = nil;
        BOOL applyReceivedInsets = NO;
        if (coloredSelf.color == -1) {
            targetColor = getReceivedBubbleColor();
            applyReceivedInsets = YES;
        } else if (coloredSelf.color == 1) {
            targetColor = getSentBubbleColor();
        } else if (coloredSelf.color == 0) {
            targetColor = getSMSSentBubbleColor();
        }
        if (targetColor) {
            UIImageRenderingMode originalMode = image.renderingMode;
            UIEdgeInsets capInsets = image.capInsets;
            UIImageResizingMode resizingMode = image.resizingMode;
            UIEdgeInsets alignmentInsets = image.alignmentRectInsets;
            CGFloat scale = image.scale;

            UIGraphicsBeginImageContextWithOptions(image.size, NO, scale);
            CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
            [image drawInRect:rect];
            CGContextRef context = UIGraphicsGetCurrentContext();
            CGContextSetBlendMode(context, kCGBlendModeSourceIn);
            [targetColor setFill];
            CGContextFillRect(context, rect);
            UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
            UIGraphicsEndImageContext();

            if (applyReceivedInsets) {
                alignmentInsets.left += 6.0;
                alignmentInsets.right -= 8.0;
            }
            tintedImage = [tintedImage resizableImageWithCapInsets:capInsets resizingMode:resizingMode];
            tintedImage = [tintedImage imageWithAlignmentRectInsets:alignmentInsets];
            tintedImage = [tintedImage imageWithRenderingMode:originalMode];
            %orig(tintedImage);
            return;
        }
    }
    %orig;
}

%end

%hook CKBalloonTextView

- (void)didMoveToSuperview {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !self.superview) return;
    [self updateTextColorForBalloon];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) return;
    [self updateTextColorForBalloon];
}

- (void)setText:(NSString *)text {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) return;
    [self updateTextColorForBalloon];
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) return;
    [self updateTextColorForBalloon];
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !self.window) return;
    [self updateTextColorForBalloon];
}

- (void)setTextColor:(UIColor *)textColor {
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) { %orig; return; }

    NSNumber *isUpdating = objc_getAssociatedObject(self, @selector(setTextColor:));
    if (isUpdating && [isUpdating boolValue]) { %orig; return; }

    UIColor *customTextColor = [self getCustomTextColor];
    if (customTextColor && ![textColor isEqual:customTextColor]) {
        objc_setAssociatedObject(self, @selector(setTextColor:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        %orig(customTextColor);
        objc_setAssociatedObject(self, @selector(setTextColor:), @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    %orig;
}

- (void)setTintColor:(UIColor *)tintColor {
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) { %orig; return; }

    NSNumber *isUpdating = objc_getAssociatedObject(self, @selector(setTintColor:));
    if (isUpdating && [isUpdating boolValue]) { %orig; return; }

    UIColor *customTextColor = [self getCustomTextColor];
    if (customTextColor && ![tintColor isEqual:customTextColor]) {
        objc_setAssociatedObject(self, @selector(setTintColor:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        %orig(customTextColor);
        objc_setAssociatedObject(self, @selector(setTintColor:), @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        return;
    }
    %orig;
}

%new
- (UIColor *)getCustomTextColor {
    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 10) {
        NSString *className = NSStringFromClass([parent class]);
        if ([className containsString:@"Reply"] || [className containsString:@"reply"]) {
            return getSystemTintColor();
        }
        parent = parent.superview;
        levels++;
    }

    parent = self.superview;
    levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKColoredBalloonView)]) {
            CKColoredBalloonView *balloonView = (CKColoredBalloonView *)parent;
            if (balloonView.color == -1) return getReceivedTextColor();
            else if (balloonView.color == 1) return getSentTextColor();
            else if (balloonView.color == 0) return getSMSSentTextColor();
            break;
        }
        parent = parent.superview;
        levels++;
    }
    return nil;
}

%new
- (void)updateTextColorForBalloon {
    UIColor *textColor = [self getCustomTextColor];
    if (textColor) {
        objc_setAssociatedObject(self, @selector(setTextColor:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, @selector(setTintColor:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        self.textColor = textColor;
        self.tintColor = textColor;
        self.linkTextAttributes = @{
            NSForegroundColorAttributeName: textColor,
            NSUnderlineStyleAttributeName: @(NSUnderlineStyleSingle)
        };
        objc_setAssociatedObject(self, @selector(setTextColor:), @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, @selector(setTintColor:), @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%end

%hook CKTranscriptStatusCell

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) return;

    UIColor *timestampColor = pickTimestampTextColor();
    if (!timestampColor) return;

    for (UIView *subview in self.contentView.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            ((UILabel *)subview).textColor = timestampColor;
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    if (self.window) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(handleTimestampPrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    }
}

%new
- (void)handleTimestampPrefsChanged {
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook CKTranscriptLabelCell

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) return;

    UIViewController *vc = [self _viewControllerForAncestor];
    if (![vc isKindOfClass:%c(CKTranscriptCollectionViewController)]) return;

    UIColor *timestampColor = pickTimestampTextColor();
    if (!timestampColor) return;

    for (UIView *subview in self.contentView.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            ((UILabel *)subview).textColor = timestampColor;
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    if (self.window) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(handleTimestampPrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    }
}

%new
- (void)handleTimestampPrefsChanged {
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook _UIVisualEffectBackdropView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    if (!self.window) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        return;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(wamHandleBackdropPrefsChanged)
        name:kPrefsChangedNotification
        object:nil];
}

%new
- (void)wamHandleBackdropPrefsChanged {
    UIView *p = self.superview;
    int lvl = 0;
    while (p && lvl < 15) {
        if ([p isKindOfClass:%c(CKMessageEntryView)]) {
            [self setNeedsLayout];
            [self layoutIfNeeded];
            return;
        }
        p = p.superview;
        lvl++;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    UIView *parent = self.superview;
    UIVisualEffectView *effectView = nil;
    BOOL isInMessageInput = NO;
    BOOL isInKeyboard = NO;
    BOOL isInAudioRecording = NO;
    int levels = 0;

    while (parent && levels < 15) {
         if ([parent isKindOfClass:[UIVisualEffectView class]] && !effectView) {
            if (objc_getAssociatedObject(parent, &kWAMInputFieldBlurKey)) return;
            effectView = (UIVisualEffectView *)parent;
        }
        if ([parent isKindOfClass:%c(UIKBVisualEffectView)] ||
            [parent isKindOfClass:%c(UIKBBackdropView)] ||
            [parent isKindOfClass:%c(UIInputView)] ||
            [NSStringFromClass([parent class]) containsString:@"Keyboard"]) {
            isInKeyboard = YES;
            break;
        }
        NSString *parentClassName = NSStringFromClass([parent class]);
        if ([parentClassName containsString:@"Audio"] ||
            [parentClassName containsString:@"Recording"] ||
            [parentClassName containsString:@"Waveform"]) {
            isInAudioRecording = YES;
            break;
        }
        if ([parent isKindOfClass:%c(CKMessageEntryView)]) isInMessageInput = YES;
        if ([parent isKindOfClass:%c(CKSearchResultsTitleHeaderCell)] && isModernNavBarEnabled()) {
            self.hidden = YES;
        }
        parent = parent.superview;
        levels++;
    }

    parent = self.superview;
    BOOL isInActionView = NO;
    BOOL isInContactView = NO;
    levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:NSClassFromString(@"CNActionView")]) isInActionView = YES;
        if ([parent isKindOfClass:NSClassFromString(@"CNContactView")]) isInContactView = YES;
        parent = parent.superview;
        levels++;
    }
    if (isInActionView && isInContactView) { self.hidden = YES; return; }
    if (isInAudioRecording && isiOS15()) return;

    if (!isInMessageInput || isInKeyboard || !effectView) return;

    if (!isModernMessageBarEnabled()) {
        if ([self.layer.mask isKindOfClass:[CAGradientLayer class]]) self.layer.mask = nil;
        for (CALayer *sub in [self.layer.sublayers copy]) {
            if ([sub.name isEqualToString:@"wamModernMsgBarTint"]) [sub removeFromSuperlayer];
        }
        NSNumber *lastExpandedH = objc_getAssociatedObject(effectView, &kWAMEffectExpandedKey);
        if (lastExpandedH) {
            CGFloat const kWAMBarExpansion = 110;
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            CGRect shrunkFrame = effectView.frame;
            shrunkFrame.origin.y += kWAMBarExpansion;
            shrunkFrame.size.height -= kWAMBarExpansion;
            effectView.frame = shrunkFrame;
            [CATransaction commit];
            objc_setAssociatedObject(effectView, &kWAMEffectExpandedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }

    if (isModernMessageBarEnabled()) {
        effectView.backgroundColor = [UIColor clearColor];
        effectView.contentView.backgroundColor = [UIColor clearColor];
        effectView.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        if (!effectView.effect) effectView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];

        CGFloat const kWAMBarExpansion = 110;
        NSNumber *lastExpandedH = objc_getAssociatedObject(effectView, &kWAMEffectExpandedKey);
        CGFloat curH = effectView.frame.size.height;
        BOOL needsExpand = !lastExpandedH || curH < lastExpandedH.floatValue - (kWAMBarExpansion / 2);
        if (needsExpand) {
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            CGRect expandedFrame = effectView.frame;
            expandedFrame.origin.y -= kWAMBarExpansion;
            expandedFrame.size.height += kWAMBarExpansion;
            effectView.frame = expandedFrame;
            [CATransaction commit];
            objc_setAssociatedObject(effectView, &kWAMEffectExpandedKey, @(expandedFrame.size.height), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

        self.alpha = 1.0;
        CAGradientLayer *maskLayer = [CAGradientLayer layer];
        maskLayer.frame = self.bounds;
        maskLayer.colors = @[
            (id)[UIColor colorWithWhite:0 alpha:0.0].CGColor,
            (id)[UIColor colorWithWhite:0 alpha:0.10].CGColor,
            (id)[UIColor colorWithWhite:0 alpha:0.55].CGColor,
            (id)[UIColor colorWithWhite:0 alpha:0.9].CGColor,
            (id)[UIColor colorWithWhite:0 alpha:1.0].CGColor
        ];
        maskLayer.locations = @[@0.0, @0.3, @0.6, @0.85, @1.0];
        self.layer.mask = maskLayer;

        static NSString * const kWAMModernMsgBarTintName = @"wamModernMsgBarTint";
        CALayer *tintLayer = nil;
        for (CALayer *sublayer in self.layer.sublayers) {
            if ([sublayer.name isEqualToString:kWAMModernMsgBarTintName]) { tintLayer = sublayer; break; }
        }
        UIColor *msgBarTint = isMessageBarCustomizationEnabled() ? getMessageBarTintColor() : nil;
        if (msgBarTint) {
            if (!tintLayer) {
                tintLayer = [CALayer layer];
                tintLayer.name = kWAMModernMsgBarTintName;
                [self.layer addSublayer:tintLayer];
            }
            [CATransaction begin];
            [CATransaction setDisableActions:YES];
            tintLayer.frame = self.bounds;
            tintLayer.backgroundColor = msgBarTint.CGColor;
            [CATransaction commit];
        } else if (tintLayer) {
            [tintLayer removeFromSuperlayer];
        }
        return;
    }

    if (isiOS15() && effectView && (!isMessageBarCustomizationEnabled() || !getMessageBarTintColor())) {
        NSMutableArray *stale = [NSMutableArray array];
        for (UIView *sub in effectView.contentView.subviews) {
            if ([sub class] == [UIView class] && sub.backgroundColor) [stale addObject:sub];
        }
        for (UIView *sub in stale) [sub removeFromSuperview];
        self.layer.mask = nil;
        return;
    }

    if (!isMessageBarCustomizationEnabled()) return;

    UIColor *tintColor = getMessageBarTintColor();
    if (!tintColor) return;

    self.layer.mask = nil;
    for (UIView *subview in effectView.subviews) {
        if ([subview isKindOfClass:%c(_UIVisualEffectSubview)]) {
            subview.backgroundColor = [UIColor clearColor];
        }
    }

    if (effectView) {
        UIView *tintOverlay = nil;
        if (isiOS15()) {
            NSMutableArray *stale = [NSMutableArray array];
            for (UIView *sub in effectView.contentView.subviews) {
                if ([sub class] == [UIView class] && sub.backgroundColor) [stale addObject:sub];
            }
            for (UIView *sub in stale) [sub removeFromSuperview];
        } else {
            for (UIView *contentSubview in effectView.contentView.subviews) {
                if ([contentSubview class] == [UIView class] && contentSubview.backgroundColor) {
                    CGFloat r1, g1, b1, a1, r2, g2, b2, a2;
                    if ([contentSubview.backgroundColor getRed:&r1 green:&g1 blue:&b1 alpha:&a1] &&
                        [tintColor getRed:&r2 green:&g2 blue:&b2 alpha:&a2]) {
                        if (fabs(r1-r2)<0.01 && fabs(g1-g2)<0.01 && fabs(b1-b2)<0.01) {
                            tintOverlay = contentSubview;
                            break;
                        }
                    }
                }
            }
        }
        if (!tintOverlay) {
            tintOverlay = [[UIView alloc] initWithFrame:effectView.contentView.bounds];
            tintOverlay.userInteractionEnabled = NO;
            tintOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [effectView.contentView addSubview:tintOverlay];
        }
        tintOverlay.backgroundColor = tintColor;
        tintOverlay.frame = effectView.contentView.bounds;
    }
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    %orig;
    if (!newSuperview || !isTweakEnabled() || !isModernMessageBarEnabled()) return;

    UIView *parent = newSuperview;
    UIVisualEffectView *effectView = nil;
    BOOL isInMessageInput = NO;
    BOOL isInKeyboard = NO;
    BOOL isInAudioRecording = NO;
    int levels = 0;

    while (parent && levels < 15) {
        if ([parent isKindOfClass:[UIVisualEffectView class]] && !effectView) {
            effectView = (UIVisualEffectView *)parent;
        }
        if ([parent isKindOfClass:%c(UIKBVisualEffectView)] ||
            [parent isKindOfClass:%c(UIInputView)] ||
            [NSStringFromClass([parent class]) containsString:@"Keyboard"]) {
            isInKeyboard = YES;
            break;
        }
        NSString *parentClassName = NSStringFromClass([parent class]);
        if ([parentClassName containsString:@"Audio"] ||
            [parentClassName containsString:@"Recording"] ||
            [parentClassName containsString:@"Waveform"]) {
            isInAudioRecording = YES;
            break;
        }
        if ([parent isKindOfClass:%c(CKMessageEntryView)]) isInMessageInput = YES;
        parent = parent.superview;
        levels++;
    }

    if (isInAudioRecording && isiOS15()) return;
    if (!isInMessageInput || isInKeyboard || !effectView) return;

    effectView.opaque = NO;
    effectView.backgroundColor = [UIColor clearColor];
    effectView.contentView.backgroundColor = [UIColor clearColor];
    if (!effectView.effect) effectView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled() || !isModernMessageBarEnabled()) { %orig; return; }

    UIView *parent = self.superview;
    BOOL isInMessageInput = NO;
    BOOL isInKeyboard = NO;
    BOOL isInAudioRecording = NO;
    int levels = 0;

    while (parent && levels < 15) {
        NSString *className = NSStringFromClass([parent class]);
        if ([className containsString:@"Keyboard"] ||
            [className isEqualToString:@"UIKBVisualEffectView"] ||
            [className isEqualToString:@"UIInputView"]) {
            isInKeyboard = YES;
            break;
        }
        if ([className containsString:@"Audio"] ||
            [className containsString:@"Recording"] ||
            [className containsString:@"Waveform"]) {
            isInAudioRecording = YES;
            break;
        }
        if ([className isEqualToString:@"CKMessageEntryView"]) isInMessageInput = YES;
        parent = parent.superview;
        levels++;
    }

    if (isInAudioRecording && isiOS15()) { %orig; return; }
    if (isInMessageInput && !isInKeyboard) { %orig([UIColor clearColor]); return; }
    %orig;
}

%end

%hook _UIVisualEffectContentView

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isModernMessageBarEnabled()) return;

    UIView *parent = self.superview;
    BOOL isInMessageInput = NO;
    BOOL isInKeyboard = NO;
    int levels = 0;

    while (parent && levels < 15) {
        if ([parent isKindOfClass:%c(UIKBVisualEffectView)] ||
            [parent isKindOfClass:%c(UIInputView)] ||
            [NSStringFromClass([parent class]) containsString:@"Keyboard"]) {
            isInKeyboard = YES; break;
        }
        if ([parent isKindOfClass:%c(CKMessageEntryView)]) isInMessageInput = YES;
        parent = parent.superview;
        levels++;

        if ([NSStringFromClass([parent class]) isEqualToString:@"CNActionView"]) {
            for (UIView *subview in self.subviews) {
                if ([subview class] == [UIView class]) {
                    subview.backgroundColor = [UIColor clearColor];
                }
            }
        }
    }

    if (isInMessageInput && !isInKeyboard) {
        self.backgroundColor = [UIColor clearColor];
        self.layer.mask = nil;
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled() || !isModernMessageBarEnabled()) { %orig; return; }

    UIView *parent = self.superview;
    BOOL isInMessageInput = NO;
    BOOL isInKeyboard = NO;
    int levels = 0;

    while (parent && levels < 15) {
        if ([parent isKindOfClass:%c(UIKBVisualEffectView)] ||
            [parent isKindOfClass:%c(UIInputView)] ||
            [NSStringFromClass([parent class]) containsString:@"Keyboard"]) {
            isInKeyboard = YES; break;
        }
        if ([parent isKindOfClass:%c(CKMessageEntryView)]) isInMessageInput = YES;
        parent = parent.superview;
        levels++;

        if ([NSStringFromClass([parent class]) isEqualToString:@"CNActionView"]) {
            for (UIView *subview in self.subviews) {
                if ([subview class] == [UIView class]) {
                    subview.backgroundColor = [UIColor clearColor];
                }
            }
        }
    }

    if (isInMessageInput && !isInKeyboard) { %orig([UIColor clearColor]); return; }
    %orig;
}

%end

%hook _UIVisualEffectSubview

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled() || !isModernMessageBarEnabled()) { %orig; return; }

    UIView *parent = self.superview;
    BOOL isInMessageInput = NO;
    BOOL isInKeyboard = NO;
    int levels = 0;

    while (parent && levels < 15) {
        NSString *className = NSStringFromClass([parent class]);
        if ([className containsString:@"Keyboard"] ||
            [className isEqualToString:@"UIKBVisualEffectView"] ||
            [className isEqualToString:@"UIInputView"]) {
            isInKeyboard = YES; break;
        }
        if ([className isEqualToString:@"CKMessageEntryView"]) isInMessageInput = YES;
        if ([className isEqualToString:@"_UIBarBackground"]) self.alpha = 0.0;
        if ([className isEqualToString:@"CNActionView"]) {
            %orig([UIColor clearColor]);
            return;
        }
        parent = parent.superview;
        levels++;
    }

    if (isInMessageInput && !isInKeyboard) { %orig([UIColor clearColor]); return; }
    %orig;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isModernMessageBarEnabled()) return;

    UIView *parent = self.superview;
    BOOL isInMessageInput = NO;
    BOOL isInKeyboard = NO;
    int levels = 0;

    while (parent && levels < 15) {
        NSString *className = NSStringFromClass([parent class]);
        if ([className containsString:@"Keyboard"] ||
            [className isEqualToString:@"UIKBVisualEffectView"] ||
            [className isEqualToString:@"UIInputView"]) {
            isInKeyboard = YES; break;
        }
        if ([className isEqualToString:@"CKMessageEntryView"]) isInMessageInput = YES;
        if ([className isEqualToString:@"_UIBarBackground"]) self.alpha = 0.0;
        if ([className isEqualToString:@"CNActionView"]) self.alpha = 0.0;
        parent = parent.superview;
        levels++;
    }

    if (isInMessageInput && !isInKeyboard) self.backgroundColor = [UIColor clearColor];
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !isModernMessageBarEnabled()) return;

    UIView *parent = self.superview;
    BOOL isInMessageInput = NO;
    BOOL isInKeyboard = NO;
    int levels = 0;

    while (parent && levels < 15) {
        NSString *className = NSStringFromClass([parent class]);
        if ([className containsString:@"Keyboard"] ||
            [className isEqualToString:@"UIKBVisualEffectView"] ||
            [className isEqualToString:@"UIInputView"]) {
            isInKeyboard = YES; break;
        }
        if ([className isEqualToString:@"CKMessageEntryView"]) isInMessageInput = YES;
        parent = parent.superview;
        levels++;
    }

    if (isInMessageInput && !isInKeyboard) self.backgroundColor = [UIColor clearColor];
}

%end

%hook CKMessageEntryView

- (void)layoutSubviews {
    %orig;
    if (isTweakEnabled() && isInputFieldCustomizationEnabled()) {
        [self applyInputFieldCustomization];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled() || !isiOS15()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            updateDarkModeFromTraits(self.traitCollection);
            refreshPrefs();
            [self setNeedsLayoutRecursively:self];
            [self layoutIfNeeded];
            if (isInputFieldCustomizationEnabled()) [self applyInputFieldCustomization];
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];

    if (self.window) {
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(handleInputFieldPrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
        if (isiOS15()) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                selector:@selector(handleAppDidBecomeActive)
                name:UIApplicationDidBecomeActiveNotification
                object:nil];
        }
        if (isInputFieldCustomizationEnabled()) [self applyInputFieldCustomization];
    }
}

%new
- (void)handleAppDidBecomeActive {
    if (!isTweakEnabled() || !isiOS15()) return;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.window) return;
        refreshPrefs();
        [strongSelf setNeedsLayoutRecursively:strongSelf];
        [strongSelf layoutIfNeeded];
        if (isInputFieldCustomizationEnabled()) [strongSelf applyInputFieldCustomization];
    });
}

%new
- (void)setNeedsLayoutRecursively:(UIView *)view {
    [view setNeedsLayout];
    for (UIView *sub in view.subviews) {
        [self setNeedsLayoutRecursively:sub];
    }
}

%new
-(void)handleInputFieldPrefsChanged {
    refreshPrefs();
    [self setNeedsLayoutRecursively:self];
    [self layoutIfNeeded];
    if (isInputFieldCustomizationEnabled()) [self applyInputFieldCustomization];
}

%new
- (void)applyInputFieldCustomization {
    UIView *inputFieldContainer = nil;
    UITextView *textView = [self findTextView:self];
    if (textView) inputFieldContainer = textView.superview;
    if (!inputFieldContainer) inputFieldContainer = [self findRoundedView:self];
    if (!inputFieldContainer) inputFieldContainer = [self findViewByClassName:self];
    if (!inputFieldContainer) return;

    NSArray *subviewsCopy = [inputFieldContainer.subviews copy];
    for (UIView *subview in subviewsCopy) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) [subview removeFromSuperview];
    }

    if (isInputFieldBlurEnabled()) {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:getInputFieldBlurStyle()];
        UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
        blurView.frame = inputFieldContainer.bounds;
        blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        blurView.layer.cornerRadius = inputFieldContainer.layer.cornerRadius;
        blurView.layer.masksToBounds = YES;
        blurView.clipsToBounds = YES;
        objc_setAssociatedObject(blurView, &kWAMInputFieldBlurKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [inputFieldContainer insertSubview:blurView atIndex:0];
        inputFieldContainer.backgroundColor = [getInputFieldBackgroundColor() colorWithAlphaComponent:0.3];
    } else {
        inputFieldContainer.backgroundColor = getInputFieldBackgroundColor();
    }

    [inputFieldContainer setNeedsLayout];
    [inputFieldContainer layoutIfNeeded];

    if (textView && [textView isKindOfClass:%c(CKMessageEntryRichTextView)]) {
        if (isMessageInputTextEnabled()) {
            applyInputTextColor(textView, getMessageInputTextColor());
        }

        for (UIView *subview in textView.subviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)subview;
                if (isPlaceholderCustomizationEnabled()) {
                    label.textColor = getPlaceholderTextColor();
                    NSString *customText = getPlaceholderText();
                    if (customText) label.text = customText;
                }
            }
        }
    }
}

%new
- (UITextView *)findTextView:(UIView *)view {
    if ([view isKindOfClass:[UITextView class]]) return (UITextView *)view;
    for (UIView *subview in view.subviews) {
        UITextView *found = [self findTextView:subview];
        if (found) return found;
    }
    return nil;
}

%new
- (UIView *)findRoundedView:(UIView *)view {
    if (view != self &&
        view.layer.cornerRadius > 10.0 &&
        view.layer.cornerRadius < 30.0 &&
        CGRectGetHeight(view.frame) > 30 &&
        CGRectGetHeight(view.frame) < 60) return view;
    for (UIView *subview in view.subviews) {
        UIView *found = [self findRoundedView:subview];
        if (found) return found;
    }
    return nil;
}

%new
- (UIView *)findViewByClassName:(UIView *)view {
    NSString *className = NSStringFromClass([view class]);
    if ([className containsString:@"ContentView"] ||
        [className containsString:@"BackgroundView"] ||
        [className containsString:@"FieldEditor"]) {
        if (CGRectGetHeight(view.frame) > 30 && CGRectGetHeight(view.frame) < 60) return view;
    }
    for (UIView *subview in view.subviews) {
        UIView *found = [self findViewByClassName:subview];
        if (found) return found;
    }
    return nil;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook CKMessageEntryRichTextView

- (void)layoutSubviews {
    %orig;

    if (isTweakEnabled() && isPlaceholderCustomizationEnabled() && isInputFieldCustomizationEnabled()) {
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)subview;
                label.textColor = getPlaceholderTextColor();
                NSString *customText = getPlaceholderText();
                if (customText) label.text = customText;
                break;
            }
        }
    }

    if (isTweakEnabled() && isInputFieldCustomizationEnabled() && isMessageInputTextEnabled()) {
        applyInputTextColor(self, getMessageInputTextColor());
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];

    if (self.window) {
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(handleRichTextPrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
    }
}

%new
- (void)handleRichTextPrefsChanged {
    refreshPrefs();
    [self setNeedsLayout];
    [self layoutIfNeeded];
    if (isMessageInputTextEnabled()) {
        applyInputTextColor(self, getMessageInputTextColor());
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

- (void)setTextColor:(UIColor *)textColor {
    if (isTweakEnabled() && isInputFieldCustomizationEnabled() && isMessageInputTextEnabled()) {
        UIColor *customTextColor = getMessageInputTextColor();
        if (customTextColor && isTextViewSafeForColorWrite(self)) { %orig(customTextColor); return; }
    }
    %orig;
}

- (void)setText:(NSString *)text {
    %orig;
    if (isTweakEnabled() && isInputFieldCustomizationEnabled() && isMessageInputTextEnabled()) {
        UIColor *customTextColor = getMessageInputTextColor();
        if (customTextColor) self.textColor = customTextColor;
    }
}

%end

%hook CKEntryViewButton

static NSInteger const kArrowOverlayTag = 99881;
static const char kWAMOriginalImageKey = 0;

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    for (UIView *subview in [self.subviews copy]) {
        if (subview.tag == kArrowOverlayTag) {
            [subview removeFromSuperview];
        }
    }

    UIColor *sendColor = getSendButtonColor();
    UIColor *buttonColor = getMessageBarButtonColor();
    UIColor *arrowColor = getSendArrowColor();
    BOOL customizeOtherButtons = isMessageBarButtonsEnabled();

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            UIVisualEffectView *effectView = (UIVisualEffectView *)subview;
            for (UIView *contentSubview in effectView.contentView.subviews) {
                if ([contentSubview isKindOfClass:[UIButton class]]) {
                    UIButton *button = (UIButton *)contentSubview;
                    for (UIView *btnSubview in [button.subviews copy]) {
                        if ([btnSubview isKindOfClass:[UIImageView class]]) {
                            UIImageView *imageView = (UIImageView *)btnSubview;
                            CGSize frameSize = imageView.frame.size;

                            if (frameSize.width > 27 && frameSize.width < 28 &&
                                frameSize.height > 27 && frameSize.height < 28) {
                                // iOS 15: the audio-record button shares the send button's
                                // 27.5×27.5 size, but its action target is
                                // CKActionMenuGestureRecognizerButton rather than CKMessageEntryView.
                                // Skip it so we don't strip its icon and force-replace it with an arrow.
                                if (isiOS15()) {
                                    BOOL isAudioButton = NO;
                                    for (id target in [button allTargets]) {
                                        if ([NSStringFromClass([target class]) containsString:@"ActionMenu"]) {
                                            isAudioButton = YES;
                                            break;
                                        }
                                    }
                                    if (isAudioButton) continue;
                                }
                                if (!sendColor) continue;
                                button.backgroundColor = sendColor;
                                button.layer.cornerRadius = button.bounds.size.width / 2;
                                button.clipsToBounds = YES;
                                [imageView removeFromSuperview];

                                UIImage *arrowImage = [UIImage systemImageNamed:@"arrow.up"];
                                if (arrowImage) {
                                    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold];
                                    arrowImage = [arrowImage imageWithConfiguration:config];
                                    arrowImage = [arrowImage imageWithTintColor:arrowColor renderingMode:UIImageRenderingModeAlwaysOriginal];
                                    UIImageView *arrowOverlay = [[UIImageView alloc] initWithImage:arrowImage];
                                    arrowOverlay.userInteractionEnabled = NO;
                                    arrowOverlay.tag = kArrowOverlayTag;
                                    CGSize buttonSize = button.bounds.size;
                                    CGSize arrowSize = arrowOverlay.bounds.size;
                                    arrowOverlay.frame = CGRectMake((buttonSize.width - arrowSize.width) / 2,
                                                                    (buttonSize.height - arrowSize.height) / 2,
                                                                    arrowSize.width, arrowSize.height);
                                    [button addSubview:arrowOverlay];
                                }
                            } else if (customizeOtherButtons && buttonColor &&
                                       ((frameSize.width > 35 && frameSize.width < 37 && frameSize.height > 35 && frameSize.height < 37) ||
                                        (frameSize.width > 40 && frameSize.width < 42 && frameSize.height > 31 && frameSize.height < 33))) {
                                UIImage *originalImage = imageView.image;
                                CGRect originalFrame = imageView.frame;
                                if (!originalImage) continue;

                                UIImage *coloredImage = [originalImage imageWithTintColor:buttonColor renderingMode:UIImageRenderingModeAlwaysOriginal];
                                UIImageView *newImageView = [[UIImageView alloc] initWithImage:coloredImage];
                                newImageView.contentMode = imageView.contentMode;
                                newImageView.userInteractionEnabled = NO;
                                objc_setAssociatedObject(newImageView, &kWAMOriginalImageKey, originalImage, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                                [imageView removeFromSuperview];

                                CGRect frameInButton = originalFrame;
                                CGRect frameInEffectContent = [button convertRect:frameInButton toView:effectView.contentView];
                                CGRect frameInEffect = [effectView.contentView convertRect:frameInEffectContent toView:effectView];
                                CGRect frameInSelf = [effectView convertRect:frameInEffect toView:self];
                                newImageView.frame = frameInSelf;
                                [self addSubview:newImageView];
                            }
                        }
                    }
                }
            }
        }
    }
}

%new
- (void)applyColorsDirectly {
    refreshPrefs();

    UIColor *sendColor = getSendButtonColor();
    UIColor *arrowColor = getSendArrowColor();
    UIColor *buttonColor = getMessageBarButtonColor();
    BOOL customizeOtherButtons = isMessageBarButtonsEnabled();

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            UIVisualEffectView *effectView = (UIVisualEffectView *)subview;
            for (UIView *contentSubview in effectView.contentView.subviews) {
                if ([contentSubview isKindOfClass:[UIButton class]]) {
                    UIButton *button = (UIButton *)contentSubview;

                    UIImageView *existingArrow = nil;
                    for (UIView *btnSubview in button.subviews) {
                        if (btnSubview.tag == kArrowOverlayTag) {
                            existingArrow = (UIImageView *)btnSubview;
                            break;
                        }
                    }

                    if (existingArrow && sendColor) {
                        button.backgroundColor = sendColor;
                        UIImage *arrowImage = [UIImage systemImageNamed:@"arrow.up"];
                        if (arrowImage) {
                            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold];
                            arrowImage = [arrowImage imageWithConfiguration:config];
                            arrowImage = [arrowImage imageWithTintColor:arrowColor renderingMode:UIImageRenderingModeAlwaysOriginal];
                            existingArrow.image = arrowImage;
                        }
                    }
                }
            }
        }

        if ([subview isKindOfClass:[UIImageView class]] && subview.tag != kArrowOverlayTag) {
            UIImage *src = objc_getAssociatedObject(subview, &kWAMOriginalImageKey);
            if (!src) continue;
            UIImageView *imgView = (UIImageView *)subview;
            if (buttonColor && customizeOtherButtons) {
                imgView.image = [src imageWithTintColor:buttonColor renderingMode:UIImageRenderingModeAlwaysOriginal];
            } else {
                imgView.image = src;
            }
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];

    if (self.window) {
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(handleButtonPrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
        if (isiOS15()) {
            [[NSNotificationCenter defaultCenter] addObserver:self
                selector:@selector(handleButtonResumeActive)
                name:UIApplicationDidBecomeActiveNotification
                object:nil];
        }
    }

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

%new
- (void)handleButtonResumeActive {
    if (!isTweakEnabled() || !isiOS15()) return;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.window) return;
        refreshPrefs();
        [strongSelf applyColorsDirectly];
    });
}

%new
- (void)handleButtonPrefsChanged {
    refreshPrefs();
    [self setNeedsLayout];
    [self layoutIfNeeded];
    [self applyColorsDirectly];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            if (isiOS15()) updateDarkModeFromTraits(self.traitCollection);
            [self setNeedsLayout];
            [self layoutIfNeeded];
            [self applyColorsDirectly];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook CKDetailsTableView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    objc_setAssociatedObject(self, "wam_headerChecked", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    [self updateDetailsBackground];
    [self applyDetailsNavTitleColor];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handleDetailsPrefsChanged)
        name:kPrefsChangedNotification
        object:nil];
}

- (void)didMoveToSuperview {
    %orig;
    if (!isTweakEnabled() || !self.superview) return;
    [self updateDetailsBackground];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    UITableView *tv = (UITableView *)self;
    if (tv.visibleCells.count == 0) return;

    BOOL hasPhotoCell = NO;
    for (UITableViewCell *cell in tv.visibleCells) {
        if ([cell isKindOfClass:%c(CKGroupPhotoCell)]) { hasPhotoCell = YES; break; }
    }
    if (hasPhotoCell) {
        objc_setAssociatedObject(self, "wam_everSawPhotoCell", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (objc_getAssociatedObject(self, "wam_everSawPhotoCell")) return;
    if (objc_getAssociatedObject(self, "wam_headerInstallScheduled")) return;
    if (tv.tableHeaderView) return;

    objc_setAssociatedObject(self, "wam_headerInstallScheduled", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    __weak typeof(self) weakSelf = self;
    __weak typeof(tv) weakTv = tv;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        __strong typeof(weakTv) strongTv = weakTv;
        if (!strongSelf || !strongTv) return;
        if (objc_getAssociatedObject(strongSelf, "wam_everSawPhotoCell")) return;
        if (strongTv.tableHeaderView) return;
        for (UITableViewCell *cell in strongTv.visibleCells) {
            if ([cell isKindOfClass:%c(CKGroupPhotoCell)]) {
                objc_setAssociatedObject(strongSelf, "wam_everSawPhotoCell", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                return;
            }
        }
        [strongSelf wamInstallCustomizeHeader];
    });
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    if (!isTweakEnabled() || !isPerContactChatBgEnabled()) return %orig;
    UITableView *tv = (UITableView *)self;
    UITableViewCell *photoCell = nil;
    for (UITableViewCell *cell in tv.visibleCells) {
        if ([cell isKindOfClass:%c(CKGroupPhotoCell)]) { photoCell = cell; break; }
    }
    if (photoCell) {
        UIView *host = [photoCell respondsToSelector:@selector(contentView)] ? photoCell.contentView : (UIView *)photoCell;
        UIView *blur = [host viewWithTag:87731];
        if (blur && blur.window) {
            CGRect blurInTable = [blur convertRect:blur.bounds toView:tv];
            if (CGRectContainsPoint(blurInTable, point)) {
                CGPoint blurPoint = [tv convertPoint:point toView:blur];
                UIView *hit = [blur hitTest:blurPoint withEvent:event];
                if (hit) return hit;
            }
        }
    }
    return %orig;
}

- (void)setDelegate:(id<UITableViewDelegate>)delegate {
    %orig;
    if (delegate && isTweakEnabled() && isPerContactChatBgEnabled()) {
        [self wamSwizzleHeightDelegate:delegate];
    }
}

%new
- (void)wamSwizzleHeightDelegate:(id)delegate {
    static NSMutableSet *swizzledClasses = nil;
    if (!swizzledClasses) swizzledClasses = [NSMutableSet new];
    Class cls = [delegate class];
    NSString *clsName = NSStringFromClass(cls);
    if ([swizzledClasses containsObject:clsName]) return;
    [swizzledClasses addObject:clsName];

    SEL sel = @selector(tableView:heightForRowAtIndexPath:);
    Method existing = class_getInstanceMethod(cls, sel);
    if (existing) {
        IMP origImp = method_getImplementation(existing);
        IMP newImp = imp_implementationWithBlock(^CGFloat(id self_, UITableView *tv, NSIndexPath *ip) {
            CGFloat origH = ((CGFloat (*)(id, SEL, UITableView *, NSIndexPath *))origImp)(self_, sel, tv, ip);
            if (![tv isKindOfClass:%c(CKDetailsTableView)]) return origH;
            if (!isTweakEnabled() || !isPerContactChatBgEnabled()) return origH;
            if (ip.section == 0 && ip.row == 0) return origH + 64;
            return origH;
        });
        method_setImplementation(existing, newImp);
    } else {
        return;
    }

    if (self.window) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (![self isKindOfClass:%c(CKDetailsTableView)]) return;
            UITableView *tv = (UITableView *)self;
            [tv beginUpdates];
            [tv endUpdates];
        });
    }
}

%new
- (void)wamInstallCustomizeHeader {
    UITableView *tv = (UITableView *)self;
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tv.bounds.size.width, 64)];
    header.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    header.backgroundColor = [UIColor clearColor];

    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    UIVisualEffectView *blur = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    blur.layer.cornerRadius = 12;
    if (@available(iOS 13.0, *)) blur.layer.cornerCurve = kCACornerCurveContinuous;
    blur.clipsToBounds = YES;
    blur.translatesAutoresizingMaskIntoConstraints = NO;
    [header addSubview:blur];

    for (UIView *sub in blur.subviews) {
        if ([sub isKindOfClass:%c(_UIVisualEffectSubview)]) sub.backgroundColor = [UIColor clearColor];
    }

    UIView *tintOverlay = [UIView new];
    tintOverlay.userInteractionEnabled = NO;
    tintOverlay.translatesAutoresizingMaskIntoConstraints = NO;
    [blur.contentView addSubview:tintOverlay];
    if (isCellBlurTintEnabled()) {
        UIColor *tint = getCellBlurTintColor();
        tintOverlay.backgroundColor = tint ? [tint colorWithAlphaComponent:0.35] : [UIColor clearColor];
    }

    UILabel *titleLabel = [UILabel new];
    titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.text = @"Customize This Chat";
    UIColor *tc = nil;
    if (chatHasPerContactOverride()) {
        NSString *stKey = isDarkMode() ? @"systemTintColorDark" : @"systemTintColor";
        id raw = getPerContactOverride(gWAMCurrentContactName, stKey);
        if (raw) tc = colorFromHex(raw);
    }
    if (!tc) tc = getSystemTintColor();
    titleLabel.textColor = tc ?: [UIColor labelColor];
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    [blur.contentView addSubview:titleLabel];

    UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    [btn addTarget:self action:@selector(wamHeaderCustomizeTapped) forControlEvents:UIControlEventTouchUpInside];
    [blur.contentView addSubview:btn];

    [NSLayoutConstraint activateConstraints:@[
        [blur.leadingAnchor constraintEqualToAnchor:header.leadingAnchor constant:16],
        [blur.trailingAnchor constraintEqualToAnchor:header.trailingAnchor constant:-16],
        [blur.heightAnchor constraintEqualToConstant:48],
        [blur.centerYAnchor constraintEqualToAnchor:header.centerYAnchor],

        [tintOverlay.topAnchor constraintEqualToAnchor:blur.contentView.topAnchor],
        [tintOverlay.bottomAnchor constraintEqualToAnchor:blur.contentView.bottomAnchor],
        [tintOverlay.leadingAnchor constraintEqualToAnchor:blur.contentView.leadingAnchor],
        [tintOverlay.trailingAnchor constraintEqualToAnchor:blur.contentView.trailingAnchor],

        [titleLabel.centerXAnchor constraintEqualToAnchor:blur.contentView.centerXAnchor],
        [titleLabel.centerYAnchor constraintEqualToAnchor:blur.contentView.centerYAnchor],
        [titleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:blur.contentView.leadingAnchor constant:12],
        [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:blur.contentView.trailingAnchor constant:-12],

        [btn.topAnchor constraintEqualToAnchor:blur.contentView.topAnchor],
        [btn.bottomAnchor constraintEqualToAnchor:blur.contentView.bottomAnchor],
        [btn.leadingAnchor constraintEqualToAnchor:blur.contentView.leadingAnchor],
        [btn.trailingAnchor constraintEqualToAnchor:blur.contentView.trailingAnchor],
    ]];

    tv.tableHeaderView = header;
}

%new
- (void)wamHeaderCustomizeTapped {
    NSString *name = gWAMCurrentContactName;
    if (!name.length) return;
    WAMPerContactSettings *vc = [WAMPerContactSettings new];
    vc.contactName = name;
    vc.displayName = gWAMCurrentContactDisplayName;
    vc.onChanged = ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
    };
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    UIViewController *host = [(UIView *)self _viewControllerForAncestor];
    [host presentViewController:vc animated:YES completion:nil];
}

%new
- (void)handleDetailsPrefsChanged {
    refreshPrefs();
    [self updateDetailsBackground];
    [self applyDetailsNavTitleColor];
    for (UITableViewCell *cell in self.visibleCells) {
        [cell setNeedsLayout];
    }
}

%new
- (void)applyDetailsNavTitleColor {
    if (!isiOS15() || !isTweakEnabled()) return;
    UIColor *titleColor = getChatContactNameColor();
    if (!titleColor) return;

    UIViewController *vc = [self _viewControllerForAncestor];
    if (!vc || ![vc.navigationItem respondsToSelector:@selector(standardAppearance)]) return;

    NSDictionary *attrs = @{ NSForegroundColorAttributeName: titleColor };

    UINavigationBar *bar = vc.navigationController.navigationBar;
    UINavigationBarAppearance *base = vc.navigationItem.standardAppearance
        ?: (bar.standardAppearance ?: [[UINavigationBarAppearance alloc] init]);
    UINavigationBarAppearance *appearance = [base copy];
    appearance.titleTextAttributes      = attrs;
    appearance.largeTitleTextAttributes = attrs;

    vc.navigationItem.standardAppearance   = appearance;
    vc.navigationItem.scrollEdgeAppearance = appearance;
    vc.navigationItem.compactAppearance    = appearance;
}

%new
- (void)updateDetailsBackground {
    if (isiOS17OrHigher()) {
        self.backgroundView = nil;
        self.backgroundColor = [UIColor clearColor];
        return;
    }

    UIImage *chatBgImage = loadImageUncached(getChatImagePath());

    if (isChatColorBgEnabled()) {
        self.backgroundView = nil;
        self.backgroundColor = getChatBackgroundColor();
    } else if (chatBgImage && shouldShowAnyChatBgImage()) {
        CGFloat blurAmount = getEffectiveChatBgBlur();
        if (blurAmount > 0) chatBgImage = blurImage(chatBgImage, blurAmount);

        UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        imageView.image = chatBgImage;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.backgroundView = imageView;
    } else {
        self.backgroundView = nil;
        self.backgroundColor = [UIColor systemBackgroundColor];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            [self updateDetailsBackground];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook CKSearchCollectionView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    [self applySearchBackground];
}

- (void)layoutSubviews {
        %orig;
        if (!isTweakEnabled()) return;
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                subview.frame = self.bounds;
                break;
            }
        }
    }

%new
- (void)applySearchBackground {
    UIView *parent = self.superview;
    BOOL isInDetailsView = NO;
    BOOL isInPushedDetailsSubmenu = NO;
    int levels = 0;
    while (parent && levels < 15) {
        if ([parent isKindOfClass:%c(CKDetailsTableView)]) { isInDetailsView = YES; break; }
        if (!isInPushedDetailsSubmenu &&
            [NSStringFromClass([parent class]) isEqualToString:@"_UIParallaxDimmingView"]) {
            isInPushedDetailsSubmenu = YES;
        }
        parent = parent.superview;
        levels++;
    }

    if (isInDetailsView) {
        self.backgroundColor = [UIColor clearColor];
        return;
    }

    if (isInPushedDetailsSubmenu) {
        UIImage *chatBgImage = loadImageUncached(getChatImagePath());
        if (isChatColorBgEnabled()) {
            self.backgroundView = nil;
            self.backgroundColor = getChatBackgroundColor();
        } else if (chatBgImage && shouldShowAnyChatBgImage()) {
            CGFloat blurAmount = getEffectiveChatBgBlur();
            if (blurAmount > 0) chatBgImage = blurImage(chatBgImage, blurAmount);
            UIImageView *imageView = [[UIImageView alloc] initWithImage:chatBgImage];
            imageView.contentMode = UIViewContentModeScaleAspectFill;
            imageView.clipsToBounds = YES;
            imageView.frame = self.bounds;
            imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            self.backgroundView = imageView;
            self.backgroundColor = [UIColor clearColor];
        } else {
            self.backgroundView = nil;
            self.backgroundColor = [UIColor clearColor];
        }
        return;
    }

    if (isConvColorBgEnabled()) {
        UIColor *bgColor = getBackgroundColor();
        if (bgColor) {
            self.backgroundColor = bgColor;
            self.backgroundView = nil;
        }
    } else if (isConvImageBgEnabled()) {
        UIImage *bgImage = getBlurredConvImage();
        if (bgImage) {
            UIImageView *imageView = [[UIImageView alloc] initWithImage:bgImage];
            imageView.contentMode = UIViewContentModeScaleAspectFill;
            imageView.clipsToBounds = YES;
            imageView.frame = self.bounds;
            imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            self.backgroundView = imageView;
            self.backgroundColor = [UIColor clearColor];
        }
    } else {
        self.backgroundView = nil;
        self.backgroundColor = [UIColor systemBackgroundColor];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            [self applySearchBackground];
        }
    }
}

%end

%hook _UITableViewHeaderFooterContentView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;

    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKDetailsTableView)]) {
            self.backgroundColor = [UIColor clearColor];
            break;
        }
        parent = parent.superview;
        levels++;
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled()) { %orig; return; }

    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKDetailsTableView)]) {
            %orig([UIColor clearColor]);
            return;
        }
        parent = parent.superview;
        levels++;
    }
    %orig;
}

%end

%hook CNGroupIdentityHeaderContainerView

- (void)didMoveToWindow {
    %orig;
    if (NO) WAMLOG(@"CNGroupIdentityHeaderContainerView.didMoveToWindow frame=%@ super=%@",
        NSStringFromCGRect(((UIView *)self).frame), NSStringFromClass([self.superview class]));
    if (!isTweakEnabled()) return;
    self.backgroundColor = [UIColor clearColor];
    if (isCustomTextColorsEnabled()) [self applyContactNameColor];
    if (isPerContactChatBgEnabled()) [self wamCacheNameAndRefreshChatBg];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    if (isCustomTextColorsEnabled()) [self applyContactNameColor];
    if (isPerContactChatBgEnabled()) [self wamCacheNameAndRefreshChatBg];
}

- (void)setFrame:(CGRect)frame {
    CGFloat orig = frame.size.height;
    if (isTweakEnabled() && isPerContactChatBgEnabled() && frame.size.height > 213) {
        frame.size.height = 213;
    }
    if (NO) WAMLOG(@"CNGroupIdentityHeaderContainerView.setFrame in=%.1f out=%.1f", orig, frame.size.height);
    %orig(frame);
}

%new
- (void)wamCacheNameAndRefreshChatBg {
    NSString *displayed = [self displayedContactName];
    if (!displayed.length) return;
    if ([displayed isEqualToString:gWAMCurrentContactDisplayName]) return;
    gWAMCurrentContactDisplayName = [displayed copy];
    [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
}

%new
- (NSString *)displayedContactName {
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            NSString *t = ((UILabel *)subview).text;
            if (t.length) return t;
        } else if ([subview isKindOfClass:[UIStackView class]]) {
            for (UIView *innerView in ((UIStackView *)subview).arrangedSubviews) {
                if ([innerView isKindOfClass:[UIStackView class]]) {
                    for (UIView *stackItem in ((UIStackView *)innerView).arrangedSubviews) {
                        if ([stackItem isKindOfClass:[UILabel class]]) {
                            NSString *t = ((UILabel *)stackItem).text;
                            if (t.length) return t;
                        }
                    }
                }
            }
        }
    }
    return nil;
}

%new
- (void)applyContactNameColor {
    UIColor *titleColor = getChatContactNameColor();
    if (!titleColor) return;

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            ((UILabel *)subview).textColor = titleColor;
        } else if ([subview isKindOfClass:[UIStackView class]]) {
            for (UIView *innerView in ((UIStackView *)subview).arrangedSubviews) {
                if ([innerView isKindOfClass:[UIStackView class]]) {
                    for (UIView *stackItem in ((UIStackView *)innerView).arrangedSubviews) {
                        if ([stackItem isKindOfClass:[UILabel class]]) {
                            ((UILabel *)stackItem).textColor = titleColor;
                        }
                    }
                }
            }
        }
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled()) { %orig; return; }
    %orig([UIColor clearColor]);
}

%end

%hook CKGroupPhotoCell

- (void)didMoveToWindow {
    %orig;
    if (NO) WAMLOG(@"CKGroupPhotoCell.didMoveToWindow window=%@ frame=%@ name=%@",
        self.window, NSStringFromCGRect(((UIView *)self).frame), gWAMCurrentContactName);
    self.backgroundColor = [UIColor clearColor];
    UITableViewCell *cell = (UITableViewCell *)self;
    if ([cell respondsToSelector:@selector(contentView)]) {
        cell.contentView.backgroundColor = [UIColor clearColor];
    }
    if (isPerContactChatBgEnabled()) [self ensurePerContactBgButton];

    if (self.window) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(handleGroupPhotoCellPrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    }
}

%new
- (void)handleGroupPhotoCellPrefsChanged {
    refreshPrefs();
    if (isPerContactChatBgEnabled()) [self ensurePerContactBgButton];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    UITableViewCell *cell = (UITableViewCell *)self;
    if ([cell respondsToSelector:@selector(contentView)]) {
        cell.contentView.backgroundColor = [UIColor clearColor];
    }
    if (isPerContactChatBgEnabled()) [self ensurePerContactBgButton];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled()) { %orig; return; }
    %orig([UIColor clearColor]);
}

- (void)setFrame:(CGRect)frame {
    CGFloat orig = frame.size.height;
    if (isTweakEnabled() && isPerContactChatBgEnabled() && frame.size.height > 0 && frame.size.height < 277) {
        frame.size.height = 277;
    }
    if (NO) WAMLOG(@"CKGroupPhotoCell.setFrame in=%.1f out=%.1f", orig, frame.size.height);
    %orig(frame);
}

- (void)setClipsToBounds:(BOOL)clips {
    if (isTweakEnabled() && isPerContactChatBgEnabled()) { %orig(NO); return; }
    %orig(clips);
}

- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event {
    if (%orig) return YES;
    if (!isTweakEnabled() || !isPerContactChatBgEnabled()) return NO;
    UITableViewCell *cell = (UITableViewCell *)self;
    UIView *host = [cell respondsToSelector:@selector(contentView)] ? cell.contentView : (UIView *)self;
    UIView *blur = [host viewWithTag:87731];
    if (blur && CGRectContainsPoint(blur.frame, point)) return YES;
    return NO;
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize sz = %orig;
    if (isTweakEnabled() && isPerContactChatBgEnabled()) sz.height += 64;
    return sz;
}

- (CGSize)systemLayoutSizeFittingSize:(CGSize)targetSize withHorizontalFittingPriority:(UILayoutPriority)hPriority verticalFittingPriority:(UILayoutPriority)vPriority {
    CGSize sz = %orig;
    if (isTweakEnabled() && isPerContactChatBgEnabled()) sz.height += 64;
    return sz;
}

- (CGSize)intrinsicContentSize {
    CGSize sz = %orig;
    if (isTweakEnabled() && isPerContactChatBgEnabled()) sz.height += 64;
    return sz;
}

%new
- (void)ensurePerContactBgButton {
    static const NSInteger kBlurTag = 87731;
    static const NSInteger kLabelTag = 87732;
    static const NSInteger kTintTag = 87733;
    UITableViewCell *cell = (UITableViewCell *)self;
    UIView *host = [cell respondsToSelector:@selector(contentView)] ? cell.contentView : (UIView *)self;
    if (NO) WAMLOG(@"ensurePerContactBgButton cell.frame=%@ host=%@ host.frame=%@",
        NSStringFromCGRect(cell.frame), NSStringFromClass([host class]), NSStringFromCGRect(host.frame));
    host.clipsToBounds = NO;
    cell.clipsToBounds = NO;

    UIVisualEffectView *blur = (UIVisualEffectView *)[host viewWithTag:kBlurTag];
    UILabel *titleLabel = nil;
    UIView *tintOverlay = nil;
    if (!blur) {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
        blur = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
        blur.tag = kBlurTag;
        blur.layer.cornerRadius = 12;
        if (@available(iOS 13.0, *)) blur.layer.cornerCurve = kCACornerCurveContinuous;
        blur.clipsToBounds = YES;
        blur.translatesAutoresizingMaskIntoConstraints = NO;
        [host addSubview:blur];

        tintOverlay = [UIView new];
        tintOverlay.tag = kTintTag;
        tintOverlay.userInteractionEnabled = NO;
        tintOverlay.translatesAutoresizingMaskIntoConstraints = NO;
        [blur.contentView addSubview:tintOverlay];

        titleLabel = [UILabel new];
        titleLabel.tag = kLabelTag;
        titleLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
        titleLabel.textAlignment = NSTextAlignmentCenter;
        titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [blur.contentView addSubview:titleLabel];

        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        btn.translatesAutoresizingMaskIntoConstraints = NO;
        [btn addTarget:self action:@selector(perContactBgCellTapped) forControlEvents:UIControlEventTouchUpInside];
        [blur.contentView addSubview:btn];

        NSMutableArray *constraints = [@[
            [blur.leadingAnchor constraintEqualToAnchor:host.leadingAnchor constant:0],
            [blur.trailingAnchor constraintEqualToAnchor:host.trailingAnchor constant:0],
            [blur.heightAnchor constraintEqualToConstant:48],

            [tintOverlay.topAnchor constraintEqualToAnchor:blur.contentView.topAnchor],
            [tintOverlay.bottomAnchor constraintEqualToAnchor:blur.contentView.bottomAnchor],
            [tintOverlay.leadingAnchor constraintEqualToAnchor:blur.contentView.leadingAnchor],
            [tintOverlay.trailingAnchor constraintEqualToAnchor:blur.contentView.trailingAnchor],

            [titleLabel.centerXAnchor constraintEqualToAnchor:blur.contentView.centerXAnchor],
            [titleLabel.centerYAnchor constraintEqualToAnchor:blur.contentView.centerYAnchor],
            [titleLabel.leadingAnchor constraintGreaterThanOrEqualToAnchor:blur.contentView.leadingAnchor constant:12],
            [titleLabel.trailingAnchor constraintLessThanOrEqualToAnchor:blur.contentView.trailingAnchor constant:-12],

            [btn.topAnchor constraintEqualToAnchor:blur.contentView.topAnchor],
            [btn.bottomAnchor constraintEqualToAnchor:blur.contentView.bottomAnchor],
            [btn.leadingAnchor constraintEqualToAnchor:blur.contentView.leadingAnchor],
            [btn.trailingAnchor constraintEqualToAnchor:blur.contentView.trailingAnchor],
        ] mutableCopy];

        [constraints addObject:[blur.bottomAnchor constraintEqualToAnchor:host.bottomAnchor constant:-4]];

        [NSLayoutConstraint activateConstraints:constraints];
    } else {
        titleLabel = (UILabel *)[blur viewWithTag:kLabelTag];
        tintOverlay = [blur viewWithTag:kTintTag];
    }

    for (UIView *sub in blur.subviews) {
        if ([sub isKindOfClass:%c(_UIVisualEffectSubview)]) {
            sub.backgroundColor = [UIColor clearColor];
        }
    }
    if (isCellBlurTintEnabled()) {
        UIColor *tint = getCellBlurTintColor();
        tintOverlay.backgroundColor = tint ? [tint colorWithAlphaComponent:0.35] : [UIColor clearColor];
    } else {
        tintOverlay.backgroundColor = [UIColor clearColor];
    }

    UIColor *tc = nil;
    if (chatHasPerContactOverride()) {
        NSString *stKey = isDarkMode() ? @"systemTintColorDark" : @"systemTintColor";
        id raw = getPerContactOverride(gWAMCurrentContactName, stKey);
        if (raw) tc = colorFromHex(raw);
    }
    if (!tc) tc = getSystemTintColor();
    titleLabel.textColor = tc ?: [UIColor labelColor];

    titleLabel.text = @"Customize This Chat";

    [host bringSubviewToFront:blur];

    host.clipsToBounds = NO;
    host.layer.masksToBounds = NO;
    cell.clipsToBounds = NO;
    cell.layer.masksToBounds = NO;
}

%new
- (void)perContactBgCellTapped {
    NSString *name = gWAMCurrentContactName;
    if (!name.length) return;
    WAMPerContactSettings *vc = [WAMPerContactSettings new];
    vc.contactName = name;
    vc.displayName = gWAMCurrentContactDisplayName;
    vc.onChanged = ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
    };
    vc.modalPresentationStyle = UIModalPresentationPageSheet;
    UIViewController *host = [(UIView *)self _viewControllerForAncestor];
    [host presentViewController:vc animated:YES completion:nil];
}

%end

%hook CNActionView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyActionViewBlur];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handleActionViewPrefsChanged)
        name:kPrefsChangedNotification
        object:nil];
}

%new
- (void)handleActionViewPrefsChanged {
    refreshPrefs();
    [self applyActionViewBlur];
}

%new
- (void)applyActionViewBlur {
    for (UIView *subview in [self.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 12345) {
            [subview removeFromSuperview];
        }
        if (subview.tag == 12346) {
            [subview removeFromSuperview];
        }
    }

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = self.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.layer.cornerRadius = self.layer.cornerRadius;
    blurView.clipsToBounds = YES;
    blurView.userInteractionEnabled = NO;
    blurView.tag = 12345;
    [self insertSubview:blurView atIndex:0];
    self.backgroundColor = [UIColor clearColor];

    for (UIView *subview in blurView.subviews) {
        if ([subview isKindOfClass:%c(_UIVisualEffectSubview)]) {
            subview.backgroundColor = [UIColor clearColor];
        }
    }

    if (isCellBlurTintEnabled()) {
        UIColor *tintColor = getCellBlurTintColor();
        if (tintColor) {
            [self wamRefreshTintInBackdrop:blurView color:tintColor];
        }
    }
}

%new
- (void)wamRefreshTintInBackdrop:(UIVisualEffectView *)blurView color:(UIColor *)tintColor {
    UIView *tintOverlay = [self viewWithTag:12346];
    if (!tintOverlay) {
        tintOverlay = [[UIView alloc] initWithFrame:self.bounds];
        tintOverlay.tag = 12346;
        tintOverlay.userInteractionEnabled = NO;
        tintOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        tintOverlay.layer.cornerRadius = self.layer.cornerRadius;
        tintOverlay.clipsToBounds = YES;
    }
    tintOverlay.backgroundColor = [tintColor colorWithAlphaComponent:0.5];

    NSUInteger blurIdx = [self.subviews indexOfObject:blurView];
    NSUInteger desiredIdx = (blurIdx == NSNotFound) ? 1 : blurIdx + 1;
    if (tintOverlay.superview != self || [self.subviews indexOfObject:tintOverlay] != desiredIdx) {
        [tintOverlay removeFromSuperview];
        if (desiredIdx >= self.subviews.count) {
            [self addSubview:tintOverlay];
        } else {
            [self insertSubview:tintOverlay atIndex:desiredIdx];
        }
    }
    tintOverlay.frame = self.bounds;
    tintOverlay.layer.cornerRadius = self.layer.cornerRadius;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    BOOL hasOurBlur = NO;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 12345) {
            hasOurBlur = YES;
            subview.frame = self.bounds;
            subview.layer.cornerRadius = self.layer.cornerRadius;
            UIVisualEffectView *blurView = (UIVisualEffectView *)subview;
            for (UIView *blurSubview in blurView.subviews) {
                if ([blurSubview isKindOfClass:%c(_UIVisualEffectSubview)]) {
                    blurSubview.backgroundColor = [UIColor clearColor];
                }
            }
            if (isCellBlurTintEnabled()) {
                UIColor *tintColor = getCellBlurTintColor();
                if (tintColor) {
                    [self wamRefreshTintInBackdrop:blurView color:tintColor];
                }
            }
            break;
        }
    }
    if (!hasOurBlur) {
        [self applyActionViewBlur];
    }

    UIColor *actionColor = getAdvancedTintColorForView(@"advancedContactActionColor", @"advancedContactActionColorDark", nil, self);
    if (actionColor) {
        self.tintColor = actionColor;
        [self applyActionColor:actionColor toView:self];
    }

    [self updateIconOpacity];
}

%new
- (void)applyActionColor:(UIColor *)color toView:(UIView *)view {
    for (UIView *sub in view.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]]) continue;
        if ([sub isKindOfClass:[UILabel class]]) {
            ((UILabel *)sub).textColor = color;
        }
        [self applyActionColor:color toView:sub];
    }
}

%new
- (void)updateIconOpacity {
    BOOL isDisabled = NO;
    @try {
        id disabled = [self valueForKey:@"disabled"];
        if (disabled) isDisabled = [disabled boolValue];
    } @catch (NSException *e) {
        isDisabled = !self.userInteractionEnabled;
    }

    for (UIView *stack in self.subviews) {
        if ([NSStringFromClass([stack class]) isEqualToString:@"NUIContainerStackView"]) {
            for (UIView *box in stack.subviews) {
                if ([NSStringFromClass([box class]) isEqualToString:@"NUIContainerBoxView"]) {
                    for (UIView *innerStack in box.subviews) {
                        if ([NSStringFromClass([innerStack class]) isEqualToString:@"NUIContainerStackView"]) {
                            for (UIView *icon in innerStack.subviews) {
                                if ([icon isKindOfClass:[UIImageView class]]) {
                                    icon.alpha = isDisabled ? 0.3 : 1.0;
                                    return;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            cachedPrefs = nil;
            reloadPrefs();
            for (UIView *subview in [self.subviews copy]) {
                if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 12345) {
                    [subview removeFromSuperview];
                }
            }
            [self applyActionViewBlur];
            UIColor *actionColor = getAdvancedTintColorForView(@"advancedContactActionColor", @"advancedContactActionColorDark", nil, self);
            if (actionColor) {
                self.tintColor = actionColor;
                [self applyActionColor:actionColor toView:self];
            }
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook CKTranscriptDetailsResizableCell

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyBlurStyle];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handleBlurCellPrefsChanged)
        name:kPrefsChangedNotification object:nil];
}

%new
- (void)handleBlurCellPrefsChanged {
    refreshPrefs();
    [self applyBlurStyle];
}

%new
- (void)applyBlurStyle {
    for (UIView *subview in [self.contentView.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) [subview removeFromSuperview];
    }

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = self.contentView.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.layer.cornerRadius = self.contentView.layer.cornerRadius;
    blurView.clipsToBounds = YES;
    [self.contentView insertSubview:blurView atIndex:0];
    self.contentView.backgroundColor = [UIColor clearColor];
    self.backgroundColor = [UIColor clearColor];

    for (UIView *subview in blurView.subviews) {
        if ([subview isKindOfClass:%c(_UIVisualEffectSubview)]) subview.backgroundColor = [UIColor clearColor];
    }

    if (isCellBlurTintEnabled()) {
        UIColor *tintColor = getCellBlurTintColor();
        if (tintColor) {
            UIView *tintOverlay = [[UIView alloc] initWithFrame:blurView.contentView.bounds];
            tintOverlay.userInteractionEnabled = NO;
            tintOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            tintOverlay.backgroundColor = [tintColor colorWithAlphaComponent:0.5];
            [blurView.contentView addSubview:tintOverlay];
        }
    }

    [self setNeedsDisplay];
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    for (UIView *subview in self.contentView.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            subview.frame = self.contentView.bounds;
            subview.layer.cornerRadius = self.contentView.layer.cornerRadius;
            UIVisualEffectView *blurView = (UIVisualEffectView *)subview;
            for (UIView *blurSubview in blurView.subviews) {
                if ([blurSubview isKindOfClass:%c(_UIVisualEffectSubview)]) blurSubview.backgroundColor = [UIColor clearColor];
            }
            if (isCellBlurTintEnabled()) {
                UIColor *tintColor = getCellBlurTintColor();
                if (tintColor) {
                    for (UIView *contentSubview in blurView.contentView.subviews) {
                        if ([contentSubview class] == [UIView class]) {
                            contentSubview.backgroundColor = [tintColor colorWithAlphaComponent:0.3];
                            contentSubview.frame = blurView.contentView.bounds;
                            break;
                        }
                    }
                }
            }
            break;
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook CKDetailsSharedWithYouCell

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyBlurStyle];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handleBlurCellPrefsChanged)
        name:kPrefsChangedNotification object:nil];
}

%new
- (void)handleBlurCellPrefsChanged {
    refreshPrefs();
    [self applyBlurStyle];
}

%new
- (void)applyBlurStyle {
    for (UIView *subview in [self.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) [subview removeFromSuperview];
    }
    for (UIView *subview in [self.contentView.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) [subview removeFromSuperview];
    }

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = self.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.layer.cornerRadius = self.layer.cornerRadius;
    blurView.clipsToBounds = YES;
    [self insertSubview:blurView atIndex:0];
    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];

    for (UIView *subview in blurView.subviews) {
        if ([subview isKindOfClass:%c(_UIVisualEffectSubview)]) subview.backgroundColor = [UIColor clearColor];
    }

    if (isCellBlurTintEnabled()) {
        UIColor *tintColor = getCellBlurTintColor();
        if (tintColor) {
            UIView *tintOverlay = [[UIView alloc] initWithFrame:blurView.contentView.bounds];
            tintOverlay.userInteractionEnabled = NO;
            tintOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            tintOverlay.backgroundColor = [tintColor colorWithAlphaComponent:0.5];
            [blurView.contentView addSubview:tintOverlay];
        }
    }

    [self setNeedsDisplay];
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            subview.frame = self.bounds;
            subview.layer.cornerRadius = self.layer.cornerRadius;
            UIVisualEffectView *blurView = (UIVisualEffectView *)subview;
            for (UIView *blurSubview in blurView.subviews) {
                if ([blurSubview isKindOfClass:%c(_UIVisualEffectSubview)]) blurSubview.backgroundColor = [UIColor clearColor];
            }
            if (isCellBlurTintEnabled()) {
                UIColor *tintColor = getCellBlurTintColor();
                if (tintColor) {
                    for (UIView *contentSubview in blurView.contentView.subviews) {
                        if ([contentSubview class] == [UIView class]) {
                            contentSubview.backgroundColor = [tintColor colorWithAlphaComponent:0.3];
                            contentSubview.frame = blurView.contentView.bounds;
                            break;
                        }
                    }
                }
            }
            break;
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook CKBackgroundDecorationView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyBlurStyle];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handleBlurCellPrefsChanged)
        name:kPrefsChangedNotification object:nil];
}

%new
- (void)handleBlurCellPrefsChanged {
    refreshPrefs();
    [self applyBlurStyle];
}

%new
- (void)applyBlurStyle {
    for (UIView *subview in [self.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) [subview removeFromSuperview];
    }

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = self.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.layer.cornerRadius = self.layer.cornerRadius;
    blurView.clipsToBounds = YES;
    [self insertSubview:blurView atIndex:0];
    self.backgroundColor = [UIColor clearColor];

    for (UIView *subview in blurView.subviews) {
        if ([subview isKindOfClass:%c(_UIVisualEffectSubview)]) subview.backgroundColor = [UIColor clearColor];
    }

    if (isCellBlurTintEnabled()) {
        UIColor *tintColor = getCellBlurTintColor();
        if (tintColor) {
            UIView *tintOverlay = [[UIView alloc] initWithFrame:blurView.contentView.bounds];
            tintOverlay.userInteractionEnabled = NO;
            tintOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            tintOverlay.backgroundColor = [tintColor colorWithAlphaComponent:0.5];
            [blurView.contentView addSubview:tintOverlay];
        }
    }

    [self setNeedsDisplay];
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            subview.frame = self.bounds;
            subview.layer.cornerRadius = self.layer.cornerRadius;
            UIVisualEffectView *blurView = (UIVisualEffectView *)subview;
            for (UIView *blurSubview in blurView.subviews) {
                if ([blurSubview isKindOfClass:%c(_UIVisualEffectSubview)]) blurSubview.backgroundColor = [UIColor clearColor];
            }
            if (isCellBlurTintEnabled()) {
                UIColor *tintColor = getCellBlurTintColor();
                if (tintColor) {
                    for (UIView *contentSubview in blurView.contentView.subviews) {
                        if ([contentSubview class] == [UIView class]) {
                            contentSubview.backgroundColor = [tintColor colorWithAlphaComponent:0.3];
                            contentSubview.frame = blurView.contentView.bounds;
                            break;
                        }
                    }
                }
            }
            break;
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook CKDetailsChatOptionsCell

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyBlurStyle];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handleBlurCellPrefsChanged)
        name:kPrefsChangedNotification object:nil];
}

%new
- (void)handleBlurCellPrefsChanged {
    refreshPrefs();
    [self applyBlurStyle];
}

%new
- (void)applyBlurStyle {
    for (UIView *subview in [self.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) [subview removeFromSuperview];
    }
    for (UIView *subview in [self.contentView.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) [subview removeFromSuperview];
    }

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = self.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.layer.cornerRadius = 0;
    blurView.clipsToBounds = NO;
    [self insertSubview:blurView atIndex:0];
    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = YES;

    for (UIView *subview in blurView.subviews) {
        if ([subview isKindOfClass:%c(_UIVisualEffectSubview)]) subview.backgroundColor = [UIColor clearColor];
    }

    if (isCellBlurTintEnabled()) {
        UIColor *tintColor = getCellBlurTintColor();
        if (tintColor) {
            UIView *tintOverlay = [[UIView alloc] initWithFrame:blurView.contentView.bounds];
            tintOverlay.userInteractionEnabled = NO;
            tintOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            tintOverlay.backgroundColor = [tintColor colorWithAlphaComponent:0.5];
            [blurView.contentView addSubview:tintOverlay];
        }
    }

    [self setNeedsDisplay];
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            subview.frame = self.bounds;
            subview.layer.cornerRadius = 0;
            UIVisualEffectView *blurView = (UIVisualEffectView *)subview;
            for (UIView *blurSubview in blurView.subviews) {
                if ([blurSubview isKindOfClass:%c(_UIVisualEffectSubview)]) blurSubview.backgroundColor = [UIColor clearColor];
            }
            if (isCellBlurTintEnabled()) {
                UIColor *tintColor = getCellBlurTintColor();
                if (tintColor) {
                    for (UIView *contentSubview in blurView.contentView.subviews) {
                        if ([contentSubview class] == [UIView class]) {
                            contentSubview.backgroundColor = [tintColor colorWithAlphaComponent:0.3];
                            contentSubview.frame = blurView.contentView.bounds;
                            break;
                        }
                    }
                }
            }
            break;
        }
    }
    self.clipsToBounds = YES;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook CKRecipientSelectionView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    [self updateRecipientBackground];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handleRecipientPrefsChanged)
        name:kPrefsChangedNotification
        object:nil];
}

%new
- (void)handleRecipientPrefsChanged {
    refreshPrefs();
    [self updateRecipientBackground];
}

%new
- (void)updateRecipientBackground {
    UIImage *chatBgImage = loadImageUncached(getChatImagePath());

    for (UIView *subview in [self.subviews copy]) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            UIImageView *imgView = (UIImageView *)subview;
            if (CGRectEqualToRect(imgView.frame, self.bounds) ||
                (imgView.frame.origin.x == 0 && imgView.frame.origin.y == 0)) {
                [imgView removeFromSuperview];
            }
        }
    }

    if (isChatColorBgEnabled()) {
        self.backgroundColor = getChatBackgroundColor();
    } else if (chatBgImage && shouldShowAnyChatBgImage()) {
        CGFloat blurAmount = getEffectiveChatBgBlur();
        if (blurAmount > 0) chatBgImage = blurImage(chatBgImage, blurAmount);

        UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        imageView.image = chatBgImage;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self insertSubview:imageView atIndex:0];
        self.backgroundColor = [UIColor clearColor];
    } else {
        self.backgroundColor = [UIColor systemBackgroundColor];
    }

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            UIImageView *imgView = (UIImageView *)subview;
            if (imgView.frame.origin.x == 0 && imgView.frame.origin.y == 0) {
                imgView.frame = self.bounds;
                break;
            }
        }
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            [self updateRecipientBackground];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook CKComposeRecipientView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    if (isChatColorBgEnabled() || isChatImageBgEnabled()) {
        self.backgroundColor = [UIColor clearColor];
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled() || (!isChatColorBgEnabled() && !isChatImageBgEnabled())) { 
        %orig; 
        return; 
    }
    %orig([UIColor clearColor]);
}

%end

%hook UITableViewLabel

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    UIColor *customTint = getAdvancedTableLabelColor();
    if (!customTint) return;
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    if (self.textColor && [self.textColor getRed:&red green:&green blue:&blue alpha:&alpha]) {
        if (red > 0.7 && green < 0.3 && blue < 0.3) return;
    }
    self.textColor = customTint;
}

- (void)setTextColor:(UIColor *)color {
    if (!isTweakEnabled()) { %orig; return; }
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    if (color && [color getRed:&red green:&green blue:&blue alpha:&alpha]) {
        if (red > 0.7 && green < 0.3 && blue < 0.3) { %orig; return; }
    }
    UIColor *customTint = getAdvancedTableLabelColor();
    if (customTint) { %orig(customTint); return; }
    %orig;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            UIColor *customTint = getAdvancedTableLabelColor();
            if (customTint) self.textColor = customTint;
        }
    }
}

%end

%hook UISwitch

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    if (wamSwitchOwnsItsTint(self)) return;

    if (self.window) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(wamHandleSwitchPrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    }

    UIColor *customTint = getAdvancedSwitchTintColor();
    if (customTint) self.onTintColor = customTint;
}

%new
- (void)wamHandleSwitchPrefsChanged {
    if (!isTweakEnabled()) return;
    if (wamSwitchOwnsItsTint(self)) return;
    refreshPrefs();
    UIColor *customTint = getAdvancedSwitchTintColor();
    if (customTint) self.onTintColor = customTint;
}

- (void)setOn:(BOOL)on animated:(BOOL)animated {
    %orig;
    if (!isTweakEnabled()) return;
    if (wamSwitchOwnsItsTint(self)) return;
    UIColor *customTint = getAdvancedSwitchTintColor();
    if (customTint) self.onTintColor = customTint;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (wamSwitchOwnsItsTint(self)) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            UIColor *customTint = getAdvancedSwitchTintColor();
            if (customTint) self.onTintColor = customTint;
        }
    }
}

%end

%hook UIButtonLabel

- (void)setText:(NSString *)text {
    %orig;
    if (!isTweakEnabled()) return;
    if ([text isEqualToString:@"Report Junk"]) {
        UIColor *customTint = getChatAdvancedTintColorForView(@"advancedReportJunkColor", @"advancedReportJunkColorDark", getSystemTintColor(), self);
        if (customTint) { self.textColor = customTint; return; }
    }
    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            UIColor *customTint = getAdvancedStatusCellColor();
            if (customTint) self.textColor = customTint;
            break;
        }
        parent = parent.superview;
        levels++;
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    if ([self.text isEqualToString:@"Report Junk"]) {
        UIColor *customTint = getChatAdvancedTintColorForView(@"advancedReportJunkColor", @"advancedReportJunkColorDark", getSystemTintColor(), self);
        if (customTint) { self.textColor = customTint; return; }
    }
    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            UIColor *customTint = getAdvancedStatusCellColor();
            if (customTint) self.textColor = customTint;
            break;
        }
        parent = parent.superview;
        levels++;
    }
}

- (void)setTextColor:(UIColor *)color {
    if (!isTweakEnabled()) { %orig; return; }
    if ([self.text isEqualToString:@"Report Junk"]) {
        UIColor *customTint = getChatAdvancedTintColorForView(@"advancedReportJunkColor", @"advancedReportJunkColorDark", getSystemTintColor(), self);
        if (customTint) { %orig(customTint); return; }
    }
    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            UIColor *customTint = getAdvancedStatusCellColor();
            if (customTint) { %orig(customTint); return; }
            break;
        }
        parent = parent.superview;
        levels++;
    }
    %orig;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    if ([self.text isEqualToString:@"Report Junk"]) {
        UIColor *customTint = getChatAdvancedTintColorForView(@"advancedReportJunkColor", @"advancedReportJunkColorDark", getSystemTintColor(), self);
        if (customTint) { self.textColor = customTint; return; }
    }
    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            UIColor *customTint = getAdvancedStatusCellColor();
            if (customTint) self.textColor = customTint;
            break;
        }
        parent = parent.superview;
        levels++;
    }
}

%end

%hook UIButton

- (void)setTintColor:(UIColor *)color {
    if (!isTweakEnabled()) { %orig; return; }
    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            UIColor *customTint = getAdvancedStatusCellColor();
            if (customTint) { %orig(customTint); return; }
            break;
        }
        parent = parent.superview;
        levels++;
    }
    %orig;
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            UIColor *customTint = getAdvancedStatusCellColor();
            if (customTint) {
                self.tintColor = customTint;
                for (UIView *subview in self.subviews) {
                    if ([subview isKindOfClass:%c(UIButtonLabel)]) [(UILabel *)subview setTextColor:customTint];
                }
            }
            break;
        }
        parent = parent.superview;
        levels++;
    }
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            UIColor *customTint = getAdvancedStatusCellColor();
            if (customTint) {
                self.tintColor = customTint;
                for (UIView *subview in self.subviews) {
                    if ([subview isKindOfClass:%c(UIButtonLabel)]) [(UILabel *)subview setTextColor:customTint];
                }
            }
            break;
        }
        parent = parent.superview;
        levels++;
    }
}

%end

%hook CKAggregateAcknowledgementBalloonView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    if (isCustomBubbleColorsEnabled()) {
        UIColor *customTint = getAdvancedReactionGlyphColor();
        if (customTint) {
            self.tintColor = customTint;
            for (UIView *subview in self.subviews) {
                if ([subview isKindOfClass:[UIImageView class]]) subview.tintColor = customTint;
            }
        }
        [self applyGlyphTintRecursively:self];
    }
}

- (void)setTintColor:(UIColor *)color {
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) { %orig; return; }
    UIColor *customTint = getAdvancedReactionGlyphColor();
    if (customTint) {
        %orig(customTint);
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) subview.tintColor = customTint;
        }
        [self applyGlyphTintRecursively:self];
        return;
    }
    %orig;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    if (isCustomBubbleColorsEnabled()) {
        UIColor *customTint = getAdvancedReactionGlyphColor();
        if (customTint) {
            self.tintColor = customTint;
            for (UIView *subview in self.subviews) {
                if ([subview isKindOfClass:[UIImageView class]]) subview.tintColor = customTint;
            }
        }
        [self applyGlyphTintRecursively:self];
    }
}

%new
- (void)applyGlyphTintRecursively:(UIView *)view {
    UIColor *glyphTint = getGlyphTintColor();

    if ([view isKindOfClass:%c(CKAcknowledgmentGlyphImageView)]) {
        view.tintColor = glyphTint;
        UIImage *img = [view valueForKey:@"_image"];
        if (img && img.renderingMode != UIImageRenderingModeAlwaysTemplate) {
            img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [view setValue:img forKey:@"_image"];
        }
    }
    if ([NSStringFromClass([view class]) containsString:@"AcknowledgmentGlyphView"]) {
        view.tintColor = glyphTint;
    }
    for (UIView *subview in view.subviews) [self applyGlyphTintRecursively:subview];
}

%end

%hook _UIPlatterClippingView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    if (self.bounds.size.height < 200) return;
    [self applyPlatterBackground];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    if (self.bounds.size.height < 200) {
        for (UIView *subview in [self.subviews copy]) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                UIImageView *imgView = (UIImageView *)subview;
                if (imgView.frame.origin.x == 0 && imgView.frame.origin.y == 0) [imgView removeFromSuperview];
            }
        }
        self.backgroundColor = [UIColor clearColor];
        return;
    }

    BOOL hasBackgroundImage = NO;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            UIImageView *imgView = (UIImageView *)subview;
            if (imgView.frame.origin.x == 0 && imgView.frame.origin.y == 0) {
                imgView.frame = self.bounds;
                hasBackgroundImage = YES;
                break;
            }
        }
    }
    if (!hasBackgroundImage) [self applyPlatterBackground];
}

%new
- (void)applyPlatterBackground {
    UIImage *chatBgImage = loadImageUncached(getChatImagePath());

    if (isChatColorBgEnabled()) {
        self.backgroundColor = getChatBackgroundColor();
    } else if (chatBgImage && shouldShowAnyChatBgImage()) {
        CGFloat blurAmount = getEffectiveChatBgBlur();
        if (blurAmount > 0) chatBgImage = blurImage(chatBgImage, blurAmount);

        UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        imageView.image = chatBgImage;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self insertSubview:imageView atIndex:0];
        self.backgroundColor = [UIColor clearColor];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            if (self.bounds.size.height < 200) return;
            refreshPrefs();
            [self applyPlatterBackground];
        }
    }
}

%end

%hook _UIPlatterShadowView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;
    if (!isChatColorBgEnabled() && !isChatImageBgEnabled()) return;
    self.hidden = YES;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    if (!isChatColorBgEnabled() && !isChatImageBgEnabled()) return;
    self.hidden = YES;
}

- (void)setHidden:(BOOL)hidden {
    if (!isTweakEnabled() || (!isChatColorBgEnabled() && !isChatImageBgEnabled())) {
        %orig;
        return;
    }
    %orig(YES);
}

%end

%hook _UIPlatterSoftShadowView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;
    if (!isChatColorBgEnabled() && !isChatImageBgEnabled()) return;
    self.hidden = YES;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    if (!isChatColorBgEnabled() && !isChatImageBgEnabled()) return;
    self.hidden = YES;
}

- (void)setHidden:(BOOL)hidden {
    if (!isTweakEnabled() || (!isChatColorBgEnabled() && !isChatImageBgEnabled())) {
        %orig;
        return;
    }
    %orig(YES);
}

%end

%hook _UICutoutShadowView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;
    if (!isChatColorBgEnabled() && !isChatImageBgEnabled()) return;
    self.hidden = YES;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    if (!isChatColorBgEnabled() && !isChatImageBgEnabled()) return;
    self.hidden = YES;
}

- (void)setHidden:(BOOL)hidden {
    if (!isTweakEnabled() || (!isChatColorBgEnabled() && !isChatImageBgEnabled())) {
        %orig;
        return;
    }
    %orig(YES);
}

%end

%hook _UIPlatterTransformView
- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    self.backgroundColor = [UIColor clearColor];
}
%end

static BOOL isReplicantInsidePlatter(UIView *view) {
    UIView *parent = view.superview;
    int levels = 0;
    while (parent && levels < 20) {
        if ([parent isKindOfClass:%c(_UIPlatterClippingView)]) return YES;
        parent = parent.superview;
        levels++;
    }
    return NO;
}

%hook _UIReplicantView

- (void)didMoveToSuperview {
    %orig;
    if (!isTweakEnabled() || !self.superview) return;
    if (!isChatColorBgEnabled() && !isChatImageBgEnabled()) return;
    if (!isReplicantInsidePlatter(self)) return;
    if (self.bounds.size.height >= 200) self.alpha = 0;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    if (!isChatColorBgEnabled() && !isChatImageBgEnabled()) return;
    if (!isReplicantInsidePlatter(self)) return;
    if (self.bounds.size.height >= 200) self.alpha = 0;
}

- (void)setAlpha:(CGFloat)alpha {
    if (!isTweakEnabled() || (!isChatColorBgEnabled() && !isChatImageBgEnabled())) {
        %orig;
        return;
    }
    if (!isReplicantInsidePlatter(self)) { %orig; return; }
    if (self.bounds.size.height >= 200) {
        %orig(0);
        return;
    }
    %orig;
}

%end

%hook _UISystemBackgroundView

- (void)setConfiguration:(id)configuration {
    %orig(configuration);
    if (!isTweakEnabled()) return;
    for (UIView *sub in self.subviews) {
        if (![sub isKindOfClass:[UIView class]]) continue;
        if ([sub isKindOfClass:[UIImageView class]]) continue;
        sub.hidden = YES;
        break;
    }
}

%end

%hook CKTranscriptReportSpamCell

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    UIColor *customTint = getChatAdvancedTintColorForView(@"advancedReportJunkColor", @"advancedReportJunkColorDark", getSystemTintColor(), self);
    if (!customTint) return;
    [self colorReportJunkButton:self withColor:customTint];
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;
    UIColor *customTint = getChatAdvancedTintColorForView(@"advancedReportJunkColor", @"advancedReportJunkColorDark", getSystemTintColor(), self);
    if (!customTint) return;
    [self colorReportJunkButton:self withColor:customTint];
}

%new
- (void)colorReportJunkButton:(UIView *)view withColor:(UIColor *)color {
    if ([view isKindOfClass:%c(UIButtonLabel)]) {
        UILabel *label = (UILabel *)view;
        if ([label.text isEqualToString:@"Report Junk"]) label.textColor = color;
    }
    for (UIView *subview in view.subviews) [self colorReportJunkButton:subview withColor:color];
}

%end

%hook CKAcknowledgmentGlyphImageView

- (void)setImage:(UIImage *)image {
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !image) { %orig; return; }

    UIColor *glyphTint = getGlyphTintColor();

    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGContextTranslateCTM(context, 0, image.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
    CGContextDrawImage(context, rect, image.CGImage);
    CGContextSetBlendMode(context, kCGBlendModeSourceIn);
    [glyphTint setFill];
    CGContextFillRect(context, rect);
    UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    %orig(tintedImage);
}

- (void)didMoveToSuperview {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !self.superview) return;
    UIImage *currentImage = [self valueForKey:@"_image"];
    if (currentImage) [self setImage:currentImage];
}

%end

%hook CKThumbsUpAcknowledgmentGlyphView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window || !isCustomBubbleColorsEnabled()) return;

    UIColor *glyphTint = getGlyphTintColor();
    self.tintColor = glyphTint;
    for (UIView *subview in self.subviews) subview.tintColor = glyphTint;
}

%end

%hook CKTranscriptUnavailabilityIndicatorCell

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    UIColor *customTint = getSystemTintColor();
    if (!customTint) return;
    [self applyColorToUnavailabilityIndicator:self.contentView withColor:[customTint colorWithAlphaComponent:0.75]];
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;
    UIColor *customTint = getSystemTintColor();
    if (!customTint) return;
    [self applyColorToUnavailabilityIndicator:self.contentView withColor:[customTint colorWithAlphaComponent:0.75]];
}

%new
- (void)applyColorToUnavailabilityIndicator:(UIView *)view withColor:(UIColor *)color {
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        label.textColor = color;
        if (label.attributedText) {
            NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithAttributedString:label.attributedText];
            [attrString enumerateAttribute:NSAttachmentAttributeName inRange:NSMakeRange(0, attrString.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
                if ([value isKindOfClass:[NSTextAttachment class]]) {
                    NSTextAttachment *attachment = (NSTextAttachment *)value;
                    UIImage *originalImage = attachment.image;
                    if (originalImage) {
                        UIImage *templateImage = [originalImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                        attachment.image = [templateImage imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];
                    }
                }
            }];
            [attrString addAttribute:NSForegroundColorAttributeName value:color range:NSMakeRange(0, attrString.length)];
            label.attributedText = attrString;
        }
    }
    for (UIView *subview in view.subviews) [self applyColorToUnavailabilityIndicator:subview withColor:color];
}

%end

%hook UINavigationButton

- (void)setTintColor:(UIColor *)color {
    if (!isTweakEnabled()) { %orig; return; }

    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(_UISearchBarSearchContainerView)] ||
            [parent isKindOfClass:%c(UISearchBarBackground)]) {
            UIColor *customTint = getSystemTintColor();
            if (customTint) { %orig(customTint); return; }
            break;
        }
        parent = parent.superview;
        levels++;
    }

    UIColor *navColor = getAdvancedTintColorForView(@"advancedNavButtonColor", @"advancedNavButtonColorDark", getSystemTintColor(), self);
    if (navColor) { %orig(navColor); return; }
    %orig;
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;

    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(_UISearchBarSearchContainerView)] ||
            [parent isKindOfClass:%c(UISearchBarBackground)]) {
            UIColor *customTint = getSystemTintColor();
            if (customTint) self.tintColor = customTint;
            return;
        }
        parent = parent.superview;
        levels++;
    }

    UIColor *navColor = getAdvancedTintColorForView(@"advancedNavButtonColor", @"advancedNavButtonColorDark", getSystemTintColor(), self);
    if (navColor) self.tintColor = navColor;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            UIColor *navColor = getAdvancedTintColorForView(@"advancedNavButtonColor", @"advancedNavButtonColorDark", getSystemTintColor(), self);
            if (navColor) self.tintColor = navColor;
        }
    }
}

%end

%hook CKTranscriptNotifyAnywayButtonCell

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    UIColor *customTint = getSystemTintColor();
    if (!customTint) return;
    for (UIView *subview in self.contentView.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            button.tintColor = customTint;
            [button setNeedsLayout];
            [button layoutIfNeeded];
            for (UIView *btnSubview in button.subviews) {
                if ([btnSubview isKindOfClass:%c(UIButtonLabel)]) [(UILabel *)btnSubview setTextColor:customTint];
            }
            break;
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;
    UIColor *customTint = getSystemTintColor();
    if (!customTint) return;
    for (UIView *subview in self.contentView.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            button.tintColor = customTint;
            [button setNeedsLayout];
            [button layoutIfNeeded];
            for (UIView *btnSubview in button.subviews) {
                if ([btnSubview isKindOfClass:%c(UIButtonLabel)]) [(UILabel *)btnSubview setTextColor:customTint];
            }
            break;
        }
    }
}

- (void)didMoveToSuperview {
    %orig;
    if (!isTweakEnabled() || !self.superview) return;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [weakSelf setNeedsLayout];
        [weakSelf layoutIfNeeded];
    });
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig;
    if (!isTweakEnabled() || !newWindow) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsLayout];
        [self layoutIfNeeded];
    });
}

- (void)prepareForReuse {
    %orig;
    if (!isTweakEnabled()) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsLayout];
        [self layoutIfNeeded];
    });
}

%end

%hook UISearchTextField

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;
    [self applySearchFieldTint];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    [self applySearchFieldTint];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            [self applySearchFieldTint];
        }
    }
}

%new
- (void)applySearchFieldTint {
    UIColor *accent = getAdvancedSearchFieldColor();
    if (!accent) return;

    BOOL useFlat = NO;
    if (isAdvancedTintEnabled()) {
        NSDictionary *prefs = loadPrefs();
        NSString *key = isDarkMode() ? @"advancedSearchFieldColorDark" : @"advancedSearchFieldColor";
        useFlat = (prefs[key] != nil);
    }

    if (!useFlat) {
        CGFloat h, s, b, a;
        if ([accent getHue:&h saturation:&s brightness:&b alpha:&a]) {
            s *= 0.6;
            accent = [[UIColor colorWithHue:h saturation:s brightness:b alpha:1.0] colorWithAlphaComponent:0.6];
        }
    }

    if (self.placeholder) {
        self.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.placeholder
            attributes:@{NSForegroundColorAttributeName: accent}];
    }

    UIImageView *leftView = (UIImageView *)self.leftView;
    if (leftView && [leftView isKindOfClass:[UIImageView class]]) leftView.tintColor = accent;

    if (self.rightView) {
        self.rightView.tintColor = accent;
        for (UIView *subview in self.rightView.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) subview.tintColor = accent;
        }
    }

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIImageView class]]) subview.tintColor = accent;
    }
}

%end

%hook UISearchBar

- (void)setAlpha:(CGFloat)alpha {
    %orig;
    if (!isTweakEnabled()) return;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:%c(UISearchTextField)]) {
            UISearchTextField *textField = (UISearchTextField *)subview;
            CGFloat accessoryAlpha = (alpha < 0.1) ? 0.0 : (alpha * 0.6);
            if (textField.leftView) textField.leftView.alpha = accessoryAlpha;
            if (textField.rightView) {
                textField.rightView.alpha = accessoryAlpha;
                for (UIView *rvSubview in textField.rightView.subviews) {
                    if ([rvSubview isKindOfClass:[UIImageView class]]) rvSubview.alpha = accessoryAlpha;
                }
            }
            for (UIView *tfSubview in textField.subviews) {
                if ([tfSubview isKindOfClass:[UIImageView class]]) tfSubview.alpha = accessoryAlpha;
            }
        }
    }
}

- (void)setTransform:(CGAffineTransform)transform {
    %orig;
    if (!isTweakEnabled()) return;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:%c(UISearchTextField)]) {
            UISearchTextField *textField = (UISearchTextField *)subview;
            CGFloat accessoryAlpha = (fabs(transform.ty) > 10) ? 0.0 : 0.6;
            if (textField.leftView) textField.leftView.alpha = accessoryAlpha;
            if (textField.rightView) {
                textField.rightView.alpha = accessoryAlpha;
                for (UIView *rvSubview in textField.rightView.subviews) {
                    if ([rvSubview isKindOfClass:[UIImageView class]]) rvSubview.alpha = accessoryAlpha;
                }
            }
            for (UIView *tfSubview in textField.subviews) {
                if ([tfSubview isKindOfClass:[UIImageView class]]) tfSubview.alpha = accessoryAlpha;
            }
        }
    }
}

%end

%hook CKDetailsSearchResultsTitleHeaderCell

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyHeaderStyle];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyHeaderStyle];
}

%new
- (void)applyHeaderStyle {
    if (isModernNavBarEnabled()) {
        self.backgroundColor = [UIColor clearColor];
        for (UIView *subview in self.subviews) {
            if ([subview class] == [UIView class]) {
                if (subview.frame.size.height < 2) {
                    subview.hidden = YES;
                    subview.alpha = 0.0;
                } else {
                    subview.backgroundColor = [UIColor clearColor];
                }
            }
        }
    }
    UIColor *tintColor = getSystemTintColor();
    if (tintColor) {
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UILabel class]]) ((UILabel *)subview).textColor = tintColor;
        }
    }
}

%end

%hook CKSearchResultsTitleHeaderCell

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyHeaderStyle];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyHeaderStyle];
}

%new
- (void)applyHeaderStyle {
    if (isModernNavBarEnabled()) {
        self.backgroundColor = [UIColor clearColor];
        for (UIView *subview in self.subviews) {
            if ([subview class] == [UIView class] && subview.frame.size.height < 2) {
                subview.hidden = YES;
                subview.alpha = 0.0;
            }
        }
    }
    if (isCustomTextColorsEnabled()) {
        UIColor *titleColor = getTitleTextColor();
        if (titleColor) {
            for (UIView *subview in self.subviews) {
                if ([subview isKindOfClass:[UILabel class]]) ((UILabel *)subview).textColor = titleColor;
            }
        }
    }
}

%end

%hook CKAvatarTitleCollectionReusableView

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isCustomTextColorsEnabled()) return;
    UIColor *titleColor = getTitleTextColor();
    if (!titleColor) return;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:%c(CKLabel)]) ((CKLabel *)subview).textColor = titleColor;
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !isCustomTextColorsEnabled() || !self.window) return;
    UIColor *titleColor = getTitleTextColor();
    if (!titleColor) return;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:%c(CKLabel)]) ((CKLabel *)subview).textColor = titleColor;
    }
}

%end

%hook CKMessageAcknowledgmentPickerBarView

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) return;
    UIColor *customColor = getReceivedBubbleColor();
    if (!customColor) return;
    for (CALayer *sublayer in self.layer.sublayers) sublayer.backgroundColor = customColor.CGColor;
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !self.window) return;
    UIColor *customColor = getReceivedBubbleColor();
    if (!customColor) return;
    for (CALayer *sublayer in self.layer.sublayers) sublayer.backgroundColor = customColor.CGColor;
}

%end

%hook CKPinnedConversationSummaryBubble

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) return;
    UIView *v = (UIView *)self;
    [v.layer removeAllAnimations];
    NSMutableArray *layerStack = [NSMutableArray arrayWithArray:[v.layer.sublayers copy]];
    while (layerStack.count) {
        CALayer *l = layerStack.lastObject;
        [layerStack removeLastObject];
        [l removeAllAnimations];
        if (l.sublayers.count) [layerStack addObjectsFromArray:l.sublayers];
    }
    if (isiOS15()) [self updateWAMPinnedColors];
    [self applyPinnedBubbleStyle];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    %orig;
    if (!isTweakEnabled() || !isPerContactChatBgEnabled()) return;
    UILabel *best = nil;
    CGFloat bestSize = 0;
    NSMutableArray *queue = [NSMutableArray arrayWithObject:(UIView *)self];
    while (queue.count > 0) {
        UIView *view = queue[0];
        [queue removeObjectAtIndex:0];
        if ([view isKindOfClass:[UILabel class]] && ![view isKindOfClass:%c(CKDateLabel)]) {
            UILabel *label = (UILabel *)view;
            if (label.text.length) {
                CGFloat sz = label.font.pointSize;
                if (sz > bestSize) { bestSize = sz; best = label; }
            }
        }
        for (UIView *sub in view.subviews) [queue addObject:sub];
    }
    NSString *captured = best.text;
    if (!captured.length) return;
    if ([captured isEqualToString:gWAMCurrentContactName]) return;
    gWAMCurrentContactName = [captured copy];
    gWAMCurrentContactDisplayName = [captured copy];
    gWAMCacheSetAt = [NSDate timeIntervalSinceReferenceDate];

    Class messagesCtrlClass = %c(CKMessagesController);
    if (!messagesCtrlClass) return;
    UIViewController *messagesCtrl = nil;
    NSMutableArray *ws = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                [ws addObjectsFromArray:((UIWindowScene *)scene).windows];
            }
        }
    }
    for (UIWindow *w in ws) {
        UIViewController *vc = w.rootViewController;
        while (vc) {
            if ([vc isKindOfClass:messagesCtrlClass]) { messagesCtrl = vc; break; }
            vc = vc.presentedViewController;
        }
        if (messagesCtrl) break;
    }
    if (messagesCtrl) {
        gWAMTriggerNameOverride = captured;
        [messagesCtrl performSelector:@selector(updateChatBackground)];
        gWAMTriggerNameOverride = nil;
    }
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;
        wamReconcileAliasFromTappedView(strongSelf);
    });
}

- (void)didMoveToWindow {
    %orig;
    if (isiOS15()) {
        UIView *selfView = (UIView *)self;
        if (selfView.window) {
            [[NSNotificationCenter defaultCenter] removeObserver:(id)self name:kPrefsChangedNotification object:nil];
            [[NSNotificationCenter defaultCenter] addObserver:(id)self
                selector:@selector(handleWAMPinnedPrefsChanged)
                name:kPrefsChangedNotification
                object:nil];
            [self updateWAMPinnedColors];
        } else {
            [[NSNotificationCenter defaultCenter] removeObserver:(id)self name:kPrefsChangedNotification object:nil];
        }
    }
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !((UIView *)self).window) return;
    [self applyPinnedBubbleStyle];
    UIView *bubbleView = (UIView *)self;
    [bubbleView.layer removeAllAnimations];
    for (CALayer *sublayer in [bubbleView.layer.sublayers copy]) {
        [sublayer removeAllAnimations];
    }
}

%new
- (void)handleWAMPinnedPrefsChanged {
    refreshPrefs();
    [self updateWAMPinnedColors];
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    [self applyPinnedBubbleStyle];
    [CATransaction commit];
}

%new
- (void)updateWAMPinnedColors {
    NSDictionary *prefs = loadPrefs();
    NSString *recvKey = isDarkMode() ? @"receivedBubbleColorDark" : @"receivedBubbleColor";
    NSString *recvTextKey = isDarkMode() ? @"receivedTextColorDark" : @"receivedTextColor";
    UIColor *globalRecv = colorFromHex(prefs[recvKey]) ?: [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    UIColor *globalRecvText = colorFromHex(prefs[recvTextKey]);
    WAMPinnedBubbleLightColor = colorFromHex(prefs[@"pinnedBubbleColor"]) ?: globalRecv;
    WAMPinnedBubbleDarkColor = colorFromHex(prefs[@"pinnedBubbleColorDark"]) ?: globalRecv;
    WAMPinnedTextLightColor = colorFromHex(prefs[@"pinnedBubbleTextColor"]) ?: globalRecvText;
    WAMPinnedTextDarkColor = colorFromHex(prefs[@"pinnedBubbleTextColorDark"]) ?: globalRecvText;

    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = ((UIView *)self).traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    }
    WAMPinnedBubbleCurrentColor = dark ? WAMPinnedBubbleDarkColor : WAMPinnedBubbleLightColor;
    WAMPinnedTextCurrentColor = dark ? WAMPinnedTextDarkColor : WAMPinnedTextLightColor;
}

%new
- (void)applyPinnedBubbleStyle {
    UIColor *bubbleColor = isiOS15() ? WAMPinnedBubbleCurrentColor : getPinnedBubbleColor();
    UIColor *textColor = isiOS15() ? WAMPinnedTextCurrentColor : getPinnedBubbleTextColor();
    if (!bubbleColor && !textColor) return;

    static const char kLastBubbleColorKey = 0;
    UIColor *prevBubble = objc_getAssociatedObject(self, &kLastBubbleColorKey);
    BOOL bubbleSame = (prevBubble == bubbleColor) ||
                      (prevBubble && bubbleColor && [prevBubble isEqual:bubbleColor]);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    if (!bubbleSame && bubbleColor) {
        objc_setAssociatedObject(self, &kLastBubbleColorKey, bubbleColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        for (CALayer *sublayer in ((UIView *)self).layer.sublayers) {
            if ([sublayer isKindOfClass:%c(CKPinnedConversationActivityItemViewBackdropLayer)]) {
                sublayer.backgroundColor = bubbleColor.CGColor;
            } else if ([sublayer isKindOfClass:%c(CKPinnedConversationActivityItemViewShadowLayer)]) {
                sublayer.opacity = 0.3;
            }
        }
    }
    if (textColor) {
        for (UIView *subview in ((UIView *)self).subviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)subview;
                if (![label.textColor isEqual:textColor]) {
                    label.textColor = textColor;
                }
            }
        }
    }
    [CATransaction commit];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:(id)self];
    %orig;
}

%end

%hook CNContactView

- (void)didMoveToSuperview {
    %orig;
    if (!isTweakEnabled() || !self.superview) return;

    UIImage *chatBgImage = loadImageUncached(getChatImagePath());

    if (isChatColorBgEnabled()) {
        self.backgroundColor = getChatBackgroundColor();
    } else if (chatBgImage && shouldShowAnyChatBgImage()) {
        CGFloat blurAmount = getEffectiveChatBgBlur();
        if (blurAmount > 0) chatBgImage = blurImage(chatBgImage, blurAmount);

        for (UIView *subview in [self.superview.subviews copy]) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                if (((UIImageView *)subview).contentMode == UIViewContentModeScaleAspectFill)
                    [subview removeFromSuperview];
            }
        }

        UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.frame];
        imageView.image = chatBgImage;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        imageView.userInteractionEnabled = NO;
        [self.superview insertSubview:imageView atIndex:0];
        self.backgroundColor = [UIColor clearColor];
    } else {
        %orig;
    }

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf applyAdvancedTintToContactLabels];
    });
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled()) { %orig; return; }
    if (isChatColorBgEnabled()) {
        %orig(getChatBackgroundColor());
    } else if (isChatImageBgEnabled()) {
        %orig([UIColor clearColor]);
    } else {
        %orig;
    }
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    if (self.superview && isChatImageBgEnabled()) {
        for (UIView *subview in self.superview.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                UIImageView *imgView = (UIImageView *)subview;
                if (imgView.contentMode == UIViewContentModeScaleAspectFill) {
                    imgView.frame = self.frame;
                    [self.superview sendSubviewToBack:imgView];
                    break;
                }
            }
        }
        self.backgroundColor = [UIColor clearColor];
    }

    [self applyAdvancedTintToContactLabels];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            UIImage *chatBgImage = loadImageUncached(getChatImagePath());
            if (isChatColorBgEnabled()) {
                self.backgroundColor = getChatBackgroundColor();
            } else if (chatBgImage && shouldShowAnyChatBgImage()) {
                CGFloat blurAmount = getEffectiveChatBgBlur();
                if (blurAmount > 0) chatBgImage = blurImage(chatBgImage, blurAmount);
                for (UIView *subview in [self.superview.subviews copy]) {
                    if ([subview isKindOfClass:[UIImageView class]]) {
                        UIImageView *imgView = (UIImageView *)subview;
                        if (imgView.contentMode == UIViewContentModeScaleAspectFill)
                            [imgView removeFromSuperview];
                    }
                }
                UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.frame];
                imageView.image = chatBgImage;
                imageView.contentMode = UIViewContentModeScaleAspectFill;
                imageView.clipsToBounds = YES;
                imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                imageView.userInteractionEnabled = NO;
                [self.superview insertSubview:imageView atIndex:0];
                self.backgroundColor = [UIColor clearColor];
            }
            __weak typeof(self) weakSelf = self;
            dispatch_async(dispatch_get_main_queue(), ^{
                [weakSelf applyAdvancedTintToContactLabels];
            });
        }
    }
}

%new
- (void)applyAdvancedTintToContactLabels {
    UIColor *actionColor = getAdvancedTintColorForView(@"advancedContactActionColor", @"advancedContactActionColorDark", getSystemTintColor(), self);
    if (!actionColor) return;
    [self walkViewForTintLabels:self color:actionColor];
}

%new
- (void)walkViewForTintLabels:(UIView *)view color:(UIColor *)color {
    NSString *className = NSStringFromClass([view class]);
    if ([className containsString:@"Keyboard"] ||
        [className containsString:@"UIKBVisualEffectView"]) return;

    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        CGFloat lr, lg, lb, la;
        if ([label.textColor getRed:&lr green:&lg blue:&lb alpha:&la]) {
            UIColor *systemTint = getSystemTintColor();
            if (systemTint) {
                CGFloat tr, tg, tb, ta;
                if ([systemTint getRed:&tr green:&tg blue:&tb alpha:&ta]) {
                    if (fabs(lr-tr) < 0.05 && fabs(lg-tg) < 0.05 && fabs(lb-tb) < 0.05) {
                        label.textColor = color;
                        return;
                    }
                }
            }
            UIColor *sysBlue = [UIColor systemBlueColor];
            CGFloat br, bg, bb, ba;
            if ([sysBlue getRed:&br green:&bg blue:&bb alpha:&ba]) {
                if (fabs(lr-br) < 0.05 && fabs(lg-bg) < 0.05 && fabs(lb-bb) < 0.05) {
                    label.textColor = color;
                    return;
                }
            }
        }
    }

    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *iv = (UIImageView *)view;
        if (iv.tintColor) {
            CGFloat lr, lg, lb, la;
            UIColor *systemTint = getSystemTintColor();
            if (systemTint && [iv.tintColor getRed:&lr green:&lg blue:&lb alpha:&la]) {
                CGFloat tr, tg, tb, ta;
                if ([systemTint getRed:&tr green:&tg blue:&tb alpha:&ta]) {
                    if (fabs(lr-tr) < 0.05 && fabs(lg-tg) < 0.05 && fabs(lb-tb) < 0.05) {
                        iv.tintColor = color;
                    }
                }
            }
        }
    }

    for (UIView *subview in view.subviews) {
        [self walkViewForTintLabels:subview color:color];
    }
}

%end

%hook UITableViewWrapperView

- (void)didMoveToSuperview {
    %orig;
    if (!isTweakEnabled()) return;
    if (!isChatColorBgEnabled() && !isChatImageBgEnabled()) return; // ← add this
    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 5) {
        if ([parent isKindOfClass:NSClassFromString(@"CNContactView")]) {
            self.backgroundColor = [UIColor clearColor];
            break;
        }
        parent = parent.superview;
        levels++;
    }
}

%end

%hook CNContactHeaderDisplayView
- (void)setFrame:(CGRect)frame {
    CGFloat orig = frame.size.height;
    if (isTweakEnabled() && isPerContactChatBgEnabled() && frame.size.height > 213) {
        frame.size.height = 213;
    }
    if (NO) WAMLOG(@"CNContactHeaderDisplayView.setFrame in=%.1f out=%.1f", orig, frame.size.height);
    %orig(frame);
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    UIColor *titleColor = getChatContactNameColor();
    if (!titleColor) return;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) ((UILabel *)subview).textColor = titleColor;
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    self.backgroundColor = [UIColor clearColor];
    UIColor *titleColor = getChatContactNameColor();
    if (titleColor) {
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UILabel class]]) ((UILabel *)subview).textColor = titleColor;
        }
    }
}

%end

%hook CNContactActionsContainerView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    self.backgroundColor = [UIColor clearColor];
    for (UIView *subview in self.subviews) {
        if ([subview class] == [UIView class] && subview.frame.size.height < 2) {
            subview.hidden = YES;
            subview.alpha = 0.0;
        }
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled()) { %orig; return; }
    %orig([UIColor clearColor]);
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    for (UIView *subview in self.subviews) {
        if ([subview class] == [UIView class] && subview.frame.size.height < 2) {
            subview.hidden = YES;
            subview.alpha = 0.0;
        }
    }
}

%end

%hook UITableViewCell
- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (isTweakEnabled() && isiOS15()) {
        NSString *cls = NSStringFromClass([self class]);
        if ([cls hasPrefix:@"CKDetails"]) {
            %orig([UIColor clearColor]);
            return;
        }
    }
    %orig;
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;

    if (isiOS15()) {
        NSString *cls = NSStringFromClass([self class]);
        if ([cls hasPrefix:@"CKDetails"]) {
            self.backgroundColor = [UIColor clearColor];
            self.contentView.backgroundColor = [UIColor clearColor];
        }
    }

    UIView *parent = self.superview;
    BOOL isInContactView = NO;
    int levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:NSClassFromString(@"CNContactView")]) { isInContactView = YES; break; }
        parent = parent.superview;
        levels++;
    }
    if (!isInContactView) return;

    [self applyContactCellBlur];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handleContactCellPrefsChanged)
        name:kPrefsChangedNotification object:nil];
}

%new
- (void)handleContactCellPrefsChanged {
    refreshPrefs();
    UIView *parent = self.superview;
    BOOL isInContactView = NO;
    int levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:NSClassFromString(@"CNContactView")]) { isInContactView = YES; break; }
        parent = parent.superview;
        levels++;
    }
    if (isInContactView) [self applyContactCellBlur];
}

%new
- (void)applyContactCellBlur {
    for (UIView *subview in [self.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) [subview removeFromSuperview];
    }

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = self.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.layer.cornerRadius = self.layer.cornerRadius;
    blurView.clipsToBounds = YES;
    [self insertSubview:blurView atIndex:0];
    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = YES;

    for (UIView *subview in blurView.subviews) {
        if ([subview isKindOfClass:%c(_UIVisualEffectSubview)]) subview.backgroundColor = [UIColor clearColor];
    }

    if (isCellBlurTintEnabled()) {
        UIColor *tintColor = getCellBlurTintColor();
        if (tintColor) {
            UIView *tintOverlay = [[UIView alloc] initWithFrame:blurView.contentView.bounds];
            tintOverlay.userInteractionEnabled = NO;
            tintOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            tintOverlay.backgroundColor = [tintColor colorWithAlphaComponent:0.5];
            [blurView.contentView addSubview:tintOverlay];
        }
    }
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    if (isiOS15()) {
        NSString *cls = NSStringFromClass([self class]);
        if ([cls hasPrefix:@"CKDetails"]) {
            self.backgroundColor = [UIColor clearColor];
            self.contentView.backgroundColor = [UIColor clearColor];
        }
    }

    UIView *parent = self.superview;
    BOOL isInContactView = NO;
    int levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:NSClassFromString(@"CNContactView")]) { isInContactView = YES; break; }
        parent = parent.superview;
        levels++;
    }
    if (!isInContactView) return;

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            subview.frame = self.bounds;
            subview.layer.cornerRadius = self.layer.cornerRadius;
            UIVisualEffectView *blurView = (UIVisualEffectView *)subview;
            for (UIView *blurSubview in blurView.subviews) {
                if ([blurSubview isKindOfClass:%c(_UIVisualEffectSubview)]) blurSubview.backgroundColor = [UIColor clearColor];
            }
            if (isCellBlurTintEnabled()) {
                UIColor *tintColor = getCellBlurTintColor();
                if (tintColor) {
                    for (UIView *contentSubview in blurView.contentView.subviews) {
                        if ([contentSubview class] == [UIView class]) {
                            contentSubview.backgroundColor = [tintColor colorWithAlphaComponent:0.3];
                            contentSubview.frame = blurView.contentView.bounds;
                            break;
                        }
                    }
                }
            }
            break;
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook CKMessageAcknowledgmentPickerBarItemViewPhone

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    UIColor *accentColor = getChatAdvancedTintColorForView(@"advancedReactionHighlightColor", @"advancedReactionHighlightColorDark", getSystemTintColor(), (UIView *)self);
    if (!accentColor) return;

    UIView *selfView = (UIView *)self;
    if (selfView.layer.sublayers.count == 3) {
        CALayer *highlightLayer = selfView.layer.sublayers[0];
        if (highlightLayer.cornerRadius > 0 && highlightLayer.backgroundColor) {
            UIColor *currentColor = [UIColor colorWithCGColor:highlightLayer.backgroundColor];
            CGFloat r, g, b, a;
            if ([currentColor getRed:&r green:&g blue:&b alpha:&a]) {
                BOOL isStockGreen = (r > 0.15 && r < 0.25 && g > 0.75 && g < 0.9 && b > 0.3 && b < 0.4);
                BOOL isStockBlue = (r < 0.1 && g > 0.4 && g < 0.6 && b > 0.9);
                if (isStockGreen || isStockBlue) highlightLayer.backgroundColor = accentColor.CGColor;
            }
        }
    }
}

%end

%hook CKCanvasBackButtonView

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyCanvasBackButtonStyle];
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;
    [self applyCanvasBackButtonStyle];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handleCanvasBackButtonPrefsChanged)
        name:kPrefsChangedNotification
        object:nil];
}

- (void)tintColorDidChange {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyCanvasBackButtonStyle];
}

%new
- (void)handleCanvasBackButtonPrefsChanged {
    refreshPrefs();
    [self applyCanvasBackButtonStyle];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            [self applyCanvasBackButtonStyle];
        }
    }
}

%new
- (void)applyCanvasBackButtonStyle {
    UIColor *bubbleColor = getAdvancedTintColorForView(@"advancedNavButtonColor", @"advancedNavButtonColorDark", getSystemTintColor(), self);
    if (!bubbleColor) return;

    CGFloat h, s, b, a;
    UIColor *adjustedBubbleColor = bubbleColor;
    if ([bubbleColor getHue:&h saturation:&s brightness:&b alpha:&a]) {
        s = MIN(1.0, s * 1.1);
        b = MIN(1.0, b * 1.3);
        adjustedBubbleColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
    }

    CGFloat r, g, bl, al;
    [adjustedBubbleColor getRed:&r green:&g blue:&bl alpha:&al];
    CGFloat luminance = 0.299 * r + 0.587 * g + 0.114 * bl;
    UIColor *textColor = luminance > 0.5 ? [UIColor blackColor] : [UIColor whiteColor];

    [self applyNavColor:adjustedBubbleColor textColor:textColor toView:self];
}

%new
- (void)applyNavColor:(UIColor *)color textColor:(UIColor *)textColor toView:(UIView *)view {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) continue;
        if ([subview isKindOfClass:[UILabel class]]) {
            ((UILabel *)subview).textColor = textColor;
        } else if (![subview isKindOfClass:[UIImageView class]]) {
            if (subview.backgroundColor && ![subview.backgroundColor isEqual:[UIColor clearColor]]) {
                subview.backgroundColor = color;
            }
        }
        [self applyNavColor:color textColor:textColor toView:subview];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook CKPinnedConversationTypingBubble

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !self.window) return;
    [self applyTypingBubbleColors];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) return;
    [self applyTypingBubbleColors];
}

%new
- (void)applyTypingBubbleColors {
    UIColor *typingColor = getReceivedBubbleColor();
    if (!typingColor) return;

    if (self.layer.sublayers.count >= 3) {
        CALayer *backdropLayer = self.layer.sublayers[2];
        if ([backdropLayer isKindOfClass:%c(CKPinnedConversationActivityItemViewBackdropLayer)]) {
            backdropLayer.backgroundColor = typingColor.CGColor;
        }
    }

    if (self.layer.sublayers.count >= 4) {
        CALayer *dotsContainerLayer = self.layer.sublayers[3];
        CGFloat h, s, b, a;
        if ([typingColor getHue:&h saturation:&s brightness:&b alpha:&a]) {
            b = b > 0.5 ? b * 0.4 : MIN(1.0, b * 2.0);
            UIColor *dotColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
            if (dotsContainerLayer.sublayers.count > 0) {
                CAReplicatorLayer *replicatorLayer = (CAReplicatorLayer *)dotsContainerLayer.sublayers[0];
                if ([replicatorLayer.sublayers firstObject]) {
                    ((CALayer *)[replicatorLayer.sublayers firstObject]).backgroundColor = dotColor.CGColor;
                }
            }
        }
    }
}

%end

%hook CKConversationListTypingIndicatorView

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) return;
    [self applyTypingIndicatorColors];
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !self.window) return;
    [self applyTypingIndicatorColors];
}

%new
- (void)applyTypingIndicatorColors {
    UIColor *typingColor = getReceivedBubbleColor();
    if (!typingColor) return;

    CALayer *typingLayer = nil;
    @try { typingLayer = [self valueForKey:@"typingLayer"]; } @catch (NSException *e) { return; }
    if (!typingLayer || typingLayer.sublayers.count < 2) return;

    CALayer *bubbleContainer = typingLayer.sublayers[0];
    for (CALayer *bubbleLayer in bubbleContainer.sublayers) bubbleLayer.backgroundColor = typingColor.CGColor;

    CALayer *dotsContainer = typingLayer.sublayers[1];
    if (dotsContainer.sublayers.count > 0) {
        CAReplicatorLayer *replicatorLayer = (CAReplicatorLayer *)dotsContainer.sublayers[0];
        CGFloat h, s, b, a;
        if ([typingColor getHue:&h saturation:&s brightness:&b alpha:&a]) {
            b = b > 0.5 ? b * 0.4 : MIN(1.0, b * 2.0);
            UIColor *dotColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
            if ([replicatorLayer.sublayers firstObject]) {
                ((CALayer *)[replicatorLayer.sublayers firstObject]).backgroundColor = dotColor.CGColor;
            }
        }
    }
}

%end

%hook CKTypingView

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) return;
    [self applyTypingIndicatorColors];
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !self.window) return;
    [self applyTypingIndicatorColors];
}

- (void)setIndicatorLayer:(CALayer *)layer {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [self applyTypingIndicatorColors];
    });
}

%new
- (void)applyTypingIndicatorColors {
    UIColor *typingColor = getReceivedBubbleColor();
    if (!typingColor) return;

    CALayer *indicatorLayer = nil;
    @try { indicatorLayer = [self valueForKey:@"indicatorLayer"]; } @catch (NSException *e) { return; }
    if (!indicatorLayer || indicatorLayer.sublayers.count < 2) return;

    CALayer *bubbleContainer = indicatorLayer.sublayers[0];
    for (CALayer *bubbleLayer in bubbleContainer.sublayers) bubbleLayer.backgroundColor = typingColor.CGColor;

    CALayer *dotsContainer = indicatorLayer.sublayers[1];
    if (dotsContainer.sublayers.count > 0) {
        CAReplicatorLayer *replicatorLayer = (CAReplicatorLayer *)dotsContainer.sublayers[0];
        CGFloat h, s, b, a;
        if ([typingColor getHue:&h saturation:&s brightness:&b alpha:&a]) {
            b = b > 0.5 ? b * 0.4 : MIN(1.0, b * 2.0);
            UIColor *dotColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
            if ([replicatorLayer.sublayers firstObject]) {
                ((CALayer *)[replicatorLayer.sublayers firstObject]).backgroundColor = dotColor.CGColor;
            }
        }
    }
}

%end

%hook CKNavigationBarCanvasView

- (void) didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !isCustomTextColorsEnabled()) return;

    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)sub;
            label.textColor = getConversationListTitleColor();
        }
    }
}

%end

%hook CKPhotosSearchResultsModeHeaderReusableView

- (void) setBackgroundColor {
    %orig;
    self.backgroundColor = [UIColor clearColor];
    return;
}

- (void) layoutSubviews {
    %orig;
    self.backgroundColor = [UIColor clearColor];
    return;
}

%end

%hook CKQuickActionSaveButton

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            [self setNeedsLayout];
            [self layoutIfNeeded];
        }
    }
}

%end

/* iOS 17 Specific Hooks */

#define kWrapperBackgroundImageTag 0x57414D54

%hook CKSendMenuPresentationPopoverBackdropView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !isiOS17OrHigher()) return;
    [self applyMenuBackdropColor];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled() || !isiOS17OrHigher()) { %orig; return; }
    UIColor *customTint = getSystemTintColor();
    if (!customTint) { %orig; return; }
    %orig([self adjustedTintColor:customTint]);
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isiOS17OrHigher()) return;
    [self applyMenuBackdropColor];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled() || !isiOS17OrHigher()) return;
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
            [self setNeedsLayout];
        }
    }
}

%new
- (UIColor *)adjustedTintColor:(UIColor *)customTint {
    CGFloat h, s, b, a;
    if ([customTint getHue:&h saturation:&s brightness:&b alpha:&a]) {
        s = MIN(1.0, s * 1.1);
        b = isDarkMode() ? b * 0.5 : MIN(1.0, b * 1.2);
        return [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
    }
    return customTint;
}

%new
- (void)applyMenuBackdropColor {
    UIColor *customTint = getSystemTintColor();
    if (!customTint) return;

    UIView *parent = self.superview;
    BOOL isCorrectHierarchy = NO;
    int levels = 0;
    while (parent && levels < 5) {
        if ([parent isKindOfClass:%c(CKSendMenuPopoverPresentationDimmingView)] ||
            [parent isKindOfClass:%c(CKSendMenuPresentationPopoverView)]) {
            isCorrectHierarchy = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }

    if (isCorrectHierarchy) self.backgroundColor = [self adjustedTintColor:customTint];
}

%end

%hook _UINavigationBarLargeTitleView

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyLargeTitleStyle];
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !isiOS17OrHigher()) return;
    [self applyLargeTitleStyle];

    if (self.window) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(handleLargeTitlePrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    }
}

%new
- (void)handleLargeTitlePrefsChanged {
    refreshPrefs();
    [self applyLargeTitleStyle];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%new
- (void)applyLargeTitleStyle {
    NSString *conversationListTitle = getConversationListTitle();
    UIColor *titleColor = getConversationListTitleColor();

    for (UIView *subview in self.subviews) {
        if (![subview isKindOfClass:[UILabel class]]) continue;
        UILabel *label = (UILabel *)subview;
        if (![label.text isEqualToString:@"Messages"] && ![label.text isEqualToString:conversationListTitle]) continue;
        label.text = conversationListTitle;
        if (titleColor) {
            if (!objc_getAssociatedObject(label, &kWAMOrigTitleColorKey)) {
                objc_setAssociatedObject(label, &kWAMOrigTitleColorKey, label.textColor ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            label.textColor = titleColor;
        } else {
            id orig = objc_getAssociatedObject(label, &kWAMOrigTitleColorKey);
            if (orig && orig != [NSNull null]) label.textColor = orig;
        }
    }
}

%end

%hook UIViewControllerWrapperView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !isiOS17OrHigher() || !self.window) return;

    UIView *parent = self.superview;
    BOOL isNoConversationView = NO;
    int levels = 0;
    while (parent && levels < 10) {
        NSString *className = NSStringFromClass([parent class]);
        if ([className containsString:@"UINavigationTransitionView"] ||
            [className containsString:@"UILayoutContainerView"] ||
            [className containsString:@"UIPanelControllerContentView"]) {
            isNoConversationView = YES;
        }
        parent = parent.superview;
        levels++;
    }
    if (!isNoConversationView) return;

    [self applyWrapperBackground];
}

- (void)didMoveToSuperview {
    %orig;
    if (!isTweakEnabled() || !isiOS17OrHigher() || !self.superview) return;

    UIView *parent = self.superview;
    BOOL isNoConversationView = NO;
    int levels = 0;
    while (parent && levels < 10) {
        NSString *className = NSStringFromClass([parent class]);
        if ([className containsString:@"UINavigationTransitionView"] ||
            [className containsString:@"UILayoutContainerView"] ||
            [className containsString:@"UIPanelControllerContentView"]) {
            isNoConversationView = YES;
        }
        parent = parent.superview;
        levels++;
    }
    if (!isNoConversationView) return;

    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        [weakSelf applyWrapperBackground];
    });
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    if (isiOS17OrHigher()) {
        UIView *contentView = nil;
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIView class]] && ![subview isKindOfClass:[UIImageView class]]) {
                contentView = subview;
                break;
            }
        }
        if (!contentView) return;

        UIView *bgHost = [contentView isKindOfClass:[UIScrollView class]] ? self : contentView;
        UIImageView *existingImageView = (UIImageView *)[bgHost viewWithTag:kWrapperBackgroundImageTag];
        if (existingImageView) existingImageView.frame = bgHost.bounds;
        return;
    }

    {
        UIView *parent = self.superview;
        BOOL isNoConversationView = NO;
        int levels = 0;
        while (parent && levels < 10) {
            NSString *className = NSStringFromClass([parent class]);
            if ([className containsString:@"UINavigationTransitionView"] ||
                [className containsString:@"UILayoutContainerView"] ||
                [className containsString:@"UIPanelControllerContentView"]) {
                isNoConversationView = YES;
            }
            parent = parent.superview;
            levels++;
        }
        if (!isNoConversationView) return;

        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIView class]]) {
                for (UIView *bgView in subview.subviews) {
                    if ([bgView isKindOfClass:[UIImageView class]]) {
                        UIImageView *imgView = (UIImageView *)bgView;
                        if (imgView.frame.origin.x == 0 && imgView.frame.origin.y == 0)
                            imgView.frame = subview.bounds;
                    }
                }
            }
        }
    }
}

%new
- (void)applyWrapperBackground {
    UIView *contentView = nil;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIView class]] && ![subview isKindOfClass:[UIImageView class]]) {
            contentView = subview;
            break;
        }
    }
    if (!contentView) return;

    UIView *bgHost = [contentView isKindOfClass:[UIScrollView class]] ? self : contentView;

    UIImage *chatBgImage = loadImageUncached(getChatImagePath());
    UIImageView *existingImageView = (UIImageView *)[bgHost viewWithTag:kWrapperBackgroundImageTag];

    if (isChatColorBgEnabled()) {
        if (existingImageView) [existingImageView removeFromSuperview];
        bgHost.backgroundColor = getChatBackgroundColor();
        contentView.backgroundColor = [UIColor clearColor];

    } else if (chatBgImage && shouldShowAnyChatBgImage()) {
        CGFloat blurAmount = getEffectiveChatBgBlur();
        if (blurAmount > 0) chatBgImage = blurImage(chatBgImage, blurAmount);

        if (existingImageView) {
            existingImageView.frame = bgHost.bounds;
            existingImageView.image = chatBgImage;
        } else {
            UIImageView *imageView = [[UIImageView alloc] initWithFrame:bgHost.bounds];
            imageView.tag = kWrapperBackgroundImageTag;
            imageView.image = chatBgImage;
            imageView.contentMode = UIViewContentModeScaleAspectFill;
            imageView.clipsToBounds = YES;
            imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            imageView.userInteractionEnabled = NO;
            [bgHost insertSubview:imageView atIndex:0];
        }
        contentView.backgroundColor = [UIColor clearColor];
        bgHost.backgroundColor = [UIColor clearColor];

    } else {
        if (existingImageView) [existingImageView removeFromSuperview];
        bgHost.backgroundColor = [UIColor systemBackgroundColor];
        contentView.backgroundColor = [UIColor systemBackgroundColor];
    }
}

%end

%hook CKEntryViewBlurrableButtonContainer

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isiOS17OrHigher()) return;

    UIColor *customTint = getSystemTintColor();
    if (!customTint) return;

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            CGSize buttonSize = button.frame.size;
            if (buttonSize.width > 27 && buttonSize.width < 28 &&
                buttonSize.height > 27 && buttonSize.height < 28) {
                for (UIView *btnSubview in [button.subviews copy]) {
                    if ([btnSubview isKindOfClass:[UIImageView class]]) { [btnSubview removeFromSuperview]; break; }
                }
                button.backgroundColor = customTint;
                button.layer.cornerRadius = buttonSize.width / 2;
                button.clipsToBounds = YES;

                UIImage *arrowImage = [UIImage systemImageNamed:@"arrow.up"];
                if (arrowImage) {
                    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold];
                    arrowImage = [arrowImage imageWithConfiguration:config];
                    arrowImage = [arrowImage imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
                    UIImageView *arrowOverlay = [[UIImageView alloc] initWithImage:arrowImage];
                    arrowOverlay.userInteractionEnabled = NO;
                    CGSize arrowSize = arrowOverlay.bounds.size;
                    arrowOverlay.frame = CGRectMake((buttonSize.width-arrowSize.width)/2,
                                                   (buttonSize.height-arrowSize.height)/2,
                                                   arrowSize.width, arrowSize.height);
                    [button addSubview:arrowOverlay];
                }
                break;
            }
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !isiOS17OrHigher()) return;

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];

    if (self.window) {
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(handleBlurrableButtonPrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
    }

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

%new
- (void)handleBlurrableButtonPrefsChanged {
    refreshPrefs();
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            [self setNeedsLayout];
            [self layoutIfNeeded];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook LPFlippedView

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled()) { %orig; return; }
    UIColor *customLinkColor = getLinkPreviewBackgroundColor();
    if (customLinkColor) { %orig(customLinkColor); return; }
    %orig;
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    UIColor *customLinkColor = getLinkPreviewBackgroundColor();
    if (customLinkColor) self.backgroundColor = customLinkColor;

    if (self.window) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(handleLinkPrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    }
}

%new
- (void)handleLinkPrefsChanged {
    refreshPrefs();
    UIColor *customLinkColor = getLinkPreviewBackgroundColor();
    if (customLinkColor) self.backgroundColor = customLinkColor;
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            UIColor *customLinkColor = getLinkPreviewBackgroundColor();
            if (customLinkColor) self.backgroundColor = customLinkColor;
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook LPTextView

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyLinkTextColors];
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;
    [self applyLinkTextColors];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handleLinkTextPrefsChanged)
        name:kPrefsChangedNotification
        object:nil];
}

%new
- (void)handleLinkTextPrefsChanged {
    refreshPrefs();
    [self applyLinkTextColors];
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%new
- (void)applyLinkTextColors {
    UIView *parent = self.superview;
    BOOL isInLinkPreview = NO;
    int levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(LPFlippedView)]) { isInLinkPreview = YES; break; }
        parent = parent.superview;
        levels++;
    }
    if (!isInLinkPreview) return;

    UIColor *headerColor = getLinkPreviewTextColor();
    if (!headerColor) return;

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            if (label.font.pointSize > 14) {
                label.textColor = headerColor;
            } else {
                CGFloat h, s, b, a;
                if ([headerColor getHue:&h saturation:&s brightness:&b alpha:&a]) {
                    s *= 0.6;
                    label.textColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:0.7];
                }
            }
        }
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            [self applyLinkTextColors];
        }
    }
}

%end

%hook LPImageView

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    for (UIView *subview in self.subviews) {
        if ([subview class] == [UIView class]) subview.backgroundColor = [UIColor clearColor];
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;
    for (UIView *subview in self.subviews) {
        if ([subview class] == [UIView class]) subview.backgroundColor = [UIColor clearColor];
    }
}

%end

/* iOS 15 specific, mostly compatibility hooks */

%hook CKMessageEntryWaveformView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !isiOS15() || !self.window) return;
    [self applyWAMAudioStyling];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isiOS15()) return;
    [self applyWAMAudioStyling];
}

%new
- (void)applyWAMAudioStyling {
    UIColor *tintColor = getSystemTintColor();
    UIColor *bgColor = isInputFieldCustomizationEnabled() ? getInputFieldBackgroundColor() : nil;

    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]]) {
            UIVisualEffectView *ev = (UIVisualEffectView *)sub;
            if (bgColor && ev.frame.size.width > 0) {
                ev.hidden = YES;

                for (UIView *existing in [self.subviews copy]) {
                    if (existing.tag == 99873) [existing removeFromSuperview];
                }

                UIView *pill = [[UIView alloc] initWithFrame:ev.frame];
                pill.tag = 99873;
                pill.backgroundColor = bgColor;
                pill.layer.cornerRadius = ev.layer.cornerRadius;
                pill.clipsToBounds = YES;
                pill.userInteractionEnabled = NO;
                [self insertSubview:pill atIndex:0];
            }
        }
        if ([sub isKindOfClass:[UIImageView class]] && tintColor) {
            UIImageView *iv = (UIImageView *)sub;
            if (iv.image && iv.image.renderingMode != UIImageRenderingModeAlwaysTemplate) {
                iv.image = [iv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            }
            iv.tintColor = tintColor;
        }
        if ([sub isKindOfClass:[UILabel class]] && tintColor) {
            ((UILabel *)sub).textColor = tintColor;
        }
    }
}

%end

%hook CKMessageEntryRecordedAudioView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !isiOS15() || !self.window) return;
    [self applyWAMAudioStyling];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isiOS15()) return;
    [self applyWAMAudioStyling];
}

%new
- (void)applyWAMAudioStyling {
    UIColor *tintColor = getSystemTintColor();
    UIColor *bgColor = isInputFieldCustomizationEnabled() ? getInputFieldBackgroundColor() : nil;

    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]]) {
            UIVisualEffectView *ev = (UIVisualEffectView *)sub;
            if (bgColor && ev.frame.size.width > 0) {
                ev.hidden = YES;

                for (UIView *existing in [self.subviews copy]) {
                    if (existing.tag == 99873) [existing removeFromSuperview];
                }

                UIView *pill = [[UIView alloc] initWithFrame:ev.frame];
                pill.tag = 99873;
                pill.backgroundColor = bgColor;
                pill.layer.cornerRadius = ev.layer.cornerRadius;
                pill.clipsToBounds = YES;
                pill.userInteractionEnabled = NO;
                [self insertSubview:pill atIndex:0];
            }
        }
        if ([sub isKindOfClass:[UIImageView class]] && tintColor) {
            UIImageView *iv = (UIImageView *)sub;
            if (iv.image && iv.image.renderingMode != UIImageRenderingModeAlwaysTemplate) {
                iv.image = [iv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            }
            iv.tintColor = tintColor;
        }
        if ([sub isKindOfClass:[UILabel class]] && tintColor) {
            ((UILabel *)sub).textColor = tintColor;
        }
        if ([sub isKindOfClass:[UIButton class]] && tintColor) {
            ((UIButton *)sub).tintColor = tintColor;
        }
    }
}

%end

%hook CKAvatarNavigationBar

- (void)layoutSubviews {
    %orig;
    [self applyWAMTitleStyling];
    [self wamApplyChatBgForVisibleTitle];
}

%new
- (void)wamApplyChatBgForVisibleTitle {
    return;
    if (!isTweakEnabled() || !isPerContactChatBgEnabled()) return;
    UILabel *best = nil;
    NSMutableArray *queue = [NSMutableArray arrayWithObject:(UIView *)self];
    while (queue.count > 0) {
        UIView *view = queue[0];
        [queue removeObjectAtIndex:0];
        if ([view isKindOfClass:%c(CKLabel)]) {
            UILabel *label = (UILabel *)view;
            if (label.text.length && !best) best = label;
        }
        for (UIView *sub in view.subviews) [queue addObject:sub];
    }

    NSString *captured = best.text;
    if (!captured.length) return;
    gWAMCurrentContactName = [captured copy];
    gWAMCacheSetAt = [NSDate timeIntervalSinceReferenceDate];

    Class messagesCtrlClass = %c(CKMessagesController);
    if (!messagesCtrlClass) return;
    UIViewController *messagesCtrl = nil;
    NSMutableArray *ws = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if ([scene isKindOfClass:[UIWindowScene class]]) {
                [ws addObjectsFromArray:((UIWindowScene *)scene).windows];
            }
        }
    }
    for (UIWindow *w in ws) {
        UIViewController *vc = w.rootViewController;
        while (vc) {
            if ([vc isKindOfClass:messagesCtrlClass]) { messagesCtrl = vc; break; }
            vc = vc.presentedViewController;
        }
        if (messagesCtrl) break;
    }
    if (messagesCtrl) {
        gWAMTriggerNameOverride = captured;
        [messagesCtrl performSelector:@selector(updateChatBackground)];
        gWAMTriggerNameOverride = nil;
    }
}

- (void)didMoveToWindow {
    %orig;
    UIView *selfView = (UIView *)self;
    if (selfView.window) {
        [[NSNotificationCenter defaultCenter] removeObserver:(id)self name:kPrefsChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:(id)self
            selector:@selector(handleWAMTitlePrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
        [selfView setNeedsLayout];
        [selfView layoutIfNeeded];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:(id)self name:kPrefsChangedNotification object:nil];
    }
}

%new
- (void)handleWAMTitlePrefsChanged {
    refreshPrefs();
    [(UIView *)self setNeedsLayout];
    [(UIView *)self layoutIfNeeded];
}

%new
- (void)applyWAMTitleStyling {
    if (!isTweakEnabled()) return;

    NSString *conversationListTitle = getConversationListTitle();
    UIColor *convListTitleColor = isiOS15() ? getConversationListTitleColor() : nil;
    NSString *chatContactName = gWAMCurrentContactName;
    UIColor *chatNameColor = chatContactName.length ? getChatContactNameColor() : nil;

    NSMutableArray *queue = [NSMutableArray arrayWithObject:(UIView *)self];
    while (queue.count > 0) {
        UIView *view = queue[0];
        [queue removeObjectAtIndex:0];
        if ([view isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)view;
            if (isiOS15() &&
                ([label.text isEqualToString:@"Messages"] ||
                 [label.text isEqualToString:conversationListTitle] ||
                 (WAMLastKnownTitle && [label.text isEqualToString:WAMLastKnownTitle]))) {
                label.text = conversationListTitle;
                if (convListTitleColor) {
                    if (!objc_getAssociatedObject(label, &kWAMOrigTitleColorKey)) {
                        objc_setAssociatedObject(label, &kWAMOrigTitleColorKey, label.textColor ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    }
                    label.textColor = convListTitleColor;
                } else {
                    id orig = objc_getAssociatedObject(label, &kWAMOrigTitleColorKey);
                    if (orig && orig != [NSNull null]) label.textColor = orig;
                }
                WAMLastKnownTitle = conversationListTitle;
            }
            else if (chatContactName.length && [label.text isEqualToString:chatContactName]) {
                if (chatNameColor) {
                    if (!objc_getAssociatedObject(label, &kWAMOrigTitleColorKey)) {
                        objc_setAssociatedObject(label, &kWAMOrigTitleColorKey, label.textColor ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    }
                    label.textColor = chatNameColor;
                } else {
                    id orig = objc_getAssociatedObject(label, &kWAMOrigTitleColorKey);
                    if (orig && orig != [NSNull null]) label.textColor = orig;
                }
            }
        }
        for (UIView *sub in view.subviews) {
            [queue addObject:sub];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:(id)self];
    %orig;
}

%end

%hook CKConversationListEmbeddedStandardTableViewCell

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isiOS15()) return;
    applyCustomTextColors((UIView *)self);
}

- (void)didMoveToWindow {
    %orig;
    UIView *selfView = (UIView *)self;
    if (!isTweakEnabled() || !isiOS15() || !selfView.window) return;
    applyCustomTextColors(selfView);
}

%end

%hook CKPinnedConversationActivityItemViewBackdropLayer

- (void)setBackgroundColor:(CGColorRef)backgroundColor {
    if (!isiOS15() || !WAMPinnedBubbleCurrentColor) { %orig; return; }
    %orig(WAMPinnedBubbleCurrentColor.CGColor);
}

%end


/*============
    %ctor
============*/
%ctor {
    reloadPrefs();

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        (CFNotificationCallback)reloadPrefsAndNotify,
        CFSTR("com.oakstheawesome.whatamessprefs/prefsChanged"),
        NULL,
        CFNotificationSuspensionBehaviorCoalesce
    );
    dispatch_async(dispatch_get_main_queue(), ^{
        [WAMHeartbeatTarget shared];
    });
}

/* Made with love from the Show Me State. Support small content creators and local farmers! */