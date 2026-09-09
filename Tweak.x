#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <WAMTweakInterfaces.h>
#import "WAMPresetModel.h"
#import "WAMPresetCardView.h"
#import "WAMGradientBuilderController.h"

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

// Marketing-screenshot mode — redacts names/previews/avatars in the conversation list with fake data so real
// conversations never appear in ad art. DEV/BUILD-TIME ONLY: set this to 0 (or delete the whole
// WAM_SCREENSHOT_MODE section, search for it below) before building anything that ships.
#define WAM_SCREENSHOT_MODE 1
// Declared unconditionally (not inside the #if block) so the general UILabel -setTextColor: hook can bypass
// its per-context color logic for this one injected label even when screenshot mode is compiled out — a
// no-op tag check either way, negligible cost, avoids duplicating the constant in two places.
static const NSInteger kWAMScreenshotInitialLabelTag = 84492;

__attribute__((unused)) static void logToFile(NSString *message) {
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
static BOOL wamIsNotificationExtension(void);

//Version Splash screen, make sure to bump this value so it acutally registers an update occurred.
#define kWAMTweakVersion @"1.3"
static NSString * const kWAMChangelogTitle = @"What's New in WhatAMess";
static NSString * const kWAMGitHubURL = @"https://github.com/OaksTheAwesome/WhatAMess";

static NSMutableDictionary *cachedPrefs = nil;
static BOOL gWAMIsDarkModeOnIOS15 = NO;
static BOOL gWAMChangelogShownThisLaunch = NO;
static NSString *gWAMCurrentContactName = nil;
static NSString *gWAMCurrentContactDisplayName = nil;
static NSString *gWAMTriggerNameOverride = nil;
static NSString *gWAMActiveChatName = nil;
static NSString *gWAMNotifContactName = nil;
// Pinned while a chat's contact/details card is on screen: the chat's own view leaves the window when
// details pushes on top, so gWAMChatIsActiveSurface flips off — this keeps per-contact theming resolving
// to that chat's contact for the details view.
static NSString *gWAMDetailsContactName = nil;
// Bumped whenever a chat is force-re-themed (per-contact preset/toggle applied). A background file can be
// overwritten with new content but the SAME path and an unchanged mtime (preset images are copied with
// copyItemAtPath:, which preserves the source's modification date), so mtime alone can't invalidate the
// cached image or the "state unchanged" skip. Folding this counter into both keys guarantees a rebuild.
static NSUInteger gWAMChatBgGen = 0;
static const char kWAMChatBgStateKey = 0;   // assoc-obj key on the chat view holding its bg "state" string
static BOOL gWAMChatIsActiveSurface = NO;
// Set while theming a conversation-list element (e.g. the relocated bottom search field) so advanced-tint
// resolution ignores the last chat's per-contact overrides and uses the global values instead — the
// search bar belongs to the list, not to any one contact.
static BOOL gWAMForceGlobalColorResolve = NO;
static __weak UIView *gWAMNameShadow = nil;   // name-platter shadow view, tracked so it can be torn down when the chat is left
static BOOL gWAMChatLeaving = NO;             // set while the chat is animating away, so the shadow's fade-out isn't reset
static BOOL gWAMPreviewActive = NO;
static NSTimeInterval gWAMCacheSetAt = 0;
static NSTimeInterval gWAMTapSetAt = 0;

#define kWAMLastChatNamePath @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/last_chat.txt"

static NSString *gWAMLastPersistedChatName = nil;

static void wamPersistLastChatName(NSString *name) {
    if (!name.length) return;
    if ([name isEqualToString:gWAMLastPersistedChatName]) return;
    gWAMLastPersistedChatName = [name copy];
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
        NSString *dir = [kWAMLastChatNamePath stringByDeletingLastPathComponent];
        [[NSFileManager defaultManager] createDirectoryAtPath:dir
                                  withIntermediateDirectories:YES
                                                   attributes:nil
                                                        error:nil];
        [name writeToFile:kWAMLastChatNamePath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    });
}

__attribute__((constructor))
static void wamLoadLastChatNameAtStartup(void) {
    NSString *name = [NSString stringWithContentsOfFile:kWAMLastChatNamePath
                                               encoding:NSUTF8StringEncoding
                                                  error:nil];
    name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length) {
        gWAMCurrentContactName = [name copy];
        gWAMCurrentContactDisplayName = [name copy];
        gWAMCacheSetAt = [NSDate timeIntervalSinceReferenceDate];
        gWAMLastPersistedChatName = [name copy];
    }
}

__attribute__((constructor))
static void wamMigrateLegacyTrailingUnderscoreKeys(void) {
    NSString *path = @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs.plist";
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:path];
    if (!prefs) return;
    BOOL dirty = NO;

    NSMutableDictionary *overrides = [(NSDictionary *)prefs[@"perContactOverrides"] mutableCopy];
    if (overrides) {
        NSArray *keys = [overrides.allKeys copy];
        for (NSString *key in keys) {
            if (![key hasSuffix:@"_"]) continue;
            NSString *trimmed = key;
            while ([trimmed hasSuffix:@"_"]) trimmed = [trimmed substringToIndex:trimmed.length - 1];
            if (!trimmed.length) continue;
            NSDictionary *legacy = overrides[key];
            NSDictionary *canonical = overrides[trimmed];
            if ([canonical isKindOfClass:[NSDictionary class]]) {
                NSMutableDictionary *merged = [legacy mutableCopy];
                [merged addEntriesFromDictionary:canonical];
                overrides[trimmed] = merged;
            } else {
                overrides[trimmed] = legacy;
            }
            [overrides removeObjectForKey:key];
            dirty = YES;
        }
        if (dirty) prefs[@"perContactOverrides"] = overrides;
    }

    NSMutableDictionary *blurMap = [(NSDictionary *)prefs[@"perContactBlur"] mutableCopy];
    if (blurMap) {
        NSArray *keys = [blurMap.allKeys copy];
        for (NSString *key in keys) {
            if (![key hasSuffix:@"_"]) continue;
            NSString *trimmed = key;
            while ([trimmed hasSuffix:@"_"]) trimmed = [trimmed substringToIndex:trimmed.length - 1];
            if (!trimmed.length || blurMap[trimmed]) continue;
            blurMap[trimmed] = blurMap[key];
            [blurMap removeObjectForKey:key];
            dirty = YES;
        }
        if (dirty) prefs[@"perContactBlur"] = blurMap;
    }

    if (dirty) [prefs writeToFile:path atomically:YES];

    NSString *imageDir = @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/per_contact";
    NSFileManager *fm = [NSFileManager defaultManager];
    NSArray *files = [fm contentsOfDirectoryAtPath:imageDir error:nil];
    for (NSString *fname in files) {
        if (![fname hasSuffix:@".jpg"]) continue;
        NSString *stem = [fname stringByDeletingPathExtension];
        BOOL isDark = [stem hasSuffix:@"_dark"];
        NSString *namePart = isDark ? [stem substringToIndex:stem.length - 5] : stem;
        if (![namePart hasSuffix:@"_"]) continue;
        NSString *trimmedName = namePart;
        while ([trimmedName hasSuffix:@"_"]) trimmedName = [trimmedName substringToIndex:trimmedName.length - 1];
        if (!trimmedName.length) continue;
        NSString *newFname = [NSString stringWithFormat:@"%@%@.jpg", trimmedName, isDark ? @"_dark" : @""];
        if ([fname isEqualToString:newFname]) continue;
        NSString *src = [imageDir stringByAppendingPathComponent:fname];
        NSString *dst = [imageDir stringByAppendingPathComponent:newFname];
        if ([fm fileExistsAtPath:dst]) {
            [fm removeItemAtPath:src error:nil];
        } else {
            [fm moveItemAtPath:src toPath:dst error:nil];
        }
    }
}
static BOOL gWAMConvListViewVisible = NO;
static NSString *getActiveContactNameForBg(void);
static void wamReconcileAliasForChat(NSString *chatIdentifier, NSString *displayName);
static void wamApplyNavButtonPlatter(UIView *host);
static void wamApplyNamePlatter(UIView *nameView);
static BOOL wamIsLandscape(void);
static void wamTearDownChatNavOverlays(void);
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

// Force an immediate, settled layout pass over every window — used after a rotation/size transition
// completes so all our layoutSubviews-driven overlays (name platter, avatar/name shadows, nav-button
// platters, bottom search) recompute against the final post-rotation frames instead of the mid-transition
// ones that left them stale (shadows stranded far-left, platters mis-sized).
static void wamForceLayoutAllWindows(void) {
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                wamForceVisualRefresh(w);   // recursively mark EVERY subview needsLayout (not just the window)
                [w layoutIfNeeded];         // then lay them all out so each overlay's layoutSubviews re-runs
            }
        }
    }
}

// Remove the chat title/avatar overlays (name platter 4401, name shadow 4403, avatar shadow 4405). In the
// landscape two-column split iOS does NOT re-lay-out the chat's title/avatar area, so these overlays can't
// be repositioned and otherwise freeze at their portrait x (≈182) — reading as "far left" in the wide
// container. Tearing them down gives a clean stock title in landscape; the name view rebuilds them in
// portrait (which lays out normally).
__attribute__((unused)) static void wamTearDownChatNavOverlays(void) {
    static const NSInteger tags[] = {4401, 4403, 4405};
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                for (int i = 0; i < 3; i++) {
                    UIView *v;
                    while ((v = [w viewWithTag:tags[i]])) [v removeFromSuperview];
                }
            }
        }
    }
    gWAMNameShadow = nil;
}

// Re-drive the chat title/avatar overlays after a rotation. iOS doesn't re-lay-out the chat's title
// collection view (CKAvatarTitleCollectionReusableView) or the avatar container on a size change, so their
// overlays freeze at the pre-rotation geometry. Find those views and force them to recompute against the
// settled post-rotation frames so the name platter / shadows / avatar shadow reposition for the new width.
static void wamRedriveChatOverlays(void) {
    // In the landscape split the chat title/avatar views aren't re-laid-out (and often aren't even in the
    // compact bar), so their overlays can't tear themselves down and freeze at portrait geometry. Remove
    // them by tag over every window; portrait rebuilds them when it lays out normally.
    if (wamIsLandscape()) { wamTearDownChatNavOverlays(); return; }
    Class nameCls = %c(CKAvatarTitleCollectionReusableView);
    Class avatarCls = %c(CNVisualIdentityAvatarContainerView);
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            for (UIWindow *w in ((UIWindowScene *)scene).windows) {
                NSMutableArray *q = [NSMutableArray arrayWithObject:w];
                while (q.count) {
                    UIView *v = q.firstObject; [q removeObjectAtIndex:0];
                    if (nameCls && [v isKindOfClass:nameCls]) {
                        wamApplyNamePlatter(v);
                    } else if (avatarCls && [v isKindOfClass:avatarCls]) {
                        [v setNeedsLayout];
                        [v layoutIfNeeded];
                    }
                    [q addObjectsFromArray:v.subviews];
                }
            }
        }
    }
}

static void wamForceGlobalColorsOnConvListLabels(UIView *view) {
    if (!view) return;
    Class cellCls = %c(CKConversationListCollectionViewConversationCell);
    if ([view isKindOfClass:%c(CKLabel)]) {
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

static void wamHealBlursInView(UIView *root);
static BOOL wamIsNotificationExtension(void);

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
        s->_link.preferredFramesPerSecond = 60;
        [s->_link addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
    });
    return s;
}
- (void)tick {
    if (!isTweakEnabled()) return;
    // This whole tick is about tracking a live CKMessagesController's foreground/background state in the
    // main app — a concept that doesn't exist in any extension process. There, it always finds foundCtrl ==
    // nil and "no chat visible", so all it ever did was forcibly reset gWAMChatIsActiveSurface/
    // gWAMCurrentContactName back to nil on literally the next frame after wamAdoptNotificationContact /
    // wamUpdateComposeRecipientName set them — a 60fps fight that made per-contact resolution flicker
    // between correct and reset. Those two functions are the sole source of truth for extension processes;
    // let them own it entirely.
    if (wamIsNotificationExtension()) return;
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

    if (foundCtrl && foundCtrl.isViewLoaded) {
        static int healTick = 0;
        if (++healTick >= 9) { healTick = 0; wamHealBlursInView(foundCtrl.view); }
    }

    id conv = nil;
    NSString *convSource = @"none";
    if (foundCtrl) {
        Ivar cv = class_getInstanceVariable([foundCtrl class], "_currentConversation");
        if (cv) {
            conv = object_getIvar(foundCtrl, cv);
            if (conv) convSource = @"ivar:_currentConversation";
        }
        if (!conv) {
            @try {
                conv = [foundCtrl valueForKey:@"currentConversation"];
                if (conv) convSource = @"kvc:currentConversation";
            } @catch (NSException *e) {}
        }
        if (!conv) {
            @try {
                conv = [foundCtrl valueForKey:@"_currentConversation"];
                if (conv) convSource = @"kvc:_currentConversation";
            } @catch (NSException *e) {}
        }
        if (!conv) {
            for (UIViewController *child in foundCtrl.childViewControllers) {
                Class chTransCls = NSClassFromString(@"CKTranscriptCollectionViewController");
                if (chTransCls && [child isKindOfClass:chTransCls]) {
                    @try {
                        conv = [child valueForKey:@"conversation"];
                        if (conv) { convSource = @"transcript:conversation"; break; }
                    } @catch (NSException *e) {}
                }
                Class navCls2 = NSClassFromString(@"CKNavigationController");
                if (navCls2 && [child isKindOfClass:navCls2]) {
                    UIViewController *top = ((UINavigationController *)child).topViewController;
                    if (top) {
                        @try {
                            conv = [top valueForKey:@"conversation"];
                            if (conv) { convSource = @"navTop:conversation"; break; }
                        } @catch (NSException *e) {}
                        @try {
                            conv = [top valueForKey:@"_conversation"];
                            if (conv) { convSource = @"navTop:_conversation"; break; }
                        } @catch (NSException *e) {}
                    }
                }
            }
        }
    }
    (void)convSource;

    static void *prevConvPtr = NULL;
    void *currentConvPtr = (__bridge void *)conv;
    BOOL convPtrChanged = (currentConvPtr != prevConvPtr);

    NSString *resolvedName = nil;
    if (conv && convPtrChanged) {
        id chat = nil;
        static const char *chatIvars[] = {"_chat", "_currentChat", "_imChat", "_chatItem", NULL};
        for (int i = 0; chatIvars[i]; i++) {
            Ivar v = class_getInstanceVariable([conv class], chatIvars[i]);
            if (!v) continue;
            chat = object_getIvar(conv, v);
            if (chat) break;
        }
        if (!chat) {
            @try { chat = [conv valueForKey:@"chat"]; } @catch (NSException *e) {}
        }

        SEL sels[] = {
            @selector(displayName),
            @selector(name),
            @selector(title),
            @selector(roomName),
            NSSelectorFromString(@"effectiveDisplayName"),
            NSSelectorFromString(@"primaryRecipientDisplayName"),
            NSSelectorFromString(@"groupName"),
            (SEL)0
        };
        for (int i = 0; sels[i] != (SEL)0; i++) {
            if ([chat respondsToSelector:sels[i]]) {
                NSString *dn = ((NSString *(*)(id, SEL))objc_msgSend)(chat, sels[i]);
                if ([dn isKindOfClass:[NSString class]] && dn.length) { resolvedName = dn; break; }
            }
            if ([conv respondsToSelector:sels[i]]) {
                NSString *dn = ((NSString *(*)(id, SEL))objc_msgSend)(conv, sels[i]);
                if ([dn isKindOfClass:[NSString class]] && dn.length) { resolvedName = dn; break; }
            }
        }

        if (!resolvedName.length) {
            static const char *nameIvars[] = {"_name", "_displayName", "_groupName", "_title", "_displayTitle", NULL};
            for (int i = 0; nameIvars[i]; i++) {
                Ivar v = class_getInstanceVariable([conv class], nameIvars[i]);
                if (v) {
                    id val = object_getIvar(conv, v);
                    if ([val isKindOfClass:[NSString class]] && [(NSString *)val length]) { resolvedName = val; break; }
                }
                if (chat) {
                    v = class_getInstanceVariable([chat class], nameIvars[i]);
                    if (v) {
                        id val = object_getIvar(chat, v);
                        if ([val isKindOfClass:[NSString class]] && [(NSString *)val length]) { resolvedName = val; break; }
                    }
                }
            }
        }

        resolvedName = [resolvedName stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }

    BOOL nameChanged = (resolvedName.length && ![resolvedName isEqualToString:gWAMCurrentContactName]);

    if (nameChanged) {
        gWAMCurrentContactName = [resolvedName copy];
        gWAMCurrentContactDisplayName = [resolvedName copy];
        gWAMActiveChatName = [resolvedName copy];
        gWAMCacheSetAt = [NSDate timeIntervalSinceReferenceDate];
        wamPersistLastChatName(resolvedName);
    }

    if (convPtrChanged) {
        prevConvPtr = currentConvPtr;
        if (conv && foundCtrl) {
            if ([foundCtrl respondsToSelector:@selector(updateChatBackground)]) {
                [foundCtrl performSelector:@selector(updateChatBackground)];
            }
        }
    }

    if (nameChanged || (convPtrChanged && conv)) {
        [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
    }

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
    BOOL navTransitioning = NO;
    if (navCls && foundCtrl) {
        for (UIViewController *child in foundCtrl.childViewControllers) {
            if ([child isKindOfClass:navCls]) {
                UINavigationController *nav = (UINavigationController *)child;
                topVCClass = NSStringFromClass([nav.topViewController class]) ?: @"(nil)";
                navTransitioning = (nav.transitionCoordinator != nil);
                break;
            }
        }
    }
    BOOL topVCChanged = ![topVCClass isEqualToString:prevTopVCClass];
    BOOL chatBecameTop = topVCChanged &&
        [topVCClass isEqualToString:@"CKNavigationController"];
    if (listInWindow != prevListVisible || topVCChanged) {
        prevListVisible = listInWindow;
        prevTopVCClass = [topVCClass copy];
    }
    if (chatBecameTop && conv && foundCtrl &&
        [foundCtrl respondsToSelector:@selector(updateChatBackground)]) {
        [foundCtrl performSelector:@selector(updateChatBackground)];
    }
    gWAMConvListViewVisible = listInWindow;

    BOOL convListIsTop = [topVCClass containsString:@"ConversationList"] ||
                         [topVCClass containsString:@"ConvList"];
    BOOL chatIsActiveSurface;
    if (gWAMPreviewActive) {
        chatIsActiveSurface = YES;
    } else if (!chatIsVisible) {
        chatIsActiveSurface = NO;
    } else if (convListIsTop) {
        chatIsActiveSurface = (navTransitioning && gWAMChatIsActiveSurface) ? YES : NO;
    } else if ([topVCClass isEqualToString:@"(none)"] && listInWindow && !conv) {
        chatIsActiveSurface = (navTransitioning && gWAMChatIsActiveSurface) ? YES : NO;
    } else {
        chatIsActiveSurface = YES;
    }

    static BOOL prevChatActive = NO;
    BOOL stateChanged = (chatIsActiveSurface != prevChatActive);
    prevChatActive = chatIsActiveSurface;

    if (chatIsActiveSurface) {
        BOOL wasActive = gWAMChatIsActiveSurface;
        gWAMChatIsActiveSurface = YES;
        if (!wasActive) {
            [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
        }
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

static BOOL wamIsPreviewContext(UIViewController *vc) {
    if (!vc || vc.parentViewController || vc.presentingViewController) return NO;
    UIView *v = vc.viewIfLoaded;
    int depth = 0;
    while (v && depth < 12) {
        if ([NSStringFromClass([v class]) isEqualToString:@"UIDropShadowView"]) return YES;
        v = v.superview;
        depth++;
    }
    return NO;
}

static NSString *getCurrentContactName(void) {
    if (gWAMNotifContactName.length) return gWAMNotifContactName;
    if (gWAMDetailsContactName.length) return gWAMDetailsContactName;
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
    name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (name.length) {
        if (cid.length) wamReconcileAliasForChat(cid, name);
        NSTimeInterval now2 = [NSDate timeIntervalSinceReferenceDate];
        BOOL tapJustFired = (now2 - gWAMTapSetAt) < 0.5;
        if (tapJustFired && gWAMCurrentContactName.length &&
            ![name isEqualToString:gWAMCurrentContactName]) {
            return gWAMCurrentContactName;
        }
        gWAMCurrentContactName = [name copy];
        gWAMCurrentContactDisplayName = [name copy];
        gWAMCacheSetAt = now2;
        wamPersistLastChatName(name);
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

// A per-contact change made from the settings sheet (a preset apply, a toggle, a mode flip) needs to
// re-theme the chat *now* — posting the prefs notification alone doesn't fully re-render it (only a
// fresh chat-entry does). Find the live CKMessagesController and run its comprehensive re-theme, so the
// background, platters and colors all pick up the new per-contact values without leaving the chat.
static void wamTriggerFullChatRefresh(void) {
    Class msgCls = %c(CKMessagesController);
    NSMutableArray<UIWindow *> *wins = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes)
            if ([scene isKindOfClass:[UIWindowScene class]])
                [wins addObjectsFromArray:((UIWindowScene *)scene).windows];
    }
    for (UIWindow *w in wins) {
        UIViewController *mc = msgCls ? wamFindVCInHierarchy(w.rootViewController, msgCls) : nil;
        if (mc && [mc respondsToSelector:@selector(wamRethemeCurrentChat)]) {
            [mc performSelector:@selector(wamRethemeCurrentChat)];
            return;
        }
    }
    // No chat on screen — at least reload and let observers repaint.
    reloadPrefs();
    [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
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
    NSString *trimmed = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) return nil;
    NSCharacterSet *invalid = [NSCharacterSet characterSetWithCharactersInString:@"/:?#[]@!$&'()*+,;= \t\n\r"];
    NSArray *parts = [trimmed componentsSeparatedByCharactersInSet:invalid];
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
    // Forced global (e.g. the conversation-list search bar in the landscape split): never resolve the open
    // chat's per-contact override, even though its surface is active.
    if (gWAMForceGlobalColorResolve) return loadPrefs()[key];
    if (!gWAMChatIsActiveSurface && !gWAMNotifContactName.length && !gWAMDetailsContactName.length) return loadPrefs()[key];
    NSString *name = getCurrentContactName();
    if (name.length && perContactOverridesEnabled(name)) {
        id override = getPerContactOverride(name, key);
        if (override) return override;
    }
    return loadPrefs()[key];
}

__attribute__((unused))
static BOOL chatHasPerContactOverride(void) {
    if (!gWAMChatIsActiveSurface && !gWAMNotifContactName.length) return NO;
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

static NSString *wamReadCurrentChatCanonicalName(void) {
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
    if (!messagesCtrl) return nil;

    Ivar cv = class_getInstanceVariable([messagesCtrl class], "_currentConversation");
    id conv = cv ? object_getIvar(messagesCtrl, cv) : nil;
    if (!conv) return nil;

    NSString *name = nil;
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
    name = [name stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    return name.length ? name : nil;
}

static NSString *getActiveContactNameForBg(void) {
    NSString *canonical = wamReadCurrentChatCanonicalName();
    if (canonical.length) return canonical;
    if (gWAMTriggerNameOverride.length) return gWAMTriggerNameOverride;
    return gWAMActiveChatName;
}

static void wamResolvePerContactImageAndName(NSString **outPath, NSString **outName) {
    if (outPath) *outPath = nil;
    if (outName) *outName = nil;
    if (!isPerContactChatBgEnabled()) return;
    if (!gWAMChatIsActiveSurface && !gWAMNotifContactName.length && !gWAMDetailsContactName.length) return;

    NSMutableArray *candidates = [NSMutableArray array];
    void (^add)(NSString *) = ^(NSString *n) {
        if (n.length && ![candidates containsObject:n]) [candidates addObject:n];
    };
    add(gWAMNotifContactName);
    add(gWAMDetailsContactName);
    add(getActiveContactNameForBg());
    add(gWAMTriggerNameOverride);
    add(gWAMCurrentContactName);
    add(gWAMCurrentContactDisplayName);
    if (!candidates.count) return;

    BOOL dark = isDarkMode();
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *name in candidates) {
        if (!perContactOverridesEnabled(name)) continue;
        NSString *p = getPerContactImagePath(name, dark);
        if (p && [fm fileExistsAtPath:p]) {
            if (outPath) *outPath = p;
            if (outName) *outName = name;
            return;
        }
    }
    for (NSString *name in candidates) {
        if (!perContactOverridesEnabled(name)) continue;
        NSString *p = getPerContactImagePath(name, !dark);
        if (p && [fm fileExistsAtPath:p]) {
            if (outPath) *outPath = p;
            if (outName) *outName = name;
            return;
        }
    }
}

static NSString *getPerContactImagePathForCurrentChat() {
    NSString *p = nil;
    wamResolvePerContactImageAndName(&p, NULL);
    return p;
}

static NSString *getChatImagePath() {
    NSString *perPath = getPerContactImagePathForCurrentChat();
    return perPath ?: getDefaultChatImagePath();
}

static CGFloat getEffectiveChatBgBlur() {
    NSString *perPath = nil, *perName = nil;
    wamResolvePerContactImageAndName(&perPath, &perName);
    if (perPath) {
        CGFloat b = getPerContactBlur(perName, isDarkMode());
        return b;
    }
    CGFloat g = getChatImageBlurAmount();
    return g;
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

__attribute__((unused)) static BOOL wamIsLandscape(void) {
    // UIScreen.bounds does NOT rotate on iPhone — it always reports portrait dimensions — so aspect
    // ratio there is useless. The window scene's interfaceOrientation is authoritative and valid in
    // any context (unlike UITraitCollection). Prefer the foreground-active scene.
    if (@available(iOS 13.0, *)) {
        UIWindowScene *fallback = nil;
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]]) continue;
            UIWindowScene *ws = (UIWindowScene *)scene;
            if (!fallback) fallback = ws;
            if (ws.activationState == UISceneActivationStateForegroundActive)
                return UIInterfaceOrientationIsLandscape(ws.interfaceOrientation);
        }
        if (fallback) return UIInterfaceOrientationIsLandscape(fallback.interfaceOrientation);
    }
    return NO;
}

// Vertical offset for the nav buttons. Portrait: Edit/Compose drop 6 to sit centred on their platters,
// FaceTime/others stay at 0 (already centred in the taller bar). Landscape split: all three share ONE
// lower offset so Edit, Compose and the chat call button line up at the same height, moved down a bit.
__attribute__((unused)) static CGFloat wamNavButtonDropY(BOOL isEditOrCompose) {
    // Landscape: Edit/Compose reach the common target centre (~32) with a +11 content shift from their
    // measured base of ~21. (FaceTime uses a computed drop instead — see wamApplyCallButtonDrop — because
    // transforming its button VIEW is absorbed by UIKit's frame layout.)
    if (wamIsLandscape()) return 11.0;
    return isEditOrCompose ? 6.0 : 0.0;
}

// Common window-y centre the three landscape nav buttons line up on (measured: Edit/Compose land here).
__attribute__((unused)) static CGFloat wamLandscapeNavCenterY(void) { return 32.0; }

BOOL isNavButtonBlurEnabled() {
    NSString *key = isDarkMode() ? @"isNavButtonBlurEnabledDark" : @"isNavButtonBlurEnabled";
    id v = effectiveValueForKey(key);   // per-mode + per-contact override
    return v ? [v boolValue] : NO;
}

// Conversation-list platters aren't contact-specific — always read the global (per-mode) value so a
// per-contact override from a chat never leaks onto the list.
static BOOL isNavButtonBlurEnabledGlobal() {
    NSString *key = isDarkMode() ? @"isNavButtonBlurEnabledDark" : @"isNavButtonBlurEnabled";
    id v = loadPrefs()[key];
    return v ? [v boolValue] : NO;
}

/* ===================================================================================================
   LIQUID (GL)ASS COMPATIBILITY (BETA)
   ---------------------------------------------------------------------------------------------------
   Soft, optional integration with the third-party "Liquid (Gl)ass" tweak (github.com/winaviation-tweaks/
   liquidass — package/dylib name "liquidass"), which injects into every UIKit process (including
   Messages) and exposes an undocumented C API (Shared/LGGlassKit.h) for registering custom views as
   "glass" material hosts. When present AND the user has opted in, our platter/blur containers get a real
   liquid-glass backdrop instead of our stock UIVisualEffectView blur.

   This is resolved via dlsym rather than linked, so the tweak works identically whether or not Liquid
   (Gl)ass is installed — a missing symbol just means the toggle stays locked and nothing below ever runs.
   Because its own README says "This tweak is incomplete, issues WILL happen" and its API is undocumented
   (reverse-derived from headers, not a stable contract), this whole feature ships as an opt-in beta.
=================================================================================================== */

typedef UIView *(*WAMLGInstallRegisteredGlassInMaterial_t)(UIView *material, const void *associationKey,
    NSString *prefix, UIEdgeInsets outset, CGFloat cornerRadius, NSString *groupName);

static WAMLGInstallRegisteredGlassInMaterial_t wamLGInstallRegisteredGlassInMaterial = NULL;

// LGInstallRegisteredGlassInMaterial's `prefix` is matched with an exact strcmp against a FIXED, compile-time
// table of ~29 known host identifiers (Shared/LGHostRegistry.h's kLGHostRegistry) — it is NOT a place to
// register a brand-new third-party identity (confirmed empirically: a synthetic prefix always returns nil,
// silently, with no error). So we borrow the closest REAL, already-supported host instead of inventing one:
// "SearchPill" for our bottom search platter (an exact semantic + geometric match) and "PrefsButton" (a
// generic rounded-button glass style) for everything else. Each surface must ALSO be individually enabled in
// Liquid (Gl)ass's own settings app — lgHostEnabled(prefix) gates on that per-host user preference, which we
// have no way to set from here.
static NSString *const kWAMLGPrefixSearchPill = @"SearchPill";
static NSString *const kWAMLGPrefixButton = @"PrefsButton";

// Resolved at most once per launch. Safe to call repeatedly — cheap after the first hit.
static BOOL wamLiquidAssAvailable(void) {
    static BOOL checked = NO, available = NO;
    if (!checked) {
        checked = YES;
        wamLGInstallRegisteredGlassInMaterial =
            (WAMLGInstallRegisteredGlassInMaterial_t)dlsym(RTLD_DEFAULT, "LGInstallRegisteredGlassInMaterial");
        available = (wamLGInstallRegisteredGlassInMaterial != NULL);
    }
    return available;
}

BOOL isLiquidAssCompatEnabled(void) {
    id v = loadPrefs()[@"isLiquidAssCompatEnabled"];
    return v ? [v boolValue] : NO;
}

static BOOL wamShouldUseLiquidAssGlass(void) {
    return isTweakEnabled() && isLiquidAssCompatEnabled() && wamLiquidAssAvailable();
}

// The glass can't be made to sample our own live Modern NavBar blur (confirmed on device: it ignores it
// entirely, live-sampling everything else fine). So don't try to make it sample anything — capture an actual
// snapshot of the navbar exactly where the platter sits (same gradient, same opacity, same color it would
// show if the platter weren't there) and stamp that image on top of the glass instead, below the button's
// own glyph/text. It reads as if the navbar shows through normally, because it genuinely is a picture of it.
static UIView *wamFindBarBackgroundForView(UIView *v) {
    UIView *bar = v;
    while (bar && ![bar isKindOfClass:[UINavigationBar class]]) bar = bar.superview;
    if (!bar) return nil;
    Class barBgCls = NSClassFromString(@"_UIBarBackground");
    for (UIView *sub in bar.subviews) if ([sub isKindOfClass:barBgCls]) return sub;
    return nil;
}

static const NSInteger kWAMNavSnapshotTag = 4421;

static char kWAMNavSnapshotKey;

static void wamCaptureNavSnapshot(UIView *container, CGFloat cornerRadius) {
    UIView *host = container.superview;
    UIImageView *snap = objc_getAssociatedObject(container, &kWAMNavSnapshotKey);
    BOOL shouldRun = wamShouldUseLiquidAssGlass() && host != nil && container.window != nil;
    if (!shouldRun) {
        if (snap) [snap removeFromSuperview];
        return;
    }
    // Refreshed on normal layout passes only — no periodic timer. The navbar's own gradient/tint is slow-
    // changing and already translucent, so it doesn't need near-live tracking, and a repeating capture was
    // both expensive and produced a visible growth/corruption glitch on device.
    UIView *barBg = wamFindBarBackgroundForView(host);
    if (!barBg || barBg.bounds.size.width < 1.0 || barBg.bounds.size.height < 1.0) {
        if (snap) [snap removeFromSuperview];
        return;
    }
    CGRect rectInBarBg = [host convertRect:container.frame toView:barBg];
    rectInBarBg = CGRectIntersection(rectInBarBg, barBg.bounds);
    if (CGRectIsEmpty(rectInBarBg)) {
        if (snap) [snap removeFromSuperview];
        return;
    }

    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat preferredFormat];
    fmt.opaque = NO;
    UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithBounds:barBg.bounds format:fmt];
    UIImage *full = [renderer imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        [barBg drawViewHierarchyInRect:barBg.bounds afterScreenUpdates:NO];
    }];
    CGFloat scale = full.scale;
    CGRect cropRect = CGRectMake(rectInBarBg.origin.x * scale, rectInBarBg.origin.y * scale,
                                 rectInBarBg.size.width * scale, rectInBarBg.size.height * scale);
    CGImageRef cropped = CGImageCreateWithImageInRect(full.CGImage, cropRect);
    if (!cropped) {
        if (snap) [snap removeFromSuperview];
        return;
    }
    UIImage *croppedImage = [UIImage imageWithCGImage:cropped scale:scale orientation:UIImageOrientationUp];
    CGImageRelease(cropped);

    if (!snap) {
        snap = [[UIImageView alloc] init];
        snap.userInteractionEnabled = NO;
        snap.clipsToBounds = YES;
        // A real UIImageView with a real .image — wamApplyNavButtonPlatter's glyph scan (which looks for
        // exactly that, to compute the platter's own bounding box) was picking this up as a phantom glyph,
        // feeding its own growing frame back into itself each pass. Tag it so that scan can skip it.
        snap.tag = kWAMNavSnapshotTag;
        snap.layer.cornerRadius = cornerRadius;
        if (@available(iOS 13.0, *)) snap.layer.cornerCurve = kCACornerCurveContinuous;
        objc_setAssociatedObject(container, &kWAMNavSnapshotKey, snap, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    snap.image = croppedImage;
    snap.frame = container.frame;
    if (fabs(snap.layer.cornerRadius - cornerRadius) > 0.5) snap.layer.cornerRadius = cornerRadius;
    // Must sit above `container` itself, not just above the glass — container holds fxv, which is our OWN
    // real stock blur (left untouched, per the purely-additive design). Landing the snapshot behind that
    // washes it out completely, since fxv's own translucent blur renders on top of it.
    if (snap.superview != host || [host.subviews indexOfObject:snap] < [host.subviews indexOfObject:container]) {
        [host insertSubview:snap aboveSubview:container];
    }
}

static void wamUpdateNavSnapshot(UIView *container, CGFloat cornerRadius) {
    wamCaptureNavSnapshot(container, cornerRadius);
    // Returning from a chat (or any nav transition) reliably triggers a layout pass on these buttons WHILE
    // the pop animation is still interpolating alpha/tint — capturing then freezes that transient, wrong-
    // looking frame, with nothing to correct it since there's no periodic refresh anymore. Debounced one-shot
    // re-capture: every real layout call cancels any pending one and schedules a fresh one shortly out, so it
    // only actually fires once things stop moving and settle on the real post-transition look.
    static char kWAMNavSnapshotPendingKey;
    dispatch_block_t pending = objc_getAssociatedObject(container, &kWAMNavSnapshotPendingKey);
    if (pending) dispatch_block_cancel(pending);
    __weak UIView *weakContainer = container;
    dispatch_block_t block = dispatch_block_create(0, ^{
        UIView *strongContainer = weakContainer;
        if (strongContainer) wamCaptureNavSnapshot(strongContainer, cornerRadius);
    });
    objc_setAssociatedObject(container, &kWAMNavSnapshotPendingKey, block, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)), dispatch_get_main_queue(), block);
}


// Swap `fxv` (one of our stock UIVisualEffectView blurs) for Liquid (Gl)ass glass installed into
// `hostContainer`, or restore the stock blur if the feature is off/unavailable/declined. `key` must be a
// distinct static address per call site (e.g. `static char kSomeKey;`) — it's how repeat calls find and
// update the SAME glass instance instead of installing a new one every layout pass, and every caller gets
// its own dedicated key rather than sharing one. `prefix` must be one of Liquid (Gl)ass's own known host
// identifiers (see kWAMLGPrefix* above).
static void wamApplyLiquidAssGlass(UIView *hostContainer, UIVisualEffectView *fxv, CGFloat cornerRadius,
                                    const void *key, NSString *prefix) {
    UIView *glass = objc_getAssociatedObject(hostContainer, key);
    if (!wamShouldUseLiquidAssGlass() || !prefix) {
        if (glass) {
            [glass removeFromSuperview];
            objc_setAssociatedObject(hostContainer, key, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        return;
    }
    if (!glass) {
        @try {
            glass = wamLGInstallRegisteredGlassInMaterial(hostContainer, key, prefix,
                                                          UIEdgeInsetsZero, cornerRadius, @"WhatAMess");
        } @catch (NSException *e) {
            glass = nil;   // undocumented third-party API — never let a beta integration crash the host app
        }
        if (glass) {
            objc_setAssociatedObject(hostContainer, key, glass, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    if (!glass) return;
    // Repeated attempts to HIDE our own blur/content so glass could take its place kept breaking whatever
    // lived inside fxv.contentView (the search field vanishing, the platter tint vanishing, then a z-position
    // hack breaking BOTH further) — every one of those was a variation on "make room for glass by removing
    // something real". So stop doing that: fxv (search field, tint overlay, everything) is left completely
    // untouched, exactly as it always renders without Liquid (Gl)ass. Glass is added PURELY as an extra
    // backdrop layer sitting behind it — since our own blur is translucent (UIBlurEffectStyleRegular, not
    // opaque), the glass refraction still contributes visible depth through it. Lower risk, and nothing that
    // already worked can regress from this.
    UIView *glassParent = glass.superview;
    CGRect targetFrame = (glassParent && glassParent != hostContainer)
        ? [hostContainer convertRect:hostContainer.bounds toView:glassParent]
        : hostContainer.bounds;
    glass.frame = targetFrame;
    glass.layer.cornerRadius = cornerRadius;
    if (@available(iOS 13.0, *)) glass.layer.cornerCurve = kCACornerCurveContinuous;
    glass.clipsToBounds = YES;
    if (glassParent == hostContainer) {
        [hostContainer sendSubviewToBack:glass];
    } else if (glassParent && [glassParent.subviews containsObject:hostContainer]) {
        [glassParent insertSubview:glass belowSubview:hostContainer];
    }
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
    return NO;
}

BOOL isChatColorBgEnabled() {
    return NO;
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

BOOL isBlurBubblesEnabled() {
    NSString *key = isDarkMode() ? @"isBlurBubblesEnabledDark" : @"isBlurBubblesEnabled";
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
        // UIScreen's trait collection reports the system appearance stably in ANY call context. Prefer
        // it everywhere. [UITraitCollection currentTraitCollection] is only valid inside UIKit layout /
        // trait callbacks and returns Unspecified elsewhere (heartbeat, notification handlers, timers) —
        // relying on it there misreported light mode, which flipped the resolved image path and the
        // isChatImageBgEnabled key, making the (fallback-less) global background blink out on scroll.
        UIUserInterfaceStyle screenStyle = [UIScreen mainScreen].traitCollection.userInterfaceStyle;
        if (screenStyle != UIUserInterfaceStyleUnspecified) {
            gWAMIsDarkModeOnIOS15 = (screenStyle == UIUserInterfaceStyleDark);   // keep the cache warm
            return screenStyle == UIUserInterfaceStyleDark;
        }
        UIUserInterfaceStyle cur = [UITraitCollection currentTraitCollection].userInterfaceStyle;
        if (cur != UIUserInterfaceStyleUnspecified) {
            gWAMIsDarkModeOnIOS15 = (cur == UIUserInterfaceStyleDark);
            return cur == UIUserInterfaceStyleDark;
        }
        return gWAMIsDarkModeOnIOS15;   // last known-good, when neither source is specified
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
    NSDictionary *prefs = loadPrefs();
    return prefs[@"isAdvancedTintEnabled"] ? [prefs[@"isAdvancedTintEnabled"] boolValue] : NO;
}

static UIColor *resolveAdvancedColorForKey(NSString *key, UIColor *fallback) {
    if (gWAMChatIsActiveSurface && !gWAMForceGlobalColorResolve) {
        NSString *name = getCurrentContactName();
        if (name.length && perContactOverridesEnabled(name)) {
            id pc = getPerContactOverride(name, key);
            if (pc) {
                UIColor *c = colorFromHex(pc);
                if (c) return c;
            }
        }
    }
    if (isAdvancedTintEnabled()) {
        id global = loadPrefs()[key];
        if (global) {
            UIColor *c = colorFromHex(global);
            if (c) return c;
        }
    }
    return fallback;
}

static BOOL isAdvancedValueExplicitlySet(NSString *lightKey, NSString *darkKey) {
    NSString *key = isDarkMode() ? darkKey : lightKey;
    if (gWAMChatIsActiveSurface && !gWAMForceGlobalColorResolve) {
        NSString *name = getCurrentContactName();
        if (name.length && perContactOverridesEnabled(name)) {
            if (getPerContactOverride(name, key)) return YES;
        }
    }
    if (isAdvancedTintEnabled() && loadPrefs()[key]) return YES;
    return NO;
}

static BOOL wamAnyAdvancedTintSet(void) {
    if (!isAdvancedTintEnabled() && !gWAMChatIsActiveSurface) return NO;
    static NSArray *bases;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        bases = @[@"advancedReactionBalloonColor", @"advancedReactionGlyphColor",
                  @"advancedReactionHighlightColor", @"advancedContactActionColor",
                  @"advancedNavButtonColor", @"advancedReportJunkColor",
                  @"advancedSearchFieldColor", @"advancedStatusCellColor",
                  @"advancedSwitchTintColor", @"advancedTableLabelColor",
                  @"advancedUnreadDotColor"];
    });
    for (NSString *base in bases) {
        if (isAdvancedValueExplicitlySet(base, [base stringByAppendingString:@"Dark"])) return YES;
    }
    return NO;
}

static BOOL wamIsReactionBalloonAncestor(UIView *view, int maxHops) {
    Class A = NSClassFromString(@"CKAggregateAcknowledgmentBalloonView");
    Class B = NSClassFromString(@"CKAggregateAcknowledgementBalloonView");
    UIView *p = view ? view.superview : nil;
    int hops = 0;
    while (p && hops < maxHops) {
        if ((A && [p isKindOfClass:A]) || (B && [p isKindOfClass:B])) return YES;
        p = p.superview;
        hops++;
    }
    return NO;
}

static BOOL wamIsInsideReactionContext(UIView *view, int maxHops) {
    Class A = NSClassFromString(@"CKAggregateAcknowledgmentBalloonView");
    Class B = NSClassFromString(@"CKAggregateAcknowledgementBalloonView");
    Class C = NSClassFromString(@"CKAggregateAcknowledgmentTranscriptCell");
    Class D = NSClassFromString(@"CKAggregateAcknowledgementTranscriptCell");
    UIView *p = view ? view.superview : nil;
    int hops = 0;
    while (p && hops < maxHops) {
        if ((A && [p isKindOfClass:A]) || (B && [p isKindOfClass:B]) ||
            (C && [p isKindOfClass:C]) || (D && [p isKindOfClass:D])) return YES;
        p = p.superview;
        hops++;
    }
    return NO;
}

static BOOL wamIsInsideHyperlinkBalloon(UIView *view, int maxHops) {
    Class H = NSClassFromString(@"CKHyperlinkBalloonView");
    if (!H) return NO;
    UIView *p = view ? view.superview : nil;
    int hops = 0;
    while (p && hops < maxHops) {
        if ([p isKindOfClass:H]) return YES;
        p = p.superview;
        hops++;
    }
    return NO;
}

static BOOL wamViewInNonChatContext(UIView *v) {
    UIView *p = v ? v.superview : nil; int hops = 0;
    while (p && hops < 20) {
        NSString *c = NSStringFromClass(p.class);
        if ([c containsString:@"ConversationList"] || [c containsString:@"PinnedConversation"]) return YES;
        p = p.superview; hops++;
    }
    return NO;
}

static UIColor *getAdvancedTintColor(NSString *lightKey, NSString *darkKey, UIColor *fallback) {
    NSString *key = isDarkMode() ? darkKey : lightKey;
    return resolveAdvancedColorForKey(key, fallback);
}

static UIColor *getAdvancedTintColorForView(NSString *lightKey, NSString *darkKey, UIColor *fallback, UIView *view) {
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = view
            ? (view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
            : isDarkMode();
    }
    NSString *key = dark ? darkKey : lightKey;
    return resolveAdvancedColorForKey(key, fallback);
}

static UIColor *getChatAdvancedTintColor(NSString *lightKey, NSString *darkKey, UIColor *fallback) {
    NSString *key = isDarkMode() ? darkKey : lightKey;
    return resolveAdvancedColorForKey(key, fallback);
}

static UIColor *getChatAdvancedTintColorForView(NSString *lightKey, NSString *darkKey, UIColor *fallback, UIView *view) {
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = view
            ? (view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
            : isDarkMode();
    }
    NSString *key = dark ? darkKey : lightKey;
    return resolveAdvancedColorForKey(key, fallback);
}

static UIColor *getAdvancedUnreadDotColor() {
    return getAdvancedTintColor(@"advancedUnreadDotColor", @"advancedUnreadDotColorDark", getSystemTintColor());
}

static UIColor *getAdvancedSwitchTintColor() {
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
    UIColor *explicit = getChatAdvancedTintColor(@"advancedReactionGlyphColor", @"advancedReactionGlyphColorDark", nil);
    if (explicit) return explicit;

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

    static CIContext *context = nil;
    static dispatch_once_t onceCtx;
    dispatch_once(&onceCtx, ^{ context = [CIContext contextWithOptions:nil]; });

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

static UIImage *wamChatBackgroundImage(NSString *path, CGFloat blurAmount) {
    if (!path) return nil;

    static NSCache<NSString *, UIImage *> *cache = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        cache = [NSCache new];
        cache.countLimit = 6;
    });

    NSDictionary *attrs = [[NSFileManager defaultManager] attributesOfItemAtPath:path error:nil];
    NSTimeInterval mtime = [(NSDate *)attrs[NSFileModificationDate] timeIntervalSince1970];
    NSString *key = [NSString stringWithFormat:@"%@|%.2f|%.0f|%lu", path, blurAmount, mtime, (unsigned long)gWAMChatBgGen];

    UIImage *hit = [cache objectForKey:key];
    if (hit) return hit;

    UIImage *img = loadImageUncached(path);
    if (!img) return nil;
    if (wamIsNotificationExtension() && blurAmount > 0) {
        CGFloat maxDim = 500.0;
        CGFloat w = img.size.width * img.scale, h = img.size.height * img.scale;
        CGFloat s = MIN(1.0, maxDim / MAX(w, h));
        if (s < 1.0) {
            CGSize ns = CGSizeMake(img.size.width * s, img.size.height * s);
            UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:ns];
            img = [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
                [img drawInRect:CGRectMake(0, 0, ns.width, ns.height)];
            }];
            blurAmount *= s;
        }
    }
    if (blurAmount > 0) img = blurImage(img, blurAmount);
    [cache setObject:img forKey:key];
    return img;
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
    UIColor *c = colorFromHex(effectiveValueForKey(key));
    if (c) return c;
    return isDarkMode()
        ? [UIColor colorWithRed:0.149 green:0.149 blue:0.161 alpha:1.0]
        : [UIColor colorWithRed:0.918 green:0.918 blue:0.922 alpha:1.0];
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

static NSString *wamPlaceholderStockText() {
    Class messagesCtrlClass = %c(CKMessagesController);
    if (!messagesCtrlClass) return @"iMessage";

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

    UIViewController *messagesCtrl = nil;
    for (UIWindow *w in windows) {
        UIViewController *vc = wamFindVCInHierarchy(w.rootViewController, messagesCtrlClass);
        if (vc && [vc isViewLoaded] && vc.view.window) { messagesCtrl = vc; break; }
    }
    if (!messagesCtrl) return @"iMessage";

    id conv = nil;
    Ivar cv = class_getInstanceVariable([messagesCtrl class], "_currentConversation");
    if (cv) conv = object_getIvar(messagesCtrl, cv);
    if (!conv) return @"iMessage";

    Ivar ch = class_getInstanceVariable([conv class], "_chat");
    if (!ch) return @"iMessage";
    id chat = object_getIvar(conv, ch);
    if (!chat) return @"iMessage";

    @try {
        if ([chat respondsToSelector:@selector(account)]) {
            id account = ((id (*)(id, SEL))objc_msgSend)(chat, @selector(account));
            if (account && [account respondsToSelector:@selector(serviceName)]) {
                NSString *serviceName = ((NSString *(*)(id, SEL))objc_msgSend)(account, @selector(serviceName));
                if ([serviceName isKindOfClass:[NSString class]] &&
                    ([serviceName isEqualToString:@"SMS"] || [serviceName containsString:@"SMS"])) {
                    return @"Text Message";
                }
            }
        }
    } @catch (NSException *e) {}

    return @"iMessage";
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

// Optional tint color for the nav-button/name blur platters. nil → plain frosted blur.
static UIColor *getNavPlatterColor(BOOL global) {
    NSString *key = isDarkMode() ? @"navPlatterColorDark" : @"navPlatterColor";
    id v = global ? loadPrefs()[key] : effectiveValueForKey(key);   // conv list = global, chat = per-contact
    return colorFromHex(v);
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

@interface WAMPerContactSettings : UIViewController <UIImagePickerControllerDelegate, UINavigationControllerDelegate, UIColorPickerViewControllerDelegate, UIDocumentPickerDelegate>
@property (nonatomic, copy) NSString *contactName;
@property (nonatomic, copy) NSString *displayName;
@property (nonatomic, copy) void (^onChanged)(void);
@end

@implementation WAMPerContactSettings {
    BOOL _editingDarkMode;
    BOOL _exportMode;
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
    UIButton *_bgGradientButton;
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
        case 4: return @"Presets";
    }
    return @"";
}

+ (NSString *)wamTabSymbolForIndex:(NSInteger)idx {
    switch (idx) {
        case 0: return @"photo.fill";
        case 1: return @"bubble.left.and.bubble.right.fill";
        case 2: return @"keyboard.fill";
        case 3: return @"sparkles";
        case 4: return @"paintpalette.fill";
    }
    return @"square";
}

+ (UIColor *)wamTabTintForIndex:(NSInteger)idx {
    switch (idx) {
        case 0: return [UIColor systemBlueColor];
        case 1: return [UIColor systemPinkColor];
        case 2: return [UIColor systemTealColor];
        case 3: return [UIColor systemYellowColor];
        case 4: return [WAMPerContactSettings wamDoneAccent];
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
    for (NSInteger i = 0; i < 5; i++) {
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

- (void)wamReloadAfterPresetApply {
    _masterSwitch.on = perContactOverridesEnabled(self.contactName);
    [self wamRefreshMasterAppearance];
    [self loadTab];
    if (self.onChanged) self.onChanged();
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
        alertControllerWithTitle:@"Reset This Chat?"
        message:[NSString stringWithFormat:@"This removes all custom settings for %@, deletes both backgrounds, blur values, and every other per-contact override. This CAN'T be undone!", self.contactName]
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
    _exportMode = NO;
    [self loadTab];
}

- (void)loadTab {
    _subtitleLabel.text = [WAMPerContactSettings wamTabNameForIndex:_selectedTab];

    UIView *old = _tabContent;
    UIView *content = nil;
    if (_selectedTab == 0)      content = [self buildBackgroundTab];
    else if (_selectedTab == 1) content = [self buildBubblesTab];
    else if (_selectedTab == 2) content = [self buildMessageBarTab];
    else if (_selectedTab == 3) content = [self buildMiscTab];
    else                        content = [self buildPresetsTab];
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

#pragma mark - Presets tab

- (UIButton *)wamMakeSubtleButton:(NSString *)title action:(SEL)action tint:(UIColor *)tint {
    UIButton *b = [UIButton buttonWithType:UIButtonTypeCustom];
    b.titleLabel.font = [WAMPerContactSettings wamRoundedFontOfSize:15 weight:UIFontWeightSemibold];
    [b setTitle:title forState:UIControlStateNormal];
    [b setTitleColor:tint forState:UIControlStateNormal];
    b.backgroundColor = [tint colorWithAlphaComponent:0.12];
    b.layer.cornerRadius = 14;
    if (@available(iOS 13.0, *)) b.layer.cornerCurve = kCACornerCurveContinuous;
    [b addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    b.translatesAutoresizingMaskIntoConstraints = NO;
    return b;
}

- (UIView *)buildPresetsTab {
    UIView *root = [UIView new];
    UIColor *accent = [WAMPerContactSettings wamDoneAccent];
    BOOL dark = _editingDarkMode;
    __weak typeof(self) ws = self;

    UIView *header = [self wamMakeSectionHeader:(_exportMode ? @"Tap a preset to export" : @"Presets")
                                         symbol:@"paintpalette.fill" tint:accent];
    [root addSubview:header];

    CGFloat width = UIScreen.mainScreen.bounds.size.width - 36;
    CGFloat cardH = [WAMPresetCardView heightForWidth:width showsConvList:NO];

    UIView *prev = header;

    if (_exportMode) {
        NSMutableArray<WAMPreset *> *list =
            [NSMutableArray arrayWithObject:[WAMPresetStore currentLookPresetForContact:self.contactName]];
        [list addObjectsFromArray:[WAMPresetStore userPresets]];
        for (WAMPreset *p in list) {
            WAMPresetCardView *card = [[WAMPresetCardView alloc] initWithPreset:p dark:dark];
            card.showsConvListPreview = NO;
            card.exportMode = YES;
            card.translatesAutoresizingMaskIntoConstraints = NO;
            card.onApply = ^(WAMPreset *preset) {
                NSURL *url = [WAMPresetStore exportPresetToTempFile:preset];
                [ws wamCancelExport];
                [ws wamShareExportURL:url];
            };
            [root addSubview:card];
            [NSLayoutConstraint activateConstraints:@[
                [card.topAnchor constraintEqualToAnchor:prev.bottomAnchor constant:(prev == header ? 8 : 14)],
                [card.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:18],
                [card.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-18],
                [card.heightAnchor constraintEqualToConstant:cardH],
            ]];
            prev = card;
        }
        UIButton *cancel = [self wamMakeSubtleButton:@"Cancel" action:@selector(wamCancelExport) tint:accent];
        [root addSubview:cancel];
        [NSLayoutConstraint activateConstraints:@[
            [header.topAnchor constraintEqualToAnchor:root.topAnchor constant:8],
            [header.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:32],
            [cancel.topAnchor constraintEqualToAnchor:prev.bottomAnchor constant:20],
            [cancel.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:18],
            [cancel.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-18],
            [cancel.heightAnchor constraintEqualToConstant:48],
            [cancel.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-28],
        ]];
        return root;
    }

    for (WAMPreset *p in [WAMPresetStore allPresets]) {
        WAMPresetCardView *card = [[WAMPresetCardView alloc] initWithPreset:p dark:dark];
        card.showsConvListPreview = NO;
        card.translatesAutoresizingMaskIntoConstraints = NO;
        card.onApply = ^(WAMPreset *preset) { [ws wamConfirmApplyPreset:preset]; };
        if (!p.builtin) {
            card.onDelete = ^(WAMPreset *preset) { [ws wamConfirmDeleteUserPreset:preset]; };
            card.onRename = ^(WAMPreset *preset) { [ws wamPromptRenamePreset:preset]; };
        }
        [root addSubview:card];
        [NSLayoutConstraint activateConstraints:@[
            [card.topAnchor constraintEqualToAnchor:prev.bottomAnchor constant:(prev == header ? 8 : 14)],
            [card.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:18],
            [card.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-18],
            [card.heightAnchor constraintEqualToConstant:cardH],
        ]];
        prev = card;
    }

    UIButton *save = [UIButton buttonWithType:UIButtonTypeCustom];
    save.titleLabel.font = [WAMPerContactSettings wamRoundedFontOfSize:16 weight:UIFontWeightSemibold];
    [save setTitle:@"Save This Chat's Look" forState:UIControlStateNormal];
    [save addTarget:self action:@selector(wamSaveChatPreset) forControlEvents:UIControlEventTouchUpInside];
    save.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:save];
    [self wamApplyGradientBackgroundToButton:save baseColor:accent];

    UIButton *imp = [self wamMakeSubtleButton:@"Import" action:@selector(wamImportSettings) tint:accent];
    [root addSubview:imp];
    UIButton *exp = [self wamMakeSubtleButton:@"Export" action:@selector(wamExportSettings) tint:accent];
    [root addSubview:exp];

    [NSLayoutConstraint activateConstraints:@[
        [header.topAnchor constraintEqualToAnchor:root.topAnchor constant:8],
        [header.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:32],

        [save.topAnchor constraintEqualToAnchor:prev.bottomAnchor constant:20],
        [save.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:18],
        [save.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-18],
        [save.heightAnchor constraintEqualToConstant:48],

        [imp.topAnchor constraintEqualToAnchor:save.bottomAnchor constant:8],
        [imp.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:18],
        [imp.heightAnchor constraintEqualToConstant:44],

        [exp.topAnchor constraintEqualToAnchor:imp.topAnchor],
        [exp.leadingAnchor constraintEqualToAnchor:imp.trailingAnchor constant:8],
        [exp.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-18],
        [exp.widthAnchor constraintEqualToAnchor:imp.widthAnchor],
        [exp.heightAnchor constraintEqualToConstant:44],

        [imp.bottomAnchor constraintEqualToAnchor:root.bottomAnchor constant:-28],
    ]];
    return root;
}

- (void)wamConfirmApplyPreset:(WAMPreset *)preset {
    NSString *who = self.displayName.length ? self.displayName : @"this chat";
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:[NSString stringWithFormat:@"Apply “%@”?", preset.name]
        message:[NSString stringWithFormat:@"Themes %@'s chat in both light and dark mode, and enables per-chat customization.", who]
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Apply" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            [WAMPresetStore applyPreset:preset toContact:self.contactName appearance:WAMPresetAppearanceBoth];
            [self wamReloadAfterPresetApply];
        }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)wamPromptRenamePreset:(WAMPreset *)preset {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Rename Preset" message:nil
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf){
        tf.placeholder = @"New name";
        tf.text = preset.name;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            NSString *name = [alert.textFields.firstObject.text
                stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            if (!name.length) return;
            preset.name = name;
            [WAMPresetStore saveUserPreset:preset];
            [self loadTab];
        }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)wamConfirmDeleteUserPreset:(WAMPreset *)preset {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:[NSString stringWithFormat:@"Delete “%@”?", preset.name]
        message:@"This removes this saved preset. Chats you've already applied it to keep their look. This CANNOT be undone."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Delete" style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *a) {
            [WAMPresetStore deleteUserPresetWithIdentifier:preset.identifier];
            [self loadTab];
        }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)wamSaveChatPreset {
    if (!self.contactName.length) return;
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Save This Chat's Look"
        message:@"Save this chat's current customization setting as a preset that can be selected and exported."
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *tf){ tf.placeholder = @"Enter name"; }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Save" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *a) {
            WAMPreset *snap = [WAMPresetStore snapshotOfContact:self.contactName
                                                          named:alert.textFields.firstObject.text];
            if (snap) [WAMPresetStore saveUserPreset:snap];
            [self loadTab];
        }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)wamExportSettings {
    _exportMode = YES;
    [self loadTab];
}

- (void)wamCancelExport {
    _exportMode = NO;
    [self loadTab];
}

- (void)wamShareExportURL:(NSURL *)url {
    if (!url) return;
    UIActivityViewController *av = [[UIActivityViewController alloc] initWithActivityItems:@[url]
                                                                     applicationActivities:nil];
    av.popoverPresentationController.sourceView = self.view;
    av.popoverPresentationController.sourceRect = CGRectMake(self.view.bounds.size.width/2,
                                                             self.view.bounds.size.height/2, 1, 1);
    [self presentViewController:av animated:YES completion:nil];
}

- (void)wamImportSettings {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
        initWithDocumentTypes:@[@"public.data", @"public.content"] inMode:UIDocumentPickerModeImport];
#pragma clang diagnostic pop
    picker.delegate = self;
    picker.allowsMultipleSelection = NO;
    [self presentViewController:picker animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
    didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (!urls.count) return;
    BOOL ok = [WAMPresetStore importSettingsFromURL:urls.firstObject];
    UIAlertController *a = [UIAlertController
        alertControllerWithTitle:ok ? @"Imported" : @"Import Failed"
        message:ok ? @"Settings applied!" : @"Not a valid WhatAMess preset!"
        preferredStyle:UIAlertControllerStyleAlert];
    [a addAction:[UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleDefault
        handler:^(UIAlertAction *x) { if (ok) [self wamReloadAfterPresetApply]; }]];
    [self presentViewController:a animated:YES completion:nil];
}

#pragma mark - Background tab

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

    _bgGradientButton = [UIButton buttonWithType:UIButtonTypeCustom];
    _bgGradientButton.titleLabel.font = [WAMPerContactSettings wamRoundedFontOfSize:16 weight:UIFontWeightSemibold];
    [_bgGradientButton setTitle:@"Create Gradient Background" forState:UIControlStateNormal];
    [_bgGradientButton addTarget:self action:@selector(wamCreateGradientTapped) forControlEvents:UIControlEventTouchUpInside];
    _bgGradientButton.translatesAutoresizingMaskIntoConstraints = NO;
    [root addSubview:_bgGradientButton];
    [self wamApplyGradientBackgroundToButton:_bgGradientButton baseColor:[UIColor colorWithRed:0.42 green:0.36 blue:0.90 alpha:1.0]];

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

        [_bgGradientButton.topAnchor constraintEqualToAnchor:_bgChooseButton.bottomAnchor constant:6],
        [_bgGradientButton.leadingAnchor constraintEqualToAnchor:root.leadingAnchor constant:18],
        [_bgGradientButton.trailingAnchor constraintEqualToAnchor:root.trailingAnchor constant:-18],
        [_bgGradientButton.heightAnchor constraintEqualToConstant:48],

        [_bgRemoveButton.topAnchor constraintEqualToAnchor:_bgGradientButton.bottomAnchor constant:6],
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

- (void)wamCreateGradientTapped {
    if (!self.contactName.length) return;
    NSString *name = self.contactName;
    BOOL dark = _editingDarkMode;
    __weak typeof(self) ws = self;
    WAMGradientBuilderController *b = [[WAMGradientBuilderController alloc] initWithStops:nil];
    b.onDone = ^(NSArray<NSString *> *stops, WAMGradientDirection direction){
        if (stops.count >= 2) {
            [WAMPresetStore setGradientBackground:stops direction:direction forContact:name dark:dark];
            [ws refreshBackgroundTab];
            if (ws.onChanged) ws.onChanged();
        }
        [ws dismissViewControllerAnimated:YES completion:nil];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:b];
    nav.modalPresentationStyle = UIModalPresentationPageSheet;
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)removeTapped {
    if (!self.contactName.length) return;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSMutableSet *aliasNames = [NSMutableSet setWithObject:self.contactName];
    NSString *visible = gWAMCurrentContactName;
    if (visible.length) [aliasNames addObject:visible];
    NSString *displayed = gWAMCurrentContactDisplayName;
    if (displayed.length) [aliasNames addObject:displayed];
    for (NSString *aliasName in aliasNames) {
        [fm removeItemAtPath:getPerContactImagePath(aliasName, _editingDarkMode) error:nil];
    }
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

        NSMutableSet *aliasNames = [NSMutableSet setWithObject:name];
        NSString *visible = gWAMCurrentContactName;
        if (visible.length && ![visible isEqualToString:name]) {
            [aliasNames addObject:visible];
        }
        NSString *displayed = gWAMCurrentContactDisplayName;
        if (displayed.length && ![aliasNames containsObject:displayed]) {
            [aliasNames addObject:displayed];
        }

        for (NSString *aliasName in aliasNames) {
            NSString *path = getPerContactImagePath(aliasName, dark);
            NSString *dir = [path stringByDeletingLastPathComponent];
            [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
            [data writeToFile:path atomically:YES];
            if (!perContactOverridesEnabled(aliasName)) {
                setPerContactOverridesEnabled(aliasName, YES);
            }
        }
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
static const void *kWAMRowReloadsAssocKey = &kWAMRowReloadsAssocKey;

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

    NSString *depKey = _editingDarkMode ? spec[@"dependsOnDark"] : spec[@"dependsOnLight"];
    if (!depKey.length) depKey = spec[@"dependsOnLight"];
    if (depKey.length) {
        id depVal = [self wamReadValueForKey:depKey];
        if (!(depVal ? [depVal boolValue] : NO)) enabled = NO;
    }

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
        if ([spec[@"reloadsOnToggle"] boolValue]) {
            objc_setAssociatedObject(valSwitch, kWAMRowReloadsAssocKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
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
    if ([objc_getAssociatedObject(sender, kWAMRowReloadsAssocKey) boolValue]) {
        [self loadTab];
    }
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
        @{ @"title": @"Blur",
           @"symbol": @"square.on.square.dashed",
           @"tint": [UIColor systemTealColor],
           @"specs": @[
               @{@"label": @"Blur Bubbles", @"light": @"isBlurBubblesEnabled", @"dark": @"isBlurBubblesEnabledDark", @"type": @"bool"},
           ]},
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
           @"tint": [UIColor colorWithRed:0.91 green:0.24 blue:0.55 alpha:1.0],
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
           @"tint": [UIColor colorWithRed:0.42 green:0.36 blue:0.82 alpha:1.0],
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
               @{@"label": @"Blur",             @"light": @"isInputFieldBlurEnabled",   @"dark": @"isInputFieldBlurEnabledDark",   @"type": @"bool",
                 @"reloadsOnToggle": @YES},
               @{@"label": @"Blur Style",       @"light": @"inputFieldBlurStyle",       @"dark": @"inputFieldBlurStyleDark",       @"type": @"choice",
                 @"dependsOnLight": @"isInputFieldBlurEnabled", @"dependsOnDark": @"isInputFieldBlurEnabledDark",
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
           @"tint": [UIColor colorWithRed:1.0 green:0.48 blue:0.30 alpha:1.0],
           @"specs": @[
               @{@"label": @"Background", @"light": @"sendButtonColor",      @"dark": @"sendButtonColorDark",      @"type": @"color"},
               @{@"label": @"Arrow Color", @"light": @"sendButtonArrowColor", @"dark": @"sendButtonArrowColorDark", @"type": @"color"},
           ]},
        @{ @"title": @"Message Bar Tint",
           @"symbol": @"paintbrush.fill",
           @"tint": [UIColor colorWithRed:0.97 green:0.49 blue:0.28 alpha:1.0],
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
           @"tint": [UIColor colorWithRed:0.31 green:0.51 blue:0.95 alpha:1.0],
           @"specs": @[
               @{@"label": @"Accent Color", @"light": @"systemTintColor", @"dark": @"systemTintColorDark", @"type": @"color"},
           ]},
        @{ @"title": @"Navigation Bar",
           @"symbol": @"rectangle.topthird.inset.filled",
           @"tint": [UIColor colorWithRed:0.95 green:0.45 blue:0.18 alpha:1.0],
           @"specs": @[
               @{@"label": @"Tint Color",     @"light": @"navBarTintColor",       @"dark": @"navBarTintColorDark",       @"type": @"color"},
               @{@"label": @"Contact Name",   @"light": @"chatContactNameColor",  @"dark": @"chatContactNameColorDark",  @"type": @"color"},
               @{@"label": @"Button Platters",@"light": @"isNavButtonBlurEnabled",@"dark": @"isNavButtonBlurEnabledDark",@"type": @"bool"},
               @{@"label": @"Platter Color",  @"light": @"navPlatterColor",       @"dark": @"navPlatterColorDark",       @"type": @"color"},
           ]},
        @{ @"title": @"Cell Tint",
           @"symbol": @"rectangle.stack.fill",
           @"tint": [UIColor colorWithRed:0.20 green:0.71 blue:0.50 alpha:1.0],
           @"specs": @[
               @{@"label": @"Enabled",    @"light": @"isCellBlurTintEnabled", @"type": @"bool"},
               @{@"label": @"Tint Color", @"light": @"cellTintColor", @"dark": @"cellTintColorDark", @"type": @"color"},
           ]},
        @{ @"title": @"Switches",
           @"symbol": @"switch.2",
           @"tint": [UIColor colorWithRed:0.30 green:0.78 blue:0.46 alpha:1.0],
           @"specs": @[
               @{@"label": @"Tint Color", @"light": @"advancedSwitchTintColor", @"dark": @"advancedSwitchTintColorDark", @"type": @"color"},
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
           @"tint": [UIColor colorWithRed:1.00 green:0.42 blue:0.51 alpha:1.0],
           @"specs": @[
               @{@"label": @"Balloon",   @"light": @"advancedReactionBalloonColor",   @"dark": @"advancedReactionBalloonColorDark",   @"type": @"color"},
               @{@"label": @"Glyph",     @"light": @"advancedReactionGlyphColor",     @"dark": @"advancedReactionGlyphColorDark",     @"type": @"color"},
               @{@"label": @"Highlight", @"light": @"advancedReactionHighlightColor", @"dark": @"advancedReactionHighlightColorDark", @"type": @"color"},
           ]},
        @{ @"title": @"Spam Warning",
           @"symbol": @"exclamationmark.triangle.fill",
           @"tint": [UIColor colorWithRed:0.90 green:0.63 blue:0.00 alpha:1.0],
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
    addBullets(@"• Blur Bubbles; exactly what it sounds like. \n• Added new Preset Picker, Bundled Presets, and overhauled exporting process. \n• Per-contact chat customization! The new menu can be found in the \"Customize This Chat\" button in the details view of a chat.");

    addHeader(@"Bug Fixes/Changes", YES);
    addBullets(@"• Everything related to replies and their views.\n• Sending a new message from the compose pane with background chat image on hid the chat's history.\n• Setting an advanced tint no longer requires a global tint to be set first.\n• Fixed issues with iMessage apps in chats (ex. GamePigeon).\n• Fixed an issue with navbars when viewing an image.");

    UILabel *thanks = [[UILabel alloc] init];
    thanks.text = @"A huge thanks to users who opened issues on GitHub!";
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
    quote.text = @"You CANNOT beg for presets now, it's BANNED! If you have one you'd like to include in the tweak, feel free to share!";
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

#define kWAMOurBgImageTag 4322

static void wamPlaceBackgroundBelowTranscript(UIView *host, UIView *bg) {
    if (!host || !bg) return;
    Class tcvClass = objc_getClass("CKTranscriptCollectionView");
    UIView *transcript = nil;
    if (tcvClass) {
        NSMutableArray *queue = [NSMutableArray arrayWithArray:host.subviews];
        int guard = 0;
        while (queue.count && guard++ < 3000) {
            UIView *v = queue.firstObject;
            [queue removeObjectAtIndex:0];
            if (v == bg) continue;
            if ([v isKindOfClass:tcvClass]) { transcript = v; break; }
            [queue addObjectsFromArray:v.subviews];
        }
    }
    if (transcript) {
        UIView *anchor = transcript;
        while (anchor.superview && anchor.superview != host) anchor = anchor.superview;
        if (anchor != bg && anchor.superview == host) {
            [host insertSubview:bg belowSubview:anchor];
            return;
        }
    }
    [host insertSubview:bg atIndex:0];
}

static char kWAMOrigBackdropKey;

static BOOL wamHasCustomChatBackdrop(void) {
    return isTweakEnabled() && (isChatColorBgEnabled() || shouldShowAnyChatBgImage());
}

static UIColor *wamBaseSystemBackground(UIView *v) {
    UIColor *c = [UIColor systemBackgroundColor];
    if (@available(iOS 13.0, *)) {
        UITraitCollection *base = [UITraitCollection traitCollectionWithUserInterfaceLevel:UIUserInterfaceLevelBase];
        UITraitCollection *tc = v ? [UITraitCollection traitCollectionWithTraitsFromCollections:@[v.traitCollection, base]]
                                  : base;
        c = [c resolvedColorWithTraitCollection:tc];
    }
    return c;
}

static BOOL wamIsInSendAnimationWindow(UIView *v) {
    UIWindow *w = v.window;
    return w && [NSStringFromClass([w class]) containsString:@"SendAnimation"];
}

static void wamApplyBackdrop(UIView *v, BOOL wantClear, BOOL opaqueFallback) {
    if (!v) return;
    if (!objc_getAssociatedObject(v, &kWAMOrigBackdropKey)) {
        objc_setAssociatedObject(v, &kWAMOrigBackdropKey,
                                 v.backgroundColor ?: (id)[NSNull null],
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (wantClear) {
        v.backgroundColor = [UIColor clearColor];
        return;
    }
    if (opaqueFallback) {

        v.backgroundColor = wamBaseSystemBackground(v);
        return;
    }
    id orig = objc_getAssociatedObject(v, &kWAMOrigBackdropKey);
    v.backgroundColor = [orig isKindOfClass:[UIColor class]] ? (UIColor *)orig : nil;
}

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
                    NSString *navKey = isDarkMode() ? @"advancedNavButtonColorDark" : @"advancedNavButtonColor";
                    if (isAdvancedTintEnabled()) {
                        UIColor *navAdvanced = colorFromHex(loadPrefs()[navKey]);
                        if (navAdvanced) return navAdvanced;
                    }
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
                    NSString *navKey = isDarkMode() ? @"advancedNavButtonColorDark" : @"advancedNavButtonColor";
                    if (isAdvancedTintEnabled()) {
                        UIColor *navAdvanced = colorFromHex(loadPrefs()[navKey]);
                        if (navAdvanced) return navAdvanced;
                    }
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

    if (!customTint && !wamAnyAdvancedTintSet()) {
        return %orig;
    }

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

    if (!isCustomBubbleColorsEnabled() &&
        !isAdvancedValueExplicitlySet(@"advancedReactionBalloonColor", @"advancedReactionBalloonColorDark") &&
        !isAdvancedValueExplicitlySet(@"advancedReactionHighlightColor", @"advancedReactionHighlightColorDark") &&
        !isAdvancedValueExplicitlySet(@"advancedReactionGlyphColor", @"advancedReactionGlyphColorDark")) {
        if (wamIsReactionBalloonAncestor(self, 5)) return %orig;
    }

    UIColor *balloonColor = getChatAdvancedTintColorForView(@"advancedReactionBalloonColor", @"advancedReactionBalloonColorDark", nil, self);
    if (balloonColor && wamIsReactionBalloonAncestor(self, 5)) {
        return balloonColor;
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

    if (customTint) return customTint;
    return %orig;
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

static const NSInteger kWAMBottomSearchTag = 4410;
static const NSInteger kWAMBottomSearchTintTag = 4412;
static const NSInteger kWAMSearchGlyphOverlayTag = 4415;
static const NSInteger kWAMBottomScreenBlurTag = 4420;
static const NSInteger kWAMBottomScreenBlurTintTag = 4421;
static char kWAMBottomSearchCtrlKey;
static char kWAMBottomSearchContainerKey;
static char kWAMSearchOrigPlaceholderKey;
static char kWAMSearchMyMagKey;   // our own leftView magnifier (immune to the system's per-contact re-tint)
static CGRect gWAMSearchKbFrameWin = {{0.0, 0.0}, {0.0, 0.0}};

BOOL isBottomBlurEnabled() {
    NSString *key = isDarkMode() ? @"isBottomBlurEnabledDark" : @"isBottomBlurEnabled";
    id v = effectiveValueForKey(key);
    return v ? [v boolValue] : NO;
}

static UIColor *getBottomBlurTintColor() {
    NSString *key = isDarkMode() ? @"bottomBlurTintColorDark" : @"bottomBlurTintColor";
    return colorFromHex(effectiveValueForKey(key));
}

// A tinted, progressive blur spanning the full screen width at the very bottom, behind the search bar
// platter — same visual language as the modern navbar's top/bottom fade (blur + gradient-mask + optional flat
// tint), but its own independently-toggled feature, listed with the platter options and gated on them (the
// bottom search platter only exists when Button Platters is on, so this has no meaning without it either).
static void wamSetupBottomScreenBlur(UIView *host, UIView *container) {
    BOOL on = isTweakEnabled() && isModernNavBarEnabled() && isNavButtonBlurEnabledGlobal() && isBottomBlurEnabled();
    UIVisualEffectView *blur = nil;
    for (UIView *sub in host.subviews) if (sub.tag == kWAMBottomScreenBlurTag) { blur = (UIVisualEffectView *)sub; break; }
    if (!on) { [blur removeFromSuperview]; return; }
    if (host.bounds.size.width < 100.0) return;   // skip transitional/degenerate geometry, like the search platter does

    CGFloat h = 210.0;
    CGFloat home = host.window ? host.window.safeAreaInsets.bottom : 0.0;
    CGRect frame = CGRectMake(0.0, host.bounds.size.height - h, host.bounds.size.width, h + home);

    if (!blur) {
        blur = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular]];
        blur.tag = kWAMBottomScreenBlurTag;
        blur.userInteractionEnabled = NO;
        blur.clipsToBounds = YES;
        // Sit just behind the search platter (so the platter's own blur/shadow reads on top of this wash),
        // but above the list content beneath — that's what actually gets blurred.
        if (container.superview == host) [host insertSubview:blur belowSubview:container];
        else [host addSubview:blur];
    }
    blur.frame = frame;

    // Colorless frosted blur — same as the search platter's own blur — the stock _UIVisualEffectSubview
    // carries a dark backing that muddies the fade; clear it so only our gradient + optional tint show.
    Class subCls = NSClassFromString(@"_UIVisualEffectSubview");
    for (UIView *sub in blur.subviews)
        if ([sub isKindOfClass:subCls]) sub.backgroundColor = [UIColor clearColor];

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    CAGradientLayer *mask = [blur.layer.mask isKindOfClass:[CAGradientLayer class]] ? (CAGradientLayer *)blur.layer.mask : nil;
    if (!mask) { mask = [CAGradientLayer layer]; blur.layer.mask = mask; }
    mask.frame = blur.bounds;
    // Smoothstep (3t²-2t³) easing across evenly-spaced stops, rather than a few hand-picked jumps — reads as
    // one continuous fade instead of visibly distinct bands.
    mask.colors = @[
        (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor,      // t=0.00
        (id)[UIColor colorWithWhite:0.0 alpha:0.061].CGColor,    // t=0.15
        (id)[UIColor colorWithWhite:0.0 alpha:0.216].CGColor,    // t=0.30
        (id)[UIColor colorWithWhite:0.0 alpha:0.500].CGColor,    // t=0.50
        (id)[UIColor colorWithWhite:0.0 alpha:0.784].CGColor,    // t=0.70
        (id)[UIColor colorWithWhite:0.0 alpha:0.939].CGColor,    // t=0.85
        (id)[UIColor colorWithWhite:0.0 alpha:1.0].CGColor       // t=1.00
    ];
    mask.locations = @[@0.0, @0.15, @0.3, @0.5, @0.7, @0.85, @1.0];
    [CATransaction commit];

    UIColor *tint = getBottomBlurTintColor();
    UIView *tintView = nil;
    for (UIView *sub in blur.contentView.subviews) if (sub.tag == kWAMBottomScreenBlurTintTag) { tintView = sub; break; }
    if (tint) {
        if (!tintView) {
            tintView = [[UIView alloc] init];
            tintView.tag = kWAMBottomScreenBlurTintTag;
            tintView.userInteractionEnabled = NO;
            [blur.contentView addSubview:tintView];
        }
        tintView.backgroundColor = tint;
        tintView.frame = blur.contentView.bounds;
    } else if (tintView) {
        [tintView removeFromSuperview];
    }
}
static BOOL gWAMSearchKbVisible = NO;
static CGFloat gWAMSearchRestMargin = -1.0;   // landscape resting left margin, reused when active so it doesn't jump

static BOOL wamIsOurBottomSearchDescendant(UIView *v) {
    for (UIView *a = v; a; a = a.superview) if (a.tag == kWAMBottomSearchTag) return YES;
    return NO;
}

static char kWAMGlyphBakedColorKey;

// Recolour every small icon-sized image view under `root`, skipping `skip`'s subtree (the dictation mic
// button, already correctly coloured elsewhere). This doesn't assume any specific property name (leftView,
// etc.) — UISearchTextField's real magnifier render path has proven immune to every leftView-based approach
// (setTintColor, image replace, view replace, hide via leftViewMode), which means it isn't rendered through
// leftView at all while editing. Hunting by geometry instead sidesteps whatever private view it actually is.
static void wamForceRecolorSearchGlyphs(UIView *root, UIColor *color, UIView *skip) {
    if (!root || !color) return;
    for (UIView *v in root.subviews) {
        if (v == skip || [v isDescendantOfView:skip]) continue;
        if ([v isKindOfClass:[UIImageView class]]) {
            UIImageView *iv = (UIImageView *)v;
            CGFloat w = iv.bounds.size.width, h = iv.bounds.size.height;
            if (iv.image && w >= 8.0 && w <= 28.0 && h >= 8.0 && h <= 28.0) {
                UIColor *already = objc_getAssociatedObject(iv, &kWAMGlyphBakedColorKey);
                if (![already isEqual:color]) {
                    UIImage *tmpl = [iv.image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                    iv.image = [tmpl imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];
                    objc_setAssociatedObject(iv, &kWAMGlyphBakedColorKey, color, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
            }
        }
        wamForceRecolorSearchGlyphs(v, color, skip);
    }
}

// UISearchBar re-centres its (natural-width) field on every layout pass, undoing the fill we set in
// wamSetupBottomSearch. For OUR bottom-search bar only (hosted inside our blur container, tag 4410), in the
// landscape split, reassert the fill AFTER the bar's own layout so the field fills the pill for good. Left
// alone while actively editing.
%hook UISearchBar

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !wamIsLandscape()) return;
    if (!wamIsOurBottomSearchDescendant(self.superview)) return;
    // The search bar is a conversation-list (global) element. In the split its ancestors carry the open
    // chat's per-contact tint, which the Cancel button + magnifier inherit. Pin them to the GLOBAL tint so
    // they follow the global side, not the last chat.
    BOOL prevG = gWAMForceGlobalColorResolve;
    gWAMForceGlobalColorResolve = YES;
    UIColor *globalTint = getSystemTintColor();
    gWAMForceGlobalColorResolve = prevG;
    if (!globalTint) globalTint = [UIColor systemBlueColor];   // no custom global tint → system default
    if (![self.tintColor isEqual:globalTint]) self.tintColor = globalTint;
    if (@available(iOS 13.0, *)) {
        UITextField *tf = self.searchTextField;
        if (!tf || tf.bounds.size.height <= 0.0) return;
        // The real search-magnifier icon is immune to every leftView-based recolour (proven across many
        // attempts) — while editing specifically, it isn't rendered via leftView at all. Hunt and recolour
        // any small icon-shaped image view in the WHOLE bar instead, skipping the dictation mic (already
        // correct via its own tintColor).
        {
            BOOL pg2 = gWAMForceGlobalColorResolve; gWAMForceGlobalColorResolve = YES;
            BOOL tActive2 = isAdvancedValueExplicitlySet(@"advancedSearchFieldColor", @"advancedSearchFieldColorDark") ||
                            isAdvancedValueExplicitlySet(@"systemTintColor", @"systemTintColorDark");
            UIColor *glyphColor2 = tActive2 ? getAdvancedSearchFieldColor() : nil;
            gWAMForceGlobalColorResolve = pg2;
            if (glyphColor2) wamForceRecolorSearchGlyphs(self, glyphColor2, tf.rightView);
        }
        // Field fills from a left inset to the right edge — or, while editing, to just before the Cancel
        // button — so it stretches across the pill and left-aligns instead of sitting tiny in the middle.
        // Always fill the field to the pill's right edge. The Cancel button (when editing) sits OUTSIDE the
        // pill to its right — normal search-bar behaviour — so it must NOT constrain the field width.
        CGFloat leftX = 8.0, rightX = self.bounds.size.width - 8.0;
        if (tf.isFirstResponder) {
            // Editing mode respects textAlignment (unlike the resting centred-placeholder style), so pin the
            // cursor / text / glyph to the left instead of floating in the middle of the field.
            tf.textAlignment = NSTextAlignmentLeft;
            // Find the rightmost button (Cancel) only to force its colour to the global tint.
            UIButton *cancel = nil;
            CGFloat cancelX = -CGFLOAT_MAX;
            NSMutableArray *q = [NSMutableArray arrayWithArray:self.subviews];
            while (q.count) {
                UIView *v = q.firstObject; [q removeObjectAtIndex:0];
                if ([v isDescendantOfView:tf]) continue;
                if ([v isKindOfClass:[UIButton class]] && v.bounds.size.width > 0) {
                    CGFloat x = [v convertRect:v.bounds toView:self].origin.x;
                    if (x > cancelX) { cancelX = x; cancel = (UIButton *)v; }
                }
                [q addObjectsFromArray:v.subviews];
            }
            if (cancel) {
                cancel.tintColor = globalTint;
                [cancel setTitleColor:globalTint forState:UIControlStateNormal];
                [cancel setTitleColor:globalTint forState:UIControlStateHighlighted];
            }
        }
        CGFloat wantW = rightX - leftX;
        if (wantW < 40.0) return;
        CGFloat wantY = (self.bounds.size.height - tf.frame.size.height) / 2.0;   // vertically centre in the pill
        if (fabs(tf.frame.size.width - wantW) > 1.0 || fabs(tf.frame.origin.x - leftX) > 1.0 ||
            fabs(tf.frame.origin.y - wantY) > 1.0) {
            CGRect r = tf.frame;
            r.origin.x = leftX;
            r.size.width = wantW;
            r.origin.y = wantY;
            tf.frame = r;
            [tf layoutIfNeeded];
        }
        // (Dictation-icon vertical centring is done in the UISearchTextField layoutSubviews hook, which runs
        // after the field positions its rightView, so it isn't reset.)
        // Once text is typed, hide our left-pinned placeholder overlay so it doesn't sit over the real text.
        UIView *ov = [self.superview viewWithTag:kWAMSearchGlyphOverlayTag];
        if (ov && tf.text.length > 0) ov.hidden = YES;
    }
}

%end

%hook CKConversationListCollectionViewController

-(void)viewWillAppear:(BOOL)animated {
    %orig;
    [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
    if (!isTweakEnabled() || !isiOS15()) return;
    [self applyCustomNavTitle];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    %orig;
    if (!isTweakEnabled()) return;
    // Rotation/split-view transition: recompute the relocated bottom search platter and the nav-bar
    // layout against the settled post-rotation size (mid-transition the platter came out mis-sized and
    // the title overlapped the Edit button).
    [coordinator animateAlongsideTransition:nil completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> ctx) {
        wamForceLayoutAllWindows();
        [self wamSetupBottomSearch];
        [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
    }];
}

-(void)viewDidAppear:(BOOL)animated {
    %orig;
    if (isTweakEnabled()) {
        [self handlePrefsChanged];
    }

    if (isTweakEnabled()) [self wamSetupBottomSearch];

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

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(wamKeyboardChanged:)
        name:UIKeyboardWillChangeFrameNotification
        object:nil];
}

%new
-(void)wamSetupBottomSearch {
    UIView *listView = self.view;
    if (!listView) return;

    UISearchController *sc = objc_getAssociatedObject(self, &kWAMBottomSearchCtrlKey);
    UIView *container = objc_getAssociatedObject(self, &kWAMBottomSearchContainerKey);
    BOOL on = isTweakEnabled() && isModernNavBarEnabled() && isNavButtonBlurEnabledGlobal();

    if (!on) {
        // Toggle off: hand the search bar back to the nav bar and drop the bottom platter (+ its blur wash).
        if (sc) {
            self.navigationItem.searchController = sc;
            objc_setAssociatedObject(self, &kWAMBottomSearchCtrlKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [container removeFromSuperview];
        objc_setAssociatedObject(self, &kWAMBottomSearchContainerKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [[listView viewWithTag:kWAMBottomScreenBlurTag] removeFromSuperview];
        return;
    }

    // Detach from the nav bar once; retain the controller so it keeps driving search.
    if (!sc) {
        sc = self.navigationItem.searchController;
        if (!sc) return;
        objc_setAssociatedObject(self, &kWAMBottomSearchCtrlKey, sc, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        self.navigationItem.searchController = nil;
    }
    UISearchBar *sb = sc.searchBar;
    if (!sb) return;

    UIVisualEffectView *fxv = nil;
    if (!container) {
        container = [[UIView alloc] initWithFrame:CGRectZero];
        container.tag = kWAMBottomSearchTag;
        container.clipsToBounds = NO;
        container.layer.shadowColor = [UIColor blackColor].CGColor;
        container.layer.shadowOpacity = 0.26;
        container.layer.shadowRadius = 6.0;
        container.layer.shadowOffset = CGSizeMake(0.0, 2.0);
        fxv = [[UIVisualEffectView alloc] initWithEffect:
               [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular]];
        fxv.clipsToBounds = YES;
        [container addSubview:fxv];
        objc_setAssociatedObject(self, &kWAMBottomSearchContainerKey, container, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    } else {
        fxv = (UIVisualEffectView *)container.subviews.firstObject;
    }

    // While the search controller is active it presents itself over the list, so re-home the platter
    // inside that presentation (on top of the results); otherwise rest it in the list view.
    BOOL active = sc.isActive && [self presentedViewController] == sc &&
                  sc.viewIfLoaded && sc.viewIfLoaded.window;
    UIView *host = active ? sc.view : listView;
    // Skip transitional/degenerate host geometry: mid-rotation the wrapper is briefly 0-wide (platter
    // came out at x=-16) — leave the last-good layout until it settles to a real width.
    if (host.bounds.size.width < 200.0) return;
    static char kWAMLiquidAssSearchKey;
    if (container.superview != host) {
        // Host is switching (list <-> the active-search presentation view) — any cached Liquid (Gl)ass glass
        // was parented as a sibling of container inside the OLD host, so it'd be left behind/orphaned there
        // once container moves, instead of following it. Drop it so it gets freshly reinstalled against the
        // new host on this pass (this is exactly why the glass background vanished on tapping into search).
        UIView *staleGlass = objc_getAssociatedObject(container, &kWAMLiquidAssSearchKey);
        if (staleGlass) {
            [staleGlass removeFromSuperview];
            objc_setAssociatedObject(container, &kWAMLiquidAssSearchKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        [host addSubview:container];
    }
    wamSetupBottomScreenBlur(host, container);

    // Keep the bar in our platter; the nav bar / controller tries to reclaim it, so grab it back here.
    if (self.navigationItem.searchController == sc) self.navigationItem.searchController = nil;
    // sb is a SIBLING of container in `host`, not nested inside fxv.contentView — see the Liquid (Gl)ass
    // comment below for why. wamIsOurBottomSearchDescendant() walks UP looking for kWAMBottomSearchTag, so
    // tag sb directly too (the walk checks the starting view itself first) — otherwise every hook gating on
    // "is this our search bar" (landscape fill, magnifier colour/hide, etc.) would stop matching.
    if (sb.superview != host) [host addSubview:sb];
    sb.tag = kWAMBottomSearchTag;
    sb.searchBarStyle = UISearchBarStyleMinimal;
    sb.backgroundImage = [UIImage new];
    if (@available(iOS 13.0, *)) sb.searchTextField.backgroundColor = [UIColor clearColor];

    // Geometry: a pill pinned near the bottom, lifted above the keyboard while it's up (a touch higher
    // and inset left while floating).
    CGFloat margin = 16.0;         // left inset
    CGFloat rightMargin = 16.0;    // right inset (kept constant so the right edge doesn't move)
    if (wamIsLandscape()) {
        // Shave the left so the platter's left lines up with the Edit button's left in the narrow split
        // column. Compute it only at REST (the nav bar's Edit button is a stable reference there) and cache
        // it; while searching, reuse the cached value verbatim so the pill's left edge doesn't grow/jump when
        // it's tapped.
        if (!active) {
            CGFloat editLeft = -1.0;
            UINavigationBar *navBar = self.navigationController.navigationBar;
            if (navBar && navBar.window) {
                NSMutableArray *q = [NSMutableArray arrayWithArray:navBar.subviews];
                while (q.count) {
                    UIView *v = q.firstObject; [q removeObjectAtIndex:0];
                    if ([v isKindOfClass:%c(_UIButtonBarButton)] && v.bounds.size.width > 0) {
                        CGRect f = [v convertRect:v.bounds toView:host];
                        if (editLeft < 0 || f.origin.x < editLeft) editLeft = f.origin.x;
                    }
                    [q addObjectsFromArray:v.subviews];
                }
            }
            if (editLeft >= 0) margin = editLeft;
            else if (host.window) margin = host.window.safeAreaInsets.left + 4.0;
            gWAMSearchRestMargin = margin;
        } else if (gWAMSearchRestMargin >= 0.0) {
            margin = gWAMSearchRestMargin;
        } else if (host.window) {
            margin = host.window.safeAreaInsets.left + 4.0;
        }
    }
    CGFloat h = 50.0;
    CGFloat w = host.bounds.size.width - margin - rightMargin;
    CGFloat bottomEdge;
    CGFloat leftShift = 0.0;
    // Only lift above the keyboard while search is actually engaged. The keyboard-state globals are
    // updated only while the list is on-screen, so they can go stale YES if the keyboard dismissed while
    // the list was covered (e.g. Messages opened straight into a chat via a notification, then popped
    // back) — trusting the flag alone stranded the platter mid-screen. Gating on the active search keeps
    // it resting at the bottom whenever the user isn't searching.
    if (gWAMSearchKbVisible && sc.isActive) {
        CGRect kb = [host convertRect:gWAMSearchKbFrameWin fromView:nil];
        bottomEdge = kb.origin.y - 12.0;
        leftShift = wamIsLandscape() ? 0.0 : 3.0;   // don't nudge the Edit-aligned left in the split
    } else {
        CGFloat home = host.window ? host.window.safeAreaInsets.bottom : 0.0;
        bottomEdge = host.bounds.size.height - home - 8.0;
    }
    container.frame = CGRectMake(margin - leftShift, bottomEdge - h, w, h);

    CGFloat radius = h / 2.0;
    fxv.frame = container.bounds;
    fxv.layer.cornerRadius = radius;
    if (@available(iOS 13.0, *)) fxv.layer.cornerCurve = kCACornerCurveContinuous;
    container.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:container.bounds cornerRadius:radius].CGPath;

    // Liquid (Gl)ass Compatibility (beta). Every technique that kept sb NESTED inside fxv.contentView (which
    // itself sits inside the same hostContainer glass is installed behind) made the search field vanish,
    // across five distinct approaches and two different borrowed surfaces — while nav buttons, where the real
    // glyph is a SIBLING of hostContainer rather than nested inside it, always rendered correctly. So sb was
    // restructured (above) to be a sibling of container in `host` too, matching that working structure exactly
    // instead of trying another variation of the nested approach. (kWAMLiquidAssSearchKey is declared earlier
    // in this function, where it's also used to invalidate stale glass on a host switch.)
    // SearchPill, not PrefsButton — PrefsButton's geometry (tuned for small square buttons) produces a
    // visible refraction seam/ridge on a wide 398×50 pill; SearchPill's own registry values are tuned for
    // exactly this shape. (Confirmed on device that nav buttons losing their navbar-blur layering happens
    // with search glass active EITHER way, same surface or different — so this isn't a "different surfaces
    // conflict" as first thought; using SearchPill costs nothing extra there.)
    wamApplyLiquidAssGlass(container, fxv, radius, &kWAMLiquidAssSearchKey, kWAMLGPrefixSearchPill);

    // The bar frame handles the left nudge + (when active) the right inset to clear Cancel. Vertical
    // position is set on the text field directly and centred in the pill — the bar's own field layout
    // drifts after the field has been edited, so centring on the field height keeps it stable.
    CGFloat cw = fxv.contentView.bounds.size.width, ch = fxv.contentView.bounds.size.height;
    // sb's frame is now in `host`'s coordinate space (it's a sibling of container there), not fxv.contentView's
    // — anchor its origin to container's own frame origin (same -6/0 offset as before) so it lands in exactly
    // the same visual position; width/height are unaffected by which view it's parented under.
    CGFloat sbX = container.frame.origin.x - 6.0, sbY = container.frame.origin.y;
    sb.frame = active ? CGRectMake(sbX, sbY, cw - 12.0, ch)
                      : CGRectMake(sbX, sbY, cw, ch);
    [sb layoutIfNeeded];

    if (@available(iOS 13.0, *)) {
        UITextField *tf = sb.searchTextField;
        if (tf && tf.bounds.size.height > 0.0) {
            CGRect r = tf.frame;
            r.origin.y = (ch - r.size.height) / 2.0;   // vertically centre in the pill
            // Fill the pill so "🔍 Search" sits left and the dictation icon rides the right edge — LANDSCAPE
            // only (portrait keeps the stock field layout). UISearchBar re-centres the field on its own later
            // layout passes, so the durable enforcement lives in the UISearchBar layoutSubviews hook below;
            // this is just the initial set.
            if (!active && wamIsLandscape()) { r.origin.x = 12.0; r.size.width = cw - 24.0; }
            tf.frame = r;
            if (!active && wamIsLandscape()) [tf layoutIfNeeded];

            // UISearchTextField centres its {🔍 + placeholder} within the field via private layout that
            // ignores frame / rect-method / positionAdjustment / placeholder-width overrides, and silently
            // reinstalls its own magnifier as leftView (so recolouring it never sticks). So in the landscape
            // split we permanently hide the real glyph + placeholder and own the magnifier ourselves — drawn
            // as an overlay that stays up in EVERY state (rest, active-empty, active-typing), only hiding the
            // "Search" placeholder label once there's real text. Portrait restores the stock field.
            NSString *origPH = objc_getAssociatedObject(tf, &kWAMSearchOrigPlaceholderKey);
            if (!origPH) {
                origPH = tf.placeholder.length ? tf.placeholder : @"Search";
                objc_setAssociatedObject(tf, &kWAMSearchOrigPlaceholderKey, origPH, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            UIView *ov = [fxv.contentView viewWithTag:kWAMSearchGlyphOverlayTag];
            if (wamIsLandscape()) {
                BOOL pg = gWAMForceGlobalColorResolve; gWAMForceGlobalColorResolve = YES;
                BOOL tActive = isAdvancedValueExplicitlySet(@"advancedSearchFieldColor", @"advancedSearchFieldColorDark") ||
                               isAdvancedValueExplicitlySet(@"systemTintColor", @"systemTintColorDark");
                UIColor *glyphColor = tActive ? getAdvancedSearchFieldColor() : [UIColor placeholderTextColor];
                gWAMForceGlobalColorResolve = pg;
                tf.leftViewMode = UITextFieldViewModeNever;   // never show the real (uncontrollable-colour) magnifier
                if (tf.placeholder.length) tf.placeholder = @"";
                if (!ov) {
                    ov = [[UIView alloc] init];
                    ov.tag = kWAMSearchGlyphOverlayTag;
                    ov.userInteractionEnabled = NO;
                    UIImageView *mg = [[UIImageView alloc] init]; mg.tag = 1;
                    mg.contentMode = UIViewContentModeScaleAspectFit;
                    UILabel *lb = [[UILabel alloc] init]; lb.tag = 2;
                    [ov addSubview:mg]; [ov addSubview:lb];
                    [fxv.contentView addSubview:ov];
                }
                [fxv.contentView bringSubviewToFront:ov];
                ov.hidden = NO;
                UIImageView *mg = (UIImageView *)[ov viewWithTag:1];
                UILabel *lb = (UILabel *)[ov viewWithTag:2];
                UIFont *font = tf.font ?: [UIFont systemFontOfSize:17.0];
                UIImageSymbolConfiguration *cfg =
                    [UIImageSymbolConfiguration configurationWithPointSize:font.pointSize weight:UIImageSymbolWeightRegular];
                // Bake the colour into the pixels (AlwaysOriginal) rather than relying on mg.tintColor —
                // the view-tree dump proved OUR overlay is the only visible icon while typing (the real one
                // is genuinely suppressed), yet it still read the wrong colour: some other tint-related hook
                // in the codebase must be touching mg.tintColor afterward. Baked pixels are immune to that.
                mg.image = [[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:cfg]
                               imageWithTintColor:glyphColor renderingMode:UIImageRenderingModeAlwaysOriginal];
                [mg sizeToFit];
                lb.text = origPH; lb.textColor = glyphColor; lb.font = font; [lb sizeToFit];
                ov.frame = fxv.contentView.bounds;
                // Align the overlay glyph/label with the dictation mic, which sits at pill-centre ≈ +0.5.
                CGFloat oy = 0.5;
                CGFloat mgW = mg.bounds.size.width, mgH = mg.bounds.size.height, lx = 14.0;
                mg.frame = CGRectMake(lx, (ch - mgH) / 2.0 + oy, mgW, mgH);
                CGFloat lbx = lx + mgW + 6.0;
                lb.frame = CGRectMake(lbx, (ch - lb.bounds.size.height) / 2.0 + oy,
                                      MIN(lb.bounds.size.width, cw - lbx - 40.0), lb.bounds.size.height);
                // Once real text is entered, hide only the "Search" placeholder label — the magnifier icon
                // (our colour-locked one, not the system's) stays up the whole time.
                lb.hidden = tf.text.length > 0;
            } else {
                tf.leftViewMode = UITextFieldViewModeAlways;
                if (tf.placeholder.length == 0 && origPH) tf.placeholder = origPH;
                if (ov) ov.hidden = YES;
            }
        }
        // Center the Cancel button too so it's inline with the field (it's a button beside the field,
        // not inside it — skip the field's own clear button).
        if (active) {
            NSMutableArray *q = [NSMutableArray arrayWithArray:sb.subviews];
            while (q.count) {
                UIView *v = q.firstObject; [q removeObjectAtIndex:0];
                if (tf && [v isDescendantOfView:tf]) continue;
                if ([v isKindOfClass:[UIButton class]]) {
                    CGRect br = v.frame;
                    br.origin.y = (v.superview.bounds.size.height - br.size.height) / 2.0;
                    v.frame = br;
                } else {
                    [q addObjectsFromArray:v.subviews];
                }
            }
        }
    }

    // Colorless frosted blur + the shared user tint, matching the nav button platters.
    Class subCls = NSClassFromString(@"_UIVisualEffectSubview");
    for (UIView *sub in fxv.subviews)
        if ([sub isKindOfClass:subCls]) sub.backgroundColor = [UIColor clearColor];
    UIView *tint = nil;
    for (UIView *s in fxv.contentView.subviews)
        if (s.tag == kWAMBottomSearchTintTag) { tint = s; break; }
    UIColor *tintColor = getNavPlatterColor(YES);   // conversation list — global color
    if (tintColor) {
        if (!tint) {
            tint = [[UIView alloc] init];
            tint.tag = kWAMBottomSearchTintTag;
            tint.userInteractionEnabled = NO;
            [fxv.contentView insertSubview:tint atIndex:0];
        }
        tint.frame = fxv.contentView.bounds;
        tint.backgroundColor = tintColor;
    } else if (tint) {
        [tint removeFromSuperview];
    }
    // sb is now a sibling of container in `host` (not nested in fxv.contentView) — bring container to front
    // first (above the list content, above glass), then sb LAST so it ends up the true topmost, above both.
    [host bringSubviewToFront:container];
    [host bringSubviewToFront:sb];
}

%new
-(void)wamKeyboardChanged:(NSNotification *)note {
    if (![self isViewLoaded] || !self.view.window) return;
    if (!objc_getAssociatedObject(self, &kWAMBottomSearchCtrlKey)) return;   // only when relocated

    CGRect kbEnd = [note.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    gWAMSearchKbVisible = kbEnd.origin.y < UIScreen.mainScreen.bounds.size.height - 1.0;
    gWAMSearchKbFrameWin = kbEnd;

    double dur = [note.userInfo[UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    NSInteger curve = [note.userInfo[UIKeyboardAnimationCurveUserInfoKey] integerValue];
    [UIView animateWithDuration:MAX(dur, 0.15) delay:0.0
                        options:(UIViewAnimationOptions)(curve << 16)
                     animations:^{ [self wamSetupBottomSearch]; } completion:nil];

    // The controller's self-presentation may not be in the window yet when the keyboard animates in;
    // re-run once it settles so the platter re-homes on top of the results.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self wamSetupBottomSearch]; });
    // Catch the search bar again after the controller's dismissal animation completes.
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.4 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ [self wamSetupBottomSearch]; });
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

    [self wamSetupBottomSearch];

    // With the blur platters on: breathing room below the nav bar so the pinned cells don't crowd the
    // (down-nudged) pills, and room at the bottom so content clears the floating search platter. Guarded
    // so setting it doesn't re-trigger layout endlessly.
    BOOL on = isModernNavBarEnabled() && isNavButtonBlurEnabledGlobal();
    CGFloat wantTop = on ? 14.0 : 0.0;
    CGFloat wantBottom = on ? 66.0 : 0.0;
    UIEdgeInsets ins = self.additionalSafeAreaInsets;
    if (fabs(ins.top - wantTop) > 0.5 || fabs(ins.bottom - wantBottom) > 0.5) {
        ins.top = wantTop;
        ins.bottom = wantBottom;
        self.additionalSafeAreaInsets = ins;
    }
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

#if WAM_SCREENSHOT_MODE
// =====================================================================
//  SCREENSHOT MODE — marketing screenshots only, never ships enabled.
//  See WAM_SCREENSHOT_MODE near the top of this file.
// =====================================================================

static NSArray<NSString *> *wamScreenshotFakeNames(void) {
    // First names only, and genuinely short (<=4 letters) — confirmed via device diagnostics the pinned-
    // conversation name label is only ~29pt wide, which clips even a plain 4-6 letter name like "Isabella"
    // or "Amelia". Kept uniformly short so the same pool works in both the roomy list row and the tight
    // pinned slot without needing separate pools per context.
    static NSArray<NSString *> *names;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        names = @[@"Emma", @"Liam", @"Ava", @"Noah", @"Mia", @"Ethan", @"Zoe", @"Jack",
                  @"Kai", @"Ella", @"Sam", @"Ivy", @"Owen", @"Leo", @"Amy", @"Ryan",
                  @"Eve", @"Ben", @"Lily", @"Max", @"Jo", @"Finn", @"Tara", @"Cole"];
    });
    return names;
}

static NSArray<NSString *> *wamScreenshotFakePreviews(void) {
    // Mixed lengths on purpose — a conv list where every preview is exactly one short line reads as
    // obviously staged. Short and long entries are interleaved through the same pool (selection is a hash
    // over the whole array) rather than split into two pools, so it comes out roughly half and half without
    // needing separate short/long logic.
    static NSArray<NSString *> *previews;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        previews = @[
            @"Sounds good, see you then!", @"Haha that's amazing 😂", @"Can you send that over?",
            @"On my way, be there in 10", @"Thanks so much for this!",
            @"I read through everything you sent over and it all looks good to me. Just a couple small tweaks and we should be set.",
            @"Yeah I'm free this weekend", @"That looks great!",
            @"Hey, I just got back from the store and grabbed everything on the list. Let me know if you need anything else before tonight.",
            @"Just landed, calling you soon", @"Happy birthday! 🎉",
            @"That meeting ran way longer than expected but I think we got everything sorted out. I'll send over the notes in a bit.",
            @"I'll bring the snacks", @"Perfect, talk soon",
            @"I was thinking about that trip we talked about and I think October could actually work great for both of us.",
            @"Love that idea",
            @"Just wanted to check in and see how everything's going on your end. It's been a minute since we caught up properly.",
            @"Got it, thank you!",
            @"The new place looks amazing so far, way bigger than I expected honestly. You'll have to come see it once we're settled in.",
            @"Can't wait to see you",
            @"I finally finished that project I've been putting off for weeks. Feels so good to have it off my plate now.",
            @"Sent you the details",
            @"We should definitely plan something for the weekend, it's been way too long since we all got together.",
            @"Running a few minutes late",
            @"Thanks again for helping me move last weekend, I really appreciate it. Let me know if you ever need a hand with anything.",
            @"No worries at all",
            @"The flight got delayed a couple hours but I should still land before dinner. I'll text you when I'm on the ground.",
            @"Did you see the game last night?",
            @"I've been meaning to ask, are you still free to help out with the thing on Saturday? No worries at all if plans changed."
        ];
    });
    return previews;
}

// Each entry is a two-color gradient pair rather than a flat fill — a wider hue spread than before, and the
// gradient itself reads as more "designed"/less repetitive across a screenshot full of avatars.
static NSArray<NSArray<UIColor *> *> *wamScreenshotAvatarGradients(void) {
    static NSArray<NSArray<UIColor *> *> *gradients;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gradients = @[
            @[[UIColor colorWithRed:0.25 green:0.55 blue:0.95 alpha:1.0], [UIColor colorWithRed:0.45 green:0.78 blue:1.00 alpha:1.0]],   // blue
            @[[UIColor colorWithRed:0.98 green:0.45 blue:0.22 alpha:1.0], [UIColor colorWithRed:1.00 green:0.72 blue:0.32 alpha:1.0]],   // orange
            @[[UIColor colorWithRed:0.30 green:0.75 blue:0.42 alpha:1.0], [UIColor colorWithRed:0.58 green:0.90 blue:0.55 alpha:1.0]],   // green
            @[[UIColor colorWithRed:0.88 green:0.22 blue:0.52 alpha:1.0], [UIColor colorWithRed:1.00 green:0.52 blue:0.70 alpha:1.0]],   // pink
            @[[UIColor colorWithRed:0.55 green:0.32 blue:0.92 alpha:1.0], [UIColor colorWithRed:0.78 green:0.60 blue:1.00 alpha:1.0]],   // purple
            @[[UIColor colorWithRed:0.95 green:0.72 blue:0.10 alpha:1.0], [UIColor colorWithRed:1.00 green:0.90 blue:0.40 alpha:1.0]],   // yellow/gold
            @[[UIColor colorWithRed:0.15 green:0.68 blue:0.72 alpha:1.0], [UIColor colorWithRed:0.42 green:0.90 blue:0.90 alpha:1.0]],   // teal
            @[[UIColor colorWithRed:0.90 green:0.18 blue:0.20 alpha:1.0], [UIColor colorWithRed:1.00 green:0.45 blue:0.42 alpha:1.0]],   // red
            @[[UIColor colorWithRed:0.28 green:0.28 blue:0.75 alpha:1.0], [UIColor colorWithRed:0.55 green:0.55 blue:0.98 alpha:1.0]],   // indigo
            @[[UIColor colorWithRed:0.62 green:0.42 blue:0.26 alpha:1.0], [UIColor colorWithRed:0.85 green:0.65 blue:0.42 alpha:1.0]],   // brown/tan
            @[[UIColor colorWithRed:0.42 green:0.65 blue:0.22 alpha:1.0], [UIColor colorWithRed:0.68 green:0.88 blue:0.32 alpha:1.0]],   // olive/lime
            @[[UIColor colorWithRed:0.28 green:0.40 blue:0.58 alpha:1.0], [UIColor colorWithRed:0.52 green:0.68 blue:0.85 alpha:1.0]],   // slate blue
            @[[UIColor colorWithRed:0.75 green:0.20 blue:0.75 alpha:1.0], [UIColor colorWithRed:0.95 green:0.50 blue:0.95 alpha:1.0]],   // magenta
            @[[UIColor colorWithRed:0.20 green:0.55 blue:0.35 alpha:1.0], [UIColor colorWithRed:0.35 green:0.78 blue:0.68 alpha:1.0]],   // forest→teal
        ];
    });
    return gradients;
}

// Deterministic per-seed pick (not random) — the same real name always maps to the same fake one, so
// scrolling a cell off/onscreen or a relayout never causes it to flicker between different fakes. Also
// collision-avoiding: a plain hash-mod-count pick let two DIFFERENT real conversations land on the same
// fake name whenever they happened to hash to the same bucket, which reads as obviously fake in a
// screenshot with more than one row visible. This instead remembers every real-name → fake-name assignment
// made so far and, on a new real name, walks the pool starting from its hash bucket until it finds one no
// other real name currently holds — so every fake name on screen at once is unique as long as there are at
// least as many pool entries as visible conversations.
static NSString *wamScreenshotFakeNameFor(NSString *seed) {
    static NSMutableDictionary<NSString *, NSString *> *seedToFake;
    static NSMutableSet<NSString *> *usedFakes;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        seedToFake = [NSMutableDictionary new];
        usedFakes = [NSMutableSet new];
    });
    NSString *existing = seedToFake[seed];
    if (existing) return existing;
    NSArray<NSString *> *names = wamScreenshotFakeNames();
    NSUInteger start = (NSUInteger)(labs((long)seed.hash) % (long)names.count);
    NSString *chosen = nil;
    for (NSUInteger i = 0; i < names.count; i++) {
        NSString *candidate = names[(start + i) % names.count];
        if (![usedFakes containsObject:candidate]) { chosen = candidate; break; }
    }
    if (!chosen) chosen = names[start];   // pool exhausted (more real conversations than fake names) — repeat
    seedToFake[seed] = chosen;
    [usedFakes addObject:chosen];
    return chosen;
}

static NSString *wamScreenshotFakePreviewFor(NSString *seed) {
    NSArray<NSString *> *previews = wamScreenshotFakePreviews();
    return previews[(NSUInteger)(labs((long)seed.hash) % (long)previews.count)];
}

static NSArray<UIColor *> *wamScreenshotAvatarGradientFor(NSString *seed) {
    NSArray<NSArray<UIColor *> *> *gradients = wamScreenshotAvatarGradients();
    return gradients[(NSUInteger)(labs((long)seed.hash) % (long)gradients.count)];
}

// Replaces label.text with a deterministic fake derived from whatever's CURRENTLY there — but only when
// that's genuinely new real data from UIKit's own cell configuration, not our own fake text sitting
// unchanged from the last pass (recognized via the associated "last fake we set" marker) — otherwise
// re-hashing our own fake output on every layout pass would make the name drift across relayouts instead of
// staying fixed per row.
static void wamScreenshotLabelFakeText(UILabel *label, BOOL isName) {
    static char kWAMSSFakeKey;
    NSString *current = label.text;
    if (!current.length) return;
    NSString *lastFake = objc_getAssociatedObject(label, &kWAMSSFakeKey);
    if ([current isEqualToString:lastFake]) return;
    NSString *fake = isName ? wamScreenshotFakeNameFor(current) : wamScreenshotFakePreviewFor(current);
    objc_setAssociatedObject(label, &kWAMSSFakeKey, fake, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    label.text = fake;
}

// Confirmed via device diagnostics: the real class is CKAvatarView, not CNVisualIdentityAvatarContainerView
// — and in the pinned-conversation layout, the actual photo isn't even nested inside it, it's a SEPARATE
// sibling UIImageView positioned over the same spot. Covering CKAvatarView's own bounds from a subview
// added inside it would sit BEHIND that sibling photo and never be visible. Instead, add the cover as a
// sibling of CKAvatarView in ITS OWN parent, sized/positioned to CKAvatarView's frame, and push it to the
// very front of that parent — which sits on top of CKAvatarView AND any later sibling (the real photo)
// regardless of which structural style this particular row uses.
static void wamScreenshotRedactAvatarAt(UIView *parent, CGRect frameInParent, NSString *fakeNameSeed) {
    static const NSInteger kWAMSSAvatarTag = 4491;
    static char kWAMSSGradientLayerKey;
    UIView *cover = [parent viewWithTag:kWAMSSAvatarTag];
    if (!cover || cover.superview != parent) {
        cover = [[UIView alloc] init];
        cover.tag = kWAMSSAvatarTag;
        cover.userInteractionEnabled = NO;
        cover.clipsToBounds = YES;
        CAGradientLayer *gradientLayer = [CAGradientLayer layer];
        gradientLayer.startPoint = CGPointMake(0.15, 0.0);
        gradientLayer.endPoint = CGPointMake(0.85, 1.0);
        [cover.layer addSublayer:gradientLayer];
        objc_setAssociatedObject(cover, &kWAMSSGradientLayerKey, gradientLayer, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        UILabel *initial = [[UILabel alloc] init];
        initial.tag = kWAMScreenshotInitialLabelTag;
        initial.textAlignment = NSTextAlignmentCenter;
        initial.textColor = [UIColor whiteColor];
        [cover addSubview:initial];
        [parent addSubview:cover];
    }
    cover.frame = frameInParent;
    cover.layer.cornerRadius = cover.bounds.size.width / 2.0;
    CAGradientLayer *gradientLayer = objc_getAssociatedObject(cover, &kWAMSSGradientLayerKey);
    gradientLayer.frame = cover.bounds;
    NSArray<UIColor *> *pair = wamScreenshotAvatarGradientFor(fakeNameSeed);
    gradientLayer.colors = @[(id)pair.firstObject.CGColor, (id)pair.lastObject.CGColor];
    UILabel *initial = (UILabel *)[cover viewWithTag:kWAMScreenshotInitialLabelTag];
    initial.frame = cover.bounds;
    initial.font = [UIFont systemFontOfSize:MAX(12.0, cover.bounds.size.height * 0.4) weight:UIFontWeightSemibold];
    initial.textColor = [UIColor whiteColor];
    initial.text = fakeNameSeed.length ? [[fakeNameSeed substringToIndex:1] uppercaseString] : @"?";
    [parent bringSubviewToFront:cover];
}

// Walks a conv-list row's (or pinned bubble's) view tree redacting name/preview labels and avatar photos.
// Same label taxonomy the rest of the file already uses (see applyCustomTextColors): CKLabel (not
// CKDateLabel) = name, CKDateLabel/UIDateLabel = timestamp (left alone — not asked for), plain UILabel =
// message preview. BFS rather than recursive-with-a-running-seed so avatar redaction (which needs the row's
// fake name) doesn't depend on the avatar view happening to be visited after the name label — it always
// runs once at the end, after the whole tree's been walked.
static void wamScreenshotApplyToCell(UIView *root) {
    NSString *fakeName = nil;
    UIView *avatarView = nil;
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    while (queue.count) {
        UIView *v = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if ([v isKindOfClass:%c(CKLabel)] && ![v isKindOfClass:%c(CKDateLabel)]) {
            wamScreenshotLabelFakeText((UILabel *)v, YES);
            if (!fakeName.length) fakeName = ((UILabel *)v).text;
        } else if ([v isKindOfClass:%c(CKDateLabel)] || [v isKindOfClass:%c(UIDateLabel)]) {
            // timestamps left as-is
        } else if ([v isKindOfClass:[UILabel class]]) {
            wamScreenshotLabelFakeText((UILabel *)v, NO);
        } else if ([v isKindOfClass:%c(CKAvatarView)]) {
            avatarView = v;
            continue;   // don't descend into it — the cover goes over it as a sibling, see above
        }
        for (UIView *sub in v.subviews) [queue addObject:sub];
    }
    if (avatarView && avatarView.superview) {
        wamScreenshotRedactAvatarAt(avatarView.superview, avatarView.frame, fakeName.length ? fakeName : @"x");
    }
}
#endif

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
    NSString *name = [best.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!name.length) return;
    if ([name isEqualToString:gWAMCurrentContactName]) return;
    gWAMCurrentContactName = [name copy];
    gWAMCurrentContactDisplayName = [name copy];
    gWAMCacheSetAt = [NSDate timeIntervalSinceReferenceDate];
    gWAMTapSetAt = gWAMCacheSetAt;
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
        gWAMActiveChatName = [name copy];
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
#if WAM_SCREENSHOT_MODE
    wamScreenshotApplyToCell(self.contentView);
#endif
}

%end

%hook UILabel

- (void)setTextColor:(UIColor *)color {
    // Screenshot mode's fake-avatar initial letter is a plain UILabel sitting inside a conv-list cell —
    // the per-context color logic below (correctly) treats every plain UILabel there as a message-preview
    // label and repaints it, which was silently overriding the white we set on it. Bypass unconditionally
    // for this one tag regardless of any other pref state.
    if (self.tag == kWAMScreenshotInitialLabelTag) { %orig; return; }
    if (!isTweakEnabled() || !isCustomTextColorsEnabled()) {
        %orig;
        return;
    }

    UIView *superview = self.superview;
    BOOL isInConversationCell = NO;
    int convHops = 0;
    while (superview && convHops < 12) {
        if ([superview isKindOfClass:%c(CKConversationListCollectionViewConversationCell)]) {
            isInConversationCell = YES;
            break;
        }
        superview = superview.superview;
        convHops++;
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
    BOOL nameMatch = NO;
    if ([self isKindOfClass:%c(CKLabel)] && text.length && chatName.length) {
        NSCharacterSet *wsTrim = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        NSString *trimmedText = [text stringByTrimmingCharactersInSet:wsTrim];
        NSString *trimmedChat = [chatName stringByTrimmingCharactersInSet:wsTrim];
        nameMatch = trimmedText.length && trimmedChat.length && [trimmedText isEqualToString:trimmedChat];
    }
    if (nameMatch) {
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
            UIColor *nameColor = nil;
            if (isCustomTextColorsEnabled()) {
                NSString *k1 = isDarkMode() ? @"chatContactNameColorDark" : @"chatContactNameColor";
                nameColor = colorFromHex(effectiveValueForKey(k1));
                if (!nameColor) {
                    NSString *k2 = isDarkMode() ? @"titleTextColorDark" : @"titleTextColor";
                    nameColor = colorFromHex(effectiveValueForKey(k2));
                }
            }
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
            } else {
                id orig = objc_getAssociatedObject(self, &kWAMOrigTitleColorKey);
                if (orig && orig != [NSNull null]) {
                    self.textColor = (UIColor *)orig;
                    objc_setAssociatedObject(self, &kWAMOrigTitleColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
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
    BOOL nameMatch = NO;
    if (text.length && chatName.length) {
        NSCharacterSet *wsTrim = [NSCharacterSet whitespaceAndNewlineCharacterSet];
        NSString *trimmedText = [text stringByTrimmingCharactersInSet:wsTrim];
        NSString *trimmedChat = [chatName stringByTrimmingCharactersInSet:wsTrim];
        nameMatch = trimmedText.length && trimmedChat.length && [trimmedText isEqualToString:trimmedChat];
    }
    if (nameMatch) {
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
            UIColor *nameColor = nil;
            if (isCustomTextColorsEnabled()) {
                NSString *k1 = isDarkMode() ? @"chatContactNameColorDark" : @"chatContactNameColor";
                nameColor = colorFromHex(effectiveValueForKey(k1));
                if (!nameColor) {
                    NSString *k2 = isDarkMode() ? @"titleTextColorDark" : @"titleTextColor";
                    nameColor = colorFromHex(effectiveValueForKey(k2));
                }
            }
            if (nameColor) {
                if (!objc_getAssociatedObject(self, &kWAMOrigTitleColorKey)) {
                    objc_setAssociatedObject(self, &kWAMOrigTitleColorKey,
                        self.textColor ?: (id)[NSNull null],
                        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
                self.textColor = nameColor;
            } else {
                id orig = objc_getAssociatedObject(self, &kWAMOrigTitleColorKey);
                if (orig && orig != [NSNull null]) {
                    self.textColor = (UIColor *)orig;
                    objc_setAssociatedObject(self, &kWAMOrigTitleColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
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

static BOOL wamBarIsInMediaViewer(UIView *bar) {
    UIView *v = bar;
    int hops = 0;
    while (v && hops++ < 16) {
        NSString *cls = NSStringFromClass([v class]);
        if ([cls containsString:@"Preview"]   || [cls containsString:@"MediaObject"] ||
            [cls containsString:@"FullScreen"] || [cls containsString:@"Fullscreen"] ||
            [cls containsString:@"Lightbox"]  || [cls containsString:@"PhotoView"]  ||
            [cls hasPrefix:@"QL"]             || [cls hasPrefix:@"PX"]              ||
            [cls hasPrefix:@"PU"]) {
            return YES;
        }
        v = v.superview;
    }
    return NO;
}

%hook _UIBarBackground

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    if (isModernNavBarEnabled() && self.window && !wamBarIsInMediaViewer(self)) {
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
    if (wamBarIsInMediaViewer(self)) return;

    static const char kHasContactCacheKey = 0;
    static const char kHasContactTimeKey = 0;
    NSNumber *cachedHas = objc_getAssociatedObject(self, &kHasContactCacheKey);
    NSNumber *cachedTime = objc_getAssociatedObject(self, &kHasContactTimeKey);
    NSTimeInterval nowT = [NSDate timeIntervalSinceReferenceDate];
    BOOL hasContactViewCached;
    if (cachedHas && cachedTime && (nowT - cachedTime.doubleValue) < 0.25) {
        hasContactViewCached = cachedHas.boolValue;
    } else {
        hasContactViewCached = self.window ? [self findContactViewInWindow:self.window] : NO;
        objc_setAssociatedObject(self, &kHasContactCacheKey, @(hasContactViewCached), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &kHasContactTimeKey, @(nowT), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (isModernNavBarEnabled()) {
        BOOL hasContactView = hasContactViewCached;
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

    if (hasContactViewCached) { self.alpha = 0.0; return; }
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
        if (isConvListTitle) {
            label.text = conversationListTitle;
            // With the blur platters on, the Edit/Compose content is nudged down; drop the title the
            // same amount so it sits centred on the platters' height.
            BOOL platters = isModernNavBarEnabled() && isNavButtonBlurEnabledGlobal();
            CGFloat ty = platters ? wamNavButtonDropY(YES) : 0.0;
            CGFloat tx = 0.0;
            if (platters && wamIsLandscape()) {
                // In the narrow split column the stock title is left-aligned and rides over the Edit button.
                // Re-centre it in the gap between the Edit and Compose PLATTERS (tags 4400 / 4413) — the
                // platters extend past the button bounds, so centring on the buttons still overlaps them.
                UIView *nav = self;
                while (nav && ![nav isKindOfClass:[UINavigationBar class]]) nav = nav.superview;
                CGFloat editRight = -CGFLOAT_MAX, composeLeft = CGFLOAT_MAX;
                if (nav) {
                    NSMutableArray *q = [NSMutableArray arrayWithArray:nav.subviews];
                    while (q.count) {
                        UIView *v = q.firstObject; [q removeObjectAtIndex:0];
                        if ((v.tag == 4400 || v.tag == 4413) && v.bounds.size.width > 0) {
                            CGRect f = [v convertRect:v.bounds toView:self];
                            // Edit platter is the left one, Compose the right — classify by centre.
                            if (CGRectGetMidX(f) < 0.0) editRight = MAX(editRight, CGRectGetMaxX(f));
                            else composeLeft = MIN(composeLeft, CGRectGetMinX(f));
                        }
                        [q addObjectsFromArray:v.subviews];
                    }
                }
                if (editRight > -CGFLOAT_MAX && composeLeft < CGFLOAT_MAX && composeLeft > editRight) {
                    CGFloat gapCenter = (editRight + composeLeft) / 2.0;
                    // The title nearly fills the gap, so even centred it hugs the platters. Constrain its
                    // width to leave a clear margin each side (truncates a touch more), keeping its centre.
                    CGFloat maxW = (composeLeft - editRight) - 28.0;
                    if (maxW > 40.0 && label.bounds.size.width > maxW) {
                        CGFloat cx = CGRectGetMidX(label.frame);
                        CGRect lf = label.frame;
                        lf.size.width = maxW;
                        lf.origin.x = cx - maxW / 2.0;
                        label.frame = lf;
                    }
                    CGPoint lc = [label.superview convertPoint:label.center toView:self];
                    tx = gapCenter - lc.x;
                    ((UIView *)self).clipsToBounds = NO;
                    label.superview.clipsToBounds = NO;
                }
            }
            label.transform = platters ? CGAffineTransformMakeTranslation(tx, ty)
                                        : CGAffineTransformIdentity;
        }
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
    NSString *captured = nil;
    {
        id tappedConv = wamConversationFromTappedView((UIView *)self);
        if (tappedConv) {
            SEL sels[] = {
                @selector(name),
                @selector(displayName),
                @selector(title),
                NSSelectorFromString(@"effectiveDisplayName"),
                NSSelectorFromString(@"primaryRecipientDisplayName"),
                NSSelectorFromString(@"groupName"),
                (SEL)0
            };
            for (int i = 0; sels[i] != (SEL)0 && !captured.length; i++) {
                if ([tappedConv respondsToSelector:sels[i]]) {
                    NSString *dn = ((NSString *(*)(id, SEL))objc_msgSend)(tappedConv, sels[i]);
                    if ([dn isKindOfClass:[NSString class]] && dn.length) captured = dn;
                }
                if (!captured.length) {
                    Ivar ch = class_getInstanceVariable([tappedConv class], "_chat");
                    id chat = ch ? object_getIvar(tappedConv, ch) : nil;
                    if (chat && [chat respondsToSelector:sels[i]]) {
                        NSString *dn = ((NSString *(*)(id, SEL))objc_msgSend)(chat, sels[i]);
                        if ([dn isKindOfClass:[NSString class]] && dn.length) captured = dn;
                    }
                }
            }
        }
        if (!captured.length) {
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
            captured = best.text;
        }
        captured = [captured stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if (!captured.length) return;
    if ([captured isEqualToString:gWAMCurrentContactName]) return;
    gWAMCurrentContactName = [captured copy];
    gWAMCurrentContactDisplayName = [captured copy];
    gWAMCacheSetAt = [NSDate timeIntervalSinceReferenceDate];
    gWAMTapSetAt = gWAMCacheSetAt;

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
        if (captured.length) gWAMActiveChatName = [captured copy];
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
#if WAM_SCREENSHOT_MODE
    wamScreenshotApplyToCell((UIView *)self);
#endif
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

static UIBezierPath *wamBubbleMaskPath(CGSize size, BOOL tailRight, BOOL hasTail);

static void wamDeOpaqueBalloonTree(UIView *root) {
    Class liveView = objc_getClass("MSMessageExtensionBalloonLiveView");
    NSMutableArray *stack = [NSMutableArray arrayWithObject:root];
    int guard = 0;
    while (stack.count && guard++ < 160) {
        UIView *v = stack.lastObject;
        [stack removeLastObject];
        if (v.layer.opaque || v.isOpaque) {
            v.opaque = NO;
            v.layer.opaque = NO;
        }
        if (liveView && [v isKindOfClass:liveView]) continue;
        [stack addObjectsFromArray:v.subviews];
    }
}

%hook CKTranscriptBalloonCell

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    wamDeOpaqueBalloonTree(self);
}

%end

%hook CKTranscriptPluginBalloonView

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !shouldShowAnyChatBgImage()) return;
    [self wamRoundPluginBalloon];
}

%new
- (void)wamRoundPluginBalloon {
    CGRect b = self.bounds;
    if (b.size.width < 20 || b.size.height < 20) return;

    CALayer *content = nil;
    for (CALayer *sub in self.layer.sublayers) {
        if (CGSizeEqualToSize(sub.frame.size, b.size)) {
            if (!content) content = sub;
        } else if (CGRectContainsRect(sub.frame, b)) {
            sub.hidden = YES;
        }
    }
    if (!content) return;

    BOOL hosted = NO;
    Class hostCls = objc_getClass("CALayerHost");
    NSMutableArray *stack = [NSMutableArray arrayWithObject:content];
    int guard = 0;
    while (stack.count && guard++ < 40 && !hosted) {
        CALayer *l = stack.lastObject;
        [stack removeLastObject];
        if (hostCls && [l isKindOfClass:hostCls]) { hosted = YES; break; }
        if (l.sublayers.count) [stack addObjectsFromArray:l.sublayers];
    }

    if (hosted) {
        self.layer.mask = nil;
        content.cornerRadius = MIN(17.0, b.size.height / 2.0);
        content.masksToBounds = YES;
        if (@available(iOS 13.0, *)) content.cornerCurve = kCACornerCurveContinuous;
        return;
    }

    BOOL tailRight = self.superview
        ? (CGRectGetMaxX(self.frame) > CGRectGetWidth(self.superview.bounds) - 24.0)
        : NO;

    CAShapeLayer *mask = (CAShapeLayer *)self.layer.mask;
    if (![mask isKindOfClass:[CAShapeLayer class]]) {
        mask = [CAShapeLayer layer];
        self.layer.mask = mask;
    }
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    mask.frame = b;
    mask.path = wamBubbleMaskPath(b.size, tailRight, YES).CGPath;
    [CATransaction commit];
}

%end

static BOOL wamIsNotificationExtension(void) {
    static BOOL computed = NO, result = NO;
    if (!computed) {
        NSString *bid = [NSBundle mainBundle].bundleIdentifier ?: @"";
        result = ![bid isEqualToString:@"com.apple.MobileSMS"];
        computed = YES;
    }
    return result;
}

static NSString *wamContactNameFromTranscript(id vc) {
    NSArray *paths = @[@"chatController.chat.displayName", @"chatController.conversation.displayName",
                       @"conversation.chat.displayName", @"conversation.displayName", @"chat.displayName"];
    for (NSString *kp in paths) {
        @try {
            id v = [vc valueForKeyPath:kp];
            if ([v isKindOfClass:[NSString class]] && [(NSString *)v length]) return v;
        } @catch (__unused NSException *e) {}
    }

    UIView *root = [vc isKindOfClass:[UIViewController class]] ? ((UIViewController *)vc).view : nil;
    if (root) {
        UILabel *best = nil; CGFloat bestSize = 0;
        NSMutableArray *queue = [NSMutableArray arrayWithObject:root];
        while (queue.count) {
            UIView *view = queue.firstObject; [queue removeObjectAtIndex:0];
            if ([view isKindOfClass:[UILabel class]] && ![view isKindOfClass:%c(CKDateLabel)]) {
                UILabel *l = (UILabel *)view;
                if (l.text.length && l.font.pointSize > bestSize) { bestSize = l.font.pointSize; best = l; }
            }
            [queue addObjectsFromArray:view.subviews];
        }
        NSString *t = [best.text stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
        if (t.length) return t;
    }
    return nil;
}

static UIView *wamFirstDescendantOfClassNamed(UIView *root, NSString *clsName) {
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    while (queue.count) {
        UIView *v = queue.firstObject; [queue removeObjectAtIndex:0];
        if ([NSStringFromClass([v class]) isEqualToString:clsName]) return v;
        [queue addObjectsFromArray:v.subviews];
    }
    return nil;
}

static void wamCollectDescendantsOfClassNamed(UIView *root, NSString *clsName, NSMutableArray<UIView *> *out) {
    if ([NSStringFromClass([root class]) isEqualToString:clsName]) { [out addObject:root]; return; }
    for (UIView *s in root.subviews) wamCollectDescendantsOfClassNamed(s, clsName, out);
}

static UILabel *wamFirstLabelDescendant(UIView *root) {
    NSMutableArray<UIView *> *queue = [NSMutableArray arrayWithObject:root];
    while (queue.count) {
        UIView *v = queue.firstObject; [queue removeObjectAtIndex:0];
        if ([v isKindOfClass:[UILabel class]] && ((UILabel *)v).text.length) return (UILabel *)v;
        [queue addObjectsFromArray:v.subviews];
    }
    return nil;
}

// In MessagesViewService (the sharesheet compose host) there's no CKMessagesController to resolve the active
// conversation from (see getCurrentContactName), and the transcript's own KVC paths + biggest-label fallback
// (wamContactNameFromTranscript) grab the wrong text there — a "Read Yesterday" receipt label, not the
// recipient — and there's no nav bar title to fall back on either (the sharesheet compose screen has none).
// The real name lives in the recipient token bar instead: CKComposeRecipientView -> _CNAtomTextView ->
// (one) CNComposeRecipientAtom per chosen recipient -> a UIView -> the name UILabel. Walked by class name via
// plain view-hierarchy traversal (no ivar reflection) so it can't repeat the earlier crash; each search stage
// tolerates Apple inserting extra wrapper views in between, since it only requires the sequence to appear
// somewhere below, not as direct children.
static NSString *wamComposeRecipientBarName(UIView *recipientView) {
    UIView *atomTextView = wamFirstDescendantOfClassNamed(recipientView, @"_CNAtomTextView");
    if (!atomTextView) return nil;
    NSMutableArray<UIView *> *atoms = [NSMutableArray array];
    wamCollectDescendantsOfClassNamed(atomTextView, @"CNComposeRecipientAtom", atoms);
    if (!atoms.count) return nil;
    NSMutableArray<NSString *> *names = [NSMutableArray array];
    for (UIView *atom in atoms) {
        UILabel *l = wamFirstLabelDescendant(atom);
        if (l.text.length) [names addObject:l.text];
    }
    return names.count ? [names componentsJoinedByString:@", "] : nil;
}

// Confirmed via device diagnostics: the class chain resolves correctly the moment a CNComposeRecipientAtom
// (one per chosen recipient) exists, but CKComposeRecipientView's own layoutSubviews doesn't reliably get
// called again the instant a chip is inserted (it's a rich-text/attachment system — the outer view isn't
// guaranteed to re-layout on its own), so resolution lagged until some unrelated layout pass happened to
// fire. Called from both CKComposeRecipientView AND CNComposeRecipientAtom itself (the atom is what's
// actually created the moment a recipient is picked) so it resolves immediately either way.
static void wamUpdateComposeRecipientName(UIView *anyDescendant) {
    if (!wamIsNotificationExtension()) return;
    UIView *recipientView = anyDescendant;
    while (recipientView && ![NSStringFromClass([recipientView class]) isEqualToString:@"CKComposeRecipientView"])
        recipientView = recipientView.superview;
    if (!recipientView) return;
    NSString *nm = wamComposeRecipientBarName(recipientView);
    if (nm.length) {
        if ([gWAMNotifContactName isEqualToString:nm]) return;
        gWAMChatIsActiveSurface = YES;
        gWAMNotifContactName = [nm copy];
        // A lot of theming (nav title color, status/read-receipt cells, reaction glyphs, etc.) reads
        // gWAMCurrentContactName directly rather than going through getCurrentContactName() — set it in
        // lockstep, matching every other capture site in the file, or those stay on global colors forever.
        gWAMCurrentContactName = [nm copy];
        gWAMCurrentContactDisplayName = [nm copy];
        gWAMCacheSetAt = [NSDate timeIntervalSinceReferenceDate];
    } else {
        if (!gWAMNotifContactName.length) return;
        // Recipient chip deleted — the field is empty again, revert to global styling.
        gWAMNotifContactName = nil;
        gWAMCurrentContactName = nil;
        gWAMCurrentContactDisplayName = nil;
    }
    // refreshPrefs() alone only reloads the plist — it doesn't notify anything. wamTriggerFullChatRefresh()
    // is what actually posts kPrefsChangedNotification (its no-CKMessagesController fallback, which is
    // exactly this process's situation), which is what every "handleXPrefsChanged" observer in this file is
    // listening for to re-theme itself right now instead of waiting for some unrelated layout pass.
    wamTriggerFullChatRefresh();
}

static void wamAdoptNotificationContact(id transcriptVC) {
    if (!wamIsNotificationExtension()) return;
    gWAMChatIsActiveSurface = YES;
    if (gWAMNotifContactName.length) return;
    NSString *nm = wamContactNameFromTranscript(transcriptVC);
    if (!nm.length) nm = getCurrentContactName();
    if (nm.length) {
        gWAMNotifContactName = [nm copy];
        refreshPrefs();
    }
}

%hook CKTranscriptCollectionViewController

- (void)viewDidLoad {
    %orig;
    wamAdoptNotificationContact(self);
    wamApplyBackdrop(self.view, wamHasCustomChatBackdrop(), YES);

    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handleTranscriptPrefsChanged)
        name:kPrefsChangedNotification
        object:nil];
}

- (void)viewWillAppear:(BOOL)animated {
    %orig;
    gWAMChatLeaving = NO;
    wamAdoptNotificationContact(self);
}

// Fade the name-platter shadow out alongside the leave transition (it lives in the stable layout
// container, so it can't slide with the chat on its own). Restore it if the swipe is cancelled.
- (void)viewWillDisappear:(BOOL)animated {
    %orig;
    gWAMChatLeaving = YES;
    UIView *shadow = gWAMNameShadow;
    id<UIViewControllerTransitionCoordinator> tc = self.transitionCoordinator;
    if (shadow && tc) {
        // Fade out alongside the transition; on a cancelled swipe restore it. Never remove — it's reused
        // and reset to alpha 1 when a chat's name lays out again, which avoids removal races on re-entry.
        [tc animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
            shadow.alpha = 0.0;
        } completion:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
            if (ctx.isCancelled) shadow.alpha = 1.0;
        }];
    } else if (shadow) {
        shadow.alpha = 0.0;
    }
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (wamIsNotificationExtension() && !gWAMNotifContactName.length) wamAdoptNotificationContact(self);
}

%new
- (void)handleTranscriptPrefsChanged {
    refreshPrefs();
    wamApplyBackdrop(self.view, wamHasCustomChatBackdrop(), YES);
    UICollectionView *cv = nil;
    @try { cv = [self valueForKey:@"collectionView"]; } @catch (NSException *e) {}
    if (!cv) @try { cv = [self valueForKey:@"_collectionView"]; } @catch (NSException *e) {}
    if (!cv) return;

    for (UICollectionViewCell *cell in [cv.visibleCells copy]) {
        [cell setNeedsLayout];
        [cell layoutIfNeeded];
    }
    [self wamRefreshTranscriptCells:cv];
}

%new
- (void)wamRefreshTranscriptCells:(UICollectionView *)cv {
    NSArray<NSIndexPath *> *visible = cv.indexPathsForVisibleItems;
    if (!visible.count) return;

    NSInteger sections = [cv numberOfSections];
    NSMutableArray<NSIndexPath *> *valid = [NSMutableArray array];
    for (NSIndexPath *p in visible) {
        if (p.section < sections && p.item < [cv numberOfItemsInSection:p.section]) [valid addObject:p];
    }
    if (!valid.count) return;

    [UIView performWithoutAnimation:^{
        @try { [cv reloadItemsAtIndexPaths:valid]; }
        @catch (NSException *e) {}
    }];
}

-(BOOL)shouldUseOpaqueMask {
    return %orig;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            wamApplyBackdrop(self.view, wamHasCustomChatBackdrop(), YES);
            UICollectionView *cv = nil;
            @try { cv = [self valueForKey:@"collectionView"]; } @catch (NSException *e) {}
            if (!cv) @try { cv = [self valueForKey:@"_collectionView"]; } @catch (NSException *e) {}
            if (cv) {
                [self wamRefreshTranscriptCells:cv];
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
    [self wamApplyChatBackdrop];
    if (isTweakEnabled()) [self wamUpdateTranscriptBackground];
}

- (void)didMoveToWindow {
    %orig;
    [self wamApplyChatBackdrop];
    if (isTweakEnabled() && self.window) [self wamUpdateTranscriptBackground];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    %orig;
    [self wamApplyChatBackdrop];
}

%new
- (void)wamApplyChatBackdrop {
    if (!self.window) return;
    if (wamIsInSendAnimationWindow(self)) {
        wamApplyBackdrop(self, NO, NO);
        return;
    }
    wamApplyBackdrop(self, wamHasCustomChatBackdrop(), YES);
}

- (void)layoutSubviews {
    %orig;
    if (isTweakEnabled()) [self wamUpdateTranscriptBackground];
}

%new
- (void)wamUpdateTranscriptBackground {
    static const char kWAMRefBgStateKey = 0;

    UIWindow *win = self.window;
    if (win && [NSStringFromClass([win class]) containsString:@"SendAnimation"]) {
        for (UIView *sub in [self.subviews copy]) {
            if (sub.tag == kWAMOurBgImageTag) [sub removeFromSuperview];
        }
        objc_setAssociatedObject(self, &kWAMRefBgStateKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
        return;
    }

    UIResponder *r = self.nextResponder;
    int rhops = 0;
    while (r && rhops++ < 6) {
        if ([r isKindOfClass:[UIViewController class]] &&
            [NSStringFromClass([r class]) containsString:@"FullScreenBalloon"]) {
            for (UIView *sub in [self.subviews copy]) {
                if (sub.tag == kWAMOurBgImageTag) [sub removeFromSuperview];
            }
            objc_setAssociatedObject(self, &kWAMRefBgStateKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
            return;
        }
        r = r.nextResponder;
    }

    if (!win) return;

    UIImageView *bg = nil;
    for (UIView *sub in self.subviews) {
        if (sub.tag == kWAMOurBgImageTag && [sub isKindOfClass:[UIImageView class]]) {
            bg = (UIImageView *)sub;
            break;
        }
    }

    BOOL ancestorHasBg = NO;
    UIView *p = self.superview;
    int hops = 0;
    while (p && hops++ < 15 && !ancestorHasBg) {
        for (UIView *sub in p.subviews) {
            if (sub.tag == 4321) { ancestorHasBg = YES; break; }
        }
        p = p.superview;
    }

    NSString *path = shouldShowAnyChatBgImage() ? getChatImagePath() : nil;
    if (ancestorHasBg || !path) {
        if (bg) {
            [bg removeFromSuperview];
            objc_setAssociatedObject(self, &kWAMRefBgStateKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
        }
        return;
    }

    CGFloat blurAmount = getEffectiveChatBgBlur();
    NSString *state = [NSString stringWithFormat:@"%@|%.2f", path, blurAmount];
    NSString *cached = objc_getAssociatedObject(self, &kWAMRefBgStateKey);

    if (!bg) {
        bg = [[UIImageView alloc] initWithFrame:self.bounds];
        bg.tag = kWAMOurBgImageTag;
        bg.userInteractionEnabled = NO;
        bg.contentMode = UIViewContentModeScaleAspectFill;
        bg.clipsToBounds = YES;
        bg.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self insertSubview:bg atIndex:0];
        cached = nil;
    }

    if (![state isEqualToString:cached]) {
        UIImage *img = wamChatBackgroundImage(path, blurAmount);
        if (!img) { [bg removeFromSuperview]; return; }
        bg.image = img;
        objc_setAssociatedObject(self, &kWAMRefBgStateKey, state, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }

    bg.frame = self.bounds;
    if (self.subviews.firstObject != bg) [self sendSubviewToBack:bg];
}

%end

static int gWAMChatGeneration = 0;

static int gWAMMaskGeneration = 0;

static void wamRelayoutGradients(UIView *root) {
    if (!root) return;
    Class gv = objc_getClass("CKGradientView");
    if (!gv) return;
    NSMutableArray *stack = [NSMutableArray arrayWithObject:root];
    int guard = 0;
    while (stack.count && guard < 3000) {
        guard++;
        UIView *v = stack.lastObject; [stack removeLastObject];
        if ([v isKindOfClass:gv]) [v setNeedsLayout];
        for (UIView *sv in v.subviews) [stack addObject:sv];
    }
}

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
    [self wamRefreshChatBackgroundWithSelfContext];
    [self wamRevalidateBlurs];
}

%new
- (void)wamRefreshChatBackgroundWithSelfContext {
    NSString *name = nil;
    @try {
        id conv = [self valueForKey:@"_currentConversation"];
        if (conv) {
            id chat = nil;
            @try { chat = [conv valueForKey:@"_chat"]; } @catch (NSException *e) {}
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
        }
    } @catch (NSException *e) {}

    if (!name.length) name = gWAMActiveChatName;

    NSString *prev = gWAMTriggerNameOverride;
    if (name.length) gWAMTriggerNameOverride = name;
    [self updateChatBackground];
    gWAMTriggerNameOverride = prev;
}

%new
-(void)handleChatPrefsChanged {
    refreshPrefs();
    [self wamRefreshChatBackgroundWithSelfContext];

}

// Comprehensive re-theme of this chat against its current conversation — used when a per-contact change
// is applied from the settings sheet while the chat is still on screen. Pins this chat as the active
// per-contact surface so the background, nav-bar platters, name platter and colors all resolve to the
// (possibly just-changed) per-contact values, then forces a layout pass.
%new
-(void)wamRethemeCurrentChat {
    if (!isTweakEnabled()) return;
    reloadPrefs();
    invalidateConvImageCache();
    gWAMChatBgGen++;   // force the chat bg past the mtime-based image cache and state-skip (see gWAMChatBgGen)

    NSString *name = nil;
    @try {
        id conv = [self valueForKey:@"_currentConversation"];
        if (conv) {
            id chat = nil;
            @try { chat = [conv valueForKey:@"_chat"]; } @catch (__unused NSException *e) {}
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
        }
    } @catch (__unused NSException *e) {}
    if (!name.length) name = gWAMActiveChatName;

    // Pin the contact context for the synchronous refresh + notification below.
    NSString *prevTrigger = gWAMTriggerNameOverride;
    NSString *prevNotif = gWAMNotifContactName;
    if (name.length) {
        gWAMCurrentContactName = [name copy];
        gWAMCurrentContactDisplayName = [name copy];
        gWAMActiveChatName = [name copy];
        gWAMCacheSetAt = [NSDate timeIntervalSinceReferenceDate];
        gWAMTriggerNameOverride = name;
        gWAMNotifContactName = name;
    }
    gWAMChatIsActiveSurface = YES;

    // A preset applied from the details sheet leaves the chat off-screen behind it. Swapping .image on
    // the existing (off-screen) bg view doesn't re-display when the chat returns — only a fresh recreate
    // does (which is why leaving and re-entering works). So drop the current bg view + its cached state:
    // if the chat is visible now, rebuild immediately; otherwise viewWillAppear rebuilds it fresh on return.
    for (UIView *sub in [self.view.subviews copy]) if (sub.tag == 4321) [sub removeFromSuperview];
    objc_setAssociatedObject(self.view, &kWAMChatBgStateKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
    if (self.view.window) [self updateChatBackground];
    [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];

    // The cached identity above keeps async layout resolving to this contact after we unpin the
    // notification override; force the pass so platters / name platter / colors re-read immediately.
    NSMutableArray<UIWindow *> *wins = [NSMutableArray array];
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in [UIApplication sharedApplication].connectedScenes)
            if ([scene isKindOfClass:[UIWindowScene class]])
                [wins addObjectsFromArray:((UIWindowScene *)scene).windows];
    }
    for (UIWindow *w in wins) wamForceVisualRefresh(w);

    gWAMTriggerNameOverride = prevTrigger;
    gWAMNotifContactName = prevNotif;
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
-(void)wamPlaceChatBackground:(UIView *)bg {
    wamPlaceBackgroundBelowTranscript(self.view, bg);
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    UIView *bg = nil;
    for (UIView *sub in self.view.subviews) {
        if (sub.tag == 4321) { bg = sub; break; }
    }
    if (bg && self.view.subviews.firstObject != bg) [self wamPlaceChatBackground:bg];
}

%new
-(void)updateChatBackground {

    refreshPrefs();

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
        desiredState = [NSString stringWithFormat:@"img:%@|%.2f|%.0f|%lu", desiredPath ?: @"", blur, mtime, (unsigned long)gWAMChatBgGen];
    }

    NSString *currentState = objc_getAssociatedObject(self.view, &kWAMChatBgStateKey);
    UIView *existingBg = nil;
    for (UIView *sub in self.view.subviews) {
        if (sub.tag == 4321) { existingBg = sub; break; }
    }

    if (!desiredState && !currentState && !existingBg) {
        return;
    }

    if (desiredState && [desiredState isEqualToString:currentState] && existingBg) {
        [self wamPlaceChatBackground:existingBg];
        return;
    }

    if (!desiredState) {
        for (UIView *sub in [self.view.subviews copy]) {
            if (sub.tag == 4321) [sub removeFromSuperview];
        }
        objc_setAssociatedObject(self.view, &kWAMChatBgStateKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
        return;
    }

    if (useColor) {
        for (UIView *sub in [self.view.subviews copy]) {
            if (sub.tag == 4321) [sub removeFromSuperview];
        }
        UIView *colorView = [[UIView alloc] initWithFrame:self.view.bounds];
        colorView.backgroundColor = getChatBackgroundColor();
        colorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        colorView.tag = 4321;
        [self wamPlaceChatBackground:colorView];
        objc_setAssociatedObject(self.view, &kWAMChatBgStateKey, desiredState, OBJC_ASSOCIATION_COPY_NONATOMIC);
        return;
    }

    UIImage *chatBgImage = wamChatBackgroundImage(desiredPath, getEffectiveChatBgBlur());
    if (!chatBgImage) return;

    if ([existingBg isKindOfClass:[UIImageView class]]) {
        ((UIImageView *)existingBg).image = chatBgImage;
        [self wamPlaceChatBackground:existingBg];
        objc_setAssociatedObject(self.view, &kWAMChatBgStateKey, desiredState, OBJC_ASSOCIATION_COPY_NONATOMIC);
        return;
    }

    for (UIView *sub in [self.view.subviews copy]) {
        if (sub.tag == 4321) [sub removeFromSuperview];
    }

    UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
    imageView.image = chatBgImage;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    imageView.tag = 4321;
    [self wamPlaceChatBackground:imageView];
    objc_setAssociatedObject(self.view, &kWAMChatBgStateKey, desiredState, OBJC_ASSOCIATION_COPY_NONATOMIC);
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
            [self wamRefreshChatBackgroundWithSelfContext];
        }
    }
}

-(void)viewWillAppear:(BOOL)animated {
    %orig;
    if (isiOS15()) updateDarkModeFromTraits(self.traitCollection);
    if (isTweakEnabled() && wamIsPreviewContext(self)) {
        objc_setAssociatedObject(self, @selector(wamIsPreviewContext:), @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        gWAMPreviewActive = YES;
    }
    gWAMChatIsActiveSurface = YES;
    // Drop any cached bg state so the background is rebuilt fresh on appear (covers returning from the
    // details sheet after a per-contact preset was applied to the off-screen chat). The notification
    // below drives handleChatPrefsChanged -> updateChatBackground with the correct contact context.
    objc_setAssociatedObject(self.view, &kWAMChatBgStateKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    %orig;
    if (!isTweakEnabled()) return;
    // Rotation/split-view transition: the nav-bar overlays (name platter, avatar & name shadows, call
    // button platter) are laid out mid-transition against unsettled frames and left stale (shadows land
    // far-left, platters mis-sized). Hide the free-floating name shadow during the animation so it doesn't
    // streak, then force a settled re-layout once the transition finishes so everything recomputes.
    gWAMNameShadow.alpha = 0.0;
    objc_setAssociatedObject(self.view, &kWAMChatBgStateKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
    [coordinator animateAlongsideTransition:nil completion:^(__unused id<UIViewControllerTransitionCoordinatorContext> ctx) {
        wamForceLayoutAllWindows();
        // The chat title/avatar area doesn't re-lay-out on rotation, so force its overlays to recompute
        // against the settled post-rotation frames.
        wamRedriveChatOverlays();
        [self updateChatBackground];
        [[NSNotificationCenter defaultCenter] postNotificationName:kPrefsChangedNotification object:nil];
    }];
}

- (void)setCurrentConversation:(id)conversation {
    gWAMChatGeneration++;
    %orig;
    [self wamRevalidateBlurs];
    gWAMActiveChatName = nil;
    [self wamHandleConversationChanged:conversation];

}

- (void)_setCurrentConversation:(id)conversation {
    gWAMChatGeneration++;
    %orig;
    [self wamRevalidateBlurs];
    gWAMActiveChatName = nil;
    [self wamHandleConversationChanged:conversation];
}

%new
- (void)wamRevalidateBlurs {
    if (!isTweakEnabled() || !self.isViewLoaded) return;
    gWAMMaskGeneration++;
    wamRelayoutGradients(self.view);
    __weak CKMessagesController *weakSelf = self;
    for (CGFloat delay = 0.15; delay <= 0.6; delay += 0.15) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            if (weakSelf.isViewLoaded) wamRelayoutGradients(weakSelf.view);
        });
    }
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
    if (!name.length) {
        gWAMCurrentContactName = nil;
        gWAMCurrentContactDisplayName = nil;
        gWAMActiveChatName = nil;
        [self updateChatBackground];
        return;
    }
    if (cid.length) wamReconcileAliasForChat(cid, name);
    gWAMCurrentContactName = [name copy];
    gWAMCurrentContactDisplayName = [name copy];
    gWAMActiveChatName = [name copy];
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
    if (objc_getAssociatedObject(self, @selector(wamIsPreviewContext:))) {
        objc_setAssociatedObject(self, @selector(wamIsPreviewContext:), nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        gWAMPreviewActive = NO;
    }
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
    [self wamRevalidateBlurs];
}

%new
- (void)wamRetryBgRefresh:(int)attempt {
    if (!isTweakEnabled()) return;
    UINavigationController *nav = self.navigationController;
    if (nav && ![nav.viewControllers containsObject:self]) return;
    [self wamRefreshChatBackgroundWithSelfContext];
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

static UIVisualEffectView *wamMakeBlurView(CGRect frame);
static void wamStripEffectTint(UIVisualEffectView *v);

static UIImage *gWAMBalloonShape = nil;
static int gWAMSentBlurCreates = 0;

static char kWAMBlurViewKey;

static char kWAMIsOurBlurKey;

static char kWAMSentBlurKey;
static char kWAMSentTintKey;
static char kWAMSentMaskKey;
static char kWAMSentMaskSizeKey;
static char kWAMSentBlurConvKey;

static char kWAMLinkBlurKey;
static char kWAMTypingBlurKey;

static int wamGradientBalloonColor(UIView *g) {
    UIView *p = g.superview; int lvl = 0;
    while (p && lvl < 6) {
        if ([p isKindOfClass:objc_getClass("CKColoredBalloonView")])
            return (int)((CKColoredBalloonView *)p).color;
        p = p.superview; lvl++;
    }
    return -99;
}

static BOOL wamSentBlurIsGood(UIView *balloon) {
    if (!balloon) return NO;
    UIView *b = objc_getAssociatedObject(balloon, &kWAMSentBlurKey);
    if (![b isKindOfClass:[UIView class]] || b.hidden || b.superview != balloon) return NO;
    if ([objc_getAssociatedObject(balloon, &kWAMSentBlurConvKey) intValue] != gWAMChatGeneration) return NO;
    return YES;
}

static UIBezierPath *wamBubbleMaskPath(CGSize size, BOOL tailRight, BOOL hasTail) {
    CGFloat w = size.width, h = size.height;
    if (!hasTail) {
        CGFloat r = MIN(17.0, h / 2.0);
        CGFloat tail = 4.0;
        CGRect body = tailRight ? CGRectMake(0, 0, w - tail, h) : CGRectMake(tail, 0, w - tail, h);
        return [UIBezierPath bezierPathWithRoundedRect:body cornerRadius:r];
    }
    UIBezierPath *p = [UIBezierPath bezierPath];
    [p moveToPoint:CGPointMake(22, h)];
    [p addLineToPoint:CGPointMake(w - 17, h)];
    [p addCurveToPoint:CGPointMake(w, h - 17) controlPoint1:CGPointMake(w - 7.61, h)  controlPoint2:CGPointMake(w, h - 7.61)];
    [p addLineToPoint:CGPointMake(w, 17)];
    [p addCurveToPoint:CGPointMake(w - 17, 0)  controlPoint1:CGPointMake(w, 7.61)      controlPoint2:CGPointMake(w - 7.61, 0)];
    [p addLineToPoint:CGPointMake(21, 0)];
    [p addCurveToPoint:CGPointMake(4, 17)      controlPoint1:CGPointMake(11.61, 0)     controlPoint2:CGPointMake(4, 7.61)];
    [p addLineToPoint:CGPointMake(4, h - 11)];
    [p addCurveToPoint:CGPointMake(0, h)       controlPoint1:CGPointMake(4, h - 1)     controlPoint2:CGPointMake(0, h)];
    [p addLineToPoint:CGPointMake(-0.05, h - 0.01)];
    [p addCurveToPoint:CGPointMake(11.04, h - 4.04) controlPoint1:CGPointMake(4.07, h + 0.43) controlPoint2:CGPointMake(8.16, h - 1.06)];
    [p addCurveToPoint:CGPointMake(22, h)      controlPoint1:CGPointMake(16, h)        controlPoint2:CGPointMake(19, h)];
    [p closePath];
    if (tailRight) {
        [p applyTransform:CGAffineTransformMakeScale(-1, 1)];
        [p applyTransform:CGAffineTransformMakeTranslation(w, 0)];
    }
    return p;
}

static void wamHealBlursInView(UIView *root) {
    if (!root || !isBlurBubblesEnabled()) return;
    Class gvCls = objc_getClass("CKGradientView");
    if (!gvCls) return;
    NSMutableArray *stack = [NSMutableArray arrayWithObject:root];
    int guard = 0;
    while (stack.count && guard < 4000) {
        guard++;
        UIView *v = stack.lastObject; [stack removeLastObject];
        if ([v isKindOfClass:gvCls]) {
            int col = wamGradientBalloonColor(v);
            BOOL isLink = wamIsInsideHyperlinkBalloon(v, 6);
            if ((col == 1 || col == 0 || (isLink && col == -1)) && !wamSentBlurIsGood(v.superview)) {
                [v setNeedsLayout];
            }
        }
        for (UIView *sv in v.subviews) [stack addObject:sv];
    }
}

static void wamRemoveSentBlur(UIView *g) {
    UIView *balloon = g.superview;
    if (balloon) {
        UIView *blur = objc_getAssociatedObject(balloon, &kWAMSentBlurKey);
        if (blur) [blur removeFromSuperview];
        objc_setAssociatedObject(balloon, &kWAMSentBlurKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(balloon, &kWAMSentTintKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(balloon, &kWAMSentMaskKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(balloon, &kWAMSentMaskSizeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (g.layer.opacity < 1.0) {
        g.layer.opacity = 1.0;
        [g setNeedsLayout];
        [g setNeedsDisplay];
    }
}

static void wamClearForeignBlur(UIView *g) {
    UIView *balloon = g.superview;
    if (!balloon) return;
    for (UIView *sv in [balloon.subviews copy]) {
        if ([sv isKindOfClass:[UIVisualEffectView class]] &&
            objc_getAssociatedObject(sv, &kWAMIsOurBlurKey)) {
            [sv removeFromSuperview];
        }
    }
    objc_setAssociatedObject(balloon, &kWAMBlurViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(balloon, &kWAMSentBlurKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(balloon, &kWAMSentTintKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(balloon, &kWAMSentMaskKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(balloon, &kWAMSentMaskSizeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%hook CKGradientView

%new
- (void)wamApplySentBlur:(int)color {
    UIView *balloon = self.superview;
    if (!balloon) return;
    CGRect b = self.bounds;
    if (b.size.width <= 5 || b.size.height <= 5) return;

    UIVisualEffectView *blur = objc_getAssociatedObject(balloon, &kWAMSentBlurKey);
    if (!blur) {
        blur = wamMakeBlurView(self.frame);
        blur.userInteractionEnabled = NO;
        blur.hidden = YES;
        objc_setAssociatedObject(balloon, &kWAMSentBlurKey, blur, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        CALayer *tint = [CALayer layer];
        [blur.contentView.layer addSublayer:tint];
        objc_setAssociatedObject(balloon, &kWAMSentTintKey, tint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        gWAMSentBlurCreates++;
    }
    [balloon insertSubview:blur belowSubview:self];

    UIView *rblur = objc_getAssociatedObject(balloon, &kWAMBlurViewKey);
    if (rblur && rblur != blur) {
        [rblur removeFromSuperview];
        objc_setAssociatedObject(balloon, &kWAMBlurViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    for (UIView *sv in [balloon.subviews copy]) {
        if (sv != blur && [sv isKindOfClass:[UIVisualEffectView class]]) [sv removeFromSuperview];
    }

    wamStripEffectTint(blur);
    UIColor *tc = (color == 0)  ? getSMSSentBubbleColor()
                : (color == -1) ? getReceivedBubbleColor()
                                : getSentBubbleColor();

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    blur.frame = self.frame;

    CALayer *tint = objc_getAssociatedObject(balloon, &kWAMSentTintKey);
    tint.frame = blur.bounds;
    tint.backgroundColor = tc.CGColor;

    CAShapeLayer *mask = objc_getAssociatedObject(balloon, &kWAMSentMaskKey);
    if (![mask isKindOfClass:[CAShapeLayer class]]) {
        mask = [CAShapeLayer layer];
        objc_setAssociatedObject(balloon, &kWAMSentMaskKey, mask, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    mask.frame = blur.bounds;
    BOOL hasTail = YES;
    @try { id v = [balloon valueForKey:@"_hasTail"]; if (v) hasTail = [v boolValue]; } @catch (__unused NSException *e) {}
    mask.path = wamBubbleMaskPath(b.size, color != -1, hasTail).CGPath;
    blur.layer.mask = mask;
    [CATransaction commit];

    self.layer.opacity = 1.0;
    objc_setAssociatedObject(balloon, &kWAMSentBlurConvKey, @(gWAMChatGeneration),
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    blur.hidden = NO;
    [self setColors:@[UIColor.clearColor, UIColor.clearColor]];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    if (self.frame.size.width <= 0 || self.frame.size.height <= 0) return;

    BOOL isReaction = wamIsInsideReactionContext(self, 8);
    if (isReaction) {
        if (isBlurBubblesEnabled()) { self.hidden = YES; return; }
        UIColor *reactionColor = getChatAdvancedTintColorForView(@"advancedReactionBalloonColor", @"advancedReactionBalloonColorDark", nil, self);
        if (reactionColor) {
            self.hidden = NO;
            [self setColors:@[reactionColor, reactionColor]];
        } else {
            self.hidden = YES;
        }
        return;
    }

    int col = wamGradientBalloonColor(self);

    BOOL isLink = wamIsInsideHyperlinkBalloon(self, 6);
    if (isBlurBubblesEnabled() && (col == 1 || col == 0 || (isLink && col == -1))) {
        [self wamApplySentBlur:col];
        return;
    }
    wamRemoveSentBlur(self);
    if (!isBlurBubblesEnabled()) wamClearForeignBlur(self);

    if (!isCustomBubbleColorsEnabled()) return;

    UIColor *bubbleColor = (col == 0) ? getSMSSentBubbleColor()
                         : (col == -1) ? getReceivedBubbleColor()
                         : getSentBubbleColor();
    [self setColors:@[bubbleColor, bubbleColor]];
}

- (void)setColors:(NSArray *)colors {
    if (!isTweakEnabled()) { %orig; return; }

    BOOL isReaction = wamIsInsideReactionContext(self, 8);
    if (isReaction) {
        if (isBlurBubblesEnabled()) { self.hidden = YES; return; }
        UIColor *reactionColor = getChatAdvancedTintColorForView(@"advancedReactionBalloonColor", @"advancedReactionBalloonColorDark", nil, self);
        if (reactionColor) {
            self.hidden = NO;
            %orig(@[reactionColor, reactionColor]);
        } else {
            self.hidden = YES;
        }
        return;
    }

    int col = wamGradientBalloonColor(self);

    BOOL isLink = wamIsInsideHyperlinkBalloon(self, 6);
    if (isBlurBubblesEnabled() && (col == 1 || col == 0 || (isLink && col == -1))) {
        UIColor *sc = (col == 0)  ? getSMSSentBubbleColor()
                    : (col == -1) ? getReceivedBubbleColor()
                                  : getSentBubbleColor();
        UIView *balloon = self.superview;
        BOOL blurShowing = wamSentBlurIsGood(balloon);
        if (blurShowing) {
            %orig(@[UIColor.clearColor, UIColor.clearColor]);
            CALayer *tint = objc_getAssociatedObject(balloon, &kWAMSentTintKey);
            if (tint) tint.backgroundColor = sc.CGColor;
        } else {
            %orig(@[sc, sc]);
        }
        return;
    }

    if (self.superview && objc_getAssociatedObject(self.superview, &kWAMSentBlurKey)) {
        wamRemoveSentBlur(self);
    }
    if (!isBlurBubblesEnabled()) wamClearForeignBlur(self);

    if (!isCustomBubbleColorsEnabled()) { %orig; return; }

    UIColor *bubbleColor = (col == 0) ? getSMSSentBubbleColor()
                         : (col == -1) ? getReceivedBubbleColor()
                         : getSentBubbleColor();
    %orig(@[bubbleColor, bubbleColor]);
}

%end

static UIImage *wamTintBalloonImage(UIImage *image, UIColor *targetColor, BOOL applyReceivedInsets) {
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
    return tintedImage;
}

static UIImage *wamRestoreBalloonAlpha(UIImage *image) {
    if (!image) return image;
    if (image.capInsets.left < 0.5 && image.capInsets.top < 0.5) return image;

    CGImageRef cg = image.CGImage;
    if (!cg) return image;
    size_t w = CGImageGetWidth(cg), h = CGImageGetHeight(cg);
    if (w < 2 || h < 2 || w * h > 1024 * 1024) return image;

    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    unsigned char *buf = calloc(w * h, 4);
    if (!buf) { CGColorSpaceRelease(cs); return image; }
    CGContextRef ctx = CGBitmapContextCreate(buf, w, h, 8, w * 4, cs,
                                             kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    if (!ctx) { free(buf); CGColorSpaceRelease(cs); return image; }
    CGContextDrawImage(ctx, CGRectMake(0, 0, w, h), cg);

    for (size_t i = 0; i < w * h; i++) {
        if (buf[i * 4 + 3] < 250) {
            CGContextRelease(ctx); CGColorSpaceRelease(cs); free(buf);
            return image;
        }
    }

    unsigned char *c0 = buf;
    unsigned char *c1 = buf + (w - 1) * 4;
    unsigned char *c2 = buf + (size_t)(h - 1) * w * 4;
    unsigned char *c3 = buf + ((size_t)(h - 1) * w + (w - 1)) * 4;
    int bgR = (c0[0] + c1[0] + c2[0] + c3[0]) / 4;
    int bgG = (c0[1] + c1[1] + c2[1] + c3[1]) / 4;
    int bgB = (c0[2] + c1[2] + c2[2] + c3[2]) / 4;
    int bgLum = (77 * bgR + 151 * bgG + 28 * bgB) >> 8;

    int maxDist = 0;
    for (size_t i = 0; i < w * h; i++) {
        unsigned char *p = buf + i * 4;
        int lum = (77 * p[0] + 151 * p[1] + 28 * p[2]) >> 8;
        int d = abs(lum - bgLum);
        if (d > maxDist) maxDist = d;
    }
    if (maxDist < 8) {
        CGContextRelease(ctx); CGColorSpaceRelease(cs); free(buf);
        return image;
    }

    for (size_t i = 0; i < w * h; i++) {
        unsigned char *p = buf + i * 4;
        int lum = (77 * p[0] + 151 * p[1] + 28 * p[2]) >> 8;
        int a = (abs(lum - bgLum) * 255) / maxDist;
        if (a > 255) a = 255;
        int inv = 255 - a;
        int r = p[0] - (bgR * inv) / 255; p[0] = r < 0 ? 0 : r;
        int g = p[1] - (bgG * inv) / 255; p[1] = g < 0 ? 0 : g;
        int b = p[2] - (bgB * inv) / 255; p[2] = b < 0 ? 0 : b;
        p[3] = (unsigned char)a;
    }

    CGImageRef outCG = CGBitmapContextCreateImage(ctx);
    UIImage *out = [UIImage imageWithCGImage:outCG scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(outCG);
    CGContextRelease(ctx);
    CGColorSpaceRelease(cs);
    free(buf);

    out = [out resizableImageWithCapInsets:image.capInsets resizingMode:image.resizingMode];
    out = [out imageWithAlignmentRectInsets:image.alignmentRectInsets];
    out = [out imageWithRenderingMode:image.renderingMode];
    return out;
}

static char kWAMBlurTintKey;
static char kWAMBlurMaskKey;
static char kWAMBlurShapeKey;
static char kWAMBlurTintColorKey;
static char kWAMBlurMirrorKey;
static char kWAMBlurMaskSizeKey;
static char kWAMBlurMaskGenKey;

static char kWAMBlurTintKey;
static char kWAMBlurMaskKey;
static char kWAMBlurShapeKey;
static char kWAMBlurTintColorKey;
static char kWAMBlurMirrorKey;
static char kWAMBlurMaskSizeKey;
static char kWAMBlurMaskGenKey;

static UIImage *wamClearImageLike(UIImage *image, BOOL applyReceivedInsets) {
    UIImageRenderingMode originalMode = image.renderingMode;
    UIEdgeInsets capInsets = image.capInsets;
    UIImageResizingMode resizingMode = image.resizingMode;
    UIEdgeInsets alignmentInsets = image.alignmentRectInsets;
    CGFloat scale = image.scale;

    UIGraphicsBeginImageContextWithOptions(image.size, NO, scale);
    UIImage *out = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();

    if (applyReceivedInsets) {
        alignmentInsets.left += 6.0;
        alignmentInsets.right -= 8.0;
    }
    out = [out resizableImageWithCapInsets:capInsets resizingMode:resizingMode];
    out = [out imageWithAlignmentRectInsets:alignmentInsets];
    out = [out imageWithRenderingMode:originalMode];
    return out;
}

static void wamStripEffectTint(UIVisualEffectView *v) {
    Class tintCls = NSClassFromString(@"_UIVisualEffectSubview");
    if (!tintCls) return;
    for (UIView *sub in [v.subviews copy]) {
        if ([sub isMemberOfClass:tintCls]) [sub removeFromSuperview];
    }
}

static UIVisualEffectView *wamMakeBlurView(CGRect frame) {
    UIBlurEffect *eff = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    UIVisualEffectView *vev = [[UIVisualEffectView alloc] initWithEffect:eff];
    vev.frame = frame;
    objc_setAssociatedObject(vev, &kWAMIsOurBlurKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    return vev;
}

static void wamStripOurBlurs(UIView *balloon) {
    if (!balloon) return;
    for (UIView *sv in [balloon.subviews copy]) {
        if ([sv isKindOfClass:[UIVisualEffectView class]] &&
            objc_getAssociatedObject(sv, &kWAMIsOurBlurKey)) {
            [sv removeFromSuperview];
        }
    }
    objc_setAssociatedObject(balloon, &kWAMBlurViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(balloon, &kWAMSentBlurKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(balloon, &kWAMSentTintKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(balloon, &kWAMSentMaskKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(balloon, &kWAMSentMaskSizeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    for (UIView *sv in balloon.subviews) {
        if ([sv isKindOfClass:objc_getClass("CKGradientView")]) {
            sv.layer.opacity = 1.0;
            [sv setNeedsLayout];
            [sv setNeedsDisplay];
        }
    }
}

%hook CKBalloonImageView

%new
- (void)wamApplyReceivedBlurWithImage:(UIImage *)shape tintColor:(UIColor *)tintColor mirror:(BOOL)mirror {
    UIVisualEffectView *blur = objc_getAssociatedObject(self, &kWAMBlurViewKey);
    if (!blur) {
        blur = wamMakeBlurView(self.bounds);
        blur.userInteractionEnabled = NO;
        [self insertSubview:blur atIndex:0];
        objc_setAssociatedObject(self, &kWAMBlurViewKey, blur, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

        CALayer *tint = [CALayer layer];
        [blur.contentView.layer addSublayer:tint];
        objc_setAssociatedObject(self, &kWAMBlurTintKey, tint, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    objc_setAssociatedObject(self, &kWAMBlurShapeKey, shape, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kWAMBlurTintColorKey, tintColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kWAMBlurMirrorKey, @(mirror), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kWAMBlurMaskSizeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    UIView *sblur = objc_getAssociatedObject(self, &kWAMSentBlurKey);
    if (sblur && sblur != blur) {
        [sblur removeFromSuperview];
        objc_setAssociatedObject(self, &kWAMSentBlurKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    [self wamLayoutBlurBubble];
}

%new
- (void)wamLayoutBlurBubble {
    UIVisualEffectView *blur = objc_getAssociatedObject(self, &kWAMBlurViewKey);
    if (!blur) return;
    CGRect b = self.bounds;
    if (b.size.width <= 0 || b.size.height <= 0) return;

    wamStripEffectTint(blur);

    UIColor *tintColor = objc_getAssociatedObject(self, &kWAMBlurTintColorKey) ?: getReceivedBubbleColor();
    UIImage *shape = objc_getAssociatedObject(self, &kWAMBlurShapeKey);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    blur.frame = b;

    CALayer *tint = objc_getAssociatedObject(self, &kWAMBlurTintKey);
    tint.frame = b;
    tint.backgroundColor = tintColor.CGColor;

    BOOL mirror = [objc_getAssociatedObject(self, &kWAMBlurMirrorKey) boolValue];
    BOOL isReaction = wamIsReactionBalloonAncestor(self, 6);

    if (!isReaction) {
        CAShapeLayer *mask = objc_getAssociatedObject(self, &kWAMBlurMaskKey);
        if (![mask isKindOfClass:[CAShapeLayer class]]) {
            mask = [CAShapeLayer layer];
            objc_setAssociatedObject(self, &kWAMBlurMaskKey, mask, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        BOOL hasTail = YES;
        UIView *anc = self.superview; int hops = 0;
        while (anc && hops++ < 8) {
            @try { id v = [anc valueForKey:@"_hasTail"]; if (v) { hasTail = [v boolValue]; break; } }
            @catch (__unused NSException *e) {}
            anc = anc.superview;
        }
        mask.frame = b;
        mask.path = wamBubbleMaskPath(b.size, mirror, hasTail).CGPath;
        blur.layer.mask = mask;
        [CATransaction commit];
        return;
    }

    CALayer *mask = objc_getAssociatedObject(self, &kWAMBlurMaskKey);
    if (![mask isKindOfClass:[CALayer class]] || [mask isKindOfClass:[CAShapeLayer class]]) {
        mask = [CALayer layer];
        objc_setAssociatedObject(self, &kWAMBlurMaskKey, mask, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &kWAMBlurMaskSizeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    NSValue *cachedSize = objc_getAssociatedObject(self, &kWAMBlurMaskSizeKey);
    int cachedGen = [objc_getAssociatedObject(self, &kWAMBlurMaskGenKey) intValue];
    BOOL sizeChanged = !cachedSize || !CGSizeEqualToSize([cachedSize CGSizeValue], b.size);
    BOOL genChanged = (cachedGen != gWAMMaskGeneration);
    if (shape && (sizeChanged || genChanged || !mask.contents)) {
        UIImage *stretch = [shape resizableImageWithCapInsets:shape.capInsets
                                                 resizingMode:UIImageResizingModeStretch];
        UIGraphicsBeginImageContextWithOptions(b.size, NO, 0);
        CGContextRef ctx = UIGraphicsGetCurrentContext();
        if (mirror) {
            CGContextTranslateCTM(ctx, b.size.width, 0);
            CGContextScaleCTM(ctx, -1, 1);
        }
        [stretch drawInRect:CGRectMake(0, 0, b.size.width, b.size.height)];
        UIImage *rendered = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        mask.contents = (id)rendered.CGImage;
        objc_setAssociatedObject(self, &kWAMBlurMaskSizeKey,
                                 [NSValue valueWithCGSize:b.size], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(self, &kWAMBlurMaskGenKey,
                                 @(gWAMMaskGeneration), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    mask.frame = b;
    blur.layer.mask = mask;

    [CATransaction commit];
}

%new
- (void)wamRemoveReceivedBlur {
    UIView *blur = objc_getAssociatedObject(self, &kWAMBlurViewKey);
    if (blur) [blur removeFromSuperview];
    objc_setAssociatedObject(self, &kWAMBlurViewKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kWAMBlurTintKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kWAMBlurMaskKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kWAMBlurShapeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kWAMBlurTintColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kWAMBlurMirrorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(self, &kWAMBlurMaskSizeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)setImage:(UIImage *)image {
    if (!isTweakEnabled() || !image) { %orig; return; }

    image = wamRestoreBalloonAlpha(image);

    BOOL isInsideReaction = wamIsReactionBalloonAncestor(self, 6);
    BOOL hasReactionBalloonOverride = isAdvancedValueExplicitlySet(@"advancedReactionBalloonColor", @"advancedReactionBalloonColorDark");
    BOOL blurEnabled = isBlurBubblesEnabled();

    if (!isCustomBubbleColorsEnabled() && !blurEnabled && !(isInsideReaction && hasReactionBalloonOverride)) {
        [self wamRemoveReceivedBlur];
        %orig; return;
    }

    if ([self isKindOfClass:%c(CKColoredBalloonView)]) {
        CKColoredBalloonView *coloredSelf = (CKColoredBalloonView *)self;

        if (blurEnabled) {
            if (isInsideReaction) {
                UIColor *rc = hasReactionBalloonOverride
                    ? getChatAdvancedTintColorForView(@"advancedReactionBalloonColor", @"advancedReactionBalloonColorDark", nil, self)
                    : getReceivedBubbleColor();
                [self wamApplyReceivedBlurWithImage:image tintColor:rc mirror:NO];
                %orig(wamClearImageLike(image, NO));
                return;
            }
            if (coloredSelf.color == -1) {
                if (!gWAMBalloonShape && image.capInsets.left > 0.5) gWAMBalloonShape = image;
                [self wamApplyReceivedBlurWithImage:image tintColor:getReceivedBubbleColor() mirror:NO];
                %orig(wamClearImageLike(image, YES));
                return;
            }
        }

        [self wamRemoveReceivedBlur];

        UIColor *targetColor = nil;
        BOOL applyReceivedInsets = NO;
        if (isInsideReaction && hasReactionBalloonOverride) {
            targetColor = getChatAdvancedTintColorForView(@"advancedReactionBalloonColor", @"advancedReactionBalloonColorDark", nil, self);
        } else if (coloredSelf.color == -1) {
            targetColor = getReceivedBubbleColor();
            applyReceivedInsets = YES;
        } else if (coloredSelf.color == 1) {
            targetColor = getSentBubbleColor();
        } else if (coloredSelf.color == 0) {
            targetColor = getSMSSentBubbleColor();
        }

        BOOL wantTint = (isCustomBubbleColorsEnabled()) || (isInsideReaction && hasReactionBalloonOverride);
        if (targetColor && wantTint) {
            %orig(wamTintBalloonImage(image, targetColor, applyReceivedInsets));
            return;
        }
    }
    %orig;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    if (!isBlurBubblesEnabled()) {
        BOOL hadOurBlur = NO;
        for (UIView *sv in self.subviews) {
            if ([sv isKindOfClass:[UIVisualEffectView class]] &&
                objc_getAssociatedObject(sv, &kWAMIsOurBlurKey)) { hadOurBlur = YES; break; }
        }
        if (hadOurBlur || objc_getAssociatedObject(self, &kWAMBlurViewKey) ||
            objc_getAssociatedObject(self, &kWAMSentBlurKey)) {
            wamStripOurBlurs(self);
        }
        return;
    }

    UIView *staleSent = objc_getAssociatedObject(self, &kWAMSentBlurKey);
    if (staleSent && [objc_getAssociatedObject(self, &kWAMSentBlurConvKey) intValue] != gWAMChatGeneration) {
        staleSent.hidden = YES;
        objc_setAssociatedObject(self, &kWAMSentMaskSizeKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        for (UIView *sv in self.subviews)
            if ([sv isKindOfClass:objc_getClass("CKGradientView")]) [sv setNeedsLayout];
    }

    if (objc_getAssociatedObject(self, &kWAMBlurViewKey)) {
        [self wamLayoutBlurBubble];
    }
}

%end

static BOOL wamReplyPreviewIsFromMe(UIView *v) {
    if (!v) return NO;
    Ivar iv = class_getInstanceVariable([v class], "_isFromMe");
    if (!iv) return NO;
    return *((char *)(__bridge void *)v + ivar_getOffset(iv)) != 0;
}

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
    Class replyCls = objc_getClass("CKTextReplyPreviewBalloonView");
    while (parent && levels < 10) {
        if (replyCls && [parent isKindOfClass:replyCls]) {
            return wamReplyPreviewIsFromMe(parent) ? getSentTextColor() : getReceivedTextColor();
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

static CGImageRef wamTintTemplateImage(CGImageRef src, UIColor *color) CF_RETURNS_RETAINED;
static CGImageRef wamTintTemplateImage(CGImageRef src, UIColor *color) {
    size_t w = CGImageGetWidth(src), h = CGImageGetHeight(src);
    if (w == 0 || h == 0 || !color) return NULL;
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGContextRef ctx = CGBitmapContextCreate(NULL, w, h, 8, 0, cs,
                                             kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
    CGColorSpaceRelease(cs);
    if (!ctx) return NULL;
    CGRect r = CGRectMake(0, 0, w, h);
    CGContextDrawImage(ctx, r, src);
    CGContextSetBlendMode(ctx, kCGBlendModeSourceIn);
    CGContextSetFillColorWithColor(ctx, color.CGColor);
    CGContextFillRect(ctx, r);
    CGImageRef out = CGBitmapContextCreateImage(ctx);
    CGContextRelease(ctx);
    return out;
}

%hook CALayer

- (void)setContents:(id)contents {
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !contents) { %orig; return; }
    Class replyCls = objc_getClass("CKTextReplyPreviewBalloonView");
    id dg = self.delegate;
    if (!replyCls || ![dg isKindOfClass:replyCls] ||
        CFGetTypeID((__bridge CFTypeRef)contents) != CGImageGetTypeID()) { %orig; return; }

    static const char kWAMReTintingKey = 0;
    if ([objc_getAssociatedObject(self, &kWAMReTintingKey) boolValue]) { %orig; return; }

    UIColor *c = wamReplyPreviewIsFromMe((UIView *)dg) ? getSentBubbleColor() : getReceivedBubbleColor();
    if (!c) { %orig; return; }
    CGImageRef tinted = wamTintTemplateImage((__bridge CGImageRef)contents, c);
    if (!tinted) { %orig; return; }
    objc_setAssociatedObject(self, &kWAMReTintingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    %orig((__bridge id)tinted);
    objc_setAssociatedObject(self, &kWAMReTintingKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    CGImageRelease(tinted);
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
            CGRect expandedFrame = effectView.frame;
            expandedFrame.origin.y -= kWAMBarExpansion;
            expandedFrame.size.height += kWAMBarExpansion;
            if (lastExpandedH) {
                effectView.frame = expandedFrame;
            } else {
                [CATransaction begin];
                [CATransaction setDisableActions:YES];
                effectView.frame = expandedFrame;
                [CATransaction commit];
            }
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

- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig;
    if (!isTweakEnabled()) return;
    if (newWindow && gWAMCurrentContactName.length) {
        gWAMChatIsActiveSurface = YES;
        [self applyInputFieldCustomization];
    }
}

- (void)layoutSubviews {
    %orig;
    if (isTweakEnabled()) {
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
            [self applyInputFieldCustomization];
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
        [self applyInputFieldCustomization];
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
    [self applyInputFieldCustomization];
}

%new
- (void)applyInputFieldCustomization {
    static const char kWAMInputFieldOrigBgKey = 0;
    static const char kWAMPlaceholderOrigColorKey = 0;
    static const char kWAMPlaceholderOrigTextKey = 0;
    static const char kWAMInputTextOrigColorKey = 0;

    UIView *inputFieldContainer = nil;
    UITextView *textView = [self findTextView:self];
    if (textView) inputFieldContainer = textView.superview;
    if (!inputFieldContainer) inputFieldContainer = [self findRoundedView:self];
    if (!inputFieldContainer) inputFieldContainer = [self findViewByClassName:self];
    if (!inputFieldContainer) {
        return;
    }

    BOOL customEnabled = isInputFieldCustomizationEnabled();

    NSArray *subviewsCopy = [inputFieldContainer.subviews copy];
    for (UIView *subview in subviewsCopy) {
        if ([subview isKindOfClass:[UIVisualEffectView class]] &&
            objc_getAssociatedObject(subview, &kWAMInputFieldBlurKey)) {
            [subview removeFromSuperview];
        }
    }

    if (customEnabled) {
        if (!objc_getAssociatedObject(inputFieldContainer, &kWAMInputFieldOrigBgKey)) {
            objc_setAssociatedObject(inputFieldContainer, &kWAMInputFieldOrigBgKey,
                inputFieldContainer.backgroundColor ?: (id)[NSNull null],
                OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
    } else {
        id orig = objc_getAssociatedObject(inputFieldContainer, &kWAMInputFieldOrigBgKey);
        if (orig) {
            inputFieldContainer.backgroundColor = (orig == [NSNull null]) ? nil : (UIColor *)orig;
            objc_setAssociatedObject(inputFieldContainer, &kWAMInputFieldOrigBgKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }

    [inputFieldContainer setNeedsLayout];
    [inputFieldContainer layoutIfNeeded];

    if (textView && [textView isKindOfClass:%c(CKMessageEntryRichTextView)]) {
        if (isMessageInputTextEnabled()) {
            if (!objc_getAssociatedObject(textView, &kWAMInputTextOrigColorKey)) {
                objc_setAssociatedObject(textView, &kWAMInputTextOrigColorKey,
                    textView.textColor ?: (id)[NSNull null],
                    OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            applyInputTextColor(textView, getMessageInputTextColor());
        } else {
            id origColor = objc_getAssociatedObject(textView, &kWAMInputTextOrigColorKey);
            if (origColor) {
                UIColor *target = (origColor == [NSNull null]) ? nil : (UIColor *)origColor;
                textView.textColor = target;
                if (textView.text.length > 0 && isTextViewSafeForColorWrite(textView)) {
                    UIColor *fillColor = target ?: [UIColor labelColor];
                    NSMutableAttributedString *mut = textView.attributedText
                        ? [textView.attributedText mutableCopy]
                        : [[NSMutableAttributedString alloc] initWithString:textView.text];
                    NSRange full = NSMakeRange(0, mut.length);
                    [mut removeAttribute:NSForegroundColorAttributeName range:full];
                    [mut addAttribute:NSForegroundColorAttributeName value:fillColor range:full];
                    NSRange savedRange = textView.selectedRange;
                    textView.attributedText = mut;
                    if (savedRange.location <= textView.text.length) textView.selectedRange = savedRange;
                }
                objc_setAssociatedObject(textView, &kWAMInputTextOrigColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }

        for (UIView *subview in textView.subviews) {
            if (![subview isKindOfClass:[UILabel class]]) continue;
            UILabel *label = (UILabel *)subview;
            if (isPlaceholderCustomizationEnabled()) {
                NSString *customText = getPlaceholderText();
                UIColor *customColor = getPlaceholderTextColor();
                if (!objc_getAssociatedObject(label, &kWAMPlaceholderOrigColorKey)) {
                    UIColor *currentColor = label.textColor;
                    id colorToSave;
                    if (currentColor && customColor &&
                        [currentColor isEqual:customColor]) {
                        colorToSave = [NSNull null];
                    } else {
                        colorToSave = currentColor ?: (id)[NSNull null];
                    }
                    objc_setAssociatedObject(label, &kWAMPlaceholderOrigColorKey, colorToSave,
                        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
                if (customText && !objc_getAssociatedObject(label, &kWAMPlaceholderOrigTextKey)) {
                    NSString *currentText = label.text;
                    id toSave;
                    if (currentText.length && [currentText isEqualToString:customText]) {
                        toSave = [NSNull null];
                    } else {
                        toSave = currentText ?: (id)[NSNull null];
                    }
                    objc_setAssociatedObject(label, &kWAMPlaceholderOrigTextKey, toSave,
                        OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
                label.textColor = getPlaceholderTextColor();
                if (customText) label.text = customText;
            } else {
                id origColor = objc_getAssociatedObject(label, &kWAMPlaceholderOrigColorKey);
                if (origColor) {
                    if (origColor == [NSNull null]) {
                        NSDictionary *prefs = loadPrefs();
                        NSString *gKey = isDarkMode() ? @"placeholderTextColorDark" : @"placeholderTextColor";
                        UIColor *globalColor = colorFromHex(prefs[gKey]);
                        label.textColor = globalColor ?: [UIColor colorWithWhite:1.0 alpha:0.3];
                    } else {
                        label.textColor = (UIColor *)origColor;
                    }
                    id origText = objc_getAssociatedObject(label, &kWAMPlaceholderOrigTextKey);

                    NSString *targetText = nil;
                    NSString *globalText = getPlaceholderText();
                    if (globalText.length) {
                        targetText = globalText;
                    } else if (origText && origText != [NSNull null]) {
                        targetText = (NSString *)origText;
                    } else {
                        targetText = wamPlaceholderStockText();
                    }
                    label.text = targetText;

                    objc_setAssociatedObject(label, &kWAMPlaceholderOrigColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    objc_setAssociatedObject(label, &kWAMPlaceholderOrigTextKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
static NSInteger const kDrawerOverlayTag = 99882;
static const char kWAMOriginalImageKey = 0;
static const char kWAMDrawerOverlayKey = 0;

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    static NSTimeInterval sLastEntryRefresh = 0;
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (now - sLastEntryRefresh > 0.25) { refreshPrefs(); sLastEntryRefresh = now; }
    [self wamApplyEntryButtonColors];
}

%new
- (void)wamApplyEntryButtonColors {
    UIColor *sendColor = getSendButtonColor();
    UIColor *arrowColor = getSendArrowColor();
    UIColor *buttonColor = getMessageBarButtonColor();
    BOOL customizeOtherButtons = isMessageBarButtonsEnabled();

    for (UIView *subview in self.subviews) {
        if (![subview isKindOfClass:[UIVisualEffectView class]]) continue;
        UIVisualEffectView *effectView = (UIVisualEffectView *)subview;
        for (UIView *contentSubview in effectView.contentView.subviews) {
            if (![contentSubview isKindOfClass:[UIButton class]]) continue;
            UIButton *button = (UIButton *)contentSubview;

            static const char kWAMBtnObservedKey = 0;
            if (!objc_getAssociatedObject(button, &kWAMBtnObservedKey)) {
                objc_setAssociatedObject(button, &kWAMBtnObservedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                [button addTarget:self action:@selector(wamScheduleEntryButtonRetries)
                 forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                                  UIControlEventTouchCancel | UIControlEventTouchDown];
            }

            UIImageView *existingArrow = nil;
            for (UIView *bs in button.subviews) {
                if (bs.tag == kArrowOverlayTag) { existingArrow = (UIImageView *)bs; break; }
            }
            if (existingArrow) {
                if (sendColor) {
                    button.backgroundColor = sendColor;
                    button.layer.cornerRadius = button.bounds.size.width / 2;
                    button.clipsToBounds = YES;
                }
                UIImage *arrowImage = [UIImage systemImageNamed:@"arrow.up"];
                if (arrowImage) {
                    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold];
                    arrowImage = [arrowImage imageWithConfiguration:config];
                    arrowImage = [arrowImage imageWithTintColor:arrowColor renderingMode:UIImageRenderingModeAlwaysOriginal];
                    existingArrow.image = arrowImage;
                }
                continue;
            }

            for (UIView *bs in [button.subviews copy]) {
                if (![bs isKindOfClass:[UIImageView class]]) continue;
                if (bs.tag == kArrowOverlayTag) continue;
                UIImageView *iv = (UIImageView *)bs;
                CGSize fs = iv.frame.size;
                BOOL sendSize = (fs.width > 27 && fs.width < 28 && fs.height > 27 && fs.height < 28);
                BOOL drawerSize = ((fs.width > 35 && fs.width < 37 && fs.height > 35 && fs.height < 37) ||
                                   (fs.width > 40 && fs.width < 42 && fs.height > 31 && fs.height < 33));

                if (sendSize) {
                    if (!sendColor) continue;
                    if (isiOS15()) {
                        BOOL isAudioButton = NO;
                        for (id target in [button allTargets]) {
                            if ([NSStringFromClass([target class]) containsString:@"ActionMenu"]) { isAudioButton = YES; break; }
                        }
                        if (isAudioButton) continue;
                    }
                    button.backgroundColor = sendColor;
                    button.layer.cornerRadius = button.bounds.size.width / 2;
                    button.clipsToBounds = YES;
                    [iv removeFromSuperview];
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
                } else if (drawerSize) {
                    UIImage *pristine = objc_getAssociatedObject(iv, &kWAMOriginalImageKey);
                    if (!pristine) {
                        if (!iv.image) continue;
                        pristine = iv.image;
                        objc_setAssociatedObject(iv, &kWAMOriginalImageKey, pristine, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    }
                    UIImageView *overlay = objc_getAssociatedObject(self, &kWAMDrawerOverlayKey);
                    if (customizeOtherButtons && buttonColor) {
                        if (!overlay) {
                            overlay = [[UIImageView alloc] init];
                            overlay.userInteractionEnabled = NO;
                            overlay.tag = kDrawerOverlayTag;
                            objc_setAssociatedObject(self, &kWAMDrawerOverlayKey, overlay, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        }
                        if (overlay.superview != self) [self addSubview:overlay];
                        overlay.contentMode = iv.contentMode;
                        overlay.image = [pristine imageWithTintColor:buttonColor renderingMode:UIImageRenderingModeAlwaysOriginal];
                        overlay.frame = [iv.superview convertRect:iv.frame toView:self];
                        overlay.hidden = NO;
                        [self bringSubviewToFront:overlay];
                        iv.hidden = YES;
                    } else {
                        iv.hidden = NO;
                        if (overlay) {
                            [overlay removeFromSuperview];
                            objc_setAssociatedObject(self, &kWAMDrawerOverlayKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
    [self wamApplyEntryButtonColors];
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig;
    if (!isTweakEnabled()) return;
    if (newWindow && gWAMCurrentContactName.length) {
        gWAMChatIsActiveSurface = YES;
        refreshPrefs();
        [self wamApplyEntryButtonColors];
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
    [self wamScheduleEntryButtonRetries];
}

%new
- (void)wamScheduleEntryButtonRetries {
    if (!self.window) return;
    __weak typeof(self) weakSelf = self;
    for (NSNumber *delay in @[@0.02, @0.08, @0.2, @0.4, @0.8]) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay.doubleValue * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) s = weakSelf;
            if (!s || !s.window) return;
            [s applyColorsDirectly];
        });
    }
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
    [self wamApplyEntryButtonColors];
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
            [self wamScheduleEntryButtonRetries];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

// The iOS 17 message-bar "+" (app drawer) button is its own class: a UIImageView glyph plus its round
// backdrop, all inside CKEntryViewPlusButton. Theme its circle to the message bar's field color and tint
// the glyph, so it reads as part of the (customized) bar.
%hook CKEntryViewPlusButton

%new
- (void)wamThemePlusButton {
    static const char kBgKey = 0;         // saved stock backgroundColor
    static const char kTemplatedKey = 0;  // glyph image already switched to template rendering

    UIView *me = (UIView *)self;
    BOOL barCustom = isInputFieldCustomizationEnabled();
    UIColor *field = getInputFieldBackgroundColor();
    // Opaque field hue. Must be fully opaque: any translucency lets the stock blur behind the button show
    // through, and that blur is present before the drawer opens but gone after it closes — which made the
    // same teal read darker (before) vs lighter (after). Opaque ⇒ backdrop can't shift it ⇒ consistent.
    UIColor *tint = [field colorWithAlphaComponent:1.0];
    // Glyph matches the nav buttons (back arrow etc.).
    UIColor *glyphColor = isMessageBarButtonsEnabled()
        ? getAdvancedTintColorForView(@"advancedNavButtonColor", @"advancedNavButtonColorDark", getSystemTintColor(), me)
        : nil;

    // Walk the (small) subtree. The stock puck is PlusButtonButtonView.backgroundColor, but that view is
    // composited through its parent PlusButtonBlendedBackgroundView's BLEND — so even an opaque color
    // rendered non-solid and shifted with the backdrop (different before/after the drawer). Put our solid
    // fill on PlusButtonClippingView instead (above the blend, still circle-clipped: cornerRadius 17), and
    // CLEAR PlusButtonButtonView so its gray doesn't blend on top. That escapes the blend → truly solid
    // and identical every time. Both views collapse to {0,0} on drawer-open, so no open/close gating.
    // Expensive work (image templating) is done once so this runs every layoutSubviews without lag.
    NSMutableArray *q = [NSMutableArray arrayWithObject:me];
    while (q.count) {
        UIView *v = q.firstObject; [q removeObjectAtIndex:0];
        NSString *cls = NSStringFromClass([v class]);
        if ([cls containsString:@"PlusButtonClippingView"]) {
            if (!objc_getAssociatedObject(v, &kBgKey))
                objc_setAssociatedObject(v, &kBgKey, v.backgroundColor ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (barCustom) {
                if (![v.backgroundColor isEqual:tint]) v.backgroundColor = tint;
            } else {
                id orig = objc_getAssociatedObject(v, &kBgKey);
                v.backgroundColor = (orig == [NSNull null]) ? nil : (UIColor *)orig;
            }
        } else if ([cls containsString:@"PlusButtonButtonView"]) {
            if (!objc_getAssociatedObject(v, &kBgKey))
                objc_setAssociatedObject(v, &kBgKey, v.backgroundColor ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            if (barCustom) {
                if (v.backgroundColor != nil) v.backgroundColor = nil;   // clear stock gray; solid fill is on ClippingView
            } else {
                id orig = objc_getAssociatedObject(v, &kBgKey);
                v.backgroundColor = (orig == [NSNull null]) ? nil : (UIColor *)orig;
            }
        } else if ([v isKindOfClass:[UIImageView class]] && ((UIImageView *)v).image) {
            UIImageView *iv = (UIImageView *)v;
            UIImage *pristine = objc_getAssociatedObject(iv, &kWAMOriginalImageKey);
            if (!pristine) {
                pristine = iv.image;
                objc_setAssociatedObject(iv, &kWAMOriginalImageKey, pristine, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            if (glyphColor) {
                if (!objc_getAssociatedObject(iv, &kTemplatedKey)) {
                    iv.image = [pristine imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                    objc_setAssociatedObject(iv, &kTemplatedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
                if (![iv.tintColor isEqual:glyphColor]) iv.tintColor = glyphColor;
            } else if (objc_getAssociatedObject(iv, &kTemplatedKey)) {
                iv.image = pristine;
                objc_setAssociatedObject(iv, &kTemplatedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
        [q addObjectsFromArray:v.subviews];
    }
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    [self wamThemePlusButton];
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;
    [self wamThemePlusButton];
    // Re-apply shortly after first appear, in case ChatKit sets its own puck color asynchronously after
    // this initial layout (that's what made the first-load shade differ from the post-drawer one).
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.35 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        if (weakSelf && ((UIView *)weakSelf).window) [weakSelf wamThemePlusButton];
    });
}

%end

%hook CKDetailsTableView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    objc_setAssociatedObject(self, "wam_headerChecked", nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    // Pin this chat's contact while the details screen is on screen. The chat's own view leaves the
    // window when details pushes on top, so gWAMChatIsActiveSurface flips off and per-contact resolution
    // fails — reverting the details background to stock. This keeps it resolving to the right contact.
    if (self.window) {
        NSString *name = wamReadCurrentChatCanonicalName();
        if (!name.length) name = gWAMCurrentContactName;
        if (name.length) gWAMDetailsContactName = [name copy];
    } else {
        gWAMDetailsContactName = nil;
    }

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
    if (objc_getAssociatedObject(self, "wam_everSawPhotoCell")) return;
    if (objc_getAssociatedObject(self, "wam_headerInstallScheduled")) return;
    if (tv.tableHeaderView) return;
    if (tv.visibleCells.count == 0) return;

    for (UITableViewCell *cell in tv.visibleCells) {
        if ([cell isKindOfClass:%c(CKGroupPhotoCell)]) {
            objc_setAssociatedObject(self, "wam_everSawPhotoCell", @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            return;
        }
    }

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
    NSString *name = wamReadCurrentChatCanonicalName();
    if (!name.length) name = gWAMCurrentContactName;
    if (!name.length) return;
    WAMPerContactSettings *vc = [WAMPerContactSettings new];
    vc.contactName = name;
    vc.displayName = name;
    vc.onChanged = ^{
        wamTriggerFullChatRefresh();
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
        [self wamRecolorTableLabelsInView:cell];
        [cell setNeedsLayout];
    }
}

%new
- (NSInteger)wamRecolorTableLabelsInView:(UIView *)view {
    NSInteger count = 0;
    if ([view isKindOfClass:%c(UITableViewLabel)] &&
        [view respondsToSelector:@selector(wamApplyTableLabelColor)]) {
        [(UITableViewLabel *)view wamApplyTableLabelColor];
        count++;
    }
    for (UIView *sub in view.subviews) count += [self wamRecolorTableLabelsInView:sub];
    return count;
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

    refreshPrefs();
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
    if (!isTweakEnabled()) return;
    self.backgroundColor = [UIColor clearColor];
    [self applyContactNameColor];
    if (isPerContactChatBgEnabled()) [self wamCacheNameAndRefreshChatBg];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyContactNameColor];
    if (isPerContactChatBgEnabled()) [self wamCacheNameAndRefreshChatBg];
}

- (void)setFrame:(CGRect)frame {
    if (isTweakEnabled() && isPerContactChatBgEnabled() && frame.size.height > 213) {
        frame.size.height = 213;
    }
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
    UIColor *titleColor = nil;
    if (isCustomTextColorsEnabled()) {
        NSString *nameKey = isDarkMode() ? @"chatContactNameColorDark" : @"chatContactNameColor";
        NSString *titleKey = isDarkMode() ? @"titleTextColorDark" : @"titleTextColor";
        titleColor = colorFromHex(effectiveValueForKey(nameKey));
        if (!titleColor) titleColor = colorFromHex(effectiveValueForKey(titleKey));
    }

    void (^apply)(UILabel *) = ^(UILabel *label) {
        if (titleColor) {
            if (!objc_getAssociatedObject(label, &kWAMOrigTitleColorKey)) {
                objc_setAssociatedObject(label, &kWAMOrigTitleColorKey,
                    label.textColor ?: (id)[NSNull null],
                    OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            label.textColor = titleColor;
        } else {
            id orig = objc_getAssociatedObject(label, &kWAMOrigTitleColorKey);
            if (orig && orig != [NSNull null]) {
                label.textColor = (UIColor *)orig;
                objc_setAssociatedObject(label, &kWAMOrigTitleColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
    };

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            apply((UILabel *)subview);
        } else if ([subview isKindOfClass:[UIStackView class]]) {
            for (UIView *innerView in ((UIStackView *)subview).arrangedSubviews) {
                if ([innerView isKindOfClass:[UIStackView class]]) {
                    for (UIView *stackItem in ((UIStackView *)innerView).arrangedSubviews) {
                        if ([stackItem isKindOfClass:[UILabel class]]) {
                            apply((UILabel *)stackItem);
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
    if (isTweakEnabled() && isPerContactChatBgEnabled() && frame.size.height > 0 && frame.size.height < 277) {
        frame.size.height = 277;
    }
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
        wamTriggerFullChatRefresh();
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

    if (self.bounds.size.height > 1.0) {   // the system radius (10) reads square on these tiles — round more
        self.layer.cornerRadius = self.bounds.size.height * 0.16;
        self.clipsToBounds = YES;
    }

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
            for (UIView *contentSubview in blurView.contentView.subviews) {
                if ([contentSubview class] == [UIView class]) {
                    contentSubview.frame = blurView.contentView.bounds;
                    break;
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
            for (UIView *contentSubview in blurView.contentView.subviews) {
                if ([contentSubview class] == [UIView class]) {
                    contentSubview.frame = blurView.contentView.bounds;
                    break;
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
            for (UIView *contentSubview in blurView.contentView.subviews) {
                if ([contentSubview class] == [UIView class]) {
                    contentSubview.frame = blurView.contentView.bounds;
                    break;
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
    for (UIView *sub in [self.subviews copy]) {
        if (sub.tag == kWAMOurBgImageTag) [sub removeFromSuperview];
    }

    static const char kWAMRecipOrigBgKey = 0;
    if (!objc_getAssociatedObject(self, &kWAMRecipOrigBgKey)) {
        objc_setAssociatedObject(self, &kWAMRecipOrigBgKey,
                                 self.backgroundColor ?: (id)[NSNull null],
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    if (isChatColorBgEnabled() || shouldShowAnyChatBgImage()) {
        self.backgroundColor = [UIColor clearColor];
    } else {
        id orig = objc_getAssociatedObject(self, &kWAMRecipOrigBgKey);
        self.backgroundColor = [orig isKindOfClass:[UIColor class]] ? (UIColor *)orig : nil;
    }

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    for (UIView *subview in self.subviews) {
        if (subview.tag == kWAMOurBgImageTag) {
            [subview removeFromSuperview];
            break;
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
    if (wamHasCustomChatBackdrop()) {
        self.backgroundColor = [UIColor clearColor];
    } else {
        self.backgroundColor = wamBaseSystemBackground(self);
    }
}

- (void)layoutSubviews {
    %orig;
    wamUpdateComposeRecipientName((UIView *)self);
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled()) { %orig; return; }
    if (wamHasCustomChatBackdrop()) { %orig([UIColor clearColor]); return; }
    %orig(wamBaseSystemBackground(self));
}

- (void)traitCollectionDidChange:(UITraitCollection *)previous {
    %orig;
    if (isTweakEnabled() && !wamHasCustomChatBackdrop()) {
        self.backgroundColor = wamBaseSystemBackground(self);
    }
}

%end

// The recipient chip itself — created the instant a recipient is picked, well before
// CKComposeRecipientView's own layoutSubviews is guaranteed to run again. Hooking this directly is what
// makes per-contact overrides apply immediately instead of only after some unrelated layout pass.
%hook CNComposeRecipientAtom

- (void)didMoveToWindow {
    %orig;
    wamUpdateComposeRecipientName((UIView *)self);
}

- (void)layoutSubviews {
    %orig;
    wamUpdateComposeRecipientName((UIView *)self);
}

// Recipient chip deleted: didMoveToWindow also fires here, but by then self is already fully detached
// (self.superview is nil), so wamUpdateComposeRecipientName's upward walk to CKComposeRecipientView fails
// silently and the "field is now empty, revert to global" branch never runs. willMoveToSuperview: fires
// BEFORE detachment (self.superview is still valid), so capture the ancestor here, then recompute on the
// next runloop tick once the removal has actually completed and this atom no longer counts.
- (void)willMoveToSuperview:(UIView *)newSuperview {
    %orig;
    if (newSuperview || !wamIsNotificationExtension()) return;
    __weak UIView *weakAncestor = ((UIView *)self).superview;
    dispatch_async(dispatch_get_main_queue(), ^{
        wamUpdateComposeRecipientName(weakAncestor);
    });
}

%end

%hook UITableViewLabel

static const char kWAMTableLabelOrigKey = 0;
static const char kWAMTableLabelUpdatingKey = 0;

static BOOL wamLabelIsRedish(UIColor *color) {
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if (color && [color getRed:&r green:&g blue:&b alpha:&a]) {
        if (r > 0.7 && g < 0.3 && b < 0.3) return YES;
    }
    return NO;
}

%new
- (void)wamApplyTableLabelColor {
    UIColor *customTint = getAdvancedTableLabelColor();
    objc_setAssociatedObject(self, &kWAMTableLabelUpdatingKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    id origObj = objc_getAssociatedObject(self, &kWAMTableLabelOrigKey);
    BOOL destructive;
    if (origObj) {
        destructive = (origObj != [NSNull null]) && wamLabelIsRedish((UIColor *)origObj);
    } else {
        destructive = wamLabelIsRedish(self.textColor);
    }

    if (!destructive) {
        if (customTint) {
            if (!origObj) {
                UIColor *cur = self.textColor;
                if (!(cur && [cur isEqual:customTint])) {
                    objc_setAssociatedObject(self, &kWAMTableLabelOrigKey,
                        cur ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
            }
            self.textColor = customTint;
        } else if (origObj) {
            self.textColor = (origObj == [NSNull null]) ? nil : (UIColor *)origObj;
            objc_setAssociatedObject(self, &kWAMTableLabelOrigKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }

    objc_setAssociatedObject(self, &kWAMTableLabelUpdatingKey, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;

    if (self.window) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(wamHandleTableLabelPrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    }

    [self wamApplyTableLabelColor];
}

%new
- (void)wamHandleTableLabelPrefsChanged {
    if (!isTweakEnabled()) return;
    refreshPrefs();
    [self wamApplyTableLabelColor];
}

- (void)setTextColor:(UIColor *)color {
    if (!isTweakEnabled()) { %orig; return; }
    NSNumber *updating = objc_getAssociatedObject(self, &kWAMTableLabelUpdatingKey);
    if (updating && [updating boolValue]) { %orig; return; }
    if (wamLabelIsRedish(color)) { %orig; return; }
    UIColor *customTint = getAdvancedTableLabelColor();
    if (!(customTint && color && [color isEqual:customTint])) {
        objc_setAssociatedObject(self, &kWAMTableLabelOrigKey, color ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (customTint) { %orig(customTint); return; }
    %orig;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            [self wamApplyTableLabelColor];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook UISwitch

%new
- (void)wamApplySwitchTint {
    static const char kWAMSwitchOrigKey = 0;
    if (wamSwitchOwnsItsTint(self)) return;
    UIColor *customTint = nil;
    if (isAdvancedValueExplicitlySet(@"advancedSwitchTintColor", @"advancedSwitchTintColorDark") ||
        isAdvancedValueExplicitlySet(@"systemTintColor", @"systemTintColorDark")) {
        customTint = getAdvancedSwitchTintColor();
    }
    if (customTint) {
        if (!objc_getAssociatedObject(self, &kWAMSwitchOrigKey)) {
            objc_setAssociatedObject(self, &kWAMSwitchOrigKey,
                self.onTintColor ?: (id)[NSNull null],
                OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        self.onTintColor = customTint;
    } else {
        id orig = objc_getAssociatedObject(self, &kWAMSwitchOrigKey);
        if (orig) {
            self.onTintColor = (orig == [NSNull null]) ? nil : (UIColor *)orig;
            objc_setAssociatedObject(self, &kWAMSwitchOrigKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

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

    [self wamApplySwitchTint];
}

%new
- (void)wamHandleSwitchPrefsChanged {
    if (!isTweakEnabled()) return;
    refreshPrefs();
    [self wamApplySwitchTint];
}

- (void)setOn:(BOOL)on animated:(BOOL)animated {
    %orig;
    if (!isTweakEnabled()) return;
    [self wamApplySwitchTint];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            [self wamApplySwitchTint];
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

static char kWAMRxnBlurKey;
static char kWAMRxnTintKey;
static char kWAMRxnMaskKey;

static UIImageView *wamReactionShapeView(UIView *c) {
    UIView *blur = objc_getAssociatedObject(c, &kWAMRxnBlurKey);
    UIImageView *shape = nil;
    for (UIView *s in c.subviews) {
        if (s == blur) continue;
        if ([s isMemberOfClass:[UIImageView class]] && ((UIImageView *)s).image) shape = (UIImageView *)s;
    }
    return shape;
}

static void wamSetReactionFillHidden(UIView *c, BOOL hidden) {
    Class gradCls = NSClassFromString(@"CKGradientView");
    UIView *blur = objc_getAssociatedObject(c, &kWAMRxnBlurKey);
    for (UIView *s in c.subviews) {
        if (s == blur) continue;
        if ([s isMemberOfClass:[UIImageView class]] || (gradCls && [s isKindOfClass:gradCls]))
            s.hidden = hidden;
    }
}

static void wamApplyReactionBlur(UIView *c, UIColor *tint) {
    CGRect b = c.bounds;
    if (b.size.width <= 0 || b.size.height <= 0) return;

    UIImageView *shapeView = wamReactionShapeView(c);
    UIImage *shape = shapeView.image;
    if (!shape) return;

    BOOL flip = (shapeView.transform.a < 0) || (shapeView.layer.transform.m11 < 0);

    UIVisualEffectView *blur = objc_getAssociatedObject(c, &kWAMRxnBlurKey);
    if (!blur) {
        blur = wamMakeBlurView(b);
        blur.userInteractionEnabled = NO;
        [c insertSubview:blur atIndex:0];
        objc_setAssociatedObject(c, &kWAMRxnBlurKey, blur, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        CALayer *t = [CALayer layer];
        [blur.contentView.layer addSublayer:t];
        objc_setAssociatedObject(c, &kWAMRxnTintKey, t, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    wamStripEffectTint(blur);
    wamSetReactionFillHidden(c, YES);

    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    blur.frame = b;
    [c sendSubviewToBack:blur];

    CALayer *t = objc_getAssociatedObject(c, &kWAMRxnTintKey);
    t.frame = b;
    t.backgroundColor = tint.CGColor;

    CALayer *mask = objc_getAssociatedObject(c, &kWAMRxnMaskKey);
    if (!mask) {
        mask = [CALayer layer];
        objc_setAssociatedObject(c, &kWAMRxnMaskKey, mask, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    UIGraphicsBeginImageContextWithOptions(b.size, NO, 0);
    CGContextRef ctx = UIGraphicsGetCurrentContext();
    if (flip) {
        CGContextTranslateCTM(ctx, b.size.width, 0);
        CGContextScaleCTM(ctx, -1, 1);
    }
    [shape drawInRect:CGRectMake(0, 0, b.size.width, b.size.height)];
    UIImage *rendered = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    mask.frame = b;
    mask.contents = (id)rendered.CGImage;
    blur.layer.mask = mask;

    [CATransaction commit];
}

static void wamRemoveReactionBlur(UIView *c) {
    UIView *blur = objc_getAssociatedObject(c, &kWAMRxnBlurKey);
    if (blur) [blur removeFromSuperview];
    objc_setAssociatedObject(c, &kWAMRxnBlurKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(c, &kWAMRxnTintKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    objc_setAssociatedObject(c, &kWAMRxnMaskKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    wamSetReactionFillHidden(c, NO);
}

static UIColor *wamReactionBlurTint(UIView *c) {
    if (isAdvancedValueExplicitlySet(@"advancedReactionBalloonColor", @"advancedReactionBalloonColorDark"))
        return getChatAdvancedTintColorForView(@"advancedReactionBalloonColor", @"advancedReactionBalloonColorDark", nil, c);
    return getReceivedBubbleColor();
}

%hook CKAggregateAcknowledgmentBalloonView
- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    UIView *v = (UIView *)self;
    if (isBlurBubblesEnabled()) wamApplyReactionBlur(v, wamReactionBlurTint(v));
    else wamRemoveReactionBlur(v);
}
%end

%hook CKAggregateAcknowledgmentGradientBalloonView
- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    UIView *v = (UIView *)self;
    if (isBlurBubblesEnabled()) wamApplyReactionBlur(v, wamReactionBlurTint(v));
    else wamRemoveReactionBlur(v);
}
%end

%hook CKAggregateAcknowledgementBalloonView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    BOOL hasGlyphOverride = isAdvancedValueExplicitlySet(@"advancedReactionGlyphColor", @"advancedReactionGlyphColorDark");
    if (!isCustomBubbleColorsEnabled() && !hasGlyphOverride) return;
    UIColor *customTint = getAdvancedReactionGlyphColor();
    if (customTint) {
        self.tintColor = customTint;
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) subview.tintColor = customTint;
        }
    }
    [self applyGlyphTintRecursively:self];
}

- (void)setTintColor:(UIColor *)color {
    if (!isTweakEnabled()) { %orig; return; }
    BOOL hasGlyphOverride = isAdvancedValueExplicitlySet(@"advancedReactionGlyphColor", @"advancedReactionGlyphColorDark");
    if (!isCustomBubbleColorsEnabled() && !hasGlyphOverride) { %orig; return; }
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
    BOOL hasGlyphOverride = isAdvancedValueExplicitlySet(@"advancedReactionGlyphColor", @"advancedReactionGlyphColorDark");
    if (!isCustomBubbleColorsEnabled() && !hasGlyphOverride) return;
    UIColor *customTint = getAdvancedReactionGlyphColor();
    if (customTint) {
        self.tintColor = customTint;
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) subview.tintColor = customTint;
        }
    }
    [self applyGlyphTintRecursively:self];
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

static BOOL wamPlatterHostsAppExtension(UIView *view) {
    if (!view) return NO;
    static NSArray *needles;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ needles = @[@"Remote", @"Plugin", @"Browser", @"MSMessages", @"Extension"]; });

    BOOL (^matches)(UIView *) = ^BOOL(UIView *v) {
        NSString *cls = NSStringFromClass(v.class);
        for (NSString *n in needles) if ([cls containsString:n]) return YES;
        return NO;
    };

    UIView *p = view.superview;
    int hops = 0;
    while (p && hops++ < 20) {
        if (matches(p)) return YES;
        p = p.superview;
    }

    NSMutableArray *queue = [NSMutableArray arrayWithObject:view];
    int guard = 0;
    while (queue.count && guard++ < 600) {
        UIView *v = queue.firstObject;
        [queue removeObjectAtIndex:0];
        if (v != view && matches(v)) return YES;
        [queue addObjectsFromArray:v.subviews];
    }
    return NO;
}

%hook _UIPlatterClippingView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    if (self.bounds.size.height < 200) return;
    if (wamPlatterHostsAppExtension(self)) return;
    [self applyPlatterBackground];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    if (wamPlatterHostsAppExtension(self)) return;

    NSMutableArray *ours = [NSMutableArray array];
    for (UIView *sub in self.subviews) {
        if (sub.tag == kWAMOurBgImageTag) [ours addObject:sub];
    }

    if (self.bounds.size.height < 200) {
        if (ours.count) {
            for (UIView *v in ours) [v removeFromSuperview];
            self.backgroundColor = [UIColor clearColor];
        }
        return;
    }

    if (ours.count) {
        for (NSUInteger i = 1; i < ours.count; i++) [ours[i] removeFromSuperview];
        ((UIView *)ours[0]).frame = self.bounds;
        return;
    }
    [self applyPlatterBackground];
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
        imageView.tag = kWAMOurBgImageTag;
        imageView.userInteractionEnabled = NO;
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
            if (wamPlatterHostsAppExtension(self)) return;
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
    if (wamPlatterHostsAppExtension(self)) return;
    self.hidden = YES;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    if (!isChatColorBgEnabled() && !isChatImageBgEnabled()) return;
    if (wamPlatterHostsAppExtension(self)) return;
    self.hidden = YES;
}

- (void)setHidden:(BOOL)hidden {
    if (!isTweakEnabled() || (!isChatColorBgEnabled() && !isChatImageBgEnabled())) {
        %orig;
        return;
    }
    if (wamPlatterHostsAppExtension(self)) { %orig; return; }
    %orig(YES);
}

%end

%hook _UIPlatterSoftShadowView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;
    if (!isChatColorBgEnabled() && !isChatImageBgEnabled()) return;
    if (wamPlatterHostsAppExtension(self)) return;
    self.hidden = YES;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    if (!isChatColorBgEnabled() && !isChatImageBgEnabled()) return;
    if (wamPlatterHostsAppExtension(self)) return;
    self.hidden = YES;
}

- (void)setHidden:(BOOL)hidden {
    if (!isTweakEnabled() || (!isChatColorBgEnabled() && !isChatImageBgEnabled())) {
        %orig;
        return;
    }
    if (wamPlatterHostsAppExtension(self)) { %orig; return; }
    %orig(YES);
}

%end

%hook _UICutoutShadowView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;
    if (!isChatColorBgEnabled() && !isChatImageBgEnabled()) return;
    if (wamPlatterHostsAppExtension(self)) return;
    self.hidden = YES;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    if (!isChatColorBgEnabled() && !isChatImageBgEnabled()) return;
    if (wamPlatterHostsAppExtension(self)) return;
    self.hidden = YES;
}

- (void)setHidden:(BOOL)hidden {
    if (!isTweakEnabled() || (!isChatColorBgEnabled() && !isChatImageBgEnabled())) {
        %orig;
        return;
    }
    if (wamPlatterHostsAppExtension(self)) { %orig; return; }
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
    if (wamPlatterHostsAppExtension(view)) return NO;
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

static const char kWAMReplicantBlankedKey = 0;

%new
- (BOOL)wamShouldBlankReplicant {
    if (!isChatColorBgEnabled() && !isChatImageBgEnabled()) return NO;
    if (!isReplicantInsidePlatter(self)) return NO;
    return self.bounds.size.height >= 200;
}

%new
- (void)wamSyncReplicantBlanking {
    BOOL blanked = [objc_getAssociatedObject(self, &kWAMReplicantBlankedKey) boolValue];
    BOOL should = [self wamShouldBlankReplicant];
    if (should) {
        objc_setAssociatedObject(self, &kWAMReplicantBlankedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        self.alpha = 0;
    } else if (blanked) {
        objc_setAssociatedObject(self, &kWAMReplicantBlankedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        self.alpha = 1;
    }
}

- (void)didMoveToSuperview {
    %orig;
    if (!isTweakEnabled() || !self.superview) return;
    [self wamSyncReplicantBlanking];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    [self wamSyncReplicantBlanking];
}

- (void)setAlpha:(CGFloat)alpha {
    if (isTweakEnabled() && [self wamShouldBlankReplicant]) {
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
    if (!isTweakEnabled() || !image) { %orig; return; }
    BOOL hasGlyphOverride = isAdvancedValueExplicitlySet(@"advancedReactionGlyphColor", @"advancedReactionGlyphColorDark");
    if (!isCustomBubbleColorsEnabled() && !hasGlyphOverride) { %orig; return; }

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

    // Our bottom-search bar (a conversation-list / global element): its Cancel button is a UINavigationButton
    // that would otherwise re-resolve to the open chat's per-contact tint here. Force the GLOBAL tint.
    if (wamIsOurBottomSearchDescendant((UIView *)self)) {
        BOOL prevG = gWAMForceGlobalColorResolve;
        gWAMForceGlobalColorResolve = YES;
        UIColor *gt = getSystemTintColor();
        gWAMForceGlobalColorResolve = prevG;
        %orig(gt ?: [UIColor systemBlueColor]);
        return;
    }

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
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    if (!isTweakEnabled() || !self.window) return;
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(wamHandleNavButtonPrefsChanged)
        name:kPrefsChangedNotification
        object:nil];
    [self wamApplyNavButtonTint];
}

%new
- (void)wamHandleNavButtonPrefsChanged {
    refreshPrefs();
    [self wamApplyNavButtonTint];
}

%new
- (void)wamApplyNavButtonTint {
    static const char kWAMNavButtonOrigKey = 0;
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

    UIColor *navColor = getAdvancedTintColorForView(@"advancedNavButtonColor", @"advancedNavButtonColorDark", nil, self);
    if (!navColor) navColor = getSystemTintColor();

    if (navColor) {
        if (!objc_getAssociatedObject(self, &kWAMNavButtonOrigKey)) {
            objc_setAssociatedObject(self, &kWAMNavButtonOrigKey,
                self.tintColor ?: (id)[NSNull null],
                OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        self.tintColor = navColor;
    } else {
        id orig = objc_getAssociatedObject(self, &kWAMNavButtonOrigKey);
        if (orig) {
            self.tintColor = (orig == [NSNull null]) ? nil : (UIColor *)orig;
            objc_setAssociatedObject(self, &kWAMNavButtonOrigKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            [self wamApplyNavButtonTint];
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
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

// The search bar re-sets the field's frame to a centred natural width when it becomes active, reverting the
// fill we apply elsewhere. Intercept every frame set for OUR bottom-search field (landscape) and force it to
// fill the pill — this can't be reverted, since it catches the system's own set. (Same setFrame pattern the
// FaceTime button uses.)
- (void)setFrame:(CGRect)frame {
    if (isTweakEnabled() && wamIsLandscape() && wamIsOurBottomSearchDescendant((UIView *)self)) {
        UIView *sup = ((UIView *)self).superview;   // the search bar
        if (sup && sup.bounds.size.width > 60.0) {
            BOOL editing = [(UITextField *)self isFirstResponder];
            CGFloat leftX = editing ? 14.0 : 12.0, rightX = sup.bounds.size.width - 12.0;
            // While editing, the Cancel button sits to the right OF the pill — stop the field short of it so
            // it doesn't overlap. (Blindly filling to the superview's full width, ignoring Cancel, is what
            // made the field too wide and put the mic behind Cancel.)
            if (editing) {
                UIView *cancel = nil;
                CGFloat cancelX = -CGFLOAT_MAX;
                NSMutableArray *q = [NSMutableArray arrayWithArray:sup.subviews];
                while (q.count) {
                    UIView *v = q.firstObject; [q removeObjectAtIndex:0];
                    if ([v isDescendantOfView:(UIView *)self]) continue;
                    if ([v isKindOfClass:[UIButton class]] && v.bounds.size.width > 0) {
                        CGFloat x = [v convertRect:v.bounds toView:sup].origin.x;
                        if (x > cancelX) { cancelX = x; cancel = v; }
                    }
                    [q addObjectsFromArray:v.subviews];
                }
                if (cancel) rightX = cancelX - 8.0;
            }
            CGFloat w = rightX - leftX;
            if (w > 40.0) {
                frame.origin.x = leftX;
                frame.size.width = w;
            }
            frame.origin.y = (sup.bounds.size.height - frame.size.height) / 2.0;
        }
    }
    %orig(frame);
}

// UISearchTextField manages its own magnifier icon and silently reinstalls it as leftView on its own layout
// passes — reassigning leftView.tintColor/image afterward doesn't stick because the system swaps the VIEW
// itself back. Intercept the assignment directly: once we've built our own baked-colour magnifier (myMag),
// redirect every competing setLeftView: to it instead, so the system's own icon can never get re-installed.
- (void)setLeftView:(UIView *)leftView {
    if (isTweakEnabled() && wamIsOurBottomSearchDescendant((UIView *)self)) {
        BOOL pg = gWAMForceGlobalColorResolve; gWAMForceGlobalColorResolve = YES;
        BOOL tintActive = isAdvancedValueExplicitlySet(@"advancedSearchFieldColor", @"advancedSearchFieldColorDark") ||
                          isAdvancedValueExplicitlySet(@"systemTintColor", @"systemTintColorDark");
        gWAMForceGlobalColorResolve = pg;
        if (tintActive) {
            UIImageView *myMag = objc_getAssociatedObject((UITextField *)self, &kWAMSearchMyMagKey);
            if (myMag && leftView != myMag) { %orig(myMag); return; }
        }
    }
    %orig(leftView);
}

- (void)didMoveToWindow {
    %orig;
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UITextFieldTextDidChangeNotification object:self];
    if (!isTweakEnabled() || !self.window) return;
    [self applySearchFieldTint];
    // Force a layout pass on every keystroke — that's where the "Search" placeholder label's visibility gets
    // synced to the field's text, and layoutSubviews isn't guaranteed to fire from text changes alone.
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(wamSearchTextDidChange)
        name:UITextFieldTextDidChangeNotification object:self];
}

%new
- (void)wamSearchTextDidChange {
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    [self applySearchFieldTint];
    if (wamIsOurBottomSearchDescendant((UIView *)self)) {
        // Force the magnifier (leftView) + dictation mic (rightView) to the GLOBAL search tint. applySearchFieldTint
        // / the UINavigationButton setTintColor path can leave them on the open chat's per-contact colour in the
        // split; this runs last, so it wins. Only when the tweak's tinting is active (else stock = gray).
        BOOL prevG = gWAMForceGlobalColorResolve;
        gWAMForceGlobalColorResolve = YES;
        BOOL tintActive = isAdvancedValueExplicitlySet(@"advancedSearchFieldColor", @"advancedSearchFieldColorDark") ||
                          isAdvancedValueExplicitlySet(@"systemTintColor", @"systemTintColorDark");
        UIColor *sgt = tintActive ? getAdvancedSearchFieldColor() : nil;
        gWAMForceGlobalColorResolve = prevG;
        UIView *rv2 = [(UITextField *)self rightView];
        if (sgt) {
            ((UIView *)self).tintColor = sgt;   // cursor + inherited tint = global
            // The system re-tints the real magnifier per-contact (setting its tintColor / re-setting its image
            // doesn't stick). So REPLACE the leftView with our own image view carrying a baked-teal magnifier —
            // the system can't re-colour what it doesn't own. (When empty the overlay covers it; when editing
            // this is the visible glyph.)
            if (@available(iOS 13.0, *)) {
                UIImageView *myMag = objc_getAssociatedObject((UITextField *)self, &kWAMSearchMyMagKey);
                if (!myMag) {
                    myMag = [[UIImageView alloc] init];
                    myMag.contentMode = UIViewContentModeCenter;
                    objc_setAssociatedObject((UITextField *)self, &kWAMSearchMyMagKey, myMag, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
                UIFont *f = ((UITextField *)self).font ?: [UIFont systemFontOfSize:17.0];
                UIImageSymbolConfiguration *cfg =
                    [UIImageSymbolConfiguration configurationWithPointSize:f.pointSize weight:UIImageSymbolWeightRegular];
                UIImage *baked = [[UIImage systemImageNamed:@"magnifyingglass" withConfiguration:cfg]
                                     imageWithTintColor:sgt renderingMode:UIImageRenderingModeAlwaysOriginal];
                if (![myMag.image isEqual:baked]) { myMag.image = baked; [myMag sizeToFit]; }
                if (((UITextField *)self).leftView != myMag) ((UITextField *)self).leftView = myMag;
            }
            if (rv2 && ![rv2.tintColor isEqual:sgt]) rv2.tintColor = sgt;
        }
        // Dictation mic vertical position in landscape. EDITING lines up with the real content (frame centre
        // of the field itself). At REST, derive the target directly from the SAME pill-content geometry the
        // overlay magnifier uses (not a guessed offset) — computed fresh each pass, so it can't drift from
        // the overlay no matter what other layout churn happens.
        if (wamIsLandscape() && rv2 && rv2.superview) {
            CGFloat wantY = (((UIView *)self).bounds.size.height - rv2.bounds.size.height) / 2.0;   // editing default
            if (![(UIView *)self isFirstResponder]) {
                UIView *container = nil;
                for (UIView *a = ((UIView *)self).superview; a; a = a.superview)
                    if (a.tag == kWAMBottomSearchTag) { container = a; break; }
                UIView *fxvA = container.subviews.firstObject;
                UIView *content = [fxvA isKindOfClass:[UIVisualEffectView class]] ? ((UIVisualEffectView *)fxvA).contentView : nil;
                if (content) {
                    // Same target the overlay centres on: pill content mid-height + its 0.5 optical nudge.
                    CGFloat desiredMidY = content.bounds.size.height / 2.0 + 0.5;
                    CGPoint pt = [content convertPoint:CGPointMake(0.0, desiredMidY) toView:(UIView *)self];
                    wantY = pt.y - rv2.bounds.size.height / 2.0;
                }
            }
            if (fabs(rv2.frame.origin.y - wantY) > 0.5) {
                CGRect rf = rv2.frame; rf.origin.y = wantY; rv2.frame = rf;
            }
        }
        // Keep the "Search" placeholder label in sync with the field's text on EVERY layout pass — this hook
        // fires per keystroke (unlike wamSetupBottomSearch, which only runs on rotation/keyboard events), so
        // it's the only place that reliably catches typing as it happens. The magnifier icon itself (our
        // overlay copy) always stays up; only the placeholder text hides once there's real content.
        if (wamIsLandscape()) {
            UIView *container = nil;
            for (UIView *a = ((UIView *)self).superview; a; a = a.superview)
                if (a.tag == kWAMBottomSearchTag) { container = a; break; }
            UIView *ov2 = container ? [container viewWithTag:kWAMSearchGlyphOverlayTag] : nil;
            UILabel *lb2 = ov2 ? (UILabel *)[ov2 viewWithTag:2] : nil;
            if (lb2) {
                BOOL wantHidden = ((UITextField *)self).text.length > 0;
                if (lb2.hidden != wantHidden) lb2.hidden = wantHidden;
            }
            // Becoming first responder makes the search bar re-shuffle its own subview z-order (Cancel
            // button animation etc.), which can push our overlay BEHIND the search bar again, exposing the
            // real (uncontrollable-colour) magnifier underneath. Re-assert front on every pass — cheap, and
            // this is exactly the case the earlier one-shot bringSubviewToFront (setup-time only) missed.
            if (ov2 && ov2.superview) [ov2.superview bringSubviewToFront:ov2];
        }
    }
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
    // The search bar is a conversation-list element — never inherit the last chat's per-contact tint.
    BOOL prevForceGlobal = gWAMForceGlobalColorResolve;
    gWAMForceGlobalColorResolve = YES;

    static const char kWAMSearchFieldAppliedKey = 0;
    BOOL hasOwn = isAdvancedValueExplicitlySet(@"advancedSearchFieldColor", @"advancedSearchFieldColorDark");
    BOOL hasGlobalTint = isAdvancedValueExplicitlySet(@"systemTintColor", @"systemTintColorDark");

    if (!hasOwn && !hasGlobalTint) {
        if (objc_getAssociatedObject(self, &kWAMSearchFieldAppliedKey)) {
            if (self.placeholder) {
                self.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.placeholder attributes:nil];
            }
            self.leftView.tintColor = nil;
            self.rightView.tintColor = nil;
            for (UIView *subview in self.rightView.subviews) {
                if ([subview isKindOfClass:[UIImageView class]]) ((UIImageView *)subview).tintColor = nil;
            }
            for (UIView *subview in self.subviews) {
                if ([subview isKindOfClass:[UIImageView class]]) ((UIImageView *)subview).tintColor = nil;
            }
            objc_setAssociatedObject(self, &kWAMSearchFieldAppliedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        gWAMForceGlobalColorResolve = prevForceGlobal;
        return;
    }

    UIColor *accent = getAdvancedSearchFieldColor();
    if (!accent) { gWAMForceGlobalColorResolve = prevForceGlobal; return; }

    if (!hasOwn) {
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
    objc_setAssociatedObject(self, &kWAMSearchFieldAppliedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    gWAMForceGlobalColorResolve = prevForceGlobal;
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

static const char kWAMHeaderLabelOrigKey = 0;

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    if (self.window) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(wamHandleHeaderPrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    }
    [self applyHeaderStyle];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyHeaderStyle];
}

%new
- (void)wamHandleHeaderPrefsChanged {
    if (!isTweakEnabled()) return;
    refreshPrefs();
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
    UIColor *labelColor = nil;
    if (isAdvancedValueExplicitlySet(@"advancedTableLabelColor", @"advancedTableLabelColorDark") ||
        isAdvancedValueExplicitlySet(@"systemTintColor", @"systemTintColorDark")) {
        labelColor = getAdvancedTableLabelColor();
    }
    for (UIView *subview in self.subviews) {
        if (![subview isKindOfClass:[UILabel class]]) continue;
        UILabel *label = (UILabel *)subview;
        if (labelColor) {
            if (!objc_getAssociatedObject(label, &kWAMHeaderLabelOrigKey)) {
                UIColor *cur = label.textColor;
                if (!(cur && [cur isEqual:labelColor])) {
                    objc_setAssociatedObject(label, &kWAMHeaderLabelOrigKey,
                        cur ?: (id)[NSNull null], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
            }
            label.textColor = labelColor;
        } else {
            id orig = objc_getAssociatedObject(label, &kWAMHeaderLabelOrigKey);
            if (orig) {
                label.textColor = (orig == [NSNull null]) ? nil : (UIColor *)orig;
                objc_setAssociatedObject(label, &kWAMHeaderLabelOrigKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
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

%new
- (void)wamApplyTitleColor {
    UIColor *applied = nil;
    if (isTweakEnabled() && isCustomTextColorsEnabled()) {
        NSString *nameKey = isDarkMode() ? @"chatContactNameColorDark" : @"chatContactNameColor";
        NSString *titleKey = isDarkMode() ? @"titleTextColorDark" : @"titleTextColor";
        applied = colorFromHex(effectiveValueForKey(nameKey));
        if (!applied) applied = colorFromHex(effectiveValueForKey(titleKey));
    }
    for (UIView *subview in self.subviews) {
        if (![subview isKindOfClass:%c(CKLabel)]) continue;
        CKLabel *label = (CKLabel *)subview;
        if (applied) {
            if (!objc_getAssociatedObject(label, &kWAMOrigTitleColorKey)) {
                objc_setAssociatedObject(label, &kWAMOrigTitleColorKey,
                    label.textColor ?: (id)[NSNull null],
                    OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
            label.textColor = applied;
        } else {
            id orig = objc_getAssociatedObject(label, &kWAMOrigTitleColorKey);
            if (orig && orig != [NSNull null]) {
                label.textColor = (UIColor *)orig;
                objc_setAssociatedObject(label, &kWAMOrigTitleColorKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            }
        }
    }
}

%new
- (void)wamHandleAvatarTitlePrefsChanged {
    refreshPrefs();
    [self wamApplyTitleColor];
    [self setNeedsLayout];
}

- (void)layoutSubviews {
    %orig;
    [self wamApplyTitleColor];
    wamApplyNamePlatter(self);
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        gWAMNameShadow.alpha = 0.0;   // hide (not remove) — reused & reset when a chat's name lays out again
        return;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(wamHandleAvatarTitlePrefsChanged)
        name:kPrefsChangedNotification
        object:nil];
    [self wamApplyTitleColor];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

static char kWAMPickerBlursKey;

%hook CKMessageAcknowledgmentPickerBarView

%new
- (void)wamApplyPickerBlur {
    NSMutableArray *blurs = objc_getAssociatedObject(self, &kWAMPickerBlursKey);
    if (!blurs) {
        blurs = [NSMutableArray array];
        objc_setAssociatedObject(self, &kWAMPickerBlursKey, blurs, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    NSMutableArray<CALayer *> *bgLayers = [NSMutableArray array];
    for (CALayer *l in self.layer.sublayers) {
        if ([l.delegate isKindOfClass:[UIVisualEffectView class]]) continue;
        if (l.hidden) continue;
        [bgLayers addObject:l];
    }

    while (blurs.count < bgLayers.count) {
        UIVisualEffectView *bv = wamMakeBlurView(CGRectZero);
        bv.userInteractionEnabled = NO;
        [self insertSubview:bv atIndex:0];
        [blurs addObject:bv];
    }
    while (blurs.count > bgLayers.count) {
        [(UIView *)blurs.lastObject removeFromSuperview];
        [blurs removeLastObject];
    }

    for (NSUInteger i = 0; i < bgLayers.count; i++) {
        CALayer *l = bgLayers[i];
        UIVisualEffectView *bv = blurs[i];
        wamStripEffectTint(bv);
        bv.frame = l.frame;
        bv.layer.cornerRadius = l.cornerRadius;
        bv.clipsToBounds = YES;
        [self sendSubviewToBack:bv];

        for (NSString *key in @[@"position", @"bounds", @"cornerRadius"]) {
            CAAnimation *a = [l animationForKey:key];
            NSString *k = [@"wam_" stringByAppendingString:key];
            if (a) [bv.layer addAnimation:[a copy] forKey:k];
            else [bv.layer removeAnimationForKey:k];
        }
    }
}

%new
- (void)wamRemovePickerBlur {
    NSMutableArray *blurs = objc_getAssociatedObject(self, &kWAMPickerBlursKey);
    for (UIView *b in blurs) [b removeFromSuperview];
    objc_setAssociatedObject(self, &kWAMPickerBlursKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (void)wamHidePickerTail {
    CALayer *pill = nil;
    CGFloat maxR = -1;
    for (CALayer *l in self.layer.sublayers) {
        if ([l.delegate isKindOfClass:[UIVisualEffectView class]]) continue;
        if (l.cornerRadius > maxR) { maxR = l.cornerRadius; pill = l; }
    }
    for (CALayer *l in self.layer.sublayers) {
        if ([l.delegate isKindOfClass:[UIVisualEffectView class]]) continue;
        l.hidden = (l != pill);
    }
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    [self wamHidePickerTail];

    BOOL blurEnabled = isBlurBubblesEnabled();
    if (blurEnabled) [self wamApplyPickerBlur];
    else [self wamRemovePickerBlur];

    if (!isCustomBubbleColorsEnabled() && !blurEnabled) return;
    UIColor *customColor = getReceivedBubbleColor();
    if (!customColor) return;
    for (CALayer *sublayer in self.layer.sublayers) {
        if ([sublayer.delegate isKindOfClass:[UIVisualEffectView class]]) continue;
        if (sublayer.hidden) continue;
        sublayer.backgroundColor = customColor.CGColor;
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;

    [self wamHidePickerTail];

    BOOL blurEnabled = isBlurBubblesEnabled();
    if (blurEnabled) [self wamApplyPickerBlur];
    if (!isCustomBubbleColorsEnabled() && !blurEnabled) return;
    UIColor *customColor = getReceivedBubbleColor();
    if (!customColor) return;
    for (CALayer *sublayer in self.layer.sublayers) {
        if ([sublayer.delegate isKindOfClass:[UIVisualEffectView class]]) continue;
        if (sublayer.hidden) continue;
        sublayer.backgroundColor = customColor.CGColor;
    }
}

%end

%hook CKPinnedConversationSummaryBubble

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
#if WAM_SCREENSHOT_MODE
    wamScreenshotApplyToCell((UIView *)self);
#endif
    if (!isCustomBubbleColorsEnabled()) return;
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
    NSString *captured = nil;
    {
        id tappedConv = wamConversationFromTappedView((UIView *)self);
        if (tappedConv) {
            SEL sels[] = {
                @selector(name),
                @selector(displayName),
                @selector(title),
                NSSelectorFromString(@"effectiveDisplayName"),
                NSSelectorFromString(@"primaryRecipientDisplayName"),
                NSSelectorFromString(@"groupName"),
                (SEL)0
            };
            for (int i = 0; sels[i] != (SEL)0 && !captured.length; i++) {
                if ([tappedConv respondsToSelector:sels[i]]) {
                    NSString *dn = ((NSString *(*)(id, SEL))objc_msgSend)(tappedConv, sels[i]);
                    if ([dn isKindOfClass:[NSString class]] && dn.length) captured = dn;
                }
                if (!captured.length) {
                    Ivar ch = class_getInstanceVariable([tappedConv class], "_chat");
                    id chat = ch ? object_getIvar(tappedConv, ch) : nil;
                    if (chat && [chat respondsToSelector:sels[i]]) {
                        NSString *dn = ((NSString *(*)(id, SEL))objc_msgSend)(chat, sels[i]);
                        if ([dn isKindOfClass:[NSString class]] && dn.length) captured = dn;
                    }
                }
            }
        }
        if (!captured.length) {
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
            captured = best.text;
        }
        captured = [captured stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    }
    if (!captured.length) return;
    if ([captured isEqualToString:gWAMCurrentContactName]) return;
    gWAMCurrentContactName = [captured copy];
    gWAMCurrentContactDisplayName = [captured copy];
    gWAMCacheSetAt = [NSDate timeIntervalSinceReferenceDate];
    gWAMTapSetAt = gWAMCacheSetAt;

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
        if (captured.length) gWAMActiveChatName = [captured copy];
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

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    // Pin this chat's contact while its details card is on screen, so per-contact theming keeps
    // resolving after the chat's own view (and gWAMChatIsActiveSurface) drops out of the window.
    if (self.window) {
        NSString *name = wamReadCurrentChatCanonicalName();
        if (!name.length) name = gWAMCurrentContactName;
        if (name.length) gWAMDetailsContactName = [name copy];
    } else {
        gWAMDetailsContactName = nil;
    }
}

- (void)didMoveToSuperview {
    %orig;
    if (!isTweakEnabled() || !self.superview) return;

    refreshPrefs();
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

    if (self.superview && shouldShowAnyChatBgImage()) {
        UIImageView *existing = nil;
        for (UIView *subview in self.superview.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                UIImageView *imgView = (UIImageView *)subview;
                if (imgView.contentMode == UIViewContentModeScaleAspectFill) {
                    existing = imgView;
                    imgView.frame = self.frame;
                    [self.superview sendSubviewToBack:imgView];
                    break;
                }
            }
        }
        if (!existing) {
            UIImage *chatBgImage = loadImageUncached(getChatImagePath());
            if (chatBgImage) {
                CGFloat blurAmount = getEffectiveChatBgBlur();
                if (blurAmount > 0) chatBgImage = blurImage(chatBgImage, blurAmount);
                UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.frame];
                imageView.image = chatBgImage;
                imageView.contentMode = UIViewContentModeScaleAspectFill;
                imageView.clipsToBounds = YES;
                imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                imageView.userInteractionEnabled = NO;
                [self.superview insertSubview:imageView atIndex:0];
            }
        }
        self.backgroundColor = [UIColor clearColor];
    }

    static const char kLastTintApplyKey = 0;
    NSNumber *last = objc_getAssociatedObject(self, &kLastTintApplyKey);
    NSTimeInterval now = [NSDate timeIntervalSinceReferenceDate];
    if (!last || (now - last.doubleValue) >= 0.25) {
        objc_setAssociatedObject(self, &kLastTintApplyKey, @(now), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        [self applyAdvancedTintToContactLabels];
    }
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
    UIColor *actionColor = nil;
    if (isAdvancedValueExplicitlySet(@"advancedContactActionColor", @"advancedContactActionColorDark") ||
        isAdvancedValueExplicitlySet(@"systemTintColor", @"systemTintColorDark")) {
        actionColor = getAdvancedTintColorForView(@"advancedContactActionColor", @"advancedContactActionColorDark", getSystemTintColor(), self);
    }
    [self walkViewForTintLabels:self color:actionColor];

    UIColor *labelColor = nil;
    if (isAdvancedValueExplicitlySet(@"advancedTableLabelColor", @"advancedTableLabelColorDark")) {
        labelColor = getAdvancedTableLabelColor();
    }
    [self wamWalkUserViewLabels:self color:labelColor];
}

%new
- (void)wamWalkUserViewLabels:(UIView *)view color:(UIColor *)color {
    NSString *className = NSStringFromClass([view class]);
    if ([className containsString:@"Keyboard"]) return;

    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        NSString *text = label.text;
        BOOL isSectionHeader = (text.length > 1 &&
                                [text isEqualToString:[text uppercaseString]] &&
                                label.font.pointSize <= 14);
        if (isSectionHeader) {
            CGFloat r, g, b, a;
            if (!label.textColor || ![label.textColor getRed:&r green:&g blue:&b alpha:&a] ||
                !(r > 0.7 && g < 0.3 && b < 0.3)) {
                label.textColor = color;
            }
        }
    }
    for (UIView *sub in view.subviews) [self wamWalkUserViewLabels:sub color:color];
}

%new
- (void)walkViewForTintLabels:(UIView *)view color:(UIColor *)color {
    NSString *className = NSStringFromClass([view class]);
    if ([className containsString:@"Keyboard"] ||
        [className containsString:@"UIKBVisualEffectView"]) return;

    static const char kWAMTintAppliedKey = 0;

    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        if (color) {
            CGFloat lr, lg, lb, la;
            if ([label.textColor getRed:&lr green:&lg blue:&lb alpha:&la]) {
                BOOL matches = NO;
                UIColor *systemTint = getSystemTintColor();
                if (systemTint) {
                    CGFloat tr, tg, tb, ta;
                    if ([systemTint getRed:&tr green:&tg blue:&tb alpha:&ta]) {
                        if (fabs(lr-tr) < 0.05 && fabs(lg-tg) < 0.05 && fabs(lb-tb) < 0.05) matches = YES;
                    }
                }
                if (!matches) {
                    UIColor *sysBlue = [UIColor systemBlueColor];
                    CGFloat br, bg, bb, ba;
                    if ([sysBlue getRed:&br green:&bg blue:&bb alpha:&ba]) {
                        if (fabs(lr-br) < 0.05 && fabs(lg-bg) < 0.05 && fabs(lb-bb) < 0.05) matches = YES;
                    }
                }
                if (matches) {
                    label.textColor = color;
                    objc_setAssociatedObject(label, &kWAMTintAppliedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                }
            }
        } else if (objc_getAssociatedObject(label, &kWAMTintAppliedKey)) {
            label.textColor = getSystemTintColor() ?: [UIColor systemBlueColor];
            objc_setAssociatedObject(label, &kWAMTintAppliedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }

    if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *iv = (UIImageView *)view;
        if (color) {
            if (iv.tintColor) {
                CGFloat lr, lg, lb, la;
                UIColor *systemTint = getSystemTintColor();
                if (systemTint && [iv.tintColor getRed:&lr green:&lg blue:&lb alpha:&la]) {
                    CGFloat tr, tg, tb, ta;
                    if ([systemTint getRed:&tr green:&tg blue:&tb alpha:&ta]) {
                        if (fabs(lr-tr) < 0.05 && fabs(lg-tg) < 0.05 && fabs(lb-tb) < 0.05) {
                            iv.tintColor = color;
                            objc_setAssociatedObject(iv, &kWAMTintAppliedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        }
                    }
                }
            }
        } else if (objc_getAssociatedObject(iv, &kWAMTintAppliedKey)) {
            iv.tintColor = getSystemTintColor() ?: [UIColor systemBlueColor];
            objc_setAssociatedObject(iv, &kWAMTintAppliedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
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
    if (!isChatColorBgEnabled() && !isChatImageBgEnabled()) return;
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
    if (isTweakEnabled() && isPerContactChatBgEnabled() && frame.size.height > 213) {
        frame.size.height = 213;
    }
    %orig(frame);
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    // The collapsed nav-bar header shown on scroll also has a full-bleed gray background — hide it.
    for (UIView *sub in self.subviews)
        if ([sub class] == [UIView class] &&
            (CGRectIsInfinite(sub.frame) || sub.frame.size.width > 100000.0)) {
            sub.hidden = YES;
            sub.alpha = 0.0;
        }

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

// Secondary contact view (tap "info" in details): a big opaque UIView sits over our custom background.
// Clear the container and hide plain-UIView backgrounds so the background shows through.
%hook CNContactHeaderStaticDisplayView

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    self.backgroundColor = [UIColor clearColor];
    // The gray background is the only plain UIView here; hide it regardless of frame (the parallax
    // resizes it and un-hides it on scroll, so re-hide it on every layout).
    for (UIView *sub in self.subviews)
        if ([sub class] == [UIView class]) {
            sub.hidden = YES;
            sub.alpha = 0.0;
        }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    self.backgroundColor = [UIColor clearColor];
    for (UIView *sub in self.subviews)
        if ([sub class] == [UIView class]) {
            sub.hidden = YES;
            sub.alpha = 0.0;
        }
}

%end

// The collapsed header shown on scroll has its own full-bleed gray UIView (responds to alpha, not
// hidden). Zero it and replace it with the nav bar's frosted blur, spanning window-top to its bottom.
%hook CNContactHeaderCollapsedView

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    self.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = NO;

    UIVisualEffectView *blur = nil;
    for (UIView *sub in self.subviews) {
        if (sub.tag == 4420) { blur = (UIVisualEffectView *)sub; continue; }   // our blur
        if ([sub class] == [UIView class]) sub.alpha = 0.0;
    }

    if (!blur) {
        blur = [[UIVisualEffectView alloc] initWithEffect:
                [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular]];
        blur.tag = 4420;
        blur.userInteractionEnabled = NO;
    }
    [self insertSubview:blur atIndex:0];

    // Span from the window top (above self) down to the header's own bottom.
    CGFloat top = [self convertPoint:CGPointZero fromView:nil].y;   // window top in self's coords
    blur.frame = CGRectMake(0.0, top, self.bounds.size.width, CGRectGetMaxY(self.bounds) - top + 36.0);

    CAGradientLayer *mask = [blur.layer.mask isKindOfClass:[CAGradientLayer class]]
        ? (CAGradientLayer *)blur.layer.mask : nil;
    if (!mask) {
        mask = [CAGradientLayer layer];
        mask.actions = @{@"position": [NSNull null], @"bounds": [NSNull null], @"frame": [NSNull null]};
        blur.layer.mask = mask;
    }
    // Full to 40%, ~55% strength at 75%, faded to clear at the bottom.
    mask.colors = @[(id)[UIColor colorWithWhite:0.0 alpha:1.0].CGColor,
                    (id)[UIColor colorWithWhite:0.0 alpha:1.0].CGColor,
                    (id)[UIColor colorWithWhite:0.0 alpha:0.55].CGColor,
                    (id)[UIColor colorWithWhite:0.0 alpha:0.0].CGColor];
    mask.locations = @[@0.0, @0.40, @0.75, @1.0];
    mask.frame = blur.bounds;

    // Strip the material's built-in darkening so the blur is colorless and the tint reads as a real
    // translucent color (also lightens the whole effect).
    Class subCls = NSClassFromString(@"_UIVisualEffectSubview");
    for (UIView *sub in blur.subviews)
        if ([sub isKindOfClass:subCls]) sub.backgroundColor = [UIColor clearColor];

    // Inherit the nav bar tint — per-contact if set, else global; nil (plain frosted) if unset.
    NSString *tintKey = isDarkMode() ? @"navBarTintColorDark" : @"navBarTintColor";
    UIColor *tint = colorFromHex(effectiveValueForKey(tintKey));
    UIView *overlay = [blur.contentView viewWithTag:4421];
    if (tint) {
        if (!overlay) {
            overlay = [[UIView alloc] init];
            overlay.tag = 4421;
            overlay.userInteractionEnabled = NO;
            overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [blur.contentView addSubview:overlay];
        }
        overlay.frame = blur.contentView.bounds;
        overlay.backgroundColor = tint;
    } else if (overlay) {
        [overlay removeFromSuperview];
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    [self setNeedsLayout];
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
            for (UIView *contentSubview in blurView.contentView.subviews) {
                if ([contentSubview class] == [UIView class]) {
                    contentSubview.frame = blurView.contentView.bounds;
                    break;
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

static UIView *wamMakePlatterContainer(NSInteger tag) {
    UIView *c = [[UIView alloc] init];
    c.tag = tag;
    c.userInteractionEnabled = NO;
    c.clipsToBounds = NO;
    c.layer.shadowColor = [UIColor blackColor].CGColor;
    c.layer.shadowOpacity = 0.26;
    c.layer.shadowRadius = 3.5;
    c.layer.shadowOffset = CGSizeMake(0.0, 1.0);
    UIVisualEffectView *fxv = [[UIVisualEffectView alloc] initWithEffect:
        [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular]];
    fxv.userInteractionEnabled = NO;
    fxv.clipsToBounds = YES;
    [c addSubview:fxv];
    return c;
}

static UIView *wamFindPlatterContainer(UIView *host, NSInteger tag) {
    for (UIView *s in host.subviews)
        if (s.tag == tag && s.subviews.count &&
            [s.subviews.firstObject isKindOfClass:[UIVisualEffectView class]])
            return s;
    return nil;
}

static void wamLayoutPlatterContainer(UIView *container, CGRect frame, CGFloat cornerRadius, BOOL globalColor,
                                       NSString *lgPrefix, const void *lgKey, BOOL wantNavSnapshot) {
    static const NSInteger kWAMPlatterTintTag = 4402;
    container.frame = frame;

    // Un-clip every ancestor up to the nav bar so the platter's drop shadow isn't cut off. Also force
    // shouldRasterize off: _UIButtonBarButton (and toolbar buttons generally) commonly get rasterized by
    // UIKit for perf, which bakes the view into a static bitmap — any live backdrop/blur nested inside then
    // can't sample live content at all and just shows whatever was behind it at bake time, unblurred. That
    // reads exactly as "acts like the blur isn't even there."
    for (UIView *a = container.superview; a; a = a.superview) {
        a.clipsToBounds = NO;
        a.layer.shouldRasterize = NO;
        if ([a isKindOfClass:%c(CKAvatarNavigationBar)] || [a isKindOfClass:[UINavigationBar class]]) break;
    }

    UIVisualEffectView *fxv = (UIVisualEffectView *)container.subviews.firstObject;
    fxv.frame = container.bounds;
    fxv.layer.cornerRadius = cornerRadius;
    if (@available(iOS 13.0, *)) fxv.layer.cornerCurve = kCACornerCurveContinuous;
    container.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:container.bounds cornerRadius:cornerRadius].CGPath;

    // Strip the material's built-in tint so the blur is colorless — then a user color reads as a real
    // translucent tint (not solid) while the plain blur still shows through.
    Class subCls = NSClassFromString(@"_UIVisualEffectSubview");
    for (UIView *sub in fxv.subviews)
        if ([sub isKindOfClass:subCls]) sub.backgroundColor = [UIColor clearColor];

    // Platter Color tints the stock blur (fxv) — once Liquid (Gl)ass glass is active, tinting happens inside
    // the glass's own layer instead (see wamApplyLiquidAssGlass), so this stays scoped to non-glass mode to
    // avoid painting both at once.
    UIView *tintOverlay = nil;
    for (UIView *s in fxv.contentView.subviews)
        if (s.tag == kWAMPlatterTintTag) { tintOverlay = s; break; }
    UIColor *tint = wamShouldUseLiquidAssGlass() ? nil : getNavPlatterColor(globalColor);
    if (tint) {
        if (!tintOverlay) {
            tintOverlay = [[UIView alloc] init];
            tintOverlay.tag = kWAMPlatterTintTag;
            tintOverlay.userInteractionEnabled = NO;
            [fxv.contentView addSubview:tintOverlay];
        }
        tintOverlay.frame = fxv.contentView.bounds;
        tintOverlay.backgroundColor = tint;
    } else if (tintOverlay) {
        [tintOverlay removeFromSuperview];
    }

    // Liquid (Gl)ass compatibility (beta): purely additive, exactly like the search platter (which works) —
    // fxv/tint above are left completely untouched, and glass is added as an extra layer behind them. Each
    // caller passes its own dedicated key, mirroring search's own kWAMLiquidAssSearchKey, rather than sharing
    // one key across every platter type.
    wamApplyLiquidAssGlass(container, fxv, cornerRadius, lgKey, lgPrefix);
    // Conv-list only (Edit/Compose) — chat's back/call/name already look right without it.
    if (wantNavSnapshot) {
        wamUpdateNavSnapshot(container, cornerRadius);
    } else {
        UIView *staleSnap = objc_getAssociatedObject(container, &kWAMNavSnapshotKey);
        if (staleSnap) [staleSnap removeFromSuperview];
    }
}

static void wamApplyNavButtonPlatter(UIView *host) {
    static const NSInteger kWAMNavPlatterTag = 4400;
    UIView *platter = wamFindPlatterContainer(host, kWAMNavPlatterTag);

    // The conversation-list Edit button (a _UIButtonBarButton) reads the global value; the chat back and
    // call buttons honor any per-contact override.
    BOOL blurOn = [host isKindOfClass:%c(_UIButtonBarButton)] ? isNavButtonBlurEnabledGlobal()
                                                              : isNavButtonBlurEnabled();
    BOOL enabled = isTweakEnabled() && isModernNavBarEnabled() && blurOn;
    BOOL isBack = [host isKindOfClass:%c(CKCanvasBackButtonView)];

    // Clear any prior content inset (back button only) so glyph positions measure true, not shifted.
    if (isBack) {
        for (UIView *sub in host.subviews)
            if (sub != platter) sub.transform = CGAffineTransformIdentity;
    }

    // Union of the visible glyphs (icon image + any badge label) in host coords, plus a count: one
    // glyph → a clean circle centered on it; two or more (chevron + unread badge, or name + chevron)
    // → a pill fitted to the pair.
    CGRect content = CGRectNull;   // union of all glyphs
    CGRect anchor = CGRectNull;    // the primary (leftmost) glyph — chevron / call icon
    BOOL anchorIsLabel = NO;       // primary glyph is text (→ pill) vs an icon (→ circle)
    NSInteger glyphCount = 0;
    if (enabled) {
        NSMutableArray *queue = [NSMutableArray arrayWithArray:host.subviews];
        while (queue.count) {
            UIView *v = queue.firstObject; [queue removeObjectAtIndex:0];
            if (v == platter || v.tag == kWAMNavSnapshotTag) continue;
            BOOL visible = !v.hidden && v.alpha > 0.05;
            BOOL isGlyph = ([v isKindOfClass:[UIImageView class]] && ((UIImageView *)v).image) ||
                           ([v isKindOfClass:[UILabel class]] && ((UILabel *)v).text.length);
            if (visible && isGlyph && v.bounds.size.width > 0 && v.bounds.size.height > 0) {
                CGRect r = [v convertRect:v.bounds toView:host];
                content = CGRectIsNull(content) ? r : CGRectUnion(content, r);
                if (CGRectIsNull(anchor) || r.origin.x < anchor.origin.x) {
                    anchor = r;
                    anchorIsLabel = [v isKindOfClass:[UILabel class]];
                }
                glyphCount++;
            }
            [queue addObjectsFromArray:v.subviews];
        }
    }

    if (!enabled || CGRectIsNull(content)) {
        [platter removeFromSuperview];
        return;
    }

    CGRect frame;
    if (glyphCount <= 1 && anchorIsLabel) {
        // Single text glyph (e.g. the "Edit" button) → a pill wrapping the text, kept the same height as
        // the sibling circle button (same MAX(44, …) rule) so the two platters match.
        CGFloat h = MAX(44.0, anchor.size.height + 14.0);
        CGFloat w = content.size.width + 28.0;
        frame = CGRectMake(CGRectGetMidX(content) - w / 2.0, CGRectGetMidY(content) - h / 2.0, w, h);
    } else {
        // Base circle centred on the primary glyph (chevron / call / compose icon). With an unread
        // badge, extend the circle rightward into a pill so the chevron keeps the exact position it has
        // with no badge — only the right side grows to wrap the badge.
        CGFloat side = MAX(44.0, MAX(anchor.size.width, anchor.size.height) + 14.0);
        frame = CGRectMake(CGRectGetMidX(anchor) - side / 2.0,
                           CGRectGetMidY(anchor) - side / 2.0, side, side);
        if (glyphCount >= 2) {
            if (isBack) {
                CGFloat right = CGRectGetMaxX(content) + 12.0;
                if (right > CGRectGetMaxX(frame)) frame.size.width = right - CGRectGetMinX(frame);
                frame = CGRectInset(frame, 0.0, -0.65);   // a touch taller than the circle, matching FaceTime
            } else {
                // Contact-name row (name + "›"): a symmetric pill wrapping both.
                frame = CGRectInset(content, -13.0, -6.0);
            }
        }
    }

    // The back "‹" glyph sits right of its imageview centre; nudge its platter to sit centred on it.
    if (isBack) frame.origin.x += 2.0;

    // In the unread (pill) state the chevron+badge read a hair right of centre; nudge just the content
    // left so it sits centred in the (fixed) platter — the platter's left edge and size are unchanged.
    if (isBack && glyphCount >= 2) {
        for (UIView *sub in host.subviews)
            if (sub != platter) sub.transform = CGAffineTransformMakeTranslation(-3.0, 0.0);
    }

    if (!platter) {
        platter = wamMakePlatterContainer(kWAMNavPlatterTag);
        [host insertSubview:platter atIndex:0];
    }
    BOOL isConvListButton = [host isKindOfClass:%c(_UIButtonBarButton)];
    static char kWAMLiquidAssConvButtonKey;
    static char kWAMLiquidAssChatButtonKey;
    wamLayoutPlatterContainer(platter, frame, frame.size.height / 2.0,
                              isConvListButton,   // Edit = global color
                              isConvListButton ? kWAMLGPrefixSearchPill : kWAMLGPrefixButton,
                              isConvListButton ? &kWAMLiquidAssConvButtonKey : &kWAMLiquidAssChatButtonKey,
                              isConvListButton);
}

static char kWAMNameFontKey;

static void wamApplyNameShadow(UIView *canvas, CGRect platterFrameInCanvas, BOOL enabled) {
    static const NSInteger kWAMNameShadowTag = 4403;
    UIView *navbar = canvas;
    while (navbar && ![navbar isKindOfClass:%c(CKAvatarNavigationBar)]) navbar = navbar.superview;
    UIView *host = navbar ? navbar.superview : nil;
    UIView *shadow = host ? [host viewWithTag:kWAMNameShadowTag] : nil;

    if (!enabled || !host || CGRectIsEmpty(platterFrameInCanvas)) {
        [shadow removeFromSuperview];
        return;
    }
    if (!shadow) {
        shadow = [[UIView alloc] init];
        shadow.tag = kWAMNameShadowTag;
        shadow.userInteractionEnabled = NO;
        shadow.backgroundColor = [UIColor clearColor];
        shadow.layer.shadowColor = [UIColor blackColor].CGColor;
        shadow.layer.shadowOpacity = 0.26;
        shadow.layer.shadowRadius = 3.5;
        shadow.layer.shadowOffset = CGSizeMake(0.0, 1.5);
    }
    NSUInteger navIdx = [host.subviews indexOfObject:navbar];
    NSUInteger shIdx = [host.subviews indexOfObject:shadow];
    if (shIdx == NSNotFound || shIdx > navIdx) [host insertSubview:shadow belowSubview:navbar];
    gWAMNameShadow = shadow;
    if (!gWAMChatLeaving) shadow.alpha = 1.0;   // reset if reused after a fade — but not mid-leave, or it'd undo the fade
    shadow.frame = [canvas convertRect:platterFrameInCanvas toView:host];
    shadow.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:shadow.bounds cornerRadius:shadow.bounds.size.height / 2.0].CGPath;
}

static void wamApplyNamePlatter(UIView *nameView) {
    static const NSInteger kWAMNamePlatterTag = 4401;

    UIView *collectionView = nameView.superview;
    UIView *canvas = collectionView;
    while (canvas && ![canvas isKindOfClass:%c(CKNavigationBarCanvasView)]) canvas = canvas.superview;

    UIView *platter = canvas ? wamFindPlatterContainer(canvas, kWAMNamePlatterTag) : nil;

    // In the landscape split the chat nav bar is compact and shows the stock centred name — the name
    // platter + its shadow have no room and look wrong, so tear them down and leave the name stock.
    BOOL enabled = isTweakEnabled() && isModernNavBarEnabled() && isNavButtonBlurEnabled() && !wamIsLandscape();

    BOOL on = enabled && canvas;

    // Skip transitional/degenerate geometry: rotation collapses the canvas toward ~0 width mid-animation,
    // and centering the name against that produced negative-x platters/shadows that landed in the
    // back-button area. Leave the last-good layout until the canvas settles to a real width.
    if (on && canvas.bounds.size.width < 200.0) return;

    // The name label, the "›" chevron, and an optional shared-location subtitle under the name.
    UILabel *label = nil; UIImageView *chev = nil; UILabel *subtitle = nil;
    for (UIView *v in nameView.subviews) {
        if ([v isKindOfClass:[UILabel class]] && ((UILabel *)v).text.length) {
            UILabel *l = (UILabel *)v;
            if (!label) label = l;
            else if (!subtitle) {   // two text lines → the higher is the name, the lower is the location
                if (l.frame.origin.y < label.frame.origin.y) { subtitle = label; label = l; }
                else subtitle = l;
            }
        }
        else if (!chev && [v isKindOfClass:[UIImageView class]] && ((UIImageView *)v).image) chev = (UIImageView *)v;
    }

    // Enlarge via a bigger font (crisp — a transform makes the row re-truncate to "Gr…") plus a scaled
    // chevron, laid out as a group centred where the original sat. Reset both when the feature is off.
    CGRect content = CGRectNull;
    if (label) {
        UIFont *orig = objc_getAssociatedObject(label, &kWAMNameFontKey);
        if (!orig) { orig = label.font; objc_setAssociatedObject(label, &kWAMNameFontKey, orig, OBJC_ASSOCIATION_RETAIN_NONATOMIC); }
        if (on) {
            CGFloat gcx = (CGRectGetMinX(label.frame) +
                           (chev ? CGRectGetMaxX(chev.frame) : CGRectGetMaxX(label.frame))) / 2.0;
            CGFloat gcy = label.center.y;

            label.transform = CGAffineTransformIdentity;
            label.font = [orig fontWithSize:orig.pointSize * 1.2];
            CGSize fit = [label sizeThatFits:CGSizeMake(CGFLOAT_MAX, CGFLOAT_MAX)];
            CGFloat lW = ceil(fit.width), lH = ceil(fit.height);

            CGFloat chevScale = 1.4, gap = 3.0;
            CGFloat chW = chev ? chev.bounds.size.width * chevScale : 0.0;
            CGFloat totalW = lW + (chev ? gap + chW : 0.0);
            CGFloat x = gcx - totalW / 2.0;

            label.frame = CGRectMake(x, gcy - lH / 2.0, lW, lH);
            content = [label convertRect:label.bounds toView:nameView];
            if (chev) {
                chev.transform = CGAffineTransformMakeScale(chevScale, chevScale);
                chev.center = CGPointMake(x + lW + gap + chW / 2.0, gcy);
                content = CGRectUnion(content, [chev convertRect:chev.bounds toView:nameView]);
            }
            // Grow to fit the shared-location subtitle (unchanged in size), keeping the same padding.
            if (subtitle)
                content = CGRectUnion(content, [subtitle convertRect:subtitle.bounds toView:nameView]);
        } else {
            label.font = orig;
            label.transform = CGAffineTransformIdentity;
            if (chev) chev.transform = CGAffineTransformIdentity;
        }
    }

    if (!on || CGRectIsNull(content)) {
        [platter removeFromSuperview];
        wamApplyNameShadow(canvas, CGRectZero, NO);
        return;
    }

    // Wider, and taller upward: the top rides up behind the avatar while the text stays in the lower
    // part of the platter, like iOS 26.
    CGFloat padX = 13.0, padTop = 9.0, padBottom = subtitle ? 11.0 : 7.0;
    CGRect pill = CGRectMake(content.origin.x - padX, content.origin.y - padTop,
                             content.size.width + padX * 2.0,
                             content.size.height + padTop + padBottom);
    CGRect frame = [nameView convertRect:pill toView:canvas];

    if (!platter) platter = wamMakePlatterContainer(kWAMNamePlatterTag);
    // Sit just behind the (transparent) title collection view, so it's behind the name text.
    NSUInteger idx = [canvas.subviews indexOfObject:collectionView];
    if (idx == NSNotFound) idx = 0;
    if (platter.superview == canvas && [canvas.subviews indexOfObject:platter] < idx) idx--;
    [canvas insertSubview:platter atIndex:idx];
    static char kWAMLiquidAssNamePlateKey;
    wamLayoutPlatterContainer(platter, frame, frame.size.height / 2.0, NO, kWAMLGPrefixButton,
                              &kWAMLiquidAssNamePlateKey, NO);   // chat name — per-contact

    // The blur container's own drop shadow is cut at the nav bar edge — disable it and render the
    // name's shadow via a separate, unbounded view behind the nav bar instead. Skip it entirely when Liquid
    // (Gl)ass is active — a drop shadow sitting on top of the glass reads as messy/muddy rather than lifted.
    platter.layer.shadowOpacity = 0.0;
    wamApplyNameShadow(canvas, frame, !wamShouldUseLiquidAssGlass());
}

%hook CKCanvasBackButtonView

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    wamApplyNavButtonPlatter(self);
    [self applyCanvasBackButtonStyle];
}

- (void)setFrame:(CGRect)frame {
    if (isTweakEnabled() && isModernNavBarEnabled() && isNavButtonBlurEnabled())
        frame.origin.x += 15.0;
    %orig(frame);
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
    [self.superview setNeedsLayout];   // re-run setFrame with the new toggle state
    wamApplyNavButtonPlatter(self);
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
        } else if ([subview isKindOfClass:[UIImageView class]]) {
            ((UIImageView *)subview).tintColor = textColor;
        } else {
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
    if (!isTweakEnabled()) return;
    if (isBlurBubblesEnabled() || isCustomBubbleColorsEnabled()) [self applyTypingIndicatorColors];
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;
    if (isBlurBubblesEnabled() || isCustomBubbleColorsEnabled()) [self applyTypingIndicatorColors];
}

- (void)setIndicatorLayer:(CALayer *)layer {
    %orig;
    if (!isTweakEnabled()) return;
    if (isBlurBubblesEnabled() || isCustomBubbleColorsEnabled())
        dispatch_async(dispatch_get_main_queue(), ^{
            [self applyTypingIndicatorColors];
        });
}

%new
- (void)wamRemoveTypingBlur {
    UIView *blur = objc_getAssociatedObject(self, &kWAMTypingBlurKey);
    if (blur) [blur removeFromSuperview];
    objc_setAssociatedObject(self, &kWAMTypingBlurKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

%new
- (void)wamApplyTypingBlur:(CALayer *)bubbleContainer tint:(UIColor *)tint {
    CGRect pill = [self.layer convertRect:bubbleContainer.bounds fromLayer:bubbleContainer];
    if (pill.size.width < 5 || pill.size.height < 5) {
        CGRect u = CGRectNull;
        for (CALayer *sl in bubbleContainer.sublayers) {
            CGRect r = [self.layer convertRect:sl.bounds fromLayer:sl];
            if (r.size.width < 2 || r.size.height < 2) continue;
            u = CGRectIsNull(u) ? r : CGRectUnion(u, r);
        }
        if (!CGRectIsNull(u)) pill = u;
    }
    if (pill.size.width < 5 || pill.size.height < 5) return;
    CGFloat inset = MIN(pill.size.width * 0.14, 11.0);
    pill = CGRectInset(pill, inset, 0);

    UIVisualEffectView *blur = objc_getAssociatedObject(self, &kWAMTypingBlurKey);
    if (!blur) {
        blur = wamMakeBlurView(pill);
        blur.userInteractionEnabled = NO;
        blur.clipsToBounds = YES;
        blur.layer.zPosition = -1;
        objc_setAssociatedObject(self, &kWAMTypingBlurKey, blur, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (blur.superview != self) [self addSubview:blur];
    blur.frame = pill;
    blur.layer.cornerRadius = pill.size.height / 2.0;
    wamStripEffectTint(blur);
    blur.contentView.backgroundColor = tint;
}

%new
- (void)applyTypingIndicatorColors {
    UIColor *typingColor = getReceivedBubbleColor();

    CALayer *indicatorLayer = nil;
    @try { indicatorLayer = [self valueForKey:@"indicatorLayer"]; } @catch (NSException *e) { return; }
    if (!indicatorLayer || indicatorLayer.sublayers.count < 2) return;

    CALayer *bubbleContainer = indicatorLayer.sublayers[0];

    if (isBlurBubblesEnabled() && !wamViewInNonChatContext(self)) {
        [self wamApplyTypingBlur:bubbleContainer tint:typingColor];
        for (CALayer *bubbleLayer in bubbleContainer.sublayers)
            bubbleLayer.backgroundColor = [UIColor clearColor].CGColor;
        return;
    }

    [self wamRemoveTypingBlur];
    if (!isCustomBubbleColorsEnabled() || !typingColor) return;

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
    if (!isTweakEnabled()) return;

    if (self.window) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(wamHandleNavCanvasPrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        return;
    }

    if (isCustomTextColorsEnabled()) {
        for (UIView *sub in self.subviews) {
            if ([sub isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)sub;
                label.textColor = getConversationListTitleColor();
            }
        }
    }
    [self wamApplyNavCanvasButtonTint:self];
    [self wamApplyComposeChromeTheme];
}

- (void) layoutSubviews {
    %orig;
    // Let the platter drop shadows spill past the canvas bounds instead of being clipped.
    self.clipsToBounds = !(isTweakEnabled() && isModernNavBarEnabled() && isNavButtonBlurEnabled());
    if (!isTweakEnabled()) return;
    [self wamApplyNavCanvasButtonTint:self];
    [self wamApplyComposeChromeTheme];
}

// MessagesViewService (the sharesheet compose host) has no nav bar / title-control system at all — its
// "New Message"/"New iMessage"/"New MMS" title and its Cancel button are just a plain UILabel and UIButton
// sitting directly on this canvas (confirmed via device diagnostics), so none of the main app's title/nav-
// button hooks (_UINavigationBarTitleControl, the BackButton/CallButton-class-name walk above) ever see
// them. Scoped to extension processes only — the main app already has its own dedicated, working mechanisms
// for these, and this shouldn't touch that.
%new
- (void)wamApplyComposeChromeTheme {
    if (!isTweakEnabled() || !wamIsNotificationExtension()) return;
    UIColor *titleColor = getChatContactNameColor();
    UIColor *buttonColor = getAdvancedTintColorForView(@"advancedNavButtonColor", @"advancedNavButtonColorDark", nil, self)
        ?: getSystemTintColor();
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UILabel class]] && ((UILabel *)sub).text.length) {
            if (titleColor) ((UILabel *)sub).textColor = titleColor;
        } else if ([sub isKindOfClass:[UIButton class]] && buttonColor) {
            ((UIButton *)sub).tintColor = buttonColor;
        }
    }
}

// Catch every attempt to re-enable clipping (e.g. during a push transition) so the shadows always spill.
- (void)setClipsToBounds:(BOOL)clipsToBounds {
    if (isTweakEnabled() && isModernNavBarEnabled() && isNavButtonBlurEnabled()) clipsToBounds = NO;
    %orig(clipsToBounds);
}

%new
- (void) wamHandleNavCanvasPrefsChanged {
    refreshPrefs();
    [self wamApplyNavCanvasButtonTint:self];
}

%new
- (void) wamApplyNavCanvasButtonTint:(UIView *)view {
    static const char kWAMNavImgTintKey = 0;
    UIColor *tint = getAdvancedTintColorForView(@"advancedNavButtonColor", @"advancedNavButtonColorDark", nil, self);
    if (!tint) tint = getSystemTintColor();

    NSMutableArray *queue = [NSMutableArray arrayWithObject:view];
    while (queue.count) {
        UIView *v = queue.firstObject;
        [queue removeObjectAtIndex:0];
        NSString *cls = NSStringFromClass([v class]);
        if ([cls containsString:@"BackButton"] || [cls containsString:@"CallButton"] ||
            [cls containsString:@"UnifiedCall"] || [cls containsString:@"CanvasBack"]) {
            NSMutableArray *innerQueue = [NSMutableArray arrayWithObject:v];
            while (innerQueue.count) {
                UIView *iv2 = innerQueue.firstObject;
                [innerQueue removeObjectAtIndex:0];
                if ([iv2 isKindOfClass:[UIImageView class]]) {
                    UIImageView *iv = (UIImageView *)iv2;
                    if (tint) {
                        if (!objc_getAssociatedObject(iv, &kWAMNavImgTintKey)) {
                            objc_setAssociatedObject(iv, &kWAMNavImgTintKey, @YES,
                                OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        }
                        iv.tintColor = tint;
                    } else {
                        if (objc_getAssociatedObject(iv, &kWAMNavImgTintKey)) {
                            iv.tintColor = nil;
                            objc_setAssociatedObject(iv, &kWAMNavImgTintKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                        }
                    }
                }
                for (UIView *sub in iv2.subviews) [innerQueue addObject:sub];
            }
        }
        for (UIView *sub in v.subviews) [queue addObject:sub];
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

// The name platter can extend below the nav content bounds (tall for a two-line name + location). The
// canvas already stops clipping, but its ancestor _UINavigationBarContentView clips too and cuts the
// platter's bottom edge. Let it spill while the platter feature is on.
%hook _UINavigationBarContentView

- (void)layoutSubviews {
    %orig;
    BOOL noClip = isTweakEnabled() && isModernNavBarEnabled() &&
                  (isNavButtonBlurEnabled() || isNavButtonBlurEnabledGlobal());
    ((UIView *)self).clipsToBounds = !noClip;
}

- (void)setClipsToBounds:(BOOL)clipsToBounds {
    if (isTweakEnabled() && isModernNavBarEnabled() &&
        (isNavButtonBlurEnabled() || isNavButtonBlurEnabledGlobal())) clipsToBounds = NO;
    %orig(clipsToBounds);
}

%end

%hook CKNavBarUnifiedCallButton

// Move the call button down in the landscape split by adjusting the frame UIKit SETS (which sticks), not a
// transform (which UIKit re-lays-out and either absorbs or drives into a feedback loop — measured both). The
// platter and glyph are subviews, so they move with the button and the platter stays full-size. This is the
// same setFrame-nudge the back button already uses. +10 lands the glyph centre on ~32, level with Edit/Compose.
- (void)setFrame:(CGRect)frame {
    if (isTweakEnabled() && isModernNavBarEnabled() && isNavButtonBlurEnabled() && wamIsLandscape())
        frame.origin.y += 10.0;
    %orig(frame);
}

%new
- (void)wamApplyCallButtonDrop {
    // Positioning is done in -setFrame:. Here just clear any stale transform a prior build may have left on
    // the button or its glyph, so it doesn't compound with the frame nudge.
    ((UIView *)self).transform = CGAffineTransformIdentity;
    NSMutableArray *q = [NSMutableArray arrayWithArray:((UIView *)self).subviews];
    while (q.count) {
        UIView *v = q.firstObject; [q removeObjectAtIndex:0];
        if ([v isKindOfClass:[UIImageView class]] && ((UIImageView *)v).image) { v.transform = CGAffineTransformIdentity; break; }
        [q addObjectsFromArray:v.subviews];
    }
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    [self wamApplyCallButtonDrop];
    wamApplyNavButtonPlatter((UIView *)self);
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || ![(UIView *)self window]) {
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        return;
    }
    [self wamApplyCallButtonDrop];
    wamApplyNavButtonPlatter((UIView *)self);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(wamCallBtnPrefsChanged)
        name:kPrefsChangedNotification object:nil];
}

%new
- (void)wamCallBtnPrefsChanged {
    refreshPrefs();
    [self wamApplyCallButtonDrop];
    wamApplyNavButtonPlatter((UIView *)self);
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook CNVisualIdentityAvatarContainerView

- (void)layoutSubviews {
    %orig;
    // Off in the landscape split (compact bar shows the stock avatar with no room for a drop shadow).
    BOOL on = isTweakEnabled() && isModernNavBarEnabled() && isNavButtonBlurEnabled() && !wamIsLandscape();
    // The avatar lives in a cell in the title collection view, in front of the name platter (which sits
    // behind that collection view). So render its shadow as a separate view at the back of the canvas,
    // where the name platter overlaps it — keeping the shadow behind the platter and its text. Find the
    // canvas UNCONDITIONALLY (even when off) so a stale shadow from a prior on-state can still be removed.
    UIView *canvas = nil;
    for (UIView *a = self.superview; a; a = a.superview)
        if ([a isKindOfClass:%c(CKNavigationBarCanvasView)]) { canvas = a; break; }

    static const NSInteger kWAMAvatarShadowTag = 4405;
    UIView *shadow = canvas ? [canvas viewWithTag:kWAMAvatarShadowTag] : nil;
    self.layer.shadowOpacity = 0.0;

    if (!on || !canvas || !self.subviews.count) {
        [shadow removeFromSuperview];
        return;
    }
    // Skip transitional/degenerate geometry (rotation collapses the canvas mid-animation → far-left shadow).
    if (canvas.bounds.size.width < 200.0) return;
    if (!shadow) {
        shadow = [[UIView alloc] init];
        shadow.tag = kWAMAvatarShadowTag;
        shadow.userInteractionEnabled = NO;
        shadow.backgroundColor = [UIColor clearColor];
        shadow.layer.shadowColor = [UIColor blackColor].CGColor;
        shadow.layer.shadowOpacity = 0.26;
        // Downward-only (offset >= radius) so there's nothing above the image to cut or darken.
        shadow.layer.shadowRadius = 3.0;
        shadow.layer.shadowOffset = CGSizeMake(0.0, 3.5);
    }
    [canvas insertSubview:shadow atIndex:0];   // behind the name platter + collection view
    UIView *img = self.subviews.firstObject;
    shadow.frame = [self convertRect:(img ? img.frame : self.bounds) toView:canvas];
    shadow.layer.shadowPath = [UIBezierPath bezierPathWithOvalInRect:shadow.bounds].CGPath;
}

%end

static BOOL wamIsConvListNavButton(UIResponder *btn) {
    UIResponder *r = btn.nextResponder;
    for (int i = 0; r && i < 15; i++) {
        if ([r isKindOfClass:[UINavigationController class]])
            return [((UINavigationController *)r).topViewController
                       isKindOfClass:%c(CKConversationListCollectionViewController)];
        r = r.nextResponder;
    }
    return NO;
}

// Compose is an image-configuration button that drops its glyph if you transform it or insert subviews
// into it. So platter it non-invasively: a separate blur view sitting BEHIND the button in the button
// bar, and shift the glyph by transforming the wrapper (_UIButtonBarButton), not the config button.
static void wamApplyComposePlatter(UIView *bv) {
    static const NSInteger kComposePlatterTag = 4413;
    UIView *superv = bv.superview;
    UIView *platter = nil;
    if (superv)
        for (UIView *s in superv.subviews)
            if (s.tag == kComposePlatterTag) { platter = s; break; }

    BOOL on = isTweakEnabled() && isModernNavBarEnabled() && isNavButtonBlurEnabledGlobal();
    UIView *content = nil;
    for (UIView *s in bv.subviews)
        if ([s isKindOfClass:%c(_UIModernBarButton)]) { content = s; break; }
    UIImageView *glyph = nil;
    if (content) {
        NSMutableArray *q = [NSMutableArray arrayWithArray:content.subviews];
        while (q.count) {
            UIView *v = q.firstObject; [q removeObjectAtIndex:0];
            if ([v isKindOfClass:[UIImageView class]] && ((UIImageView *)v).image) { glyph = (UIImageView *)v; break; }
            [q addObjectsFromArray:v.subviews];
        }
    }

    if (!on || !superv || !glyph || !bv.window || bv.hidden) {
        bv.transform = CGAffineTransformIdentity;
        [platter removeFromSuperview];
        return;
    }

    // Shift the glyph inward + down (inline with Edit) by moving the wrapper button. The −8 x makes the
    // platter's gap from the right screen edge match the chat call/FaceTime button's platter. In landscape
    // the down-shift matches Edit/FaceTime (see wamNavButtonDropY).
    bv.transform = CGAffineTransformMakeTranslation(-8.0, wamNavButtonDropY(YES));

    // Frosted platter behind the button, a circle around the glyph's now-shifted position.
    CGRect g = [glyph convertRect:glyph.bounds toView:superv];
    CGFloat side = MAX(44.0, MAX(g.size.width, g.size.height) + 14.0);
    CGRect frame = CGRectMake(CGRectGetMidX(g) - side / 2.0, CGRectGetMidY(g) - side / 2.0, side, side);
    if (!platter) platter = wamMakePlatterContainer(kComposePlatterTag);
    [superv insertSubview:platter belowSubview:bv];
    static char kWAMLiquidAssComposeKey;
    wamLayoutPlatterContainer(platter, frame, frame.size.height / 2.0, YES, kWAMLGPrefixSearchPill,
                              &kWAMLiquidAssComposeKey, YES);
}

// Edit vs Compose by CONTENT, not position: Edit has a text label; Compose is image-only. Position is
// unreliable mid-transition, and misdetecting Compose as Edit applies Edit's content transform, which
// drops Compose's image-config glyph.
static UIView *wamModernBarContent(UIView *bv) {
    for (UIView *s in bv.subviews)
        if ([s isKindOfClass:%c(_UIModernBarButton)]) return s;
    return nil;
}
static BOOL wamIsEditListButton(UIView *bv) {
    UIView *content = wamModernBarContent(bv);
    if (!content) return NO;
    NSMutableArray *q = [NSMutableArray arrayWithArray:content.subviews];
    while (q.count) {
        UIView *v = q.firstObject; [q removeObjectAtIndex:0];
        if ([v isKindOfClass:[UILabel class]] && ((UILabel *)v).text.length > 0) return YES;
        [q addObjectsFromArray:v.subviews];
    }
    return NO;
}

// Dispatch a conversation-list nav button: Edit uses the in-button platter; Compose uses the safe
// behind-the-button platter.
static void wamStyleListButton(UIView *bv) {
    if (wamIsEditListButton(bv)) {
        UIView *content = wamModernBarContent(bv);
        BOOL on = isTweakEnabled() && isModernNavBarEnabled() && isNavButtonBlurEnabledGlobal();
        if (on && content && bv.window) {
            bv.clipsToBounds = NO;
            content.clipsToBounds = NO;
            // Portrait nudges the Edit content +16 right for spacing from the screen edge. In the narrow
            // landscape split column the safe-area inset already provides that gap, and +16 shoves "Edit"
            // into the centred title — so don't shift it horizontally there. Drop it lower in landscape so
            // it lines up with Compose/FaceTime (see wamNavButtonDropY).
            content.transform = CGAffineTransformMakeTranslation(wamIsLandscape() ? 0.0 : 16.0,
                                                                 wamNavButtonDropY(YES));
        } else if (content) {
            content.transform = CGAffineTransformIdentity;
        }
        wamApplyNavButtonPlatter(bv);   // self-manages add/remove by the toggle
        if (content) [bv bringSubviewToFront:content];
    } else {
        wamApplyComposePlatter(bv);
    }
}

%hook _UIButtonBarButton

- (void)layoutSubviews {
    %orig;
    UIView *bv = (UIView *)self;
    if (!isTweakEnabled() || !wamIsConvListNavButton((UIResponder *)bv)) return;

    wamStyleListButton(bv);
}

- (void)didMoveToWindow {
    %orig;
    if (![(UIView *)self window]) {
        // Leaving the window (e.g. pushing a chat): drop our wrapper transform and separate platter so
        // the Compose config button re-renders its glyph cleanly when it comes back.
        UIView *bv = (UIView *)self;
        bv.transform = CGAffineTransformIdentity;
        if (bv.superview)
            for (UIView *s in [bv.superview.subviews copy])
                if (s.tag == 4413) [s removeFromSuperview];   // kComposePlatterTag
        [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
        return;
    }
    if (isTweakEnabled() && wamIsConvListNavButton((UIResponder *)self))
        wamStyleListButton((UIView *)self);
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(wamListBtnPrefsChanged)
        name:kPrefsChangedNotification object:nil];
}

%new
- (void)wamListBtnPrefsChanged {
    refreshPrefs();
    if (wamIsConvListNavButton((UIResponder *)self))
        wamStyleListButton((UIView *)self);
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
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
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
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
    // This is the VISIBLE iOS 17 chat background. Observe prefs changes so a per-contact preset applied
    // in-chat refreshes it live — otherwise it only updates on re-entry (didMoveToWindow/Superview).
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(wamHandleWrapperPrefsChanged)
        name:kPrefsChangedNotification object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    %orig;
}

%new
- (void)wamHandleWrapperPrefsChanged {
    if (!isTweakEnabled() || !isiOS17OrHigher() || !self.window) return;
    refreshPrefs();
    // Force a fresh rebuild: drop the existing wrapper bg so applyWrapperBackground recreates it (an
    // in-place .image swap doesn't reliably re-display, and preset images are copied with an unchanged
    // mtime so nothing else signals "reload").
    UIView *contentView = nil;
    for (UIView *subview in self.subviews)
        if ([subview isKindOfClass:[UIView class]] && ![subview isKindOfClass:[UIImageView class]]) { contentView = subview; break; }
    UIView *bgHost = (contentView && [contentView isKindOfClass:[UIScrollView class]]) ? self : (contentView ?: self);
    [[bgHost viewWithTag:kWrapperBackgroundImageTag] removeFromSuperview];
    [self applyWrapperBackground];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled() || !isiOS17OrHigher()) return;
    if (@available(iOS 13.0, *)) {
        // On a light/dark switch the per-contact background has a different image for the new mode; the
        // wrapper doesn't otherwise get told, so rebuild it here (previously required leaving the chat).
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            if ([self respondsToSelector:@selector(wamHandleWrapperPrefsChanged)])
                [self performSelector:@selector(wamHandleWrapperPrefsChanged)];
        }
    }
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

    {
        UIView *cv = nil;
        for (UIView *sub in self.subviews) {
            if ([sub isKindOfClass:[UIView class]] && ![sub isKindOfClass:[UIImageView class]]) { cv = sub; break; }
        }
        UIView *host = (cv && ![cv isKindOfClass:[UIScrollView class]]) ? cv : self;
        UIView *bg = [host viewWithTag:kWrapperBackgroundImageTag];
        if (bg && bg.superview == host && host.subviews.firstObject != bg) {
            wamPlaceBackgroundBelowTranscript(host, bg);
        }
    }

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
            wamPlaceBackgroundBelowTranscript(bgHost, existingImageView);
        } else {
            UIImageView *imageView = [[UIImageView alloc] initWithFrame:bgHost.bounds];
            imageView.tag = kWrapperBackgroundImageTag;
            imageView.image = chatBgImage;
            imageView.contentMode = UIViewContentModeScaleAspectFill;
            imageView.clipsToBounds = YES;
            imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            imageView.userInteractionEnabled = NO;
            wamPlaceBackgroundBelowTranscript(bgHost, imageView);
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

static UIView *wamFindLinkContainer(UIView *v) {
    UIView *p = v ? v.superview : nil; int hops = 0;
    while (p && hops < 6) {
        if ([NSStringFromClass(p.class) isEqualToString:@"RichLinkView"]) return p;
        p = p.superview; hops++;
    }
    return nil;
}

static void wamRemoveLinkBlur(UIView *container) {
    UIView *blur = objc_getAssociatedObject(container, &kWAMLinkBlurKey);
    if (blur) [blur removeFromSuperview];
    objc_setAssociatedObject(container, &kWAMLinkBlurKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void wamApplyLinkBlur(UIView *container) {
    if (!container) return;
    if (!isBlurBubblesEnabled()) { wamRemoveLinkBlur(container); return; }
    CGRect b = container.bounds;
    if (b.size.width < 5 || b.size.height < 5) return;

    UIVisualEffectView *blur = objc_getAssociatedObject(container, &kWAMLinkBlurKey);
    if (!blur) {
        blur = wamMakeBlurView(b);
        blur.userInteractionEnabled = NO;
        blur.clipsToBounds = YES;
        blur.layer.cornerRadius = 2.0;
        blur.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        objc_setAssociatedObject(container, &kWAMLinkBlurKey, blur, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    [container insertSubview:blur atIndex:0];
    blur.frame = container.bounds;
    wamStripEffectTint(blur);
    blur.contentView.backgroundColor = getLinkPreviewBackgroundColor();
}

%hook LPFlippedView

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled()) { %orig; return; }
    if (isBlurBubblesEnabled()) { %orig([UIColor clearColor]); return; }
    UIColor *customLinkColor = getLinkPreviewBackgroundColor();
    if (customLinkColor) { %orig(customLinkColor); return; }
    %orig;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    UIView *rlv = wamFindLinkContainer(self);
    if (!rlv) return;
    if (isBlurBubblesEnabled()) wamApplyLinkBlur(rlv);
    else wamRemoveLinkBlur(rlv);
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    if (isBlurBubblesEnabled()) self.backgroundColor = [UIColor clearColor];
    else {
        UIColor *customLinkColor = getLinkPreviewBackgroundColor();
        if (customLinkColor) self.backgroundColor = customLinkColor;
    }

    if (self.window) {
        UIView *rlv = wamFindLinkContainer(self);
        if (rlv) {
            if (isBlurBubblesEnabled()) wamApplyLinkBlur(rlv);
            else wamRemoveLinkBlur(rlv);
        }
    }

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
    if (isBlurBubblesEnabled()) self.backgroundColor = [UIColor clearColor];
    else {
        UIColor *customLinkColor = getLinkPreviewBackgroundColor();
        if (customLinkColor) self.backgroundColor = customLinkColor;
    }
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            refreshPrefs();
            if (isBlurBubblesEnabled()) self.backgroundColor = [UIColor clearColor];
            else {
                UIColor *customLinkColor = getLinkPreviewBackgroundColor();
                if (customLinkColor) self.backgroundColor = customLinkColor;
            }
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
    gWAMTapSetAt = gWAMCacheSetAt;

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

static void wamKillMessagesCallback(CFNotificationCenterRef center, void *observer,
                                    CFStringRef name, const void *object,
                                    CFDictionaryRef userInfo) {
    dispatch_async(dispatch_get_main_queue(), ^{ exit(0); });
}

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

    CFNotificationCenterAddObserver(
        CFNotificationCenterGetDarwinNotifyCenter(),
        NULL,
        (CFNotificationCallback)wamKillMessagesCallback,
        CFSTR("com.oakstheawesome.whatamessprefs/killMessages"),
        NULL,
        CFNotificationSuspensionBehaviorDeliverImmediately
    );
    dispatch_async(dispatch_get_main_queue(), ^{
        [WAMHeartbeatTarget shared];
    });

    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidBecomeActiveNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            gWAMMaskGeneration++;
        }];
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidReceiveMemoryWarningNotification
        object:nil queue:[NSOperationQueue mainQueue] usingBlock:^(NSNotification *n) {
            gWAMMaskGeneration++;
        }];
}

/* Made with love from the Show Me State. Support small content creators and local farmers! */
