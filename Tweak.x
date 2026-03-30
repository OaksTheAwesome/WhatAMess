#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <WAMTweakInterfaces.h>

/* ===================
  PREFERENCE THINGS 
==================== */

#define kPrefsChangedNotification @"com.oakstheawesome.whatamessprefs/prefsChanged"
#define kPrefsPlistPathRootless @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs.plist"
#define kPrefsPlistPathRootfull  @"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs.plist"

BOOL isDarkMode();

static NSMutableDictionary *cachedPrefs = nil;

static void reloadPrefs() {
    NSMutableDictionary *fromDisk = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefsPlistPathRootless];
    if (!fromDisk || fromDisk.count == 0) {
        fromDisk = [NSMutableDictionary dictionaryWithContentsOfFile:kPrefsPlistPathRootfull];
    }
    if (fromDisk && fromDisk.count > 0) {
        cachedPrefs = fromDisk;
        return;
    }

    CFPreferencesSynchronize(
        CFSTR("com.oakstheawesome.whatamessprefs"),
        kCFPreferencesCurrentUser,
        kCFPreferencesAnyHost
    );
    CFArrayRef keyList = CFPreferencesCopyKeyList(
        CFSTR("com.oakstheawesome.whatamessprefs"),
        kCFPreferencesCurrentUser,
        kCFPreferencesAnyHost
    );
    if (keyList) {
        cachedPrefs = (__bridge_transfer NSMutableDictionary *)CFPreferencesCopyMultiple(
            keyList,
            CFSTR("com.oakstheawesome.whatamessprefs"),
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        );
        CFRelease(keyList);
    }
    if (!cachedPrefs) {
        cachedPrefs = [NSMutableDictionary new];
    }
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

static NSString *getChatImagePath() {
    return isDarkMode()
        ? @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background_dark.jpg"
        : @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background.jpg";
}

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
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isChatColorBgEnabledDark" : @"isChatColorBgEnabled";
    return prefs[key] ? [prefs[key] boolValue] : NO;
}

BOOL isConvImageBgEnabled() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isConvImageBgEnabledDark" : @"isConvImageBgEnabled";
    return prefs[key] ? [prefs[key] boolValue] : NO;
}

BOOL isChatImageBgEnabled() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isChatImageBgEnabledDark" : @"isChatImageBgEnabled";
    return prefs[key] ? [prefs[key] boolValue] : NO;
}

BOOL isCustomTextColorsEnabled() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isCustomTextColorsEnabledDark" : @"isCustomTextColorsEnabled";
    return prefs[key] ? [prefs[key] boolValue] : NO;
}

BOOL isCustomBubbleColorsEnabled() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isCustomBubbleColorsEnabledDark" : @"isCustomBubbleColorsEnabled";
    return prefs[key] ? [prefs[key] boolValue] : NO;
}

BOOL isModernMessageBarEnabled() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isModernMessageBarEnabledDark" : @"isModernMessageBarEnabled";
    return prefs[key] ? [prefs[key] boolValue] : YES;
}

BOOL isInputFieldCustomizationEnabled() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isInputFieldCustomizationEnabledDark" : @"isInputFieldCustomizationEnabled";
    return prefs[key] ? [prefs[key] boolValue] : NO;
}

BOOL isInputFieldBlurEnabled() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isInputFieldBlurEnabledDark" : @"isInputFieldBlurEnabled";
    return prefs[key] ? [prefs[key] boolValue] : NO;
}

BOOL isPlaceholderCustomizationEnabled() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isPlaceholderCustomizationEnabledDark" : @"isPlaceholderCustomizationEnabled";
    return prefs[key] ? [prefs[key] boolValue] : NO;
}

BOOL isMessageInputTextEnabled() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isMessageInputTextEnabledDark" : @"isMessageInputTextEnabled";
    return prefs[key] ? [prefs[key] boolValue] : NO;
}

BOOL isMessageBarButtonsEnabled() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isMessageBarButtonsEnabledDark" : @"isMessageBarButtonsEnabled";
    return prefs[key] ? [prefs[key] boolValue] : NO;
}

BOOL isNavBarCustomizationEnabled() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isNavBarCustomizationEnabledDark" : @"isNavBarCustomizationEnabled";
    return prefs[key] ? [prefs[key] boolValue] : NO;
}

BOOL isMessageBarCustomizationEnabled() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"isMessageBarCustomizationEnabledDark" : @"isMessageBarCustomizationEnabled";
    return prefs[key] ? [prefs[key] boolValue] : NO;
}

BOOL isCellBlurTintEnabled() {
    NSDictionary *prefs = loadPrefs();
    return prefs[@"isCellBlurTintEnabled"] ? [prefs[@"isCellBlurTintEnabled"] boolValue] : NO;
}
BOOL isiOS17OrHigher() {
    NSOperatingSystemVersion iOS17 = {17, 0, 0};
    return [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:iOS17];
}

BOOL isDarkMode() {
    if (@available(iOS 13.0, *)) {
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
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"chatImageBlurAmountDark" : @"chatImageBlurAmount";
    return prefs[key] ? [prefs[key] floatValue] : 0.0;
}

/*=================================
    Helper and Getter Functions
=================================*/

static UIColor *getSystemTintColor(); //forward decl

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
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"chatBackgroundColorDark" : @"chatBackgroundColor";
    return colorFromHex(prefs[key]) ?: [UIColor blackColor];
}

UIColor *getCellColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"convListCellColorDark" : @"convListCellColor";
    return colorFromHex(prefs[key]) ?: [UIColor blackColor];
}

UIColor *getTitleTextColor() {
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
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"inputFieldBackgroundColorDark" : @"inputFieldBackgroundColor";
    return colorFromHex(prefs[key]) ?: [UIColor whiteColor];
}

static BOOL isAdvancedTintEnabled() {
    NSDictionary *prefs = loadPrefs();
    return prefs[@"isAdvancedTintEnabled"] ? [prefs[@"isAdvancedTintEnabled"] boolValue] : NO;
}


static UIColor *getAdvancedTintColor(NSString *lightKey, NSString *darkKey, UIColor *fallback) {
    if (!isAdvancedTintEnabled()) return fallback;
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? darkKey : lightKey;
    UIColor *color = colorFromHex(prefs[key]);
    return color ?: fallback;
}

static UIColor *getAdvancedTintColorForView(NSString *lightKey, NSString *darkKey, UIColor *fallback, UIView *view) {
    if (!isAdvancedTintEnabled()) return fallback;
    NSDictionary *prefs = loadPrefs();
    BOOL dark = NO;
    if (@available(iOS 13.0, *)) {
        dark = view
            ? (view.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark)
            : isDarkMode();
    }
    NSString *key = dark ? darkKey : lightKey;
    UIColor *color = colorFromHex(prefs[key]);
    return color ?: fallback;
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
    return getAdvancedTintColor(@"advancedReactionGlyphColor", @"advancedReactionGlyphColorDark", getSystemTintColor());
}

UIBlurEffectStyle getInputFieldBlurStyle() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"inputFieldBlurStyleDark" : @"inputFieldBlurStyle";
    NSString *style = prefs[key] ?: @"regular";
    if ([style isEqualToString:@"light"]) return UIBlurEffectStyleLight;
    if ([style isEqualToString:@"dark"]) return UIBlurEffectStyleDark;
    if ([style isEqualToString:@"ultraThinLight"]) return UIBlurEffectStyleSystemUltraThinMaterialLight;
    if ([style isEqualToString:@"ultraThinDark"]) return UIBlurEffectStyleSystemUltraThinMaterialDark;
    return UIBlurEffectStyleRegular;
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
    if (!isCustomTextColorsEnabled()) return;

    if ([view isKindOfClass:%c(CKLabel)]) {
        ((UILabel *)view).textColor = getTitleTextColor();
    } else if ([view isKindOfClass:%c(CKDateLabel)]) {
        ((UILabel *)view).textColor = getDateTimeTextColor();
    } else if ([view isKindOfClass:[UILabel class]]) {
        ((UILabel *)view).textColor = getMessagePreviewTextColor();
    } else if ([view isKindOfClass:[UIImageView class]]) {
        UIImageView *imageView = (UIImageView *)view;
        if (imageView.image.renderingMode == UIImageRenderingModeAlwaysTemplate ||
            imageView.image.renderingMode == UIImageRenderingModeAutomatic) {
            imageView.tintColor = getDateTimeTextColor();
        }
    }

    for (UIView *subview in view.subviews) {
        applyCustomTextColors(subview);
    }
}

static UIColor *getSMSSentBubbleColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"sentSMSBubbleColorDark" : @"sentSMSBubbleColor";
    return colorFromHex(prefs[key]) ?: [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
}

static UIColor *getSentBubbleColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"sentBubbleColorDark" : @"sentBubbleColor";
    return colorFromHex(prefs[key]) ?: [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
}

static UIColor *getReceivedBubbleColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"receivedBubbleColorDark" : @"receivedBubbleColor";
    return colorFromHex(prefs[key]) ?: [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
}

static UIColor *getReceivedTextColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"receivedTextColorDark" : @"receivedTextColor";
    return colorFromHex(prefs[key]);
}


static UIColor *getSentTextColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"sentTextColorDark" : @"sentTextColor";
    return colorFromHex(prefs[key]);
}

static UIColor *getSMSSentTextColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"sentSMSTextColorDark" : @"sentSMSTextColor";
    return colorFromHex(prefs[key]);
}

static UIColor *pickTimestampTextColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"timestampTextColorDark" : @"timestampTextColor";
    return colorFromHex(prefs[key]);
}

static UIColor *getSystemTintColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"systemTintColorDark" : @"systemTintColor";
    return colorFromHex(prefs[key]);
}

static UIColor *getPlaceholderTextColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"placeholderTextColorDark" : @"placeholderTextColor";
    return colorFromHex(prefs[key]) ?: [UIColor grayColor];
}

static NSString *getPlaceholderText() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"placeholderTextDark" : @"placeholderText";
    NSString *text = prefs[key];
    return text.length > 0 ? text : nil;
}

static UIColor *getMessageInputTextColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"messageInputTextColorDark" : @"messageInputTextColor";
    return colorFromHex(prefs[key]) ?: [UIColor whiteColor];
}

static UIColor *getMessageBarButtonColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"messageBarButtonColorDark" : @"messageBarButtonColor";
    return colorFromHex(prefs[key]);
}

static UIColor *getLinkPreviewBackgroundColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"linkPreviewBackgroundColorDark" : @"linkPreviewBackgroundColor";
    return colorFromHex(prefs[key]) ?: [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0];
}

static UIColor *getLinkPreviewTextColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"linkPreviewTextColorDark" : @"linkPreviewTextColor";
    return colorFromHex(prefs[key]) ?: [UIColor whiteColor];
}

static UIColor *getPinnedBubbleColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"pinnedBubbleColorDark" : @"pinnedBubbleColor";
    NSString *hexColor = prefs[key];
    if (!hexColor || [hexColor length] == 0) return getReceivedBubbleColor();
    return colorFromHex(hexColor);
}

static UIColor *getPinnedBubbleTextColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"pinnedBubbleTextColorDark" : @"pinnedBubbleTextColor";
    NSString *hexColor = prefs[key];
    if (!hexColor || [hexColor length] == 0) return getReceivedTextColor();
    return colorFromHex(hexColor);
}

static UIColor *getNavBarTintColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"navBarTintColorDark" : @"navBarTintColor";
    return colorFromHex(prefs[key]) ?: getSystemTintColor();
}

static UIColor *getMessageBarTintColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"messageBarTintColorDark" : @"messageBarTintColor";
    return colorFromHex(prefs[key]) ?: getSystemTintColor();
}

static UIColor *getCellBlurTintColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"cellTintColorDark" : @"cellTintColor";
    return colorFromHex(prefs[key]) ?: getSystemTintColor();
}

static UIColor *getSendArrowColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"sendButtonArrowColorDark" : @"sendButtonArrowColor";
    return colorFromHex(prefs[key]) ?: [UIColor whiteColor];
}

static UIColor *getSendButtonColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *key = isDarkMode() ? @"sendButtonColorDark" : @"sendButtonColor";
    return colorFromHex(prefs[key]) ?: [UIColor systemBlueColor];
}

/*============
==============
    HOOKS
==============
============*/

%hook UIView

- (UIColor *)tintColor {
    if (!isTweakEnabled()) return %orig;

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

    if (isAdvancedTintEnabled()) {
        // Check for reaction balloon context
        UIColor *balloonColor = getAdvancedTintColorForView(@"advancedReactionBalloonColor", @"advancedReactionBalloonColorDark", nil, self);
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

        // Check for CNActionView context
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

        // Check for nav bar / contact action button context
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
    [self.collectionView reloadData];
    [self.collectionView layoutIfNeeded];
    
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

%new
-(void)applyCustomColorsToCKLabelsInView:(UIView *)view {
    if (!isCustomTextColorsEnabled()) return;
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:%c(CKLabel)]) {
            ((CKLabel *)subview).textColor = getTitleTextColor();
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
            %orig(getTitleTextColor());
        } else if ([self isKindOfClass:%c(CKDateLabel)]) {
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
        if (levels < 5 && [parent isKindOfClass:%c(CKConversationListEmbeddedStandardTableViewCell)]) {
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
                self.tintColor = customTint;
                self.tag = 88771;
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
        }

        self.backgroundColor = [UIColor clearColor];
        return;
    }

    if (!isNavBarCustomizationEnabled()) return;

    UIColor *tintColor = getNavBarTintColor();
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

            tintOverlay.backgroundColor = [tintColor colorWithAlphaComponent:0.5];
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
- (void)handleNavBarPrefsChanged {
    refreshPrefs();
    [self setNeedsLayout];
    [self layoutIfNeeded];
    if (isModernNavBarEnabled()) {
        [self ensureBlurExists];
    }
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

    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)sub;
            if ([label.text isEqualToString:@"Messages"] || [label.text isEqualToString:conversationListTitle]) {
                label.text = conversationListTitle;
                label.textColor = getConversationListTitleColor();
            } else if (isCustomTextColorsEnabled()) {
                label.textColor = getTitleTextColor();
            }
        }
        if ([sub isKindOfClass:[UIView class]]) {
            for (UIView *subview in sub.subviews) {
                if ([subview isKindOfClass:[UILabel class]]) {
                    UILabel *label = (UILabel *)subview;
                    if ([label.text isEqualToString:@"Messages"] || [label.text isEqualToString:conversationListTitle]) {
                        label.text = conversationListTitle;
                        label.textColor = getConversationListTitleColor();
                    } else if (isCustomTextColorsEnabled()) {
                        label.textColor = getTitleTextColor();
                    }
                }
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

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyPinnedGlow];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    [self applyPinnedGlow];
}

%new
- (void)applyPinnedGlow {
    for (UIView *sub in self.subviews) {
        if (![sub isKindOfClass:[UIImageView class]]) continue;
        UIImageView *img = (UIImageView *)sub;
        img.hidden = isPinnedGlowEnabled();
        img.alpha = isPinnedGlowEnabled() ? 1.0 : 0.0;
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
    for (UIView *subview in [self.view.subviews copy]) {
        if (subview.tag == 4321) [subview removeFromSuperview];
    }

    UIImage *chatBgImage = loadImageUncached(getChatImagePath());

    if (isChatColorBgEnabled()) {
        UIView *colorView = [[UIView alloc] initWithFrame:self.view.bounds];
        colorView.backgroundColor = getChatBackgroundColor();
        colorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        colorView.tag = 4321;
        [self.view insertSubview:colorView atIndex:0];
    } else if (chatBgImage && isChatImageBgEnabled()) {
        CGFloat blurAmount = getChatImageBlurAmount();
        if (blurAmount > 0) chatBgImage = blurImage(chatBgImage, blurAmount);

        UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
        imageView.image = chatBgImage;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        imageView.tag = 4321;
        [self.view insertSubview:imageView atIndex:0];
    }

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
            refreshPrefs();
            [self updateChatBackground];
        }
    }
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
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
        if (coloredSelf.color == -1) {
            UIColor *receivedColor = getReceivedBubbleColor();
            if (receivedColor) {
                UIImageRenderingMode originalMode = image.renderingMode;
                UIEdgeInsets capInsets = image.capInsets;
                UIImageResizingMode resizingMode = image.resizingMode;
                UIEdgeInsets alignmentInsets = image.alignmentRectInsets;
                CGFloat scale = image.scale;

                UIGraphicsBeginImageContextWithOptions(image.size, NO, scale);
                CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
                [image drawInRect:rect];
                [receivedColor setFill];
                UIRectFillUsingBlendMode(rect, kCGBlendModeSourceAtop);
                UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();

                alignmentInsets.left += 6.0;
                alignmentInsets.right -= 8.0;
                tintedImage = [tintedImage resizableImageWithCapInsets:capInsets resizingMode:resizingMode];
                tintedImage = [tintedImage imageWithAlignmentRectInsets:alignmentInsets];
                tintedImage = [tintedImage imageWithRenderingMode:originalMode];
                %orig(tintedImage);
                return;
            }
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

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;

    UIView *parent = self.superview;
    UIVisualEffectView *effectView = nil;
    BOOL isInMessageInput = NO;
    BOOL isInKeyboard = NO;
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

    if (!isInMessageInput || isInKeyboard || !effectView) return;

    if (isModernMessageBarEnabled()) {
        effectView.backgroundColor = [UIColor clearColor];
        effectView.contentView.backgroundColor = [UIColor clearColor];
        effectView.opaque = NO;
        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;
        if (!effectView.effect) effectView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];

        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        CGRect expandedFrame = effectView.frame;
        expandedFrame.origin.y -= 70;
        expandedFrame.size.height += 70;
        effectView.frame = expandedFrame;
        [CATransaction commit];

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
        if (!tintOverlay) {
            tintOverlay = [[UIView alloc] initWithFrame:effectView.contentView.bounds];
            tintOverlay.userInteractionEnabled = NO;
            tintOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [effectView.contentView addSubview:tintOverlay];
        }
        tintOverlay.backgroundColor = [tintColor colorWithAlphaComponent:0.5];
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
        if ([parent isKindOfClass:%c(CKMessageEntryView)]) isInMessageInput = YES;
        parent = parent.superview;
        levels++;
    }

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
    int levels = 0;

    while (parent && levels < 15) {
        NSString *className = NSStringFromClass([parent class]);
        if ([className containsString:@"Keyboard"] ||
            [className isEqualToString:@"UIKBVisualEffectView"] ||
            [className isEqualToString:@"UIInputView"]) {
            isInKeyboard = YES;
            break;
        }
        if ([className isEqualToString:@"CKMessageEntryView"]) isInMessageInput = YES;
        parent = parent.superview;
        levels++;
    }

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

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];

    if (self.window) {
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(handleInputFieldPrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
        if (isInputFieldCustomizationEnabled()) [self applyInputFieldCustomization];
    }
}

%new
-(void)handleInputFieldPrefsChanged {
    refreshPrefs();
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
        [inputFieldContainer insertSubview:blurView atIndex:0];
        inputFieldContainer.backgroundColor = [getInputFieldBackgroundColor() colorWithAlphaComponent:0.3];
    } else {
        inputFieldContainer.backgroundColor = getInputFieldBackgroundColor();
    }

    [inputFieldContainer setNeedsLayout];
    [inputFieldContainer layoutIfNeeded];
    
    if (textView && [textView isKindOfClass:%c(CKMessageEntryRichTextView)]) {
        if (isMessageInputTextEnabled()) {
            textView.textColor = getMessageInputTextColor();
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
        UIColor *customTextColor = getMessageInputTextColor();
        if (customTextColor) self.textColor = customTextColor;
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
        UIColor *customTextColor = getMessageInputTextColor();
        if (customTextColor) self.textColor = customTextColor;
    }
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

- (void)setTextColor:(UIColor *)textColor {
    if (isTweakEnabled() && isInputFieldCustomizationEnabled() && isMessageInputTextEnabled()) {
        UIColor *customTextColor = getMessageInputTextColor();
        if (customTextColor) { %orig(customTextColor); return; }
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

        if ([subview isKindOfClass:[UIImageView class]] && subview.tag != kArrowOverlayTag && buttonColor && customizeOtherButtons) {
            UIImageView *imgView = (UIImageView *)subview;
            if (imgView.image) {
                imgView.image = [imgView.image imageWithTintColor:buttonColor renderingMode:UIImageRenderingModeAlwaysOriginal];
            }
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];

    if (self.window) {
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(handleButtonPrefsChanged)
            name:kPrefsChangedNotification
            object:nil];
    }

    [self setNeedsLayout];
    [self layoutIfNeeded];
}

%new
- (void)handleButtonPrefsChanged {
    refreshPrefs();
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
    if (@available(iOS 13.0, *)) {
        if ([self.traitCollection hasDifferentColorAppearanceComparedToTraitCollection:previousTraitCollection]) {
            ((void (*)(id, SEL))objc_msgSend)(self, NSSelectorFromString(@"applyColorsDirectly"));
        }
    }
}

%end

%hook CKDetailsTableView

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;

    [self updateDetailsBackground];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:kPrefsChangedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(handleDetailsPrefsChanged)
        name:kPrefsChangedNotification
        object:nil];
}

%new
- (void)handleDetailsPrefsChanged {
    refreshPrefs();
    [self updateDetailsBackground];
}

%new
- (void)updateDetailsBackground {
    UIImage *chatBgImage = loadImageUncached(getChatImagePath());

    if (isChatColorBgEnabled()) {
        self.backgroundView = nil;
        self.backgroundColor = getChatBackgroundColor();
    } else if (chatBgImage && isChatImageBgEnabled()) {
        CGFloat blurAmount = getChatImageBlurAmount();
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
    int levels = 0;
    while (parent && levels < 15) {
        if ([parent isKindOfClass:%c(CKDetailsTableView)]) { isInDetailsView = YES; break; }
        parent = parent.superview;
        levels++;
    }

    if (isInDetailsView) {
        self.backgroundColor = [UIColor clearColor];
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
    if (isCustomTextColorsEnabled()) [self applyContactNameColor];
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    if (isCustomTextColorsEnabled()) [self applyContactNameColor];
}

%new
- (void)applyContactNameColor {
    UIColor *titleColor = getTitleTextColor();
    if (!titleColor) return;

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIStackView class]]) {
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
    if (!isTweakEnabled()) return;
    self.backgroundColor = [UIColor clearColor];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled()) { %orig; return; }
    %orig([UIColor clearColor]);
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

    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 12345) {
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
    } else if (chatBgImage && isChatImageBgEnabled()) {
        CGFloat blurAmount = getChatImageBlurAmount();
        if (blurAmount > 0) chatBgImage = blurImage(chatBgImage, blurAmount);

        UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        imageView.image = chatBgImage;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self insertSubview:imageView atIndex:0];
        self.backgroundColor = [UIColor clearColor];
    } else {
        self.backgroundColor = [UIColor clearColor];
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
    self.backgroundColor = [UIColor clearColor];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled()) { %orig; return; }
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
    UIColor *customTint = getAdvancedSwitchTintColor();
    if (customTint) self.onTintColor = customTint;
}

- (void)setOn:(BOOL)on animated:(BOOL)animated {
    %orig;
    if (!isTweakEnabled()) return;
    UIColor *customTint = getAdvancedSwitchTintColor();
    if (customTint) self.onTintColor = customTint;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    if (!isTweakEnabled()) return;
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
        UIColor *customTint = getAdvancedTintColorForView(@"advancedReportJunkColor", @"advancedReportJunkColorDark", getSystemTintColor(), self);
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
        UIColor *customTint = getAdvancedTintColorForView(@"advancedReportJunkColor", @"advancedReportJunkColorDark", getSystemTintColor(), self);
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
        UIColor *customTint = getAdvancedTintColorForView(@"advancedReportJunkColor", @"advancedReportJunkColorDark", getSystemTintColor(), self);
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
        UIColor *customTint = getAdvancedTintColorForView(@"advancedReportJunkColor", @"advancedReportJunkColorDark", getSystemTintColor(), self);
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
    UIColor *customTint = getAdvancedReactionGlyphColor();
    if (customTint) {
        self.tintColor = customTint;
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) subview.tintColor = customTint;
        }
    }
    if (isCustomBubbleColorsEnabled()) [self applyGlyphTintRecursively:self];
}

- (void)setTintColor:(UIColor *)color {
    if (!isTweakEnabled()) { %orig; return; }
    UIColor *customTint = getAdvancedReactionGlyphColor();
    if (customTint) {
        %orig(customTint);
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) subview.tintColor = customTint;
        }
        if (isCustomBubbleColorsEnabled()) [self applyGlyphTintRecursively:self];
        return;
    }
    %orig;
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled()) return;
    UIColor *customTint = getAdvancedReactionGlyphColor();
    if (customTint) {
        self.tintColor = customTint;
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) subview.tintColor = customTint;
        }
    }
    if (isCustomBubbleColorsEnabled()) [self applyGlyphTintRecursively:self];
}

%new
- (void)applyGlyphTintRecursively:(UIView *)view {
    UIColor *glyphTint = [UIColor colorWithWhite:0.85 alpha:1.0];
    UIColor *customGlyphTint = getAdvancedReactionGlyphColor();
    if (customGlyphTint) {
            NSDictionary *prefs = loadPrefs();
        NSString *key = isDarkMode() ? @"advancedReactionGlyphColorDark" : @"advancedReactionGlyphColor";
        if (prefs[key]) {
            // User explicitly set this color, use it directly
            glyphTint = customGlyphTint;
        } else {
            // Falling back to system tint, apply derivation
            CGFloat h, s, b, a;
            if ([customGlyphTint getHue:&h saturation:&s brightness:&b alpha:&a]) {
                s *= 0.3;
                b = MIN(1.0, b + 0.4);
                glyphTint = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
            }
        }
    }

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
    } else if (chatBgImage && isChatImageBgEnabled()) {
        CGFloat blurAmount = getChatImageBlurAmount();
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
    UIColor *customTint = getAdvancedTintColorForView(@"advancedReportJunkColor", @"advancedReportJunkColorDark", getSystemTintColor(), self);
    if (!customTint) return;
    [self colorReportJunkButton:self withColor:customTint];
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !self.window) return;
    UIColor *customTint = getAdvancedTintColorForView(@"advancedReportJunkColor", @"advancedReportJunkColorDark", getSystemTintColor(), self);
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

    UIColor *glyphTint = [UIColor colorWithWhite:0.85 alpha:1.0];
    UIColor *customGlyphTint = getAdvancedReactionGlyphColor();
    if (customGlyphTint) {
            NSDictionary *prefs = loadPrefs();
        NSString *key = isDarkMode() ? @"advancedReactionGlyphColorDark" : @"advancedReactionGlyphColor";
        if (prefs[key]) {
            // User explicitly set this color, use it directly
            glyphTint = customGlyphTint;
        } else {
            // Falling back to system tint, apply derivation
            CGFloat h, s, b, a;
            if ([customGlyphTint getHue:&h saturation:&s brightness:&b alpha:&a]) {
                s *= 0.3;
                b = MIN(1.0, b + 0.4);
                glyphTint = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
            }
        }
    }

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

    UIColor *glyphTint = [UIColor colorWithWhite:0.85 alpha:1.0];
    UIColor *customGlyphTint = getAdvancedReactionGlyphColor();
    if (customGlyphTint) {
            NSDictionary *prefs = loadPrefs();
        NSString *key = isDarkMode() ? @"advancedReactionGlyphColorDark" : @"advancedReactionGlyphColor";
        if (prefs[key]) {
            // User explicitly set this color, use it directly
            glyphTint = customGlyphTint;
        } else {
            // Falling back to system tint, apply derivation
            CGFloat h, s, b, a;
            if ([customGlyphTint getHue:&h saturation:&s brightness:&b alpha:&a]) {
                s *= 0.3;
                b = MIN(1.0, b + 0.4);
                glyphTint = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
            }
        }
    }
    
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setNeedsLayout];
        [self layoutIfNeeded];
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
    [self applyPinnedBubbleStyle];
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !self.window) return;
    [self applyPinnedBubbleStyle];
}

%new
- (void)applyPinnedBubbleStyle {
    UIColor *bubbleColor = getPinnedBubbleColor();
    UIColor *textColor = getPinnedBubbleTextColor();
    if (!bubbleColor && !textColor) return;

    for (CALayer *sublayer in self.layer.sublayers) {
        if ([sublayer isKindOfClass:%c(CKPinnedConversationActivityItemViewBackdropLayer)]) {
            if (bubbleColor) sublayer.backgroundColor = bubbleColor.CGColor;
        } else if ([sublayer isKindOfClass:%c(CKPinnedConversationActivityItemViewShadowLayer)]) {
            sublayer.opacity = 0.3;
        }
    }
    if (textColor) {
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UILabel class]]) ((UILabel *)subview).textColor = textColor;
        }
    }
}

%end

%hook CNContactView

- (void)didMoveToSuperview {
    %orig;
    if (!isTweakEnabled() || !self.superview) return;

    UIImage *chatBgImage = loadImageUncached(getChatImagePath());

    if (isChatColorBgEnabled()) {
        self.backgroundColor = getChatBackgroundColor();
    } else if (chatBgImage && isChatImageBgEnabled()) {
        CGFloat blurAmount = getChatImageBlurAmount();
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
            } else if (chatBgImage && isChatImageBgEnabled()) {
                CGFloat blurAmount = getChatImageBlurAmount();
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

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || !isCustomTextColorsEnabled()) return;
    UIColor *titleColor = getTitleTextColor();
    if (!titleColor) return;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) ((UILabel *)subview).textColor = titleColor;
    }
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;
    self.backgroundColor = [UIColor clearColor];
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

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled()) return;

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
    UIColor *accentColor = getAdvancedTintColorForView(@"advancedReactionHighlightColor", @"advancedReactionHighlightColorDark", getSystemTintColor(), (UIView *)self);
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
    if (!isTweakEnabled() || !isiOS17OrHigher()) return;
    [self applyLargeTitleStyle];
}

- (void)didMoveToWindow {
    %orig;
    if (!isTweakEnabled() || !isiOS17OrHigher()) return;
    [self applyLargeTitleStyle];
}

%new
- (void)applyLargeTitleStyle {
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            if ([label.text isEqualToString:@"Messages"] || [label.text isEqualToString:getConversationListTitle()]) {
                label.text = getConversationListTitle();
                label.textColor = getConversationListTitleColor();
            }
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

    UIView *contentView = nil;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIView class]] && ![subview isKindOfClass:[UIImageView class]]) {
            contentView = subview;
            break;
        }
    }
    if (!contentView) return;

    for (UIView *subview in [contentView.subviews copy]) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            UIImageView *imgView = (UIImageView *)subview;
            if (imgView.frame.origin.x == 0 && imgView.frame.origin.y == 0) [imgView removeFromSuperview];
        }
    }

    UIImage *chatBgImage = loadImageUncached(getChatImagePath());

    if (isChatColorBgEnabled()) {
        contentView.backgroundColor = getChatBackgroundColor();
    } else if (chatBgImage && isChatImageBgEnabled()) {
        CGFloat blurAmount = getChatImageBlurAmount();
        if (blurAmount > 0) chatBgImage = blurImage(chatBgImage, blurAmount);

        UIImageView *imageView = [[UIImageView alloc] initWithFrame:contentView.bounds];
        imageView.image = chatBgImage;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [contentView insertSubview:imageView atIndex:0];
        contentView.backgroundColor = [UIColor clearColor];
    } else {
        contentView.backgroundColor = [UIColor clearColor];
    }
}

- (void)layoutSubviews {
    %orig;
    if (!isTweakEnabled() || isiOS17OrHigher()) return;

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
                    if (imgView.frame.origin.x == 0 && imgView.frame.origin.y == 0) imgView.frame = subview.bounds;
                }
            }
        }
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
}
