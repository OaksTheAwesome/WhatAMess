#import <Foundation/Foundation.h>
#import "WAMRootListController.h"
#import <spawn.h>

@implementation WAMRootListController {
	NSString *_currentColorKey;
}
 // Essentially sets up prefences in Settings, fetches plist
- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return _specifiers;
}

- (void)pickSystemTintColor {
    _currentColorKey = @"systemTintColor";
    [self showColorPicker];
}

- (void)pickNavBarTintColor {
    _currentColorKey = @"navBarTintColor";
    [self showColorPicker];
}

- (void)pickCellTintColor {
    _currentColorKey = @"cellTintColor";
    [self showColorPicker];
}

 // Posts preference change after window is closed.
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	
	// Post notification when leaving settings
	CFNotificationCenterPostNotification(
		CFNotificationCenterGetDarwinNotifyCenter(),
		CFSTR("com.oakstheawesome.whatamessprefs/prefsChanged"),
		NULL, NULL, YES
	);
}

// Resping method lol 
- (void)respring {
	/* Confirmation alert dialog */
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Respring"
		message:@"Are you sure you want to respring?"
		preferredStyle:UIAlertControllerStyleAlert];
	
	[alert addAction:[UIAlertAction actionWithTitle:@"Not Yet" style:UIAlertActionStyleCancel handler:nil]];
	
	[alert addAction:[UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
		/* reload sb */
		pid_t pid;
		const char* args[] = {"sbreload", NULL};
		posix_spawn(&pid, "/var/jb/usr/bin/sbreload", NULL, NULL, (char* const*)args, NULL);
	}]];
	
	[self presentViewController:alert animated:YES completion:nil];
}

/*====================
 COLOR PICKER METHODS
 ===================*/

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
		colorPicker.selectedColor = [UIColor blackColor];
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
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGColorRef rgbColor = CGColorCreateCopyByMatchingToColorSpace(
        rgbColorSpace,
        kCGRenderingIntentDefault,
        color.CGColor,
        NULL
    );
    
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    
    if (rgbColor) {
        const CGFloat *components = CGColorGetComponents(rgbColor);
        size_t componentCount = CGColorGetNumberOfComponents(rgbColor);
        
        if (componentCount >= 3) {
            red = components[0];
            green = components[1];
            blue = components[2];
            if (componentCount >= 4) {
                alpha = components[3];
            } else {
                alpha = 1.0;
            }
        }
        
        CGColorRelease(rgbColor);
    } else {
        [color getRed:&red green:&green blue:&blue alpha:&alpha];
    }
    
    CGColorSpaceRelease(rgbColorSpace);
    
    int r = (int)(red * 255.0);
    int g = (int)(green * 255.0);
    int b = (int)(blue * 255.0);
    int a = (int)(alpha * 255.0);
    
    r = MAX(0, MIN(255, r));
    g = MAX(0, MIN(255, g));
    b = MAX(0, MIN(255, b));
    a = MAX(0, MIN(255, a));
    
    return [NSString stringWithFormat:@"#%02X%02X%02X%02X", r, g, b, a];
}

/* Opposite, converts hex string to ints for a UIColor. Strips the "#" and converts. Extracts RGB, divides
by 255, and returns. */
- (UIColor *)colorFromHex:(NSString *)hexString {
    if ([hexString hasPrefix:@"#"]) {
        hexString = [hexString substringFromIndex:1];
    }
    
    CGFloat r, g, b, a;
    
    if (hexString.length == 8) {
        // RRGGBBAA format - parse each component separately
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
        // RRGGBB format
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
        // Invalid format
        return [UIColor blackColor];
    }
    
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

@end