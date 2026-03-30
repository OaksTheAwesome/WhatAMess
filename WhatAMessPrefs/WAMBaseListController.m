#import "WAMBaseListController.h"

@implementation WAMBaseListController

#pragma mark - Unified Plist Storage

- (NSMutableDictionary *)readPrefs {
    NSMutableDictionary *prefs = [NSMutableDictionary dictionaryWithContentsOfFile:kWAMPrefsPlistPath];
    return prefs ?: [NSMutableDictionary new];
}

- (void)writePrefs:(NSDictionary *)prefs {
    // Ensure directory exists
    NSString *dir = [kWAMPrefsPlistPath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];
    // Synchronous atomic write — data is on disk before notification fires
    [prefs writeToFile:kWAMPrefsPlistPath atomically:YES];
}

- (void)saveValue:(id)value forKey:(NSString *)key {
    NSMutableDictionary *prefs = [self readPrefs];
    if (value) {
        prefs[key] = value;
    } else {
        [prefs removeObjectForKey:key];
    }
    [self writePrefs:prefs];
}

- (void)postNotification {
    CFNotificationCenterPostNotification(
        CFNotificationCenterGetDarwinNotifyCenter(),
        CFSTR(kWAMPrefsChanged),
        NULL, NULL, YES
    );
}

#pragma mark - PSListController Override

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSSet *globalKeys = [NSSet setWithArray:@[
        @"isCellBlurTintEnabled",
        @"isAdvancedTintEnabled"
    ]];

    NSString *lightKey = specifier.properties[@"lightModeKey"];
    NSString *key;

    if (lightKey && [globalKeys containsObject:lightKey]) {
        key = lightKey; // always use base key, never append Dark
    } else if (lightKey) {
        key = [self keyForBase:lightKey];
    } else {
        key = specifier.properties[@"key"];
    }

    if (key) {
        [self saveValue:value forKey:key];
    } else {
        [super setPreferenceValue:value specifier:specifier];
    }
    [self postNotification];

    if ([key isEqualToString:@"editingDarkMode"]) {
        _specifiers = nil;
        [self reloadSpecifiers];
    }
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    NSSet *globalKeys = [NSSet setWithArray:@[
        @"isCellBlurTintEnabled",
        @"isAdvancedTintEnabled"
    ]];

    NSString *lightKey = specifier.properties[@"lightModeKey"];
    NSString *key;

    if (lightKey && [globalKeys containsObject:lightKey]) {
        key = lightKey;
    } else if (lightKey) {
        key = [self keyForBase:lightKey];
    } else {
        key = specifier.properties[@"key"];
    }

    if (!key) return [super readPreferenceValue:specifier];
    id value = [self readPrefs][key];
    return value ?: specifier.properties[@"default"];
}

#pragma mark - Dark/Light Mode Editing

- (BOOL)isEditingDarkMode {
    return [[self readPrefs][@"editingDarkMode"] boolValue];
}

- (NSString *)keyForBase:(NSString *)baseKey {
    return [self isEditingDarkMode] ? [baseKey stringByAppendingString:@"Dark"] : baseKey;
}

#pragma mark - Color Picker

- (void)showColorPickerForKey:(NSString *)baseKey defaultColor:(UIColor *)defaultColor {
    _currentColorKey = [self keyForBase:baseKey];  // resolve dark/light key here

    UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
    picker.delegate = self;
    picker.supportsAlpha = YES;

    NSString *saved = [self readPrefs][_currentColorKey];
    picker.selectedColor = saved ? [self colorFromHex:saved] : (defaultColor ?: [UIColor blackColor]);

    [self presentViewController:picker animated:YES completion:nil];
}

- (void)showColorPickerForKeyDirect:(NSString *)key defaultColor:(UIColor *)defaultColor {
    _currentColorKey = key; // use the key as-is, no dark/light resolution

    UIColorPickerViewController *picker = [[UIColorPickerViewController alloc] init];
    picker.delegate = self;
    picker.supportsAlpha = YES;

    NSString *saved = [self readPrefs][key];
    picker.selectedColor = saved ? [self colorFromHex:saved] : (defaultColor ?: [UIColor blackColor]);

    [self presentViewController:picker animated:YES completion:nil];
}

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
    NSString *hex = [self hexFromColor:viewController.selectedColor];
    [self saveValue:hex forKey:_currentColorKey];
    [self postNotification];
}

// Also save on every live change so the app updates as the user drags the picker
- (void)colorPickerViewController:(UIColorPickerViewController *)viewController
          didSelectColor:(UIColor *)color
          continuously:(BOOL)continuously {
    NSString *hex = [self hexFromColor:color];
    [self saveValue:hex forKey:_currentColorKey];
    [self postNotification];
}

#pragma mark - Image Picker

- (void)showImagePickerForDestinationPath:(NSString *)destPath {
    _currentImageDestPath = destPath;

    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;

    UIWindowScene *scene = (UIWindowScene *)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
    UIWindow *window = scene.windows.firstObject;
    [window.rootViewController presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker
    didFinishPickingMediaWithInfo:(NSDictionary<NSString *, id> *)info {

    UIImage *image = info[UIImagePickerControllerOriginalImage];
    [picker dismissViewControllerAnimated:YES completion:nil];
    if (!image) return;

    NSString *dir = [_currentImageDestPath stringByDeletingLastPathComponent];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:nil];

    NSData *data = UIImageJPEGRepresentation(image, 0.9);
    [data writeToFile:_currentImageDestPath atomically:YES];

    [self postNotification];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Color Helpers

- (NSString *)hexFromColor:(UIColor *)color {
    CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
    CGColorRef converted = CGColorCreateCopyByMatchingToColorSpace(
        rgb, kCGRenderingIntentDefault, color.CGColor, NULL);
    CGColorSpaceRelease(rgb);

    CGFloat r = 0, g = 0, b = 0, a = 1;
    if (converted) {
        const CGFloat *c = CGColorGetComponents(converted);
        size_t n = CGColorGetNumberOfComponents(converted);
        if (n >= 3) { r = c[0]; g = c[1]; b = c[2]; }
        if (n >= 4) { a = c[3]; }
        CGColorRelease(converted);
    } else {
        [color getRed:&r green:&g blue:&b alpha:&a];
    }

    int ri = MAX(0, MIN(255, (int)(r * 255)));
    int gi = MAX(0, MIN(255, (int)(g * 255)));
    int bi = MAX(0, MIN(255, (int)(b * 255)));
    int ai = MAX(0, MIN(255, (int)(a * 255)));

    return [NSString stringWithFormat:@"#%02X%02X%02X%02X", ri, gi, bi, ai];
}

- (UIColor *)colorFromHex:(NSString *)hex {
    if ([hex hasPrefix:@"#"]) hex = [hex substringFromIndex:1];

    CGFloat r, g, b, a = 1;
    unsigned int ri, gi, bi, ai;

    if (hex.length == 8) {
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(0,2)]] scanHexInt:&ri];
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(2,2)]] scanHexInt:&gi];
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(4,2)]] scanHexInt:&bi];
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(6,2)]] scanHexInt:&ai];
        r = ri/255.0; g = gi/255.0; b = bi/255.0; a = ai/255.0;
    } else if (hex.length == 6) {
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(0,2)]] scanHexInt:&ri];
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(2,2)]] scanHexInt:&gi];
        [[NSScanner scannerWithString:[hex substringWithRange:NSMakeRange(4,2)]] scanHexInt:&bi];
        r = ri/255.0; g = gi/255.0; b = bi/255.0;
    } else {
        return [UIColor blackColor];
    }

    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

@end
