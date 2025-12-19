#import <Foundation/Foundation.h>
#import "WAMRootListController.h"

@implementation WAMRootListController {
	NSString *_currentColorKey;
}

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return _specifiers;
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	
	// Post notification when leaving settings
	CFNotificationCenterPostNotification(
		CFNotificationCenterGetDarwinNotifyCenter(),
		CFSTR("com.oakstheawesome.whatamessprefs/prefsChanged"),
		NULL, NULL, YES
	);
}

// Color picker methods
- (void)pickBackgroundColor {
	_currentColorKey = @"convListBackgroundColor";
	[self showColorPicker];
}

- (void)pickCellColor {
	_currentColorKey = @"convListCellColor";
	[self showColorPicker];
}

- (void)pickTitleColor {
	_currentColorKey = @"titleTextColor";
	[self showColorPicker];
}

- (void)pickMessagePreviewColor {
	_currentColorKey = @"messagePreviewTextColor";
	[self showColorPicker];
}

- (void)pickDateTimeColor {
	_currentColorKey = @"dateTimeTextColor";
	[self showColorPicker];
}

- (void)showColorPicker {
	UIColorPickerViewController *colorPicker = [[UIColorPickerViewController alloc] init];
	colorPicker.delegate = self;
	colorPicker.supportsAlpha = YES;
	
	// Load current color
	NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.oakstheawesome.whatamessprefs"];
	NSString *hexColor = [prefs objectForKey:_currentColorKey];
	if (hexColor) {
		colorPicker.selectedColor = [self colorFromHex:hexColor];
	} else {
		// Default colors
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

- (void)colorPickerViewControllerDidFinish:(UIColorPickerViewController *)viewController {
	UIColor *selectedColor = viewController.selectedColor;
	NSString *hexColor = [self hexFromColor:selectedColor];
	
	// Save to preferences
	NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"com.oakstheawesome.whatamessprefs"];
	[prefs setObject:hexColor forKey:_currentColorKey];
	[prefs synchronize];
	
	// Post notification
	CFNotificationCenterPostNotification(
		CFNotificationCenterGetDarwinNotifyCenter(),
		CFSTR("com.oakstheawesome.whatamessprefs/prefsChanged"),
		NULL, NULL, YES
	);
}

- (NSString *)hexFromColor:(UIColor *)color {
	CGFloat red, green, blue, alpha;
	[color getRed:&red green:&green blue:&blue alpha:&alpha];
	
	int r = (int)(red * 255);
	int g = (int)(green * 255);
	int b = (int)(blue * 255);
	
	return [NSString stringWithFormat:@"#%02X%02X%02X", r, g, b];
}

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

- (void)openConversationListTitleColorPicker {
	_currentColorKey = @"conversationListTitleColor";
	[self showColorPicker];
}

// Image picker methods
- (void)pickConvListBgImage {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = (id<UINavigationControllerDelegate, UIImagePickerControllerDelegate>)self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;

   	UIWindowScene *scene = (UIWindowScene *)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
    UIWindow *window = scene.windows.firstObject;
    UIViewController *rootVC = window.rootViewController;

    [rootVC presentViewController:picker animated:YES completion:nil];
}

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

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end