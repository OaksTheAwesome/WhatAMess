#import <Preferences/Preferences.h>
#import <UIKit/UIKit.h>

// Resolves a path relative to the actual jbroot. On rootless (Dopamine) this is
// "/var/jb/<suffix>"; on Roothide it's the per-app sandbox jbroot followed by suffix;
// on rootful (no /var/jb) it's just "<suffix>". posix_spawn binary paths and any
// file path we hand to lower-level APIs MUST go through this — Roothide's symlink
// at /var/jb only resolves for Foundation APIs hooked by the loader.
NSString *WAMJBPath(NSString *suffix);

// Single source of truth for where prefs live on disk.
// Every controller writes here; Tweak.x reads from here.
#define kWAMPrefsPlistPath WAMJBPath(@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs.plist")
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
- (void)showColorPickerForKeyDirect:(NSString *)key defaultColor:(UIColor *)defaultColor;

// Image picker
- (void)showImagePickerForDestinationPath:(NSString *)destPath;

// Color conversion helpers
- (NSString *)hexFromColor:(UIColor *)color;
- (UIColor *)colorFromHex:(NSString *)hexString;

- (BOOL)isEditingDarkMode;
- (NSString *)keyForBase:(NSString *)baseKey;
@end
