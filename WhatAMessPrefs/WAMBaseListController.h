#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>

// Single source of truth for where prefs live on disk.
// Every controller writes here; Tweak.x reads from here.
#define kWAMPrefsPlistPath @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs.plist"
#define kWAMPrefsDomain    @"com.oakstheawesome.whatamessprefs"
#define kWAMPrefsChanged   "com.oakstheawesome.whatamessprefs/prefsChanged"

@interface WAMBaseListController : PSListController
    <UIColorPickerViewControllerDelegate,
     UIImagePickerControllerDelegate,
     UINavigationControllerDelegate>
{
    NSString *_currentColorKey;
    NSString *_currentImageDestPath;
}

// Unified plist read/write — bypasses cfprefsd entirely
- (NSMutableDictionary *)readPrefs;
- (void)writePrefs:(NSDictionary *)prefs;
- (void)saveValue:(id)value forKey:(NSString *)key;
- (void)postNotification;

// Color picker
- (void)showColorPickerForKey:(NSString *)key defaultColor:(UIColor *)defaultColor;

// Image picker
- (void)showImagePickerForDestinationPath:(NSString *)destPath;

// Color conversion helpers
- (NSString *)hexFromColor:(UIColor *)color;
- (UIColor *)colorFromHex:(NSString *)hexString;

@end
