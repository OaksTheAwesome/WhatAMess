#import "WAMPresetModel.h"
#import <stdlib.h>
#import <sys/syslimits.h>

#pragma mark - Paths

static NSString *WAMJBRoot(void) {
    static NSString *root = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        char buf[PATH_MAX];
        root = realpath("/var/jb", buf) ? [NSString stringWithUTF8String:buf] : @"";
    });
    return root;
}

static NSString *WAMPrefsPlistPath(void) {
    return [WAMJBRoot() stringByAppendingString:
        @"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs.plist"];
}

static NSString *WAMPrefsDataDir(void) {
    return [WAMJBRoot() stringByAppendingString:
        @"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs"];
}

static NSString *WAMPerContactDir(void) {
    return [WAMPrefsDataDir() stringByAppendingPathComponent:@"per_contact"];
}

NSString *WAMPresetImagePath(NSString *name) {
    if (!name.length) return nil;
    return [NSString stringWithFormat:@"%@/Library/PreferenceBundles/WhatAMessPrefs.bundle/%@.jpg",
            WAMJBRoot(), name];
}

static NSString *WAMResolveImageRef(NSString *ref) {
    if (!ref.length) return nil;
    return [ref hasPrefix:@"/"] ? ref : WAMPresetImagePath(ref);
}

static NSString *WAMUserPresetImageDir(void) {
    return [WAMPrefsDataDir() stringByAppendingPathComponent:@"user_presets"];
}

static void WAMCopyImage(NSString *src, NSString *dst) {
    if (!src.length || !dst.length) return;
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:src]) return;
    [fm createDirectoryAtPath:[dst stringByDeletingLastPathComponent]
  withIntermediateDirectories:YES attributes:nil error:nil];
    [fm removeItemAtPath:dst error:nil];
    [fm copyItemAtPath:src toPath:dst error:nil];
}

UIImage *WAMGradientImage(NSArray<NSString *> *stops, CGSize size, WAMGradientDirection direction) {
    if (stops.count < 2 || size.width < 1 || size.height < 1) return nil;
    NSMutableArray *cgColors = [NSMutableArray array];
    for (NSString *hex in stops) {
        UIColor *c = WAMColorFromHex(hex) ?: UIColor.blackColor;
        [cgColors addObject:(id)c.CGColor];
    }
    CGPoint start = CGPointZero, end;
    switch (direction) {
        case WAMGradientDirectionVertical:   end = CGPointMake(0, size.height); break;
        case WAMGradientDirectionHorizontal: end = CGPointMake(size.width, 0);  break;
        case WAMGradientDirectionDiagonal:
        default:                             end = CGPointMake(size.width, size.height); break;
    }
    UIGraphicsImageRendererFormat *fmt = [UIGraphicsImageRendererFormat defaultFormat];
    fmt.opaque = YES;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:size format:fmt];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *rc) {
        CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
        CGGradientRef grad = CGGradientCreateWithColors(cs, (CFArrayRef)cgColors, NULL);
        CGContextDrawLinearGradient(rc.CGContext, grad, start, end,
            kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation);
        CGGradientRelease(grad);
        CGColorSpaceRelease(cs);
    }];
}

UIImage *WAMPresetBackgroundImage(WAMPreset *preset, BOOL dark, BOOL convList, CGSize size) {
    if (!preset) return nil;
    NSString *ref;
    if (convList) ref = dark ? (preset.convBgImageDark ?: preset.convBgImage) : preset.convBgImage;
    else          ref = dark ? (preset.chatBgImageDark ?: preset.chatBgImage) : preset.chatBgImage;
    NSString *path = WAMResolveImageRef(ref);
    if (path && [[NSFileManager defaultManager] fileExistsAtPath:path]) {
        UIImage *img = [UIImage imageWithContentsOfFile:path];
        if (img) return img;
    }
    NSArray *stops = dark ? preset.darkGradient : preset.lightGradient;
    UIImage *grad = WAMGradientImage(stops, size, WAMGradientDirectionDiagonal);
    if (grad) return grad;
    UIColor *bg = [preset backgroundColorForDark:dark];
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *rc) {
        [bg setFill]; [rc fillRect:CGRectMake(0,0,size.width,size.height)];
    }];
}

static const CGFloat kWAMScreenRefWidthPx = 1170.0;

static UIImage *WAMBlurred(UIImage *image, CGFloat radius) {
    if (!image || radius < 0.5) return image;
    CIImage *input = [CIImage imageWithCGImage:image.CGImage];
    CIFilter *clamp = [CIFilter filterWithName:@"CIAffineClamp"];
    [clamp setValue:input forKey:kCIInputImageKey];
    CIFilter *blur = [CIFilter filterWithName:@"CIGaussianBlur"];
    [blur setValue:clamp.outputImage forKey:kCIInputImageKey];
    [blur setValue:@(radius) forKey:kCIInputRadiusKey];
    CIContext *ctx = [CIContext contextWithOptions:nil];
    CGImageRef cg = [ctx createCGImage:blur.outputImage fromRect:input.extent];
    if (!cg) return image;
    UIImage *out = [UIImage imageWithCGImage:cg scale:image.scale orientation:image.imageOrientation];
    CGImageRelease(cg);
    return out;
}

static UIImage *WAMScaledToFill(UIImage *src, CGSize size) {
    if (!src || size.width < 1 || size.height < 1) return src;
    UIGraphicsImageRenderer *r = [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [r imageWithActions:^(UIGraphicsImageRendererContext *ctx) {
        CGFloat s = MAX(size.width / src.size.width, size.height / src.size.height);
        CGSize scaled = CGSizeMake(src.size.width * s, src.size.height * s);
        [src drawInRect:CGRectMake((size.width - scaled.width) / 2.0,
                                   (size.height - scaled.height) / 2.0,
                                   scaled.width, scaled.height)];
    }];
}

UIImage *WAMPresetPreviewBackgroundImage(WAMPreset *preset, BOOL dark, BOOL convList, CGSize size) {
    UIImage *src = WAMPresetBackgroundImage(preset, dark, convList, size);
    if (!src) return nil;
    CGFloat amount = [preset backgroundBlurForDark:dark convList:convList];
    if (amount < 0.5) return src;

    NSString *ref = convList ? (dark ? (preset.convBgImageDark ?: preset.convBgImage) : preset.convBgImage)
                             : (dark ? (preset.chatBgImageDark ?: preset.chatBgImage) : preset.chatBgImage);
    BOOL isPhoto = (ref.length > 0);
    CGFloat sourcePx = isPhoto ? (src.size.width * src.scale) : kWAMScreenRefWidthPx;

    CGFloat screenScale = UIScreen.mainScreen.scale ?: 2.0;
    CGFloat previewPx = size.width * screenScale;
    UIImage *small = WAMScaledToFill(src, size);
    return WAMBlurred(small, amount * (previewPx / MAX(sourcePx, 1.0)));
}

static void WAMWritePresetBackground(WAMPreset *preset, BOOL dark, BOOL convList, NSString *dst) {
    NSString *ref = convList ? (dark ? (preset.convBgImageDark ?: preset.convBgImage) : preset.convBgImage)
                             : (dark ? (preset.chatBgImageDark ?: preset.chatBgImage) : preset.chatBgImage);
    NSString *src = WAMResolveImageRef(ref);
    if (src && [[NSFileManager defaultManager] fileExistsAtPath:src]) {
        WAMCopyImage(src, dst);
        return;
    }
    UIImage *img = WAMPresetBackgroundImage(preset, dark, convList, CGSizeMake(1170, 2532));
    if (!img) return;
    NSData *jpg = UIImageJPEGRepresentation(img, 0.95);
    if (!jpg.length) return;
    [[NSFileManager defaultManager] createDirectoryAtPath:[dst stringByDeletingLastPathComponent]
                              withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:dst error:nil];
    [jpg writeToFile:dst atomically:YES];
}

#define kWAMPrefsChangedName  "com.oakstheawesome.whatamessprefs/prefsChanged"
#define kWAMKillMessagesName  "com.oakstheawesome.whatamessprefs/killMessages"

static NSMutableDictionary *WAMReadPrefs(void) {
    NSMutableDictionary *p = [NSMutableDictionary dictionaryWithContentsOfFile:WAMPrefsPlistPath()];
    return p ?: [NSMutableDictionary new];
}

static void WAMWritePrefs(NSDictionary *prefs) {
    NSString *path = WAMPrefsPlistPath();
    NSString *dir = [path stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES attributes:nil error:nil];
    [prefs writeToFile:path atomically:YES];
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR(kWAMPrefsChangedName), NULL, NULL, YES);
}

static BOOL WAMIsExcludedKey(NSString *key);

static NSString *WAMSanitizeContactName(NSString *raw) {
    if (!raw.length) return nil;
    NSString *trimmed = [raw stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (!trimmed.length) return nil;
    NSCharacterSet *invalid = [NSCharacterSet characterSetWithCharactersInString:@"/:?#[]@!$&'()*+,;= \t\n\r"];
    NSArray *parts = [trimmed componentsSeparatedByCharactersInSet:invalid];
    return [parts componentsJoinedByString:@"_"];
}

#pragma mark - Hex helpers

UIColor *WAMColorFromHex(NSString *hex) {
    if (![hex isKindOfClass:[NSString class]]) return nil;
    if ([hex hasPrefix:@"#"]) hex = [hex substringFromIndex:1];
    unsigned int ri = 0, gi = 0, bi = 0, ai = 255;
    if (hex.length == 8) {
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(0,2)]] scanHexInt:&ri];
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(2,2)]] scanHexInt:&gi];
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(4,2)]] scanHexInt:&bi];
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(6,2)]] scanHexInt:&ai];
    } else if (hex.length == 6) {
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(0,2)]] scanHexInt:&ri];
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(2,2)]] scanHexInt:&gi];
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(4,2)]] scanHexInt:&bi];
    } else {
        return nil;
    }
    return [UIColor colorWithRed:ri/255.0 green:gi/255.0 blue:bi/255.0 alpha:ai/255.0];
}

NSString *WAMHexFromColor(UIColor *color) {
    CGFloat r = 0, g = 0, b = 0, a = 1;
    [color getRed:&r green:&g blue:&b alpha:&a];
    int ri = MAX(0, MIN(255, (int)(r*255)));
    int gi = MAX(0, MIN(255, (int)(g*255)));
    int bi = MAX(0, MIN(255, (int)(b*255)));
    int ai = MAX(0, MIN(255, (int)(a*255)));
    return [NSString stringWithFormat:@"#%02X%02X%02X%02X", ri, gi, bi, ai];
}

#pragma mark - Key categories

static NSArray<NSString *> *WAMChatKeys(void) {
    return @[@"isCustomBubbleColorsEnabled", @"receivedBubbleColor", @"sentBubbleColor",
             @"sentSMSBubbleColor", @"receivedTextColor", @"sentTextColor", @"sentSMSTextColor",
             @"isBlurBubblesEnabled", @"isChatColorBgEnabled", @"isChatImageBgEnabled",
             @"chatImageBlurAmount",
             @"linkPreviewBackgroundColor", @"linkPreviewTextColor",
             @"chatContactNameColor", @"dateTimeTextColor", @"timestampTextColor"];
}
static NSArray<NSString *> *WAMConvListKeys(void) {
    return @[@"isConvColorBgEnabled", @"isConvImageBgEnabled", @"imageBlurAmount",
             @"isCustomTextColorsEnabled", @"conversationListTitleColor",
             @"titleTextColor", @"messagePreviewTextColor",
             @"pinnedBubbleColor", @"pinnedBubbleTextColor"];
}
static NSArray<NSString *> *WAMBarKeys(void) {
    return @[@"isNavBarCustomizationEnabled", @"navBarTintColor", @"systemTintColor",
             @"isMessageBarCustomizationEnabled", @"isMessageBarButtonsEnabled",
             @"isInputFieldCustomizationEnabled", @"isMessageInputTextEnabled",
             @"isPlaceholderCustomizationEnabled",
             @"messageBarTintColor", @"messageBarButtonColor", @"sendButtonColor",
             @"sendButtonArrowColor", @"messageInputTextColor", @"inputFieldBackgroundColor",
             @"placeholderTextColor"];
}
static NSArray<NSString *> *WAMAdvancedKeys(void) {
    return @[@"isAdvancedTintEnabled", @"isCellBlurTintEnabled", @"cellTintColor",
             @"advancedNavButtonColor", @"advancedSwitchTintColor", @"advancedTableLabelColor",
             @"advancedUnreadDotColor", @"advancedReactionBalloonColor", @"advancedReactionGlyphColor",
             @"advancedReactionHighlightColor", @"advancedContactActionColor", @"advancedReportJunkColor",
             @"advancedSearchFieldColor", @"advancedStatusCellColor"];
}

#pragma mark - WAMPreset

@implementation WAMPreset

+ (instancetype)presetWithDictionary:(NSDictionary *)dict {
    WAMPreset *p = [WAMPreset new];
    p.identifier  = dict[@"id"];
    p.name        = dict[@"name"];
    p.subtitle    = dict[@"subtitle"];
    p.builtin     = [dict[@"builtin"] boolValue];
    p.chatBgImage = dict[@"chatBgImage"];
    p.chatBgImageDark = dict[@"chatBgImageDark"];
    p.convBgImage = dict[@"convBgImage"];
    p.convBgImageDark = dict[@"convBgImageDark"];
    p.lightGradient = dict[@"lightGradient"];
    p.darkGradient  = dict[@"darkGradient"];
    p.lightValues = dict[@"light"] ?: @{};
    p.darkValues  = dict[@"dark"]  ?: @{};
    return p;
}

- (NSDictionary *)dictionaryRepresentation {
    NSMutableDictionary *d = [NSMutableDictionary dictionary];
    d[@"id"]       = self.identifier ?: [[NSUUID UUID] UUIDString];
    d[@"name"]     = self.name ?: @"Preset";
    if (self.subtitle)    d[@"subtitle"]    = self.subtitle;
    d[@"builtin"]  = @(self.builtin);
    if (self.chatBgImage)     d[@"chatBgImage"]     = self.chatBgImage;
    if (self.chatBgImageDark) d[@"chatBgImageDark"] = self.chatBgImageDark;
    if (self.convBgImage)     d[@"convBgImage"]     = self.convBgImage;
    if (self.convBgImageDark) d[@"convBgImageDark"] = self.convBgImageDark;
    if (self.lightGradient) d[@"lightGradient"] = self.lightGradient;
    if (self.darkGradient)  d[@"darkGradient"]  = self.darkGradient;
    d[@"light"]    = self.lightValues ?: @{};
    d[@"dark"]     = self.darkValues  ?: @{};
    return d;
}

- (id)valueForBaseKey:(NSString *)baseKey dark:(BOOL)dark {
    id v = (dark ? self.darkValues : self.lightValues)[baseKey];
    if (!v) v = (dark ? self.lightValues : self.darkValues)[baseKey];
    return v;
}

- (UIColor *)colorForBaseKey:(NSString *)key dark:(BOOL)dark fallback:(UIColor *)fb {
    UIColor *c = WAMColorFromHex([self valueForBaseKey:key dark:dark]);
    return c ?: fb;
}

- (UIColor *)backgroundColorForDark:(BOOL)dark {
    UIColor *c = WAMColorFromHex([self valueForBaseKey:@"chatBackgroundColor" dark:dark]);
    if (c) return c;
    NSArray *g = dark ? self.darkGradient : self.lightGradient;
    UIColor *gc = g.count ? WAMColorFromHex(g.firstObject) : nil;
    return gc ?: (dark ? UIColor.blackColor : UIColor.whiteColor);
}
- (UIColor *)sentColorForDark:(BOOL)dark         { return [self colorForBaseKey:@"sentBubbleColor" dark:dark fallback:UIColor.systemBlueColor]; }
- (UIColor *)receivedColorForDark:(BOOL)dark     { return [self colorForBaseKey:@"receivedBubbleColor" dark:dark fallback:(dark ? [UIColor colorWithWhite:0.18 alpha:1] : [UIColor colorWithWhite:0.9 alpha:1])]; }
- (UIColor *)sentTextColorForDark:(BOOL)dark     { return [self colorForBaseKey:@"sentTextColor" dark:dark fallback:UIColor.whiteColor]; }
- (UIColor *)receivedTextColorForDark:(BOOL)dark { return [self colorForBaseKey:@"receivedTextColor" dark:dark fallback:(dark ? UIColor.whiteColor : UIColor.blackColor)]; }
- (UIColor *)titleColorForDark:(BOOL)dark        { return [self colorForBaseKey:@"titleTextColor" dark:dark fallback:(dark ? UIColor.whiteColor : UIColor.blackColor)]; }
- (UIColor *)previewColorForDark:(BOOL)dark      { return [self colorForBaseKey:@"messagePreviewTextColor" dark:dark fallback:[UIColor colorWithWhite:0.55 alpha:1]]; }
- (UIColor *)tintColorForDark:(BOOL)dark         { return [self colorForBaseKey:@"systemTintColor" dark:dark fallback:UIColor.systemBlueColor]; }
- (BOOL)blurEnabledForDark:(BOOL)dark            { return [[self valueForBaseKey:@"isBlurBubblesEnabled" dark:dark] boolValue]; }

- (CGFloat)backgroundBlurForDark:(BOOL)dark convList:(BOOL)convList {
    id v = [self valueForBaseKey:(convList ? @"imageBlurAmount" : @"chatImageBlurAmount") dark:dark];
    return v ? [v floatValue] : 0.0;
}

@end

#pragma mark - Preset builder

static void WAMSplitSnapshot(NSDictionary *source, BOOL (^shouldSkip)(NSString *key),
                             NSMutableDictionary *light, NSMutableDictionary *dark);

static WAMPreset *WAMMakeFullPreset(NSString *ident, NSString *name, NSString *subtitle,
                                    NSString *chatImg, NSString *chatImgDark,
                                    NSString *convImg, NSString *convImgDark,
                                    NSDictionary *flatPrefs) {
    WAMPreset *p = [WAMPreset new];
    p.identifier = ident;
    p.name = name;
    p.subtitle = subtitle;
    p.builtin = YES;
    NSMutableDictionary *light = [NSMutableDictionary dictionary];
    NSMutableDictionary *dark  = [NSMutableDictionary dictionary];
    WAMSplitSnapshot(flatPrefs, ^BOOL(NSString *k) { return WAMIsExcludedKey(k); }, light, dark);
    p.lightValues = light;
    p.darkValues  = dark;
    p.chatBgImage = chatImg; p.chatBgImageDark = chatImgDark;
    p.convBgImage = convImg; p.convBgImageDark = convImgDark;
    return p;
}

static WAMPreset *WAMMakeGradientPreset(NSString *ident, NSString *name, NSString *subtitle,
                                        NSArray<NSString *> *lightGrad, NSArray<NSString *> *darkGrad,
                                        NSDictionary *flatPrefs) {
    WAMPreset *p = [WAMPreset new];
    p.identifier = ident;
    p.name = name;
    p.subtitle = subtitle;
    p.builtin = YES;
    NSMutableDictionary *light = [NSMutableDictionary dictionary];
    NSMutableDictionary *dark  = [NSMutableDictionary dictionary];
    WAMSplitSnapshot(flatPrefs, ^BOOL(NSString *k) { return WAMIsExcludedKey(k); }, light, dark);
    p.lightValues = light;
    p.darkValues  = dark;
    p.lightGradient = lightGrad;
    p.darkGradient  = darkGrad;
    return p;
}

static WAMPreset *WAMMakeHybridPreset(NSString *ident, NSString *name, NSString *subtitle,
                                      NSArray<NSString *> *lightGrad,
                                      NSString *chatImgDark, NSString *convImgDark,
                                      NSDictionary *flatPrefs) {
    WAMPreset *p = [WAMPreset new];
    p.identifier = ident;
    p.name = name;
    p.subtitle = subtitle;
    p.builtin = YES;
    NSMutableDictionary *light = [NSMutableDictionary dictionary];
    NSMutableDictionary *dark  = [NSMutableDictionary dictionary];
    WAMSplitSnapshot(flatPrefs, ^BOOL(NSString *k) { return WAMIsExcludedKey(k); }, light, dark);
    p.lightValues = light;
    p.darkValues  = dark;
    p.lightGradient   = lightGrad;
    p.chatBgImageDark = chatImgDark;
    p.convBgImageDark = convImgDark;
    return p;
}

#pragma mark - WAMPresetStore

@implementation WAMPresetStore

+ (NSArray<WAMPreset *> *)builtinPresets {
    static NSArray *presets = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSMutableArray *arr = [NSMutableArray array];

        [arr addObjectsFromArray:@[
        WAMMakeFullPreset(@"ios26", @"iOS 26 Inspired", @"The blurs, the bubbles, etc.",
            @"preset_ios26_2e4345d5", @"preset_ios26_e400094b", @"preset_ios26_db275ad3", @"preset_ios26_e400094b",
            @{
            @"advancedContactActionColor": @"#DAF8FFFF",
            @"advancedContactActionColorDark": @"#0086D9FF",
            @"advancedNavButtonColor": @"#0086CDFF",
            @"advancedNavButtonColorDark": @"#2672BAFF",
            @"advancedReactionBalloonColor": @"#9999994D",
            @"advancedReactionBalloonColorDark": @"#0E112964",
            @"advancedReactionGlyphColor": @"#FEFFFFFF",
            @"advancedReactionGlyphColorDark": @"#0090C6FF",
            @"advancedReactionHighlightColor": @"#7DD1FFFF",
            @"advancedReactionHighlightColorDark": @"#4FB4E8FF",
            @"advancedReportJunkColor": @"#FF7A59FF",
            @"advancedReportJunkColorDark": @"#FF7A59FF",
            @"advancedSearchFieldColor": @"#D6E2FCBF",
            @"advancedSearchFieldColorDark": @"#66AFC964",
            @"advancedStatusCellColor": @"#DAF8FFFF",
            @"advancedStatusCellColorDark": @"#FEFFFF7F",
            @"advancedSwitchTintColor": @"#99E0FFFF",
            @"advancedSwitchTintColorDark": @"#007CC0FF",
            @"advancedTableLabelColor": @"#FFFFFFFF",
            @"advancedTableLabelColorDark": @"#FEFFFFFF",
            @"advancedUnreadDotColor": @"#0086CDFF",
            @"advancedUnreadDotColorDark": @"#3AAEFFFF",
            @"cellTintColor": @"#ADADADFF",
            @"cellTintColorDark": @"#000000FF",
            @"chatContactNameColor": @"#FFFFFFFF",
            @"chatContactNameColorDark": @"#FFFFFFFF",
            @"chatImageBlurAmount": @(26.239906311035156),
            @"chatImageBlurAmountDark": @(26.12456703186035),
            @"convListCellColor": @"#FEFFFFFF",
            @"convListCellColorDark": @"#FFFFFF14",
            @"conversationListTitleColor": @"#FFFFFFFF",
            @"conversationListTitleColorDark": @"#D7FFFFFF",
            @"conversationListTitleText": @"Welcome Back",
            @"conversationListTitleTextDark": @"Welcome Back",
            @"dateTimeTextColor": @"#FEFFFFBF",
            @"dateTimeTextColorDark": @"#B0FFFF80",
            @"imageBlurAmount": @(26.12456703186035),
            @"imageBlurAmountDark": @(26.12456703186035),
            @"inputFieldBackgroundColor": @"#5B5B5B81",
            @"inputFieldBackgroundColorDark": @"#000000FF",
            @"inputFieldBlurStyle": @"light",
            @"inputFieldBlurStyleDark": @"dark",
            @"isAdvancedTintEnabled": @YES,
            @"isAdvancedTintEnabledDark": @YES,
            @"isBlurBubblesEnabled": @YES,
            @"isBlurBubblesEnabledDark": @YES,
            @"isCellBlurTintEnabled": @YES,
            @"isCellBlurTintEnabledDark": @YES,
            @"isChatColorBgEnabled": @NO,
            @"isChatColorBgEnabledDark": @NO,
            @"isChatImageBgEnabled": @YES,
            @"isChatImageBgEnabledDark": @YES,
            @"isConvColorBgEnabled": @NO,
            @"isConvColorBgEnabledDark": @NO,
            @"isConvImageBgEnabled": @YES,
            @"isConvImageBgEnabledDark": @YES,
            @"isCustomBubbleColorsEnabled": @YES,
            @"isCustomBubbleColorsEnabledDark": @YES,
            @"isCustomTextColorsEnabled": @YES,
            @"isCustomTextColorsEnabledDark": @YES,
            @"isInputFieldBlurEnabled": @YES,
            @"isInputFieldBlurEnabledDark": @YES,
            @"isInputFieldCustomizationEnabled": @YES,
            @"isInputFieldCustomizationEnabledDark": @YES,
            @"isMessageBarButtonsEnabled": @YES,
            @"isMessageBarButtonsEnabledDark": @YES,
            @"isMessageBarCustomizationEnabled": @YES,
            @"isMessageBarCustomizationEnabledDark": @YES,
            @"isMessageInputTextEnabled": @YES,
            @"isMessageInputTextEnabledDark": @YES,
            @"isModernMessageBarEnabledDark": @YES,
            @"isModernNavBarEnabled": @YES,
            @"isModernNavBarEnabledDark": @YES,
            @"isNavBarCustomizationEnabled": @YES,
            @"isNavBarCustomizationEnabledDark": @YES,
            @"isPerContactChatBgEnabledDark": @YES,
            @"isPinnedGlowEnabled": @YES,
            @"isPlaceholderCustomizationEnabled": @YES,
            @"isPlaceholderCustomizationEnabledDark": @YES,
            @"isSearchBgEnabled": @YES,
            @"isSeparatorsEnabled": @YES,
            @"linkPreviewBackgroundColor": @"#99999966",
            @"linkPreviewBackgroundColorDark": @"#0000003E",
            @"linkPreviewTextColor": @"#FFFFFFFF",
            @"linkPreviewTextColorDark": @"#F0FFFFFF",
            @"messageBarButtonColor": @"#DDF0FDA4",
            @"messageBarButtonColorDark": @"#8C8B8B4C",
            @"messageBarTintColor": @"#FEFFFF40",
            @"messageBarTintColorDark": @"#0000003F",
            @"messageInputTextColor": @"#EEFDFEFF",
            @"messageInputTextColorDark": @"#EEFEFEFF",
            @"messagePreviewTextColor": @"#EFFAFFCE",
            @"messagePreviewTextColorDark": @"#D1FFFFB1",
            @"navBarTintColor": @"#FFFEFE67",
            @"navBarTintColorDark": @"#0000004B",
            @"navPlatterColor": @"#FFFFFF66",
            @"navPlatterColorDark": @"#00000066",
            @"isNavButtonBlurEnabled": @YES,
            @"isNavButtonBlurEnabledDark": @YES,
            @"pinnedBubbleColor": @"#0060FD80",
            @"pinnedBubbleColorDark": @"#0584FF80",
            @"pinnedBubbleTextColor": @"#FFFFFFFF",
            @"pinnedBubbleTextColorDark": @"#FFFFFFFF",
            @"placeholderText": @"Enter Here",
            @"placeholderTextColor": @"#DCFFFE65",
            @"placeholderTextColorDark": @"#DDFFFF66",
            @"placeholderTextDark": @"Enter Here",
            @"receivedBubbleColor": @"#99999966",
            @"receivedBubbleColorDark": @"#00000066",
            @"receivedTextColor": @"#1C2A3EFF",
            @"receivedTextColorDark": @"#FEFFFFFF",
            @"sendButtonArrowColor": @"#FFFFFFFF",
            @"sendButtonArrowColorDark": @"#FFFFFFFF",
            @"sendButtonColor": @"#40B9FFC0",
            @"sendButtonColorDark": @"#2B7AD7A5",
            @"sentBubbleColor": @"#0060FD66",
            @"sentBubbleColorDark": @"#0584FF66",
            @"sentSMSBubbleColor": @"#2AD054A5",
            @"sentSMSBubbleColorDark": @"#2AD154A6",
            @"sentSMSTextColor": @"#FFFFFFFF",
            @"sentSMSTextColorDark": @"#FEFFFFFF",
            @"sentTextColor": @"#FFFFFFFF",
            @"sentTextColorDark": @"#FFFFFFFF",
            @"systemTintColor": @"#DAF8FFFF",
            @"systemTintColorDark": @"#0086CDFF",
            @"timestampTextColor": @"#E1FDFEA7",
            @"timestampTextColorDark": @"#E1FEFE98",
            @"titleTextColor": @"#FFFFFFFF",
            @"titleTextColorDark": @"#E1FFFFFF",
        }),
        WAMMakeHybridPreset(@"tanblue", @"Tan & Blue", @"The classic, first showcased!",
            @[@"#ADCEDFFF",@"#DAF7FFFF",@"#EAE4D6FF",@"#FADDBDFF"],
            @"preset_tanblue_5d022bf0", @"preset_tanblue_02d843df",
            @{
            @"advancedContactActionColor": @"#1F4355FF",
            @"advancedContactActionColorDark": @"#D9B99BFF",
            @"advancedNavButtonColor": @"#697C8EFF",
            @"advancedNavButtonColorDark": @"#FADDBDFF",
            @"advancedReactionBalloonColor": @"#ACCEDFFF",
            @"advancedReactionBalloonColorDark": @"#D9B99BFF",
            @"advancedReactionGlyphColor": @"#5A7C8FFF",
            @"advancedReactionGlyphColorDark": @"#F6F0E0FF",
            @"advancedReactionHighlightColor": @"#84A4B6FF",
            @"advancedReactionHighlightColorDark": @"#D9B99BFF",
            @"advancedReportJunkColor": @"#35C2A8FF",
            @"advancedReportJunkColorDark": @"#35C2A8FF",
            @"advancedSearchFieldColor": @"#29435359",
            @"advancedSearchFieldColorDark": @"#ACCEDF4B",
            @"advancedStatusCellColor": @"#1F4355BF",
            @"advancedStatusCellColorDark": @"#DFB7967F",
            @"advancedSwitchTintColor": @"#FADDBDFF",
            @"advancedSwitchTintColorDark": @"#D9B99BFF",
            @"advancedTableLabelColor": @"#1F4355FF",
            @"advancedTableLabelColorDark": @"#FADDBDFF",
            @"advancedUnreadDotColor": @"#2E6FA8FF",
            @"advancedUnreadDotColorDark": @"#E2BE98FF",
            @"cellTintColor": @"#D9B99BFF",
            @"cellTintColorDark": @"#1F4355FF",
            @"chatContactNameColor": @"#1F4355FF",
            @"chatContactNameColorDark": @"#FADDBDFF",
            @"chatImageBlurAmount": @(0.0),
            @"chatImageBlurAmountDark": @(100.0),
            @"convListCellColor": @"#FFFFFF14",
            @"convListCellColorDark": @"#FFFFFF14",
            @"conversationListTitleColor": @"#1F4355FF",
            @"conversationListTitleColorDark": @"#D9B99BFF",
            @"conversationListTitleText": @"Welcome Back",
            @"conversationListTitleTextDark": @"Welcome Back",
            @"dateTimeTextColor": @"#1F435566",
            @"dateTimeTextColorDark": @"#D9B99BBF",
            @"imageBlurAmount": @(0.0),
            @"imageBlurAmountDark": @(100.0),
            @"inputFieldBackgroundColor": @"#ADCEDFFF",
            @"inputFieldBackgroundColorDark": @"#1F4355FF",
            @"inputFieldBlurStyle": @"regular",
            @"inputFieldBlurStyleDark": @"dark",
            @"isAdvancedTintEnabled": @YES,
            @"isAdvancedTintEnabledDark": @YES,
            @"isBlurBubblesEnabled": @NO,
            @"isBlurBubblesEnabledDark": @NO,
            @"isCellBlurTintEnabled": @YES,
            @"isCellBlurTintEnabledDark": @YES,
            @"isChatColorBgEnabled": @NO,
            @"isChatColorBgEnabledDark": @NO,
            @"isChatImageBgEnabled": @YES,
            @"isChatImageBgEnabledDark": @YES,
            @"isConvColorBgEnabled": @NO,
            @"isConvColorBgEnabledDark": @NO,
            @"isConvImageBgEnabled": @YES,
            @"isConvImageBgEnabledDark": @YES,
            @"isCustomBubbleColorsEnabled": @YES,
            @"isCustomBubbleColorsEnabledDark": @YES,
            @"isCustomTextColorsEnabled": @YES,
            @"isCustomTextColorsEnabledDark": @YES,
            @"isInputFieldBlurEnabled": @YES,
            @"isInputFieldBlurEnabledDark": @YES,
            @"isInputFieldCustomizationEnabled": @YES,
            @"isInputFieldCustomizationEnabledDark": @YES,
            @"isMessageBarButtonsEnabled": @YES,
            @"isMessageBarButtonsEnabledDark": @YES,
            @"isMessageBarCustomizationEnabled": @YES,
            @"isMessageBarCustomizationEnabledDark": @YES,
            @"isMessageInputTextEnabled": @YES,
            @"isMessageInputTextEnabledDark": @YES,
            @"isModernMessageBarEnabledDark": @YES,
            @"isModernNavBarEnabled": @YES,
            @"isModernNavBarEnabledDark": @YES,
            @"isNavBarCustomizationEnabled": @YES,
            @"isNavBarCustomizationEnabledDark": @YES,
            @"isPerContactChatBgEnabledDark": @YES,
            @"isPinnedGlowEnabled": @YES,
            @"isPlaceholderCustomizationEnabled": @YES,
            @"isPlaceholderCustomizationEnabledDark": @YES,
            @"isSearchBgEnabled": @YES,
            @"isSeparatorsEnabled": @YES,
            @"linkPreviewBackgroundColor": @"#5C7CA6FF",
            @"linkPreviewBackgroundColorDark": @"#1F4355FF",
            @"linkPreviewTextColor": @"#ACCEDEFF",
            @"linkPreviewTextColorDark": @"#ADCEDFBF",
            @"messageBarButtonColor": @"#ADCEDFFF",
            @"messageBarButtonColorDark": @"#D9B99BC0",
            @"messageBarTintColor": @"#FADDBD3F",
            @"messageBarTintColorDark": @"#1F435598",
            @"messageInputTextColor": @"#1F4355FF",
            @"messageInputTextColorDark": @"#ADCEDFBF",
            @"messagePreviewTextColor": @"#1F435599",
            @"messagePreviewTextColorDark": @"#ADCEDF7E",
            @"navBarTintColor": @"#ACCEDFFF",
            @"navBarTintColorDark": @"#1C425480",
            @"navPlatterColor": @"#FFFFFF66",
            @"navPlatterColorDark": @"#29435326",
            @"isNavButtonBlurEnabled": @YES,
            @"isNavButtonBlurEnabledDark": @YES,
            @"pinnedBubbleColor": @"#ACCEDFFF",
            @"pinnedBubbleColorDark": @"#1C4254FF",
            @"pinnedBubbleTextColor": @"#1F4355FF",
            @"pinnedBubbleTextColorDark": @"#ADCEDFCB",
            @"placeholderText": @"Enter Here",
            @"placeholderTextColor": @"#1E425599",
            @"placeholderTextColorDark": @"#ACCEDF34",
            @"placeholderTextDark": @"Type Here",
            @"receivedBubbleColor": @"#ACCEDFFF",
            @"receivedBubbleColorDark": @"#1C4254FF",
            @"receivedTextColor": @"#1F4355FF",
            @"receivedTextColorDark": @"#ADCEDFCB",
            @"sendButtonArrowColor": @"#FADDBDFF",
            @"sendButtonArrowColorDark": @"#D9B99BFF",
            @"sendButtonColor": @"#ADCEDFFF",
            @"sendButtonColorDark": @"#1F4355FF",
            @"sentBubbleColor": @"#5C7DA6FF",
            @"sentBubbleColorDark": @"#D9B99BFF",
            @"sentSMSBubbleColor": @"#5B7DA6FF",
            @"sentSMSBubbleColorDark": @"#D9B99BFF",
            @"sentSMSTextColor": @"#FFFFFFFF",
            @"sentSMSTextColorDark": @"#F6F0E0FF",
            @"sentTextColor": @"#FFFFFFFF",
            @"sentTextColorDark": @"#F6F0E0FF",
            @"systemTintColor": @"#1F4355FF",
            @"systemTintColorDark": @"#D9B99BFF",
            @"timestampTextColor": @"#1F43555A",
            @"timestampTextColorDark": @"#ADCEDF80",
            @"titleTextColor": @"#1F4355FF",
            @"titleTextColorDark": @"#D9B99BFF",
        }),
        WAMMakeGradientPreset(@"aurora_b", @"Aurora Borealis", @"…localized entirely within your kitchen?",
            @[@"#00A988FF",@"#00B49BFF",@"#00D2C9FF",@"#00F1E4FF",@"#A3FFFEFF"],
            @[@"#01A396FF",@"#439C88FF",@"#4D8EA0FF",@"#3F7CA8FF",@"#4B69CBFF"],
            @{
            @"advancedContactActionColor": @"#1F43554B",
            @"advancedContactActionColorDark": @"#2FFFE4FF",
            @"advancedNavButtonColor": @"#2FFFE4FF",
            @"advancedNavButtonColorDark": @"#2DDDD4FF",
            @"advancedReactionBalloonColor": @"#FEFFFF31",
            @"advancedReactionBalloonColorDark": @"#00000033",
            @"advancedReactionGlyphColor": @"#009191FF",
            @"advancedReactionGlyphColorDark": @"#2FD4C1FF",
            @"advancedReactionHighlightColor": @"#2FFFE4FF",
            @"advancedReactionHighlightColorDark": @"#4AEAD67E",
            @"advancedReportJunkColor": @"#35C2A8FF",
            @"advancedReportJunkColorDark": @"#35C2A8FF",
            @"advancedSearchFieldColor": @"#00000033",
            @"advancedSearchFieldColorDark": @"#2FFFE47F",
            @"advancedStatusCellColor": @"#03261E3E",
            @"advancedStatusCellColorDark": @"#C1F9EAB1",
            @"advancedSwitchTintColor": @"#1D425533",
            @"advancedSwitchTintColorDark": @"#47AAB6FF",
            @"advancedTableLabelColor": @"#1F435566",
            @"advancedTableLabelColorDark": @"#B5F9EDFF",
            @"advancedUnreadDotColor": @"#00A79DFF",
            @"advancedUnreadDotColorDark": @"#2DDDD4FF",
            @"cellTintColor": @"#D9B99BFF",
            @"cellTintColorDark": @"#35C2A8FF",
            @"chatContactNameColor": @"#2FFFE4FF",
            @"chatContactNameColorDark": @"#2FFFE4FF",
            @"chatImageBlurAmount": @(0.0),
            @"chatImageBlurAmountDark": @(0.0),
            @"convListCellColor": @"#FFFFFF14",
            @"convListCellColorDark": @"#FFFFFF14",
            @"conversationListTitleColor": @"#028574FF",
            @"conversationListTitleColorDark": @"#DAF8FFFF",
            @"conversationListTitleText": @"Welcome Back",
            @"conversationListTitleTextDark": @"Welcome Back",
            @"dateTimeTextColor": @"#0185747F",
            @"dateTimeTextColorDark": @"#E1FDF18D",
            @"imageBlurAmount": @(0.0),
            @"imageBlurAmountDark": @(0.0),
            @"inputFieldBackgroundColor": @"#00C4B9FF",
            @"inputFieldBackgroundColorDark": @"#676DA5FF",
            @"inputFieldBlurStyle": @"light",
            @"inputFieldBlurStyleDark": @"dark",
            @"isAdvancedTintEnabled": @YES,
            @"isAdvancedTintEnabledDark": @YES,
            @"isBlurBubblesEnabled": @YES,
            @"isBlurBubblesEnabledDark": @YES,
            @"isCellBlurTintEnabled": @NO,
            @"isCellBlurTintEnabledDark": @YES,
            @"isChatColorBgEnabled": @NO,
            @"isChatColorBgEnabledDark": @NO,
            @"isChatImageBgEnabled": @YES,
            @"isChatImageBgEnabledDark": @YES,
            @"isConvColorBgEnabled": @NO,
            @"isConvColorBgEnabledDark": @NO,
            @"isConvImageBgEnabled": @YES,
            @"isConvImageBgEnabledDark": @YES,
            @"isCustomBubbleColorsEnabled": @YES,
            @"isCustomBubbleColorsEnabledDark": @YES,
            @"isCustomTextColorsEnabled": @YES,
            @"isCustomTextColorsEnabledDark": @YES,
            @"isInputFieldBlurEnabled": @YES,
            @"isInputFieldBlurEnabledDark": @YES,
            @"isInputFieldCustomizationEnabled": @YES,
            @"isInputFieldCustomizationEnabledDark": @YES,
            @"isMessageBarButtonsEnabled": @YES,
            @"isMessageBarButtonsEnabledDark": @YES,
            @"isMessageBarCustomizationEnabled": @YES,
            @"isMessageBarCustomizationEnabledDark": @YES,
            @"isMessageInputTextEnabled": @YES,
            @"isMessageInputTextEnabledDark": @YES,
            @"isModernMessageBarEnabledDark": @YES,
            @"isModernNavBarEnabled": @YES,
            @"isModernNavBarEnabledDark": @YES,
            @"isNavBarCustomizationEnabled": @YES,
            @"isNavBarCustomizationEnabledDark": @YES,
            @"isPerContactChatBgEnabledDark": @YES,
            @"isPinnedGlowEnabled": @YES,
            @"isPlaceholderCustomizationEnabled": @YES,
            @"isPlaceholderCustomizationEnabledDark": @YES,
            @"isSearchBgEnabled": @YES,
            @"isSeparatorsEnabled": @YES,
            @"linkPreviewBackgroundColor": @"#FEFFFF33",
            @"linkPreviewBackgroundColorDark": @"#7133B833",
            @"linkPreviewTextColor": @"#009B90FF",
            @"linkPreviewTextColorDark": @"#CEF8ECFF",
            @"messageBarButtonColor": @"#00C4B9FF",
            @"messageBarButtonColorDark": @"#71AEFEBE",
            @"messageBarTintColor": @"#93FFEE00",
            @"messageBarTintColorDark": @"#6A6FE419",
            @"messageInputTextColor": @"#1F4355CB",
            @"messageInputTextColorDark": @"#CFF8F0FF",
            @"messagePreviewTextColor": @"#0185747F",
            @"messagePreviewTextColorDark": @"#D5FEF7FF",
            @"navBarTintColor": @"#2EFFE400",
            @"navBarTintColorDark": @"#34C2A84B",
            @"navPlatterColor": @"#2EDDD466",
            @"navPlatterColorDark": @"#44ADA559",
            @"isNavButtonBlurEnabled": @YES,
            @"isNavButtonBlurEnabledDark": @YES,
            @"pinnedBubbleColor": @"#00C4B9FF",
            @"pinnedBubbleColorDark": @"#35C2A8FF",
            @"pinnedBubbleTextColor": @"#0000003F",
            @"pinnedBubbleTextColorDark": @"#06302BFF",
            @"placeholderText": @"Enter Here",
            @"placeholderTextColor": @"#00000033",
            @"placeholderTextColorDark": @"#DAC9FF7F",
            @"placeholderTextDark": @"Enter Here",
            @"receivedBubbleColor": @"#FEFFFF33",
            @"receivedBubbleColorDark": @"#00000031",
            @"receivedTextColor": @"#0000004B",
            @"receivedTextColorDark": @"#FEFFFFB3",
            @"sendButtonArrowColor": @"#1F4355FF",
            @"sendButtonArrowColorDark": @"#C2F8E2FF",
            @"sendButtonColor": @"#00E0D5FF",
            @"sendButtonColorDark": @"#34C2A8FF",
            @"sentBubbleColor": @"#005EFD3E",
            @"sentBubbleColorDark": @"#005FFD40",
            @"sentSMSBubbleColor": @"#30C55939",
            @"sentSMSBubbleColorDark": @"#31C65938",
            @"sentSMSTextColor": @"#0000004C",
            @"sentSMSTextColorDark": @"#F1FFF4BF",
            @"sentTextColor": @"#0000004B",
            @"sentTextColorDark": @"#E6FEFEBF",
            @"systemTintColor": @"#1F43553E",
            @"systemTintColorDark": @"#34C2A8FF",
            @"timestampTextColor": @"#1432364B",
            @"timestampTextColorDark": @"#93FFEE7F",
            @"titleTextColor": @"#008574FF",
            @"titleTextColorDark": @"#93FFEEFF",
        }),
        WAMMakeGradientPreset(@"sunrise", @"Sunrise to Sunset", @"Dawn to dusk, 9 to 5.",
            @[@"#A8C9EAFF",@"#BEDBE9FF",@"#E1C5B7FF",@"#E49958FF",@"#FCA829FF"],
            @[@"#F9C33CFF",@"#FCA82BFF",@"#E27E1CFF",@"#D6620FFF",@"#DA5100FF"],
            @{
            @"advancedContactActionColor": @"#E37E1CFF",
            @"advancedContactActionColorDark": @"#FF6900FF",
            @"advancedNavButtonColor": @"#D7620FFF",
            @"advancedNavButtonColorDark": @"#DA5100FF",
            @"advancedReactionBalloonColor": @"#FEFFFF33",
            @"advancedReactionBalloonColorDark": @"#33160C3F",
            @"advancedReactionGlyphColor": @"#FFF3E4FF",
            @"advancedReactionGlyphColorDark": @"#FBA828FF",
            @"advancedReactionHighlightColor": @"#FEDCCABE",
            @"advancedReactionHighlightColorDark": @"#E37E1CFF",
            @"advancedReportJunkColor": @"#F1521EFF",
            @"advancedReportJunkColorDark": @"#FF7A45FF",
            @"advancedSearchFieldColor": @"#FEFFFF7E",
            @"advancedSearchFieldColorDark": @"#FEECD45B",
            @"advancedStatusCellColor": @"#FFF5E267",
            @"advancedStatusCellColorDark": @"#FCA829B2",
            @"advancedSwitchTintColor": @"#FCA829FF",
            @"advancedSwitchTintColorDark": @"#FCA829FF",
            @"advancedTableLabelColor": @"#37130081",
            @"advancedTableLabelColorDark": @"#FEE4A8FF",
            @"advancedUnreadDotColor": @"#FF3A2FFF",
            @"advancedUnreadDotColorDark": @"#DA5100FF",
            @"cellTintColor": @"#9BBFD1FF",
            @"cellTintColorDark": @"#CF9D79FF",
            @"chatContactNameColor": @"#522B12FF",
            @"chatContactNameColorDark": @"#FED976FF",
            @"chatImageBlurAmount": @0,
            @"chatImageBlurAmountDark": @0,
            @"conversationListTitleColor": @"#3E372AFF",
            @"conversationListTitleColorDark": @"#DA5100FF",
            @"conversationListTitleText": @"Back at It",
            @"conversationListTitleTextDark": @"Back at It",
            @"dateTimeTextColor": @"#B06B4E7F",
            @"dateTimeTextColorDark": @"#FFC77665",
            @"imageBlurAmount": @0,
            @"imageBlurAmountDark": @0,
            @"inputFieldBackgroundColor": @"#F1C1B6FF",
            @"inputFieldBackgroundColorDark": @"#AD3E005B",
            @"inputFieldBlurStyle": @"light",
            @"inputFieldBlurStyleDark": @"dark",
            @"isAdvancedTintEnabled": @YES,
            @"isBlurBubblesEnabled": @YES,
            @"isBlurBubblesEnabledDark": @YES,
            @"isCellBlurTintEnabled": @YES,
            @"isChatColorBgEnabled": @NO,
            @"isChatColorBgEnabledDark": @NO,
            @"isChatImageBgEnabled": @YES,
            @"isChatImageBgEnabledDark": @YES,
            @"isConvColorBgEnabled": @NO,
            @"isConvColorBgEnabledDark": @NO,
            @"isConvImageBgEnabled": @YES,
            @"isConvImageBgEnabledDark": @YES,
            @"isCustomBubbleColorsEnabled": @YES,
            @"isCustomBubbleColorsEnabledDark": @YES,
            @"isCustomTextColorsEnabled": @YES,
            @"isCustomTextColorsEnabledDark": @YES,
            @"isInputFieldBlurEnabled": @YES,
            @"isInputFieldBlurEnabledDark": @YES,
            @"isInputFieldCustomizationEnabled": @YES,
            @"isInputFieldCustomizationEnabledDark": @YES,
            @"isMessageBarButtonsEnabled": @YES,
            @"isMessageBarButtonsEnabledDark": @YES,
            @"isMessageBarCustomizationEnabled": @YES,
            @"isMessageBarCustomizationEnabledDark": @YES,
            @"isMessageInputTextEnabled": @YES,
            @"isMessageInputTextEnabledDark": @YES,
            @"isModernMessageBarEnabled": @YES,
            @"isModernMessageBarEnabledDark": @YES,
            @"isModernNavBarEnabled": @YES,
            @"isModernNavBarEnabledDark": @YES,
            @"isNavBarCustomizationEnabled": @YES,
            @"isNavBarCustomizationEnabledDark": @YES,
            @"isPinnedGlowEnabled": @YES,
            @"isPlaceholderCustomizationEnabled": @YES,
            @"isPlaceholderCustomizationEnabledDark": @YES,
            @"isSearchBgEnabled": @YES,
            @"isSeparatorsEnabled": @YES,
            @"linkPreviewBackgroundColor": @"#FEC6B57F",
            @"linkPreviewBackgroundColorDark": @"#38180C41",
            @"linkPreviewTextColor": @"#5B2310BF",
            @"linkPreviewTextColorDark": @"#FFE0CEFF",
            @"messageBarButtonColor": @"#F9701CBE",
            @"messageBarButtonColorDark": @"#FEB43DBC",
            @"messageBarTintColor": @"#E37E1C66",
            @"messageBarTintColorDark": @"#FF7A453D",
            @"messageInputTextColor": @"#59390EBE",
            @"messageInputTextColorDark": @"#FEE4A8FF",
            @"messagePreviewTextColor": @"#644A2B65",
            @"messagePreviewTextColorDark": @"#FFD9A87F",
            @"navBarTintColor": @"#ACCEDF32",
            @"navBarTintColorDark": @"#F9C43B5A",
            @"navPlatterColor": @"#E0F7FF4D",
            @"navPlatterColorDark": @"#F0AC494D",
            @"isNavButtonBlurEnabled": @YES,
            @"isNavButtonBlurEnabledDark": @YES,
            @"pinnedBubbleColor": @"#F1521EFF",
            @"pinnedBubbleColorDark": @"#E37E1CFF",
            @"pinnedBubbleTextColor": @"#FFFFFFFF",
            @"pinnedBubbleTextColorDark": @"#FFC5ABBE",
            @"placeholderText": @"What’s on Your Mind?",
            @"placeholderTextColor": @"#4D30124B",
            @"placeholderTextColorDark": @"#FFC5AB7F",
            @"placeholderTextDark": @"What’s Up?",
            @"receivedBubbleColor": @"#FEFFFF6C",
            @"receivedBubbleColorDark": @"#37180C40",
            @"receivedTextColor": @"#82574BBE",
            @"receivedTextColorDark": @"#FBEFD3FF",
            @"sendButtonArrowColor": @"#F9C43BFF",
            @"sendButtonArrowColorDark": @"#FFD9A8FF",
            @"sendButtonColor": @"#DA5100FF",
            @"sendButtonColorDark": @"#FF6900FF",
            @"sentBubbleColor": @"#F1521D33",
            @"sentBubbleColorDark": @"#FF69303F",
            @"sentSMSBubbleColor": @"#F0521C33",
            @"sentSMSBubbleColorDark": @"#FE693040",
            @"sentSMSTextColor": @"#FEFFFFCC",
            @"sentSMSTextColorDark": @"#FEFBDDFF",
            @"sentTextColor": @"#FEFFFFCB",
            @"sentTextColorDark": @"#FEFBDFFF",
            @"systemTintColor": @"#E37E1CFF",
            @"systemTintColorDark": @"#FEE4A7FF",
            @"timestampTextColor": @"#5832007F",
            @"timestampTextColorDark": @"#FFC5AB7E",
            @"titleTextColor": @"#3D160A66",
            @"titleTextColorDark": @"#FFD9A8FF",
        }),
        ]];

        [arr addObjectsFromArray:@[
        WAMMakeGradientPreset(@"synthwave", @"Synthwave", @"Synthetic Waves? A wavepool?",
            @[@"#FFC597FF",@"#FFB9B9FF",@"#FFAFDAFF"],
            @[@"#2A0A55FF",@"#C01E8BFF",@"#FF7A4DFF"],
            @{
            @"advancedContactActionColor": @"#E981E4FF",
            @"advancedContactActionColorDark": @"#FFBDE7BE",
            @"advancedNavButtonColor": @"#E981E4FF",
            @"advancedNavButtonColorDark": @"#DC49FEFF",
            @"advancedReactionBalloonColor": @"#FEDCFF3F",
            @"advancedReactionBalloonColorDark": @"#28184B33",
            @"advancedReactionGlyphColor": @"#623289FF",
            @"advancedReactionGlyphColorDark": @"#FF99FFFF",
            @"advancedReactionHighlightColor": @"#E981E465",
            @"advancedReactionHighlightColorDark": @"#FF18AA80",
            @"advancedReportJunkColor": @"#B04DE8FF",
            @"advancedReportJunkColorDark": @"#C24DFFFF",
            @"advancedSearchFieldColor": @"#62328933",
            @"advancedSearchFieldColorDark": @"#DAC9FF58",
            @"advancedStatusCellColor": @"#6132894F",
            @"advancedStatusCellColorDark": @"#E6A5FF7E",
            @"advancedSwitchTintColor": @"#FF9BA1FF",
            @"advancedSwitchTintColorDark": @"#C059FEFF",
            @"advancedTableLabelColor": @"#2B124697",
            @"advancedTableLabelColorDark": @"#FBC6FFD8",
            @"advancedUnreadDotColor": @"#B04DE8FF",
            @"advancedUnreadDotColorDark": @"#C24DFFFF",
            @"cellTintColor": @"#FFBF9EFF",
            @"cellTintColorDark": @"#865B9DFF",
            @"chatContactNameColor": @"#2C114699",
            @"chatContactNameColorDark": @"#ECC4FFFF",
            @"chatImageBlurAmount": @0,
            @"chatImageBlurAmountDark": @0,
            @"conversationListTitleColor": @"#2B124699",
            @"conversationListTitleColorDark": @"#FFA6FFFF",
            @"conversationListTitleText": @"Welcome Back",
            @"conversationListTitleTextDark": @"Welcome Back",
            @"dateTimeTextColor": @"#2B114533",
            @"dateTimeTextColorDark": @"#A784D8B1",
            @"imageBlurAmount": @0,
            @"imageBlurAmountDark": @0,
            @"inputFieldBackgroundColor": @"#AF859833",
            @"inputFieldBackgroundColorDark": @"#887DB0FF",
            @"inputFieldBlurStyle": @"light",
            @"inputFieldBlurStyleDark": @"dark",
            @"isAdvancedTintEnabled": @YES,
            @"isBlurBubblesEnabled": @YES,
            @"isBlurBubblesEnabledDark": @YES,
            @"isCellBlurTintEnabled": @YES,
            @"isChatColorBgEnabled": @NO,
            @"isChatColorBgEnabledDark": @NO,
            @"isChatImageBgEnabled": @YES,
            @"isChatImageBgEnabledDark": @YES,
            @"isConvColorBgEnabled": @NO,
            @"isConvColorBgEnabledDark": @NO,
            @"isConvImageBgEnabled": @YES,
            @"isConvImageBgEnabledDark": @YES,
            @"isCustomBubbleColorsEnabled": @YES,
            @"isCustomBubbleColorsEnabledDark": @YES,
            @"isCustomTextColorsEnabled": @YES,
            @"isCustomTextColorsEnabledDark": @YES,
            @"isInputFieldBlurEnabled": @YES,
            @"isInputFieldBlurEnabledDark": @YES,
            @"isInputFieldCustomizationEnabled": @YES,
            @"isInputFieldCustomizationEnabledDark": @YES,
            @"isMessageBarButtonsEnabled": @YES,
            @"isMessageBarButtonsEnabledDark": @YES,
            @"isMessageBarCustomizationEnabled": @YES,
            @"isMessageBarCustomizationEnabledDark": @YES,
            @"isMessageInputTextEnabled": @YES,
            @"isMessageInputTextEnabledDark": @YES,
            @"isModernMessageBarEnabled": @YES,
            @"isModernMessageBarEnabledDark": @YES,
            @"isModernNavBarEnabled": @YES,
            @"isModernNavBarEnabledDark": @YES,
            @"isNavBarCustomizationEnabled": @YES,
            @"isNavBarCustomizationEnabledDark": @YES,
            @"isPinnedGlowEnabled": @YES,
            @"isPlaceholderCustomizationEnabled": @YES,
            @"isPlaceholderCustomizationEnabledDark": @YES,
            @"isSearchBgEnabled": @YES,
            @"isSeparatorsEnabled": @YES,
            @"linkPreviewBackgroundColor": @"#FEDCFF4A",
            @"linkPreviewBackgroundColorDark": @"#28184B33",
            @"linkPreviewTextColor": @"#623289FF",
            @"linkPreviewTextColorDark": @"#F9B4FFD8",
            @"messageBarButtonColor": @"#E981E4FF",
            @"messageBarButtonColorDark": @"#D27DFFFF",
            @"messageBarTintColor": @"#BB869966",
            @"messageBarTintColorDark": @"#C24C8556",
            @"messageInputTextColor": @"#9235ADFF",
            @"messageInputTextColorDark": @"#FFD2FFFF",
            @"messagePreviewTextColor": @"#7E5FA081",
            @"messagePreviewTextColorDark": @"#DAC9FF7F",
            @"navBarTintColor": @"#FF7E8D4C",
            @"navBarTintColorDark": @"#2C09761A",
            @"navPlatterColor": @"#FCEDD74D",
            @"navPlatterColorDark": @"#280B7259",
            @"isNavButtonBlurEnabled": @YES,
            @"isNavButtonBlurEnabledDark": @YES,
            @"pinnedBubbleColor": @"#FFD7FFB2",
            @"pinnedBubbleColorDark": @"#B44CA7FF",
            @"pinnedBubbleTextColor": @"#623289FF",
            @"pinnedBubbleTextColorDark": @"#FEFFFFB2",
            @"placeholderText": @"Enter Here",
            @"placeholderTextColor": @"#6232897F",
            @"placeholderTextColorDark": @"#FFC3FF7F",
            @"placeholderTextDark": @"Enter Here",
            @"receivedBubbleColor": @"#FFDDFF4B",
            @"receivedBubbleColorDark": @"#28184C33",
            @"receivedTextColor": @"#62338AFF",
            @"receivedTextColorDark": @"#E6B0FFFF",
            @"sendButtonArrowColor": @"#F3E7FFFF",
            @"sendButtonArrowColorDark": @"#FFC8FFFF",
            @"sendButtonColor": @"#E981E4FF",
            @"sendButtonColorDark": @"#B058BBFF",
            @"sentBubbleColor": @"#7344E23E",
            @"sentBubbleColorDark": @"#FF3DBE4B",
            @"sentSMSBubbleColor": @"#10C7E64D",
            @"sentSMSBubbleColorDark": @"#00E5FF59",
            @"sentSMSTextColor": @"#EEDFFDFF",
            @"sentSMSTextColorDark": @"#FFD1FFFF",
            @"sentTextColor": @"#EFDFFDFF",
            @"sentTextColorDark": @"#FFD0FFFF",
            @"systemTintColor": @"#B04DE8FF",
            @"systemTintColorDark": @"#DAC9FFFF",
            @"timestampTextColor": @"#6232899A",
            @"timestampTextColorDark": @"#F38AF1B1",
            @"titleTextColor": @"#2B11457F",
            @"titleTextColorDark": @"#FCBDFFCC",
        }),
        WAMMakeGradientPreset(@"sakura", @"Sakura", @"Minecraft cherry tree type stuff",
            @[@"#F0D3E7FF",@"#E49BB9FF",@"#DA638DFF"],
            @[@"#280B1FFF",@"#803755FF",@"#DA638DFF"],
            @{
            @"advancedContactActionColor": @"#F55C92FF",
            @"advancedContactActionColorDark": @"#FF80AEFF",
            @"advancedNavButtonColor": @"#F55C92FF",
            @"advancedNavButtonColorDark": @"#FF80AEFF",
            @"advancedReactionBalloonColor": @"#FAD8E559",
            @"advancedReactionBalloonColorDark": @"#FDC6F23F",
            @"advancedReactionGlyphColor": @"#9A557CFF",
            @"advancedReactionGlyphColorDark": @"#FDC6F2FF",
            @"advancedReactionHighlightColor": @"#C27DA47E",
            @"advancedReactionHighlightColorDark": @"#F495B8D8",
            @"advancedReportJunkColor": @"#F55C92FF",
            @"advancedReportJunkColorDark": @"#FF80AEFF",
            @"advancedSearchFieldColor": @"#4E16294D",
            @"advancedSearchFieldColorDark": @"#FFBCE258",
            @"advancedStatusCellColor": @"#B05F7980",
            @"advancedStatusCellColorDark": @"#CA8DA87F",
            @"advancedSwitchTintColor": @"#F18AAAFF",
            @"advancedSwitchTintColorDark": @"#FF80AEFF",
            @"advancedTableLabelColor": @"#9A547BFF",
            @"advancedTableLabelColorDark": @"#FDC6F2FF",
            @"advancedUnreadDotColor": @"#F55C92FF",
            @"advancedUnreadDotColorDark": @"#FF80AEFF",
            @"cellTintColor": @"#FAD8E5FF",
            @"cellTintColorDark": @"#8D4863FF",
            @"chatContactNameColor": @"#9A557CFF",
            @"chatContactNameColorDark": @"#F4A4C0FF",
            @"chatImageBlurAmount": @0,
            @"chatImageBlurAmountDark": @0,
            @"conversationListTitleColor": @"#9A547BFF",
            @"conversationListTitleColorDark": @"#F3A3BFFF",
            @"conversationListTitleText": @"Let’s Go",
            @"conversationListTitleTextDark": @"Let’s Go",
            @"dateTimeTextColor": @"#9A567C7F",
            @"dateTimeTextColorDark": @"#FFB1EE66",
            @"imageBlurAmount": @0,
            @"imageBlurAmountDark": @0,
            @"inputFieldBackgroundColor": @"#FAD8E5FF",
            @"inputFieldBackgroundColorDark": @"#F9A2C8FF",
            @"inputFieldBlurStyle": @"light",
            @"inputFieldBlurStyleDark": @"regular",
            @"isAdvancedTintEnabled": @YES,
            @"isBlurBubblesEnabled": @YES,
            @"isBlurBubblesEnabledDark": @YES,
            @"isCellBlurTintEnabled": @YES,
            @"isChatColorBgEnabled": @NO,
            @"isChatColorBgEnabledDark": @NO,
            @"isChatImageBgEnabled": @YES,
            @"isChatImageBgEnabledDark": @YES,
            @"isConvColorBgEnabled": @NO,
            @"isConvColorBgEnabledDark": @NO,
            @"isConvImageBgEnabled": @YES,
            @"isConvImageBgEnabledDark": @YES,
            @"isCustomBubbleColorsEnabled": @YES,
            @"isCustomBubbleColorsEnabledDark": @YES,
            @"isCustomTextColorsEnabled": @YES,
            @"isCustomTextColorsEnabledDark": @YES,
            @"isInputFieldBlurEnabled": @YES,
            @"isInputFieldBlurEnabledDark": @YES,
            @"isInputFieldCustomizationEnabled": @YES,
            @"isInputFieldCustomizationEnabledDark": @YES,
            @"isMessageBarButtonsEnabled": @YES,
            @"isMessageBarButtonsEnabledDark": @YES,
            @"isMessageBarCustomizationEnabled": @YES,
            @"isMessageBarCustomizationEnabledDark": @YES,
            @"isMessageInputTextEnabled": @YES,
            @"isMessageInputTextEnabledDark": @YES,
            @"isModernMessageBarEnabled": @YES,
            @"isModernMessageBarEnabledDark": @YES,
            @"isModernNavBarEnabled": @YES,
            @"isModernNavBarEnabledDark": @YES,
            @"isNavBarCustomizationEnabled": @YES,
            @"isNavBarCustomizationEnabledDark": @YES,
            @"isPinnedGlowEnabled": @YES,
            @"isPlaceholderCustomizationEnabled": @YES,
            @"isPlaceholderCustomizationEnabledDark": @YES,
            @"isSearchBgEnabled": @YES,
            @"isSeparatorsEnabled": @YES,
            @"linkPreviewBackgroundColor": @"#FBD9E67F",
            @"linkPreviewBackgroundColorDark": @"#FEC7F33F",
            @"linkPreviewTextColor": @"#6E2444FF",
            @"linkPreviewTextColorDark": @"#FFBCE2FF",
            @"messageBarButtonColor": @"#FFBCE1FF",
            @"messageBarButtonColorDark": @"#FF80AEE0",
            @"messageBarTintColor": @"#D8638C33",
            @"messageBarTintColorDark": @"#FF80AE33",
            @"messageInputTextColor": @"#9A567DFF",
            @"messageInputTextColorDark": @"#FFBCE4FF",
            @"messagePreviewTextColor": @"#9A557BA5",
            @"messagePreviewTextColorDark": @"#FFC0DF7F",
            @"navBarTintColor": @"#FAD8E54B",
            @"navBarTintColorDark": @"#3B071A3E",
            @"navPlatterColor": @"#FFFFFF4D",
            @"navPlatterColorDark": @"#FF9EA933",
            @"isNavButtonBlurEnabled": @YES,
            @"isNavButtonBlurEnabledDark": @YES,
            @"pinnedBubbleColor": @"#FAD8E5BE",
            @"pinnedBubbleColorDark": @"#F3A3BFCB",
            @"pinnedBubbleTextColor": @"#9A567CFF",
            @"pinnedBubbleTextColorDark": @"#FFBCE2FF",
            @"placeholderText": @"Ready to Go?",
            @"placeholderTextColor": @"#9A567D7E",
            @"placeholderTextColorDark": @"#FEFFFF3F",
            @"placeholderTextDark": @"Ready to Go?",
            @"receivedBubbleColor": @"#FAD9E54C",
            @"receivedBubbleColorDark": @"#FDC6F240",
            @"receivedTextColor": @"#9A577DFF",
            @"receivedTextColorDark": @"#FFBCE3FF",
            @"sendButtonArrowColor": @"#FFBCE1FF",
            @"sendButtonArrowColorDark": @"#FFBCE3FF",
            @"sendButtonColor": @"#FE6C9CFF",
            @"sendButtonColorDark": @"#FF77A8FF",
            @"sentBubbleColor": @"#FE88B858",
            @"sentBubbleColorDark": @"#FF77A84B",
            @"sentSMSBubbleColor": @"#FF89B85A",
            @"sentSMSBubbleColorDark": @"#FF9BC24C",
            @"sentSMSTextColor": @"#FFBCE2FF",
            @"sentSMSTextColorDark": @"#FFBCE3FF",
            @"sentTextColor": @"#FFBCE1FF",
            @"sentTextColorDark": @"#FFBCE3FF",
            @"systemTintColor": @"#F55C92FF",
            @"systemTintColorDark": @"#FF80AEFF",
            @"timestampTextColor": @"#B05F787F",
            @"timestampTextColorDark": @"#CA8DA8BF",
            @"titleTextColor": @"#9A567CFF",
            @"titleTextColorDark": @"#F3A3BFFF",
        }),
        WAMMakeGradientPreset(@"unc0ver", @"Unc0ver", @"Uncover this great theme!",
            @[@"#EAEAF6FF",@"#CBCAD8FF",@"#ABADBAFF"],
            @[@"#1C1C24FF",@"#4F5055FF",@"#77787DFF"],
            @{
            @"advancedContactActionColor": @"#798894FF",
            @"advancedContactActionColorDark": @"#9AA6B2FF",
            @"advancedNavButtonColor": @"#242730FF",
            @"advancedNavButtonColorDark": @"#9AA6B2FF",
            @"advancedReactionBalloonColor": @"#E3E5EEFF",
            @"advancedReactionBalloonColorDark": @"#98A6B2FF",
            @"advancedReactionGlyphColor": @"#798894FF",
            @"advancedReactionGlyphColorDark": @"#E4E5EFFF",
            @"advancedReactionHighlightColor": @"#BAC3CFFF",
            @"advancedReactionHighlightColorDark": @"#B7C4D0FF",
            @"advancedReportJunkColor": @"#4C6470FF",
            @"advancedReportJunkColorDark": @"#9AA6B2FF",
            @"advancedSearchFieldColor": @"#5C5C5C99",
            @"advancedSearchFieldColorDark": @"#E3E5EE4D",
            @"advancedStatusCellColor": @"#7C828CFF",
            @"advancedStatusCellColorDark": @"#ADADADC1",
            @"advancedSwitchTintColor": @"#798894FF",
            @"advancedSwitchTintColorDark": @"#9AA6B2FF",
            @"advancedTableLabelColor": @"#242730C0",
            @"advancedTableLabelColorDark": @"#E4E5EFCC",
            @"advancedUnreadDotColor": @"#4C6470FF",
            @"advancedUnreadDotColorDark": @"#9AA6B2FF",
            @"cellTintColor": @"#798894FF",
            @"cellTintColorDark": @"#657380FF",
            @"chatContactNameColor": @"#43464DFF",
            @"chatContactNameColorDark": @"#E4E5EFFF",
            @"chatImageBlurAmount": @0,
            @"chatImageBlurAmountDark": @0,
            @"conversationListTitleColor": @"#43464CFF",
            @"conversationListTitleColorDark": @"#E3E5EEFF",
            @"conversationListTitleText": @"What’s Up?",
            @"conversationListTitleTextDark": @"What’s Up?",
            @"dateTimeTextColor": @"#7B828C99",
            @"dateTimeTextColorDark": @"#E3E5EE4C",
            @"imageBlurAmount": @0,
            @"imageBlurAmountDark": @0,
            @"inputFieldBackgroundColor": @"#798894FF",
            @"inputFieldBackgroundColorDark": @"#76787DFF",
            @"inputFieldBlurStyle": @"light",
            @"inputFieldBlurStyleDark": @"dark",
            @"isAdvancedTintEnabled": @YES,
            @"isBlurBubblesEnabled": @NO,
            @"isBlurBubblesEnabledDark": @NO,
            @"isCellBlurTintEnabled": @YES,
            @"isChatColorBgEnabled": @NO,
            @"isChatColorBgEnabledDark": @NO,
            @"isChatImageBgEnabled": @YES,
            @"isChatImageBgEnabledDark": @YES,
            @"isConvColorBgEnabled": @NO,
            @"isConvColorBgEnabledDark": @NO,
            @"isConvImageBgEnabled": @YES,
            @"isConvImageBgEnabledDark": @YES,
            @"isCustomBubbleColorsEnabled": @YES,
            @"isCustomBubbleColorsEnabledDark": @YES,
            @"isCustomTextColorsEnabled": @YES,
            @"isCustomTextColorsEnabledDark": @YES,
            @"isInputFieldBlurEnabled": @YES,
            @"isInputFieldBlurEnabledDark": @YES,
            @"isInputFieldCustomizationEnabled": @YES,
            @"isInputFieldCustomizationEnabledDark": @YES,
            @"isMessageBarButtonsEnabled": @YES,
            @"isMessageBarButtonsEnabledDark": @YES,
            @"isMessageBarCustomizationEnabled": @YES,
            @"isMessageBarCustomizationEnabledDark": @YES,
            @"isMessageInputTextEnabled": @YES,
            @"isMessageInputTextEnabledDark": @YES,
            @"isModernMessageBarEnabled": @YES,
            @"isModernMessageBarEnabledDark": @YES,
            @"isModernNavBarEnabled": @YES,
            @"isModernNavBarEnabledDark": @YES,
            @"isNavBarCustomizationEnabled": @YES,
            @"isNavBarCustomizationEnabledDark": @YES,
            @"isPinnedGlowEnabled": @YES,
            @"isPlaceholderCustomizationEnabled": @YES,
            @"isPlaceholderCustomizationEnabledDark": @YES,
            @"isSearchBgEnabled": @YES,
            @"isSeparatorsEnabled": @YES,
            @"linkPreviewBackgroundColor": @"#E4E5EFFF",
            @"linkPreviewBackgroundColorDark": @"#98A6B2FF",
            @"linkPreviewTextColor": @"#798894FF",
            @"linkPreviewTextColorDark": @"#E4E6EFFF",
            @"messageBarButtonColor": @"#788894FF",
            @"messageBarButtonColorDark": @"#9AA6B2E0",
            @"messageBarTintColor": @"#ABADBA3E",
            @"messageBarTintColorDark": @"#76787D4F",
            @"messageInputTextColor": @"#657480FF",
            @"messageInputTextColorDark": @"#E4E5EFFF",
            @"messagePreviewTextColor": @"#798894B2",
            @"messagePreviewTextColorDark": @"#E3E5EE8B",
            @"navBarTintColor": @"#E8EAF64C",
            @"navBarTintColorDark": @"#1B1C2233",
            @"navPlatterColor": @"#D6D6D633",
            @"navPlatterColorDark": @"#00000033",
            @"isNavButtonBlurEnabled": @YES,
            @"isNavButtonBlurEnabledDark": @YES,
            @"pinnedBubbleColor": @"#242730FF",
            @"pinnedBubbleColorDark": @"#98A6B2FF",
            @"pinnedBubbleTextColor": @"#C6C7D1FF",
            @"pinnedBubbleTextColorDark": @"#E4E5EFFF",
            @"placeholderText": @"Uncover the truth",
            @"placeholderTextColor": @"#1919193E",
            @"placeholderTextColorDark": @"#FEFFFF4D",
            @"placeholderTextDark": @"Uncover the truth",
            @"receivedBubbleColor": @"#E4E5EFFF",
            @"receivedBubbleColorDark": @"#99A6B2FF",
            @"receivedTextColor": @"#7A8894FF",
            @"receivedTextColorDark": @"#E5E5F0FF",
            @"sendButtonArrowColor": @"#E4E5EFFF",
            @"sendButtonArrowColorDark": @"#262831FF",
            @"sendButtonColor": @"#798894FF",
            @"sendButtonColorDark": @"#C6C8D1FF",
            @"sentBubbleColor": @"#252830FF",
            @"sentBubbleColorDark": @"#C7C7D2FF",
            @"sentSMSBubbleColor": @"#25282FFF",
            @"sentSMSBubbleColorDark": @"#C8C8D2FF",
            @"sentSMSTextColor": @"#C5C8D0FF",
            @"sentSMSTextColorDark": @"#272832FF",
            @"sentTextColor": @"#C6C7D1FF",
            @"sentTextColorDark": @"#262831FF",
            @"systemTintColor": @"#4C6470FF",
            @"systemTintColorDark": @"#E5E6F0FF",
            @"timestampTextColor": @"#7B828C98",
            @"timestampTextColorDark": @"#89929CA6",
            @"titleTextColor": @"#24273099",
            @"titleTextColorDark": @"#E3E5EEFF",
        }),
        WAMMakeGradientPreset(@"taurine", @"Taurine", @"Also found in Monster energy drinks.",
            @[@"#DCDCFFFF",@"#D8B0ECFF",@"#FFB5ACFF"],
            @[@"#2E2DD0FF",@"#792CB0FF",@"#E84C59FF"],
            @{
            @"advancedContactActionColor": @"#724FB9FF",
            @"advancedContactActionColorDark": @"#CEA9FAFF",
            @"advancedNavButtonColor": @"#7A4CE0FF",
            @"advancedNavButtonColorDark": @"#FF5592FF",
            @"advancedReactionBalloonColor": @"#3568FF1A",
            @"advancedReactionBalloonColorDark": @"#05041047",
            @"advancedReactionGlyphColor": @"#724EB9FF",
            @"advancedReactionGlyphColorDark": @"#CEA9FAFF",
            @"advancedReactionHighlightColor": @"#CEA9FAFF",
            @"advancedReactionHighlightColorDark": @"#896AE0FF",
            @"advancedReportJunkColor": @"#7A4CE0FF",
            @"advancedReportJunkColorDark": @"#8A6BFFFF",
            @"advancedSearchFieldColor": @"#3732CE3F",
            @"advancedSearchFieldColorDark": @"#DAC9FF59",
            @"advancedStatusCellColor": @"#7A6CA8FF",
            @"advancedStatusCellColorDark": @"#A899D8FF",
            @"advancedSwitchTintColor": @"#CEA9FAFF",
            @"advancedSwitchTintColorDark": @"#8A6BFFFF",
            @"advancedTableLabelColor": @"#724FB9BF",
            @"advancedTableLabelColorDark": @"#DAC9FFB2",
            @"advancedUnreadDotColor": @"#7A4CE0FF",
            @"advancedUnreadDotColorDark": @"#8A6BFFFF",
            @"cellTintColor": @"#B58EE9FF",
            @"cellTintColorDark": @"#724FB9FF",
            @"chatContactNameColor": @"#724FB9FF",
            @"chatContactNameColorDark": @"#D0BBFFFF",
            @"chatImageBlurAmount": @0,
            @"chatImageBlurAmountDark": @0,
            @"conversationListTitleColor": @"#3732CEB3",
            @"conversationListTitleColorDark": @"#DAC9FFFF",
            @"conversationListTitleText": @"Let’s Go!",
            @"conversationListTitleTextDark": @"Let’s Go!",
            @"dateTimeTextColor": @"#724FB94C",
            @"dateTimeTextColorDark": @"#A899D897",
            @"imageBlurAmount": @0,
            @"imageBlurAmountDark": @0,
            @"inputFieldBackgroundColor": @"#DAC9FFFF",
            @"inputFieldBackgroundColorDark": @"#724FB9FF",
            @"inputFieldBlurStyle": @"light",
            @"inputFieldBlurStyleDark": @"dark",
            @"isAdvancedTintEnabled": @YES,
            @"isBlurBubblesEnabled": @YES,
            @"isBlurBubblesEnabledDark": @YES,
            @"isCellBlurTintEnabled": @YES,
            @"isChatColorBgEnabled": @NO,
            @"isChatColorBgEnabledDark": @NO,
            @"isChatImageBgEnabled": @YES,
            @"isChatImageBgEnabledDark": @YES,
            @"isConvColorBgEnabled": @NO,
            @"isConvColorBgEnabledDark": @NO,
            @"isConvImageBgEnabled": @YES,
            @"isConvImageBgEnabledDark": @YES,
            @"isCustomBubbleColorsEnabled": @YES,
            @"isCustomBubbleColorsEnabledDark": @YES,
            @"isCustomTextColorsEnabled": @YES,
            @"isCustomTextColorsEnabledDark": @YES,
            @"isInputFieldBlurEnabled": @YES,
            @"isInputFieldBlurEnabledDark": @YES,
            @"isInputFieldCustomizationEnabled": @YES,
            @"isInputFieldCustomizationEnabledDark": @YES,
            @"isMessageBarButtonsEnabled": @YES,
            @"isMessageBarButtonsEnabledDark": @YES,
            @"isMessageBarCustomizationEnabled": @YES,
            @"isMessageBarCustomizationEnabledDark": @YES,
            @"isMessageInputTextEnabled": @YES,
            @"isMessageInputTextEnabledDark": @YES,
            @"isModernMessageBarEnabled": @YES,
            @"isModernMessageBarEnabledDark": @YES,
            @"isModernNavBarEnabled": @YES,
            @"isModernNavBarEnabledDark": @YES,
            @"isNavBarCustomizationEnabled": @YES,
            @"isNavBarCustomizationEnabledDark": @YES,
            @"isPinnedGlowEnabled": @YES,
            @"isPlaceholderCustomizationEnabled": @YES,
            @"isPlaceholderCustomizationEnabledDark": @YES,
            @"isSearchBgEnabled": @YES,
            @"isSeparatorsEnabled": @YES,
            @"linkPreviewBackgroundColor": @"#3568FF18",
            @"linkPreviewBackgroundColorDark": @"#2C087559",
            @"linkPreviewTextColor": @"#724EB9FF",
            @"linkPreviewTextColorDark": @"#D9C9FEFF",
            @"messageBarButtonColor": @"#FF7991FF",
            @"messageBarButtonColorDark": @"#E981E4FF",
            @"messageBarTintColor": @"#FA515C26",
            @"messageBarTintColorDark": @"#F053584B",
            @"messageInputTextColor": @"#724EB9FF",
            @"messageInputTextColorDark": @"#FFD1FEFF",
            @"messagePreviewTextColor": @"#724FB997",
            @"messagePreviewTextColorDark": @"#CEA9FA99",
            @"navBarTintColor": @"#DAC9FF4A",
            @"navBarTintColorDark": @"#2C097659",
            @"navPlatterColor": @"#EADEFF40",
            @"navPlatterColorDark": @"#6D51B459",
            @"isNavButtonBlurEnabled": @YES,
            @"isNavButtonBlurEnabledDark": @YES,
            @"pinnedBubbleColor": @"#B58EE9B1",
            @"pinnedBubbleColorDark": @"#2B07747D",
            @"pinnedBubbleTextColor": @"#724EB9FF",
            @"pinnedBubbleTextColorDark": @"#D9C9FEFF",
            @"placeholderText": @"Let’s Get Typing",
            @"placeholderTextColor": @"#B58EE973",
            @"placeholderTextColorDark": @"#FFD1FE4D",
            @"placeholderTextDark": @"Let’s Get Typing",
            @"receivedBubbleColor": @"#3468FF1A",
            @"receivedBubbleColorDark": @"#2B087458",
            @"receivedTextColor": @"#724FB9FF",
            @"receivedTextColorDark": @"#DAC9FFFF",
            @"sendButtonArrowColor": @"#FEE9FEFF",
            @"sendButtonArrowColorDark": @"#FFD1FEFF",
            @"sendButtonColor": @"#FF8F99FF",
            @"sendButtonColorDark": @"#FF5592FF",
            @"sentBubbleColor": @"#F0526A33",
            @"sentBubbleColorDark": @"#5C070058",
            @"sentSMSBubbleColor": @"#EF516A31",
            @"sentSMSBubbleColorDark": @"#5B060059",
            @"sentSMSTextColor": @"#FFE9FFFF",
            @"sentSMSTextColorDark": @"#FFD1FFFF",
            @"sentTextColor": @"#FFE9FFFF",
            @"sentTextColorDark": @"#FFD2FFFF",
            @"systemTintColor": @"#7A4CE0FF",
            @"systemTintColorDark": @"#B58EE9FF",
            @"timestampTextColor": @"#796CA898",
            @"timestampTextColorDark": @"#A899D8A7",
            @"titleTextColor": @"#724FB9FF",
            @"titleTextColorDark": @"#DAC9FFFF",
        }),
        WAMMakeGradientPreset(@"sileo", @"Sileo", @"Managing this package of colors.",
            @[@"#DCF5F2FF",@"#A7E6DEFF",@"#5ED6CAFF"],
            @[@"#032F2EFF",@"#0A6B64FF",@"#14B0A2FF"],
            @{
            @"advancedContactActionColor": @"#2BB1BEFF",
            @"advancedContactActionColorDark": @"#2FEAF9FF",
            @"advancedNavButtonColor": @"#2BB1BEFF",
            @"advancedNavButtonColorDark": @"#1ED4DCFF",
            @"advancedReactionBalloonColor": @"#C9F0FD66",
            @"advancedReactionBalloonColorDark": @"#04272F58",
            @"advancedReactionGlyphColor": @"#007E8CFF",
            @"advancedReactionGlyphColorDark": @"#BAE8FFFF",
            @"advancedReactionHighlightColor": @"#2BB1BEFF",
            @"advancedReactionHighlightColorDark": @"#1DD4E8FF",
            @"advancedReportJunkColor": @"#009E9EFF",
            @"advancedReportJunkColorDark": @"#1FD4C6FF",
            @"advancedSearchFieldColor": @"#007E8C4C",
            @"advancedSearchFieldColorDark": @"#9DE5FF3F",
            @"advancedStatusCellColor": @"#007E8C71",
            @"advancedStatusCellColorDark": @"#99EEFFFF",
            @"advancedSwitchTintColor": @"#48C4D2FF",
            @"advancedSwitchTintColorDark": @"#1ED4E5FF",
            @"advancedTableLabelColor": @"#007E8CCC",
            @"advancedTableLabelColorDark": @"#C2EBFFCC",
            @"advancedUnreadDotColor": @"#009E9EFF",
            @"advancedUnreadDotColorDark": @"#1ED4E2FF",
            @"cellTintColor": @"#A6EFF3FF",
            @"cellTintColorDark": @"#7BD3EFFF",
            @"chatContactNameColor": @"#007E8CFF",
            @"chatContactNameColorDark": @"#C2EAFFFF",
            @"chatImageBlurAmount": @0,
            @"chatImageBlurAmountDark": @0,
            @"conversationListTitleColor": @"#007E8CCC",
            @"conversationListTitleColorDark": @"#97EEFFFF",
            @"conversationListTitleText": @"Packaged Message Manager",
            @"conversationListTitleTextDark": @"Packaged Message Manager",
            @"dateTimeTextColor": @"#2BB1BE9A",
            @"dateTimeTextColorDark": @"#62B8D599",
            @"imageBlurAmount": @0,
            @"imageBlurAmountDark": @0,
            @"inputFieldBackgroundColor": @"#B6E0ECFF",
            @"inputFieldBackgroundColorDark": @"#00A3AFFF",
            @"inputFieldBlurStyle": @"light",
            @"inputFieldBlurStyleDark": @"dark",
            @"isAdvancedTintEnabled": @YES,
            @"isBlurBubblesEnabled": @YES,
            @"isBlurBubblesEnabledDark": @YES,
            @"isCellBlurTintEnabled": @YES,
            @"isChatColorBgEnabled": @NO,
            @"isChatColorBgEnabledDark": @NO,
            @"isChatImageBgEnabled": @YES,
            @"isChatImageBgEnabledDark": @YES,
            @"isConvColorBgEnabled": @NO,
            @"isConvColorBgEnabledDark": @NO,
            @"isConvImageBgEnabled": @YES,
            @"isConvImageBgEnabledDark": @YES,
            @"isCustomBubbleColorsEnabled": @YES,
            @"isCustomBubbleColorsEnabledDark": @YES,
            @"isCustomTextColorsEnabled": @YES,
            @"isCustomTextColorsEnabledDark": @YES,
            @"isInputFieldBlurEnabled": @YES,
            @"isInputFieldBlurEnabledDark": @YES,
            @"isInputFieldCustomizationEnabled": @YES,
            @"isInputFieldCustomizationEnabledDark": @YES,
            @"isMessageBarButtonsEnabled": @YES,
            @"isMessageBarButtonsEnabledDark": @YES,
            @"isMessageBarCustomizationEnabled": @YES,
            @"isMessageBarCustomizationEnabledDark": @YES,
            @"isMessageInputTextEnabled": @YES,
            @"isMessageInputTextEnabledDark": @YES,
            @"isModernMessageBarEnabled": @YES,
            @"isModernMessageBarEnabledDark": @YES,
            @"isModernNavBarEnabled": @YES,
            @"isModernNavBarEnabledDark": @YES,
            @"isNavBarCustomizationEnabled": @YES,
            @"isNavBarCustomizationEnabledDark": @YES,
            @"isPinnedGlowEnabled": @YES,
            @"isPlaceholderCustomizationEnabled": @YES,
            @"isPlaceholderCustomizationEnabledDark": @YES,
            @"isSearchBgEnabled": @YES,
            @"isSeparatorsEnabled": @YES,
            @"linkPreviewBackgroundColor": @"#C9F0FD66",
            @"linkPreviewBackgroundColorDark": @"#04272D5A",
            @"linkPreviewTextColor": @"#017274FF",
            @"linkPreviewTextColorDark": @"#C0F2FFFF",
            @"messageBarButtonColor": @"#2BB1BEDA",
            @"messageBarButtonColorDark": @"#1ED4E3E0",
            @"messageBarTintColor": @"#2BB1BE3F",
            @"messageBarTintColorDark": @"#1DD4DF3F",
            @"messageInputTextColor": @"#007E8CFF",
            @"messageInputTextColorDark": @"#A8F0FFFF",
            @"messagePreviewTextColor": @"#007E9580",
            @"messagePreviewTextColorDark": @"#A1EEFF80",
            @"navBarTintColor": @"#CFF2FF4C",
            @"navBarTintColorDark": @"#072A3858",
            @"navPlatterColor": @"#E4FFFF73",
            @"navPlatterColorDark": @"#6CDAD333",
            @"isNavButtonBlurEnabled": @YES,
            @"isNavButtonBlurEnabledDark": @YES,
            @"pinnedBubbleColor": @"#C8F2EFB3",
            @"pinnedBubbleColorDark": @"#004B637F",
            @"pinnedBubbleTextColor": @"#017274FF",
            @"pinnedBubbleTextColorDark": @"#9BEAFFFF",
            @"placeholderText": @"Time to Talk?",
            @"placeholderTextColor": @"#007E8C4C",
            @"placeholderTextColorDark": @"#95F9FF4D",
            @"placeholderTextDark": @"Time to Talk?",
            @"receivedBubbleColor": @"#C9F0FE65",
            @"receivedBubbleColorDark": @"#00162A3F",
            @"receivedTextColor": @"#007374FF",
            @"receivedTextColorDark": @"#BDFEFFFF",
            @"sendButtonArrowColor": @"#98F3FFFF",
            @"sendButtonArrowColorDark": @"#BFF4FFFF",
            @"sendButtonColor": @"#2BB1BEFF",
            @"sendButtonColorDark": @"#13C7D5FF",
            @"sentBubbleColor": @"#2BB1BE58",
            @"sentBubbleColorDark": @"#0EC7E34B",
            @"sentSMSBubbleColor": @"#0BC1BC5A",
            @"sentSMSBubbleColorDark": @"#11C6E049",
            @"sentSMSTextColor": @"#007E8CFF",
            @"sentSMSTextColorDark": @"#A4FCFFFF",
            @"sentTextColor": @"#007D8CFF",
            @"sentTextColorDark": @"#A6F2FFFF",
            @"systemTintColor": @"#2BB1BEFF",
            @"systemTintColorDark": @"#45EDFFFF",
            @"timestampTextColor": @"#007E8C80",
            @"timestampTextColorDark": @"#75B8C7C0",
            @"titleTextColor": @"#007E8CD8",
            @"titleTextColorDark": @"#9FEFFFFF",
        }),
        WAMMakeGradientPreset(@"cydia", @"Cydia", @"It's just a cardboard box right?",
            @[@"#F0DCC1FF",@"#D8AE7EFF",@"#B57C45FF"],
            @[@"#241609FF",@"#4A2E18FF",@"#7A4E2BFF"],
            @{
            @"advancedContactActionColor": @"#926552FF",
            @"advancedContactActionColorDark": @"#D7A882FF",
            @"advancedNavButtonColor": @"#A56C40FF",
            @"advancedNavButtonColorDark": @"#D7A882FF",
            @"advancedReactionBalloonColor": @"#EDD3C0FF",
            @"advancedReactionBalloonColorDark": @"#453018FF",
            @"advancedReactionGlyphColor": @"#6A3C2AFF",
            @"advancedReactionGlyphColorDark": @"#E9D5B9FF",
            @"advancedReactionHighlightColor": @"#A67967FF",
            @"advancedReactionHighlightColorDark": @"#634E36FF",
            @"advancedReportJunkColor": @"#A9683CFF",
            @"advancedReportJunkColorDark": @"#D8A882FF",
            @"advancedSearchFieldColor": @"#643E2E80",
            @"advancedSearchFieldColorDark": @"#CA9970A6",
            @"advancedStatusCellColor": @"#8A6C46FF",
            @"advancedStatusCellColorDark": @"#E9D5B966",
            @"advancedSwitchTintColor": @"#A9683CFF",
            @"advancedSwitchTintColorDark": @"#D7AD85FF",
            @"advancedTableLabelColor": @"#6A3C2ACC",
            @"advancedTableLabelColorDark": @"#E9D5B9CB",
            @"advancedUnreadDotColor": @"#A9683CFF",
            @"advancedUnreadDotColorDark": @"#D8A882FF",
            @"cellTintColor": @"#D3966AFF",
            @"cellTintColorDark": @"#7E503EFF",
            @"chatContactNameColor": @"#725443FF",
            @"chatContactNameColorDark": @"#E9D5B9FF",
            @"chatImageBlurAmount": @0,
            @"chatImageBlurAmountDark": @0,
            @"conversationListTitleColor": @"#6A3C2AFF",
            @"conversationListTitleColorDark": @"#F5C7A5FF",
            @"conversationListTitleText": @"Welcome Back",
            @"conversationListTitleTextDark": @"Welcome Back",
            @"dateTimeTextColor": @"#563C257F",
            @"dateTimeTextColorDark": @"#CEB28766",
            @"imageBlurAmount": @0,
            @"imageBlurAmountDark": @0,
            @"inputFieldBackgroundColor": @"#86807CFF",
            @"inputFieldBackgroundColorDark": @"#483E33FF",
            @"inputFieldBlurStyle": @"light",
            @"inputFieldBlurStyleDark": @"dark",
            @"isAdvancedTintEnabled": @YES,
            @"isBlurBubblesEnabled": @NO,
            @"isBlurBubblesEnabledDark": @NO,
            @"isCellBlurTintEnabled": @YES,
            @"isChatColorBgEnabled": @NO,
            @"isChatColorBgEnabledDark": @NO,
            @"isChatImageBgEnabled": @YES,
            @"isChatImageBgEnabledDark": @YES,
            @"isConvColorBgEnabled": @NO,
            @"isConvColorBgEnabledDark": @NO,
            @"isConvImageBgEnabled": @YES,
            @"isConvImageBgEnabledDark": @YES,
            @"isCustomBubbleColorsEnabled": @YES,
            @"isCustomBubbleColorsEnabledDark": @YES,
            @"isCustomTextColorsEnabled": @YES,
            @"isCustomTextColorsEnabledDark": @YES,
            @"isInputFieldBlurEnabled": @YES,
            @"isInputFieldBlurEnabledDark": @YES,
            @"isInputFieldCustomizationEnabled": @YES,
            @"isInputFieldCustomizationEnabledDark": @YES,
            @"isMessageBarButtonsEnabled": @YES,
            @"isMessageBarButtonsEnabledDark": @YES,
            @"isMessageBarCustomizationEnabled": @YES,
            @"isMessageBarCustomizationEnabledDark": @YES,
            @"isMessageInputTextEnabled": @YES,
            @"isMessageInputTextEnabledDark": @YES,
            @"isModernMessageBarEnabled": @YES,
            @"isModernMessageBarEnabledDark": @YES,
            @"isModernNavBarEnabled": @YES,
            @"isModernNavBarEnabledDark": @YES,
            @"isNavBarCustomizationEnabled": @YES,
            @"isNavBarCustomizationEnabledDark": @YES,
            @"isPinnedGlowEnabled": @YES,
            @"isPlaceholderCustomizationEnabled": @YES,
            @"isPlaceholderCustomizationEnabledDark": @YES,
            @"isSearchBgEnabled": @YES,
            @"isSeparatorsEnabled": @YES,
            @"linkPreviewBackgroundColor": @"#EDD3C0FF",
            @"linkPreviewBackgroundColorDark": @"#453019FF",
            @"linkPreviewTextColor": @"#725443FF",
            @"linkPreviewTextColorDark": @"#E9D5B9FF",
            @"messageBarButtonColor": @"#A56C40E2",
            @"messageBarButtonColorDark": @"#C8905DFF",
            @"messageBarTintColor": @"#D396694C",
            @"messageBarTintColorDark": @"#5B33204B",
            @"messageInputTextColor": @"#725443FF",
            @"messageInputTextColorDark": @"#F1C8ABFF",
            @"messagePreviewTextColor": @"#6A3C2A66",
            @"messagePreviewTextColorDark": @"#E9D5B998",
            @"navBarTintColor": @"#FDE9CD33",
            @"navBarTintColorDark": @"#00000033",
            @"navPlatterColor": @"#E8E5D742",
            @"navPlatterColorDark": @"#CA99714D",
            @"isNavButtonBlurEnabled": @YES,
            @"isNavButtonBlurEnabledDark": @YES,
            @"pinnedBubbleColor": @"#EEDACBFF",
            @"pinnedBubbleColorDark": @"#453018FF",
            @"pinnedBubbleTextColor": @"#693B2AFF",
            @"pinnedBubbleTextColorDark": @"#EAD5BAFF",
            @"placeholderText": @"Send Message Here",
            @"placeholderTextColor": @"#6A3C2A4C",
            @"placeholderTextColorDark": @"#D396694B",
            @"placeholderTextDark": @"Send Message Here",
            @"receivedBubbleColor": @"#EDD3C1FF",
            @"receivedBubbleColorDark": @"#453018FF",
            @"receivedTextColor": @"#6A3C2AFF",
            @"receivedTextColorDark": @"#EAD5BAFF",
            @"sendButtonArrowColor": @"#EAD5BAFF",
            @"sendButtonArrowColorDark": @"#F7D2C0FF",
            @"sendButtonColor": @"#A56C40FF",
            @"sendButtonColorDark": @"#B47A46FF",
            @"sentBubbleColor": @"#A56D41FF",
            @"sentBubbleColorDark": @"#B47A45FF",
            @"sentSMSBubbleColor": @"#A46E41FF",
            @"sentSMSBubbleColorDark": @"#B47A46FF",
            @"sentSMSTextColor": @"#F4E2CCFF",
            @"sentSMSTextColorDark": @"#F1C9ABFF",
            @"sentTextColor": @"#F4E2CCFF",
            @"sentTextColorDark": @"#F1C9ABFF",
            @"systemTintColor": @"#6A3C2AD7",
            @"systemTintColorDark": @"#D7A882FF",
            @"timestampTextColor": @"#8A6C4598",
            @"timestampTextColorDark": @"#F1C9AB80",
            @"titleTextColor": @"#7E503ED7",
            @"titleTextColorDark": @"#ECC59EFF",
        }),
        ]];

        presets = arr;
    });
    return presets;
}

+ (NSString *)userPresetsKey { return @"userPresets"; }

+ (NSArray<WAMPreset *> *)userPresets {
    NSArray *raw = WAMReadPrefs()[[self userPresetsKey]];
    if (![raw isKindOfClass:[NSArray class]]) return @[];
    NSMutableArray *out = [NSMutableArray array];
    for (NSDictionary *d in raw) {
        if ([d isKindOfClass:[NSDictionary class]]) [out addObject:[WAMPreset presetWithDictionary:d]];
    }
    return out;
}

+ (NSArray<WAMPreset *> *)allPresets {
    return [[self builtinPresets] arrayByAddingObjectsFromArray:[self userPresets]];
}

+ (void)saveUserPreset:(WAMPreset *)preset {
    if (!preset) return;
    preset.builtin = NO;
    if (!preset.identifier.length) preset.identifier = [[NSUUID UUID] UUIDString];
    NSMutableDictionary *prefs = WAMReadPrefs();
    NSMutableArray *arr = [(NSArray *)prefs[[self userPresetsKey]] mutableCopy] ?: [NSMutableArray array];
    NSUInteger idx = [arr indexOfObjectPassingTest:^BOOL(NSDictionary *d, NSUInteger i, BOOL *stop) {
        return [d isKindOfClass:[NSDictionary class]] && [d[@"id"] isEqual:preset.identifier];
    }];
    NSDictionary *rep = [preset dictionaryRepresentation];
    if (idx == NSNotFound) [arr addObject:rep]; else arr[idx] = rep;
    prefs[[self userPresetsKey]] = arr;
    WAMWritePrefs(prefs);
}

+ (void)deleteUserPresetWithIdentifier:(NSString *)identifier {
    if (!identifier.length) return;
    NSMutableDictionary *prefs = WAMReadPrefs();
    NSArray *arr = prefs[[self userPresetsKey]];
    if (![arr isKindOfClass:[NSArray class]]) return;
    NSMutableArray *keep = [NSMutableArray array];
    for (NSDictionary *d in arr) {
        if ([d isKindOfClass:[NSDictionary class]] && [d[@"id"] isEqual:identifier]) continue;
        [keep addObject:d];
    }
    if (keep.count) prefs[[self userPresetsKey]] = keep; else [prefs removeObjectForKey:[self userPresetsKey]];
    WAMWritePrefs(prefs);
    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *suffix in @[@"chat", @"chatd", @"conv", @"convd"]) {
        NSString *img = [WAMUserPresetImageDir() stringByAppendingPathComponent:
                         [NSString stringWithFormat:@"%@_%@.jpg", identifier, suffix]];
        [fm removeItemAtPath:img error:nil];
    }
}

static NSString *WAMCaptureUserImage(NSString *presetID, NSString *suffix, NSString *srcPath) {
    if (!srcPath.length || ![[NSFileManager defaultManager] fileExistsAtPath:srcPath]) return nil;
    NSString *dst = [WAMUserPresetImageDir() stringByAppendingPathComponent:
                     [NSString stringWithFormat:@"%@_%@.jpg", presetID, suffix]];
    WAMCopyImage(srcPath, dst);
    return dst;
}

static NSString *WAMFirstExistingPath(NSArray<NSString *> *paths) {
    for (NSString *p in paths)
        if (p.length && [[NSFileManager defaultManager] fileExistsAtPath:p]) return p;
    return nil;
}

// A contact's background blur lives in perContactBlur, not the override dict — overlay it onto the
// effective values so a saved/exported per-contact preset carries the blur the chat actually shows.
static void WAMOverlayPerContactBlur(NSMutableDictionary *merged, NSDictionary *prefs, NSString *safe) {
    id map = prefs[@"perContactBlur"];
    id entry = (safe.length && [map isKindOfClass:[NSDictionary class]]) ? map[safe] : nil;
    if ([entry isKindOfClass:[NSDictionary class]]) {
        id l = entry[@"light"]; if (l) merged[@"chatImageBlurAmount"]     = l;
        id d = entry[@"dark"];  if (d) merged[@"chatImageBlurAmountDark"] = d;
    } else if ([entry isKindOfClass:[NSNumber class]]) {
        merged[@"chatImageBlurAmount"]     = entry;
        merged[@"chatImageBlurAmountDark"] = entry;
    }
}

static void WAMSplitSnapshot(NSDictionary *source, BOOL (^shouldSkip)(NSString *key),
                             NSMutableDictionary *light, NSMutableDictionary *dark) {
    for (NSString *k in source) {
        if (shouldSkip && shouldSkip(k)) continue;
        id v = source[k];
        if (!v) continue;
        if ([k hasSuffix:@"Dark"] && k.length > 4) {
            dark[[k substringToIndex:k.length - 4]] = v;
        } else {
            light[k] = v;
        }
    }
}

+ (WAMPreset *)snapshotOfCurrentSettingsNamed:(NSString *)name {
    NSDictionary *prefs = WAMReadPrefs();
    NSMutableDictionary *light = [NSMutableDictionary dictionary];
    NSMutableDictionary *dark  = [NSMutableDictionary dictionary];
    WAMSplitSnapshot(prefs, ^BOOL(NSString *k) { return WAMIsExcludedKey(k); }, light, dark);

    WAMPreset *p = [WAMPreset new];
    p.identifier = [[NSUUID UUID] UUIDString];
    p.name = name.length ? name : @"My Preset";
    static NSDateFormatter *df;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ df = [NSDateFormatter new]; df.dateFormat = @"MMM d, yyyy"; });
    p.subtitle = [NSString stringWithFormat:@"Your preset · %@", [df stringFromDate:[NSDate date]]];
    p.builtin = NO;
    p.lightValues = light;
    p.darkValues = dark;
    NSString *dir = WAMPrefsDataDir();
    p.chatBgImage     = WAMCaptureUserImage(p.identifier, @"chat",  [dir stringByAppendingPathComponent:@"chat_background.jpg"]);
    p.chatBgImageDark = WAMCaptureUserImage(p.identifier, @"chatd", [dir stringByAppendingPathComponent:@"chat_background_dark.jpg"]);
    p.convBgImage     = WAMCaptureUserImage(p.identifier, @"conv",  [dir stringByAppendingPathComponent:@"background.jpg"]);
    p.convBgImageDark = WAMCaptureUserImage(p.identifier, @"convd", [dir stringByAppendingPathComponent:@"background_dark.jpg"]);
    return p;
}

+ (WAMPreset *)snapshotOfContact:(NSString *)contactName named:(NSString *)name {
    NSString *safe = WAMSanitizeContactName(contactName);
    if (!safe.length) return nil;
    NSMutableDictionary *prefs = WAMReadPrefs();
    NSDictionary *all = prefs[@"perContactOverrides"];
    NSDictionary *ov = [all isKindOfClass:[NSDictionary class]] ? all[safe] : nil;
    if (![ov isKindOfClass:[NSDictionary class]]) ov = @{};
    NSMutableDictionary *merged = [prefs mutableCopy];
    [merged addEntriesFromDictionary:ov];
    WAMOverlayPerContactBlur(merged, prefs, safe);

    NSMutableDictionary *light = [NSMutableDictionary dictionary];
    NSMutableDictionary *dark  = [NSMutableDictionary dictionary];
    WAMSplitSnapshot(merged, ^BOOL(NSString *k) {
        return WAMIsExcludedKey(k) || [k isEqualToString:@"_enabled"];
    }, light, dark);

    WAMPreset *p = [WAMPreset new];
    p.identifier = [[NSUUID UUID] UUIDString];
    p.name = name.length ? name : @"My Preset";
    p.subtitle = @"Saved from this chat";
    p.builtin = NO;
    p.lightValues = light;
    p.darkValues = dark;

    NSString *gDir = WAMPrefsDataDir();
    NSString *pcLight = [WAMPerContactDir() stringByAppendingPathComponent:[safe stringByAppendingString:@".jpg"]];
    NSString *pcDark  = [WAMPerContactDir() stringByAppendingPathComponent:[safe stringByAppendingString:@"_dark.jpg"]];
    p.chatBgImage     = WAMCaptureUserImage(p.identifier, @"chat",  WAMFirstExistingPath(@[pcLight, [gDir stringByAppendingPathComponent:@"chat_background.jpg"]]));
    p.chatBgImageDark = WAMCaptureUserImage(p.identifier, @"chatd", WAMFirstExistingPath(@[pcDark,  [gDir stringByAppendingPathComponent:@"chat_background_dark.jpg"]]));
    p.convBgImage     = WAMCaptureUserImage(p.identifier, @"conv",  [gDir stringByAppendingPathComponent:@"background.jpg"]);
    p.convBgImageDark = WAMCaptureUserImage(p.identifier, @"convd", [gDir stringByAppendingPathComponent:@"background_dark.jpg"]);
    return p;
}

+ (NSArray<NSString *> *)baseKeysForScope:(WAMPresetScope)scope {
    NSMutableArray *keys = [NSMutableArray array];
    if (scope & WAMPresetScopeConvList) [keys addObjectsFromArray:WAMConvListKeys()];
    if (scope & WAMPresetScopeChats)  { [keys addObjectsFromArray:WAMChatKeys()];
                                        [keys addObjectsFromArray:WAMBarKeys()]; }
    [keys addObjectsFromArray:WAMAdvancedKeys()];
    return keys;
}

static BOOL WAMIsModeAgnosticKey(NSString *base) {
    static NSSet *keys;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        keys = [NSSet setWithArray:@[@"isAdvancedTintEnabled", @"isCellBlurTintEnabled",
                                     @"isSeparatorsEnabled", @"isSearchBgEnabled",
                                     @"isPinnedGlowEnabled"]];
    });
    return [keys containsObject:base];
}

static BOOL WAMKeyAllowedInScope(NSString *base, WAMPresetScope scope) {
    static NSSet *convOnly, *chatAndBars;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        convOnly = [NSSet setWithArray:WAMConvListKeys()];
        chatAndBars = [NSSet setWithArray:[WAMChatKeys() arrayByAddingObjectsFromArray:WAMBarKeys()]];
    });
    if (scope == WAMPresetScopeBoth) return YES;
    if (scope & WAMPresetScopeChats)    return ![convOnly containsObject:base];
    if (scope & WAMPresetScopeConvList) return ![chatAndBars containsObject:base];
    return YES;
}

static void WAMAppearanceModes(WAMPresetAppearance a, BOOL *doLight, BOOL *doDark) {
    *doLight = (a == WAMPresetAppearanceLight || a == WAMPresetAppearanceBoth);
    *doDark  = (a == WAMPresetAppearanceDark  || a == WAMPresetAppearanceBoth);
}

static void WAMWriteValues(WAMPreset *preset, WAMPresetScope scope, BOOL doLight, BOOL doDark,
                           NSMutableDictionary *dest) {
    NSMutableSet *bases = [NSMutableSet setWithArray:preset.lightValues.allKeys];
    [bases addObjectsFromArray:preset.darkValues.allKeys];
    for (NSString *base in bases) {
        if (!WAMKeyAllowedInScope(base, scope)) continue;
        id lv = preset.lightValues[base];
        id dv = preset.darkValues[base];

        if (WAMIsModeAgnosticKey(base) || (lv && !dv)) {
            id v = lv ?: dv;
            if (v) dest[base] = v;
            continue;
        }

        if (doLight && lv) dest[base] = lv;
        if (doDark  && (dv ?: lv)) dest[[base stringByAppendingString:@"Dark"]] = (dv ?: lv);
    }
}

+ (void)applyPreset:(WAMPreset *)preset scope:(WAMPresetScope)scope appearance:(WAMPresetAppearance)appearance {
    if (!preset) return;
    BOOL doLight, doDark; WAMAppearanceModes(appearance, &doLight, &doDark);
    NSMutableDictionary *prefs = WAMReadPrefs();

    NSMutableDictionary *cleaned = [NSMutableDictionary dictionary];
    for (NSString *k in prefs) {
        if (WAMIsExcludedKey(k)) { cleaned[k] = prefs[k]; continue; }
        NSString *base = [k hasSuffix:@"Dark"] ? [k substringToIndex:k.length - 4] : k;
        if (WAMKeyAllowedInScope(base, scope)) continue;
        cleaned[k] = prefs[k];
    }
    prefs = cleaned;

    WAMWriteValues(preset, scope, doLight, doDark, prefs);
    prefs[@"appliedPresetIdentifier"] = preset.identifier ?: @"";

    NSString *dir = WAMPrefsDataDir();
    if (scope & WAMPresetScopeChats) {
        if (doLight) WAMWritePresetBackground(preset, NO,  NO, [dir stringByAppendingPathComponent:@"chat_background.jpg"]);
        if (doDark)  WAMWritePresetBackground(preset, YES, NO, [dir stringByAppendingPathComponent:@"chat_background_dark.jpg"]);
    }
    if (scope & WAMPresetScopeConvList) {
        if (doLight) WAMWritePresetBackground(preset, NO,  YES, [dir stringByAppendingPathComponent:@"background.jpg"]);
        if (doDark)  WAMWritePresetBackground(preset, YES, YES, [dir stringByAppendingPathComponent:@"background_dark.jpg"]);
    }

    WAMWritePrefs(prefs);
}

#pragma mark - Import / export

static BOOL WAMIsExcludedKey(NSString *key) {
    if ([key isEqualToString:@"editingDarkMode"]) return YES;
    if ([key isEqualToString:@"isEnabled"]) return YES;
    if ([key isEqualToString:@"chatIdentifierAliases"]) return YES;
    if ([key isEqualToString:@"userPresets"]) return YES;
    if ([key isEqualToString:@"lastGradient"]) return YES;
    if ([key isEqualToString:@"appliedPresetIdentifier"]) return YES;
    if ([key isEqualToString:@"lastSeenChangelogVersion"]) return YES;
    if ([key hasPrefix:@"perContact"]) return YES;
    return NO;
}

static NSArray<NSString *> *WAMBackgroundFileNames(void) {
    return @[@"background.jpg", @"background_dark.jpg", @"chat_background.jpg", @"chat_background_dark.jpg"];
}

+ (NSURL *)exportSettingsToTempFile {
    NSDictionary *prefs = WAMReadPrefs();
    NSMutableDictionary *shared = [NSMutableDictionary dictionary];
    for (NSString *k in prefs) if (!WAMIsExcludedKey(k)) shared[k] = prefs[k];

    NSMutableDictionary *images = [NSMutableDictionary dictionary];
    NSString *dir = WAMPrefsDataDir();
    for (NSString *name in WAMBackgroundFileNames()) {
        NSData *d = [NSData dataWithContentsOfFile:[dir stringByAppendingPathComponent:name]];
        if (d) images[name] = d;
    }

    NSDictionary *pkg = @{ @"version": @2, @"prefs": shared, @"images": images };
    NSData *plist = [NSPropertyListSerialization dataWithPropertyList:pkg
        format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    if (!plist.length) return nil;
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"WhatAMess_Preset.wampreset"];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    if (![plist writeToFile:path atomically:YES]) return nil;
    return [NSURL fileURLWithPath:path];
}

+ (WAMPreset *)currentLookPreset {
    NSDictionary *prefs = WAMReadPrefs();
    NSMutableDictionary *light = [NSMutableDictionary dictionary];
    NSMutableDictionary *dark  = [NSMutableDictionary dictionary];
    WAMSplitSnapshot(prefs, ^BOOL(NSString *k) { return WAMIsExcludedKey(k); }, light, dark);
    WAMPreset *p = [WAMPreset new];
    p.identifier = @"__current__";
    p.name = @"Current Look";
    p.subtitle = @"Your live settings";
    p.lightValues = light;
    p.darkValues = dark;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = WAMPrefsDataDir();
    NSString *cl = [dir stringByAppendingPathComponent:@"chat_background.jpg"];
    NSString *cd = [dir stringByAppendingPathComponent:@"chat_background_dark.jpg"];
    NSString *vl = [dir stringByAppendingPathComponent:@"background.jpg"];
    NSString *vd = [dir stringByAppendingPathComponent:@"background_dark.jpg"];
    if ([fm fileExistsAtPath:cl]) p.chatBgImage     = cl;
    if ([fm fileExistsAtPath:cd]) p.chatBgImageDark = cd;
    if ([fm fileExistsAtPath:vl]) p.convBgImage     = vl;
    if ([fm fileExistsAtPath:vd]) p.convBgImageDark = vd;
    return p;
}

+ (WAMPreset *)currentLookPresetForContact:(NSString *)contactName {
    NSString *safe = WAMSanitizeContactName(contactName);
    NSMutableDictionary *prefs = WAMReadPrefs();
    NSDictionary *all = prefs[@"perContactOverrides"];
    NSDictionary *ov = (safe.length && [all isKindOfClass:[NSDictionary class]]) ? all[safe] : nil;
    if (![ov isKindOfClass:[NSDictionary class]]) ov = @{};
    NSMutableDictionary *merged = [prefs mutableCopy];
    [merged addEntriesFromDictionary:ov];
    WAMOverlayPerContactBlur(merged, prefs, safe);

    NSMutableDictionary *light = [NSMutableDictionary dictionary];
    NSMutableDictionary *dark  = [NSMutableDictionary dictionary];
    WAMSplitSnapshot(merged, ^BOOL(NSString *k) {
        return WAMIsExcludedKey(k) || [k isEqualToString:@"_enabled"];
    }, light, dark);

    WAMPreset *p = [WAMPreset new];
    p.identifier = @"__current__";
    p.name = @"This Chat";
    p.subtitle = @"This chat's current look";
    p.lightValues = light;
    p.darkValues = dark;
    NSString *gDir = WAMPrefsDataDir();
    NSString *pcL = [WAMPerContactDir() stringByAppendingPathComponent:[safe stringByAppendingString:@".jpg"]];
    NSString *pcD = [WAMPerContactDir() stringByAppendingPathComponent:[safe stringByAppendingString:@"_dark.jpg"]];
    p.chatBgImage     = WAMFirstExistingPath(@[pcL, [gDir stringByAppendingPathComponent:@"chat_background.jpg"]]);
    p.chatBgImageDark = WAMFirstExistingPath(@[pcD, [gDir stringByAppendingPathComponent:@"chat_background_dark.jpg"]]);
    p.convBgImage     = WAMFirstExistingPath(@[[gDir stringByAppendingPathComponent:@"background.jpg"]]);
    p.convBgImageDark = WAMFirstExistingPath(@[[gDir stringByAppendingPathComponent:@"background_dark.jpg"]]);
    return p;
}

+ (NSURL *)exportPresetToTempFile:(WAMPreset *)preset {
    if (!preset) return nil;
    NSMutableDictionary *shared = [NSMutableDictionary dictionary];
    NSMutableSet *bases = [NSMutableSet setWithArray:preset.lightValues.allKeys];
    [bases addObjectsFromArray:preset.darkValues.allKeys];
    for (NSString *base in bases) {
        id lv = preset.lightValues[base];
        id dv = preset.darkValues[base];
        if (WAMIsModeAgnosticKey(base) || (lv && !dv)) {
            id v = lv ?: dv; if (v) shared[base] = v;
        } else {
            if (lv) shared[base] = lv;
            if (dv ?: lv) shared[[base stringByAppendingString:@"Dark"]] = (dv ?: lv);
        }
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tmp = [NSTemporaryDirectory() stringByAppendingPathComponent:@"wampreset_bg"];
    [fm removeItemAtPath:tmp error:nil];
    [fm createDirectoryAtPath:tmp withIntermediateDirectories:YES attributes:nil error:nil];
    NSMutableDictionary *images = [NSMutableDictionary dictionary];
    NSDictionary *jobs = @{ @"chat_background.jpg": @[@NO, @NO],  @"chat_background_dark.jpg": @[@YES, @NO],
                            @"background.jpg":      @[@NO, @YES], @"background_dark.jpg":      @[@YES, @YES] };
    for (NSString *name in jobs) {
        NSString *dst = [tmp stringByAppendingPathComponent:name];
        WAMWritePresetBackground(preset, [jobs[name][0] boolValue], [jobs[name][1] boolValue], dst);
        NSData *d = [NSData dataWithContentsOfFile:dst];
        if (d) images[name] = d;
    }
    [fm removeItemAtPath:tmp error:nil];

    NSDictionary *pkg = @{ @"version": @2, @"prefs": shared, @"images": images };
    NSData *plist = [NSPropertyListSerialization dataWithPropertyList:pkg
        format:NSPropertyListBinaryFormat_v1_0 options:0 error:nil];
    if (!plist.length) return nil;
    NSString *safe = WAMSanitizeContactName(preset.name) ?: @"WhatAMess_Preset";
    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:
                      [safe stringByAppendingPathExtension:@"wampreset"]];
    [fm removeItemAtPath:path error:nil];
    if (![plist writeToFile:path atomically:YES]) return nil;
    return [NSURL fileURLWithPath:path];
}

+ (BOOL)importSettingsFromURL:(NSURL *)url {
    NSData *data = [NSData dataWithContentsOfURL:url];
    if (!data.length) return NO;
    id pkg = [NSPropertyListSerialization propertyListWithData:data options:0 format:NULL error:nil];
    if (![pkg isKindOfClass:[NSDictionary class]]) return NO;
    NSDictionary *shared = pkg[@"prefs"];
    if (![shared isKindOfClass:[NSDictionary class]]) return NO;

    NSMutableDictionary *current = WAMReadPrefs();
    NSMutableDictionary *fresh = [NSMutableDictionary dictionary];
    for (NSString *k in current) if (WAMIsExcludedKey(k)) fresh[k] = current[k];
    for (NSString *k in shared) fresh[k] = shared[k];

    NSDictionary *images = pkg[@"images"];
    if ([images isKindOfClass:[NSDictionary class]]) {
        NSString *dir = WAMPrefsDataDir();
        NSFileManager *fm = [NSFileManager defaultManager];
        for (NSString *name in images) {
            NSData *d = images[name];
            if (![d isKindOfClass:[NSData class]]) continue;
            NSString *dst = [dir stringByAppendingPathComponent:name];
            [fm removeItemAtPath:dst error:nil];
            [d writeToFile:dst atomically:YES];
        }
    }
    WAMWritePrefs(fresh);

    NSString *label = [[url.lastPathComponent stringByDeletingPathExtension]
                       stringByReplacingOccurrencesOfString:@"_" withString:@" "];
    if (!label.length || [label isEqualToString:@"WhatAMess Preset"]) label = @"Imported Preset";
    WAMPreset *imported = [self snapshotOfCurrentSettingsNamed:label];
    imported.subtitle = @"Imported";
    [self saveUserPreset:imported];
    return YES;
}

+ (NSString *)appliedPresetIdentifier {
    id v = WAMReadPrefs()[@"appliedPresetIdentifier"];
    return ([v isKindOfClass:[NSString class]] && [(NSString *)v length]) ? v : nil;
}

+ (void)restartMessages {
    CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR(kWAMKillMessagesName), NULL, NULL, YES);
}

+ (NSArray<NSString *> *)lastGradientStops {
    NSDictionary *g = WAMReadPrefs()[@"lastGradient"];
    NSArray *stops = [g isKindOfClass:[NSDictionary class]] ? g[@"stops"] : nil;
    return ([stops isKindOfClass:[NSArray class]] && stops.count >= 2) ? stops : nil;
}

+ (WAMGradientDirection)lastGradientDirection {
    NSDictionary *g = WAMReadPrefs()[@"lastGradient"];
    if (![g isKindOfClass:[NSDictionary class]]) return WAMGradientDirectionDiagonal;
    return (WAMGradientDirection)[g[@"direction"] unsignedIntegerValue];
}

+ (void)saveLastGradientStops:(NSArray<NSString *> *)stops direction:(WAMGradientDirection)direction {
    if (stops.count < 2) return;
    NSMutableDictionary *prefs = WAMReadPrefs();
    prefs[@"lastGradient"] = @{ @"stops": stops, @"direction": @(direction) };
    WAMWritePrefs(prefs);
}

+ (void)setGradientBackground:(NSArray<NSString *> *)stops direction:(WAMGradientDirection)direction
                         chat:(BOOL)isChat dark:(BOOL)dark {
    if (stops.count < 2) return;
    UIImage *img = WAMGradientImage(stops, CGSizeMake(1170, 2532), direction);
    NSData *jpg = UIImageJPEGRepresentation(img, 0.9);
    if (!jpg.length) return;
    NSString *dir = WAMPrefsDataDir();
    NSString *name = isChat ? (dark ? @"chat_background_dark.jpg" : @"chat_background.jpg")
                            : (dark ? @"background_dark.jpg" : @"background.jpg");
    NSString *dst = [dir stringByAppendingPathComponent:name];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:dst error:nil];
    [jpg writeToFile:dst atomically:YES];

    NSMutableDictionary *prefs = WAMReadPrefs();
    NSString *suffix = dark ? @"Dark" : @"";
    if (isChat) {
        prefs[[@"isChatImageBgEnabled" stringByAppendingString:suffix]] = @YES;
        prefs[[@"isChatColorBgEnabled" stringByAppendingString:suffix]] = @NO;
    } else {
        prefs[[@"isConvImageBgEnabled" stringByAppendingString:suffix]] = @YES;
        prefs[[@"isConvColorBgEnabled" stringByAppendingString:suffix]] = @NO;
    }
    prefs[@"lastGradient"] = @{ @"stops": stops, @"direction": @(direction) };
    WAMWritePrefs(prefs);
}

+ (void)setGradientBackground:(NSArray<NSString *> *)stops direction:(WAMGradientDirection)direction
                   forContact:(NSString *)contactName dark:(BOOL)dark {
    NSString *safe = WAMSanitizeContactName(contactName);
    if (stops.count < 2 || !safe.length) return;
    UIImage *img = WAMGradientImage(stops, CGSizeMake(1170, 2532), direction);
    NSData *jpg = UIImageJPEGRepresentation(img, 0.9);
    if (!jpg.length) return;
    NSString *name = dark ? [safe stringByAppendingString:@"_dark.jpg"] : [safe stringByAppendingString:@".jpg"];
    NSString *dst = [WAMPerContactDir() stringByAppendingPathComponent:name];
    [[NSFileManager defaultManager] createDirectoryAtPath:WAMPerContactDir() withIntermediateDirectories:YES attributes:nil error:nil];
    [[NSFileManager defaultManager] removeItemAtPath:dst error:nil];
    [jpg writeToFile:dst atomically:YES];
    WAMWritePrefs(WAMReadPrefs());
}

+ (void)applyPreset:(WAMPreset *)preset toContact:(NSString *)contactName appearance:(WAMPresetAppearance)appearance {
    NSString *safe = WAMSanitizeContactName(contactName);
    if (!preset || !safe.length) return;
    BOOL doLight, doDark; WAMAppearanceModes(appearance, &doLight, &doDark);
    NSMutableDictionary *prefs = WAMReadPrefs();
    NSMutableDictionary *all = [(NSDictionary *)prefs[@"perContactOverrides"] mutableCopy] ?: [NSMutableDictionary new];
    NSMutableDictionary *per = [(NSDictionary *)all[safe] mutableCopy] ?: [NSMutableDictionary new];
    WAMWriteValues(preset, WAMPresetScopeChats, doLight, doDark, per);
    per[@"_enabled"] = @YES;
    all[safe] = per;
    prefs[@"perContactOverrides"] = all;

    NSString *lightDst = [WAMPerContactDir() stringByAppendingPathComponent:[safe stringByAppendingString:@".jpg"]];
    NSString *darkDst  = [WAMPerContactDir() stringByAppendingPathComponent:[safe stringByAppendingString:@"_dark.jpg"]];
    if (doLight) WAMWritePresetBackground(preset, NO,  NO, lightDst);
    if (doDark)  WAMWritePresetBackground(preset, YES, NO, darkDst);

    // A contact's background blur is read from its own perContactBlur map, not the override dict, so
    // mirror the preset's chat-image blur there too — otherwise the applied image shows unblurred.
    NSMutableDictionary *blurMap = [(NSDictionary *)prefs[@"perContactBlur"] mutableCopy] ?: [NSMutableDictionary new];
    NSMutableDictionary *blurEntry = [(NSDictionary *)blurMap[safe] mutableCopy] ?: [NSMutableDictionary new];
    if (doLight) blurEntry[@"light"] = preset.lightValues[@"chatImageBlurAmount"] ?: @0;
    if (doDark)  blurEntry[@"dark"]  = preset.darkValues[@"chatImageBlurAmount"]  ?: @0;
    blurMap[safe] = blurEntry;
    prefs[@"perContactBlur"] = blurMap;

    WAMWritePrefs(prefs);
}

@end
