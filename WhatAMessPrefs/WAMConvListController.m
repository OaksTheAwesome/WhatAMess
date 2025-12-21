#import <Foundation/Foundation.h>
#import "WAMConvListController.h"

@implementation WAMConvListController {
    NSString *_currentColorKey;
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"ConvList" target:self];
	}

	return _specifiers;
}


/*================
   COLOR STUFFS
=============== */


/* Presents color picker and stores color to the indicated key in root.plist. */
- (void)pickBackgroundColor {
	_currentColorKey = @"convListBackgroundColor";
	[self showColorPicker];
}

/* Presents color picker and stores color to the indicated key in root.plist. */
- (void)pickCellColor {
	_currentColorKey = @"convListCellColor";
	[self showColorPicker];
}

/* Presents color picker and stores color to the indicated key in root.plist. */
- (void)pickTitleColor {
	_currentColorKey = @"titleTextColor";
	[self showColorPicker];
}

/* Presents color picker and stores color to the indicated key in root.plist. */
- (void)pickMessagePreviewColor {
	_currentColorKey = @"messagePreviewTextColor";
	[self showColorPicker];
}

/* Presents color picker and stores color to the indicated key in root.plist. */
- (void)pickDateTimeColor {
	_currentColorKey = @"dateTimeTextColor";
	[self showColorPicker];
}

/* Creates a color picker, delegates to self so that code can respond to picked color, and allows alpha.
Loads tweak prefs, and reads the currently stored color in that key. When color is already stored in prefs,
converts it from hex string to UIColor. If no saved color, falls back to indicated default. Presents the picker
so the user can do just that, pick. */
- (void)showColorPicker {
	UIColorPickerViewController *colorPicker = [[UIColorPickerViewController alloc] init];
	colorPicker.delegate = self;
	colorPicker.supportsAlpha = YES;
	
	NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.oakstheawesome.whatamessprefs"];
	NSString *hexColor = [prefs objectForKey:_currentColorKey];
	if (hexColor) {
		colorPicker.selectedColor = [self colorFromHex:hexColor];
	} else {
		if ([_currentColorKey isEqualToString:@"convListBackgroundColor"]) {
			colorPicker.selectedColor = [UIColor blackColor];
		} else if ([_currentColorKey isEqualToString:@"convListCellColor"]) {
			colorPicker.selectedColor = [UIColor blackColor];
		} else if ([_currentColorKey isEqualToString:@"titleTextColor"]) {
			colorPicker.selectedColor = [UIColor whiteColor];
		} else if ([_currentColorKey isEqualToString:@"messagePreviewTextColor"]) {
			colorPicker.selectedColor = [UIColor grayColor];
		} else if ([_currentColorKey isEqualToString:@"dateTimeTextColor"]) {
			colorPicker.selectedColor = [UIColor grayColor];
		}
	}
	
	[self presentViewController:colorPicker animated:YES completion:nil];
}

/* Gets user color, converts to hex string to save in prefs under the key in _currentColorKey. synchronize
writes the changes immediately to the disk. Posts an update notification to apply change semi-quickly. */
- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
	UIColor *selectedColor = viewController.selectedColor;
	NSString *hexColor = [self hexFromColor:selectedColor];
	
	NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.oakstheawesome.whatamessprefs"];
	[prefs setObject:hexColor forKey:_currentColorKey];
	[prefs synchronize];
	
	CFNotificationCenterPostNotification(
		CFNotificationCenterGetDarwinNotifyCenter(),
		CFSTR("com.oakstheawesome.whatamessprefs/prefsChanged"),
		NULL, NULL, YES
	);
}

/* Retrieves RGB and alpha from a UIColor, and converts each component from 0-1 to 0-255, the hex format.
Formats those ints as a hex string with a leading "#" while ensuring two digits/component.*/
- (NSString *)hexFromColor:(UIColor *)color {
	CGFloat red, green, blue, alpha;
	[color getRed:&red green:&green blue:&blue alpha:&alpha];
	
	int r = (int)(red * 255);
	int g = (int)(green * 255);
	int b = (int)(blue * 255);
	
	return [NSString stringWithFormat:@"#%02X%02X%02X", r, g, b];
}

/* Opposite, converts hex string to ints for a UIColor. Strips the "#" and converts. Extracts RGB, divides
by 255, and returns. */
- (UIColor *)colorFromHex:(NSString *)hexString {
	if ([hexString hasPrefix:@"#"]) {
		hexString = [hexString substringFromIndex:1];
	}
	
	unsigned int hex = 0;
	NSScanner *scanner = [NSScanner scannerWithString:hexString];
	[scanner scanHexInt:&hex];
	
	CGFloat r = ((hex >> 16) & 0xFF) / 255.0;
	CGFloat g = ((hex >> 8) & 0xFF) / 255.0;
	CGFloat b = (hex & 0xFF) / 255.0;
	
	return [UIColor colorWithRed:r green:g blue:b alpha:1.0];
}

/* Prepares color picker and stores the key so the color picker knows what prefs to load/save. */
- (void)openConversationListTitleColorPicker {
	_currentColorKey = @"conversationListTitleColor";
	[self showColorPicker];
}


/*====================
 IMAGE PICKER METHODS
 ===================*/


/* Creates an image picker to allow user to select image. Makes it open library, not camera. Presents as
window on top of other view controllers. Then actually presents picker to user. Basically handles window.
Ngl kinda had to rely heavily on ChatGPT here for help. */
- (void)pickConvListBgImage {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = (id<UINavigationControllerDelegate, UIImagePickerControllerDelegate>)self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;

   	UIWindowScene *scene = (UIWindowScene *)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
    UIWindow *window = scene.windows.firstObject;
    UIViewController *rootVC = window.rootViewController;

    [rootVC presentViewController:picker animated:YES completion:nil];
}

/* Gets selected image from dir. If no image returned, dismisses picker. Defines dir where image is saved.
Creates dir if not existant. Saves image as a jpg at path, 90% quality, and ensures file is fully written
or not written at all. Closes image picker after saving image to path. Posts an update notification. */
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
	if (!image) {
		[picker dismissViewControllerAnimated:YES completion:nil];
		return;
	}

    NSString *dirPath = @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs";
    if (![[NSFileManager defaultManager] fileExistsAtPath:dirPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dirPath
        withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSString *path = [dirPath stringByAppendingPathComponent:@"background.jpg"];
    NSData *data = UIImageJPEGRepresentation(image, 0.9);
    [data writeToFile:path atomically:YES];

    [picker dismissViewControllerAnimated:YES completion:nil];
    
    // Notify that image changed
    CFNotificationCenterPostNotification(
		CFNotificationCenterGetDarwinNotifyCenter(),
		CFSTR("com.oakstheawesome.whatamessprefs/prefsChanged"),
		NULL, NULL, YES
	);
}

/* Called only if user cancels process of picking image/picker. Simply dismisses it without issue. */
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end