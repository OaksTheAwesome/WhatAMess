#import <UIKit/UIKit.h>
#import <objc/runtime.h>

/*Interfaces, declare to hook certain things. Ex: Want to change label colors, hook CKLabel,
inherits attributes from UILabel*/
/*---------------------------------------------------*/
@interface CKConversationListCollectionViewController : UICollectionViewController
-(void)updateBackground;
-(void)makeSubviewsTransparent:(UIView *)view;
- (void)applyCustomColorsToCKLabelsInView:(UIView *)view;
@end

@interface CKTranscriptCollectionViewController : UIViewController
@end

@interface CKGradientReferenceView : UIView
@end

@interface CKMessagesController : UIViewController
@end

@interface _UIBarBackground : UIView
@end

@interface _UICollectionViewListSeparatorView : UIView
@end

@interface _UISearchBarSearchFieldBackgroundView : UIView
@end

@interface CKPinnedConversationView : UIView
@end

@class CKConversationListCollectionViewController;

@interface _UINavigationBarTitleControl : UIControl
@end

@interface _UIVisualEffectBackdropView : UIView
@end

@interface UIView (Private)
- (UIViewController *)_viewControllerForAncestor;
@end

@interface CKLabel : UILabel
@end

@interface UIDateLabel : UILabel
@end

@interface CKDateLabel : UIDateLabel
@end

@interface CKConversationListCollectionViewConversationCell : UICollectionViewCell
@end

@interface CKGradientView : UIView
- (void)setColors:(NSArray *)colors;
- (NSArray *)colors;
@end

@interface CKBalloonImageView : UIImageView
@property (nonatomic, strong) UIImage *image;
@end

@interface CKColoredBalloonView : UIView
@property (nonatomic, assign) int color;
@end

@interface CKBalloonTextView : UITextView
- (void)updateTextColorForBalloon;
@end

@interface CKTranscriptStatusCell : UICollectionViewCell
@end

@interface CKTranscriptLabelCell : UICollectionViewCell
@end

@interface _UIVisualEffectContentView : UIView
@end

@interface _UIVisualEffectSubview : UIView
@end

@interface CKMessageEntryView : UIView
- (void)applyInputFieldCustomization;
- (UITextView *)findTextView:(UIView *)view;
- (UIView *)findRoundedView:(UIView *)view;
- (UIView *)findViewByClassName:(UIView *)view;
@end

@interface UIKBVisualEffectView : UIVisualEffectView
@end

@interface CKMessageEntryRichTextView : UITextView
@end

@interface CKEntryViewButton : UIView
@end


/* ===================
  PREFERENCE THINGS 
==================== */


/* Define paths for preferences to save to (in the case of kImagePath, where to save image
and how to name it [background.jpg]). Notification is used to post the preference change and update tweak.
In case of messages, no respring is *required*, just close and reopen app a couple of times. */
/*--------------------------------------------------------------------------*/
#define kPrefsPath @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs.plist"
#define kImagePath @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background.jpg"
#define kChatImagePath @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background.jpg"
#define kPrefsChangedNotification @"com.oakstheawesome.whatamessprefs/prefsChanged"

/* Basically just holds preferences for a bit so they don't have to be reread everytime. */
static NSDictionary *cachedPrefs = nil;

/* Loads the preferences from the indicated path (defined in kPrefsPath). Checks chachedPrefs, if it = nil,
reads the plist (root.plist) into a NSDictionary. If cachedPrefs is already set, it returns the cached dictionary,
avoiding repeated reading from kPrefsPath. */
static NSDictionary *loadPrefs() {
	if (!cachedPrefs) {
		cachedPrefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
	}
	return cachedPrefs;
}

/* Resets cachedPrefs to nil, forces loadPrefs to read from kPrefsPath again. Useful for a prefs change
when tweak is running. */
static void clearPrefsCache() {
	cachedPrefs = nil;
}

/* Checks whether tweak is enabled according to prefs. Reads from prefs directly. Converts key "isEnabled" to
a boolean value, defaults to YES otherwise (if , for example, no preference has been set yet, like with fresh install). */
BOOL isTweakEnabled() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
	return prefs[@"isEnabled"] ? [prefs[@"isEnabled"] boolValue] : YES;
}

/* Checks if Modern NavBar is enabled/disabled. Uses loadPrefs and defaults to YES. */
BOOL isModernNavBarEnabled() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"isModernNavBarEnabled"] ? [prefs[@"isModernNavBarEnabled"] boolValue] : YES;
}

/* Checks if separators are enabled/disabled. Uses loadPrefs and defaults to NO. */
BOOL isSeparatorsEnabled() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"isSeparatorsEnabled"] ? [prefs[@"isSeparatorsEnabled"] boolValue] : NO;
}

/* Checks if search bar background is enabled/disabled. Uses loadPrefs, defaults to NO (bar on/not affected). */
BOOL isSearchBgEnabled() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"isSearchBgEnabled"] ? [prefs[@"isSearchBgEnabled"] boolValue] : NO;
}

/* Checks if pinned conversation glow hiding is enabled/disabled. Uses loadPrefs, defaults to NO. */
BOOL isPinnedGlowEnabled() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"isPinnedGlowEnabled"] ? [prefs[@"isPinnedGlowEnabled"] boolValue] : NO;
}

/* Checks if conversation list bg is enabled. Reads directly from prefs. Defaults to YES. */
BOOL isConvColorBgEnabled() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
	return prefs[@"isConvColorBgEnabled"] ? [prefs[@"isConvColorBgEnabled"] boolValue] : YES;
}

BOOL isChatColorBgEnabled() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"isChatColorBgEnabled"] ? [prefs[@"isChatColorBgEnabled"] boolValue] : NO;
}

/* Checks if conversation list image background is enabled. Reads directly from prefs. Defaults to NO. */
BOOL isConvImageBgEnabled() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
	return prefs[@"isConvImageBgEnabled"] ? [prefs[@"isConvImageBgEnabled"] boolValue] : NO;
}

BOOL isChatImageBgEnabled() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
	return prefs[@"isChatImageBgEnabled"] ? [prefs[@"isChatImageBgEnabled"] boolValue] : NO;
}

/* Checks if custom text colors should be enabled. Uses loadPrefs, defaults to NO. */
BOOL isCustomTextColorsEnabled() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"isCustomTextColorsEnabled"] ? [prefs[@"isCustomTextColorsEnabled"] boolValue] : NO;
}

BOOL isCustomBubbleColorsEnabled() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"isCustomBubbleColorsEnabled"] ? [prefs[@"isCustomBubbleColorsEnabled"] boolValue] : NO;
}

BOOL isModernMessageBarEnabled() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"isModernMessageBarEnabled"] ? [prefs[@"isModernMessageBarEnabled"] boolValue] : YES;
}

BOOL isInputFieldCustomizationEnabled() {
	NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:kPrefsPath];
    return prefs[@"isInputFieldCustomizationEnabled"] ? [prefs[@"isInputFieldCustomizationEnabled"] boolValue] : YES;
}

BOOL isInputFieldBlurEnabled() {
    NSDictionary *prefs = loadPrefs();
    return prefs[@"isInputFieldBlurEnabled"] ? [prefs[@"isInputFieldBlurEnabled"] boolValue] : NO;
}

BOOL isPlaceholderCustomizationEnabled() {
    NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:kPrefsPath];
    if (prefs && prefs[@"isPlaceholderCustomizationEnabled"]) {
        return [prefs[@"isPlaceholderCustomizationEnabled"] boolValue];
    }
    return NO;
}

BOOL isMessageInputTextEnabled() {
	NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:kPrefsPath];
    if (prefs && prefs[@"isMessageInputTextEnabled"]) {
        return [prefs[@"isMessageInputTextEnabled"] boolValue];
    }
    return NO;
}

/* Checks the amount of blur to apply to image based on user slider input. 
Uses loadPrefs, defaults to 0.0 (no blurring). */
CGFloat getImageBlurAmount() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"imageBlurAmount"] ? [prefs[@"imageBlurAmount"] floatValue] : 0.0;
}

CGFloat getChatImageBlurAmount() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"chatImageBlurAmount"] ? [prefs[@"chatImageBlurAmount"] floatValue] : 0.0;
}

/* Checks if input string is nil/empty. If it is, returns nil. If hex string has a leading "#", removes
that and ensures scanner only sees hex digits. Converts the hex string to an int. NSScanner parses string
into a numeric value. Then extracts RGB components and returns a useable UIColor. */
UIColor *colorFromHex(NSString *hexString) {
    if (!hexString || [hexString length] == 0) return nil;

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
        return nil;
    }
    
    return [UIColor colorWithRed:r green:g blue:b alpha:a];
}

/* Loads prefs, reads background color hex from prefs string "convListBackgroundColor". Converts to 
UIColor using colorFromHex, and defaults to black otherwise. */
UIColor *getBackgroundColor() {
	NSDictionary *prefs = loadPrefs();
	NSString *colorString = prefs[@"convListBackgroundColor"];
	UIColor *color = colorFromHex(colorString);
	return color ?: [UIColor blackColor];
}

UIColor *getChatBackgroundColor() {
	NSDictionary *prefs = loadPrefs();
	NSString *colorString = prefs[@"chatBackgroundColor"];
	UIColor *color = colorFromHex(colorString);
	return color ?: [UIColor blackColor];
}

/* Same as above, just for the cells instead of the background. Defaults to black. */
UIColor *getCellColor() {
	NSDictionary *prefs = loadPrefs();
	NSString *colorString = prefs[@"convListCellColor"];
	UIColor *color = colorFromHex(colorString);
	return color ?: [UIColor blackColor];
}

/* Same again, loads hex string for color for title text, defaults to white. */
UIColor *getTitleTextColor() {
	NSDictionary *prefs = loadPrefs();
	NSString *colorString = prefs[@"titleTextColor"];
	UIColor *color = colorFromHex(colorString);
	return color ?: [UIColor whiteColor];
}

/* Same again, loads hex string for color of message previews, defaults to gray. */
UIColor *getMessagePreviewTextColor() {
	NSDictionary *prefs = loadPrefs();
	NSString *colorString = prefs[@"messagePreviewTextColor"];
	UIColor *color = colorFromHex(colorString);
	return color ?: [UIColor grayColor];
}

/* Same again, loads hex string for color of date/time and chevron. Defaults to gray. */
UIColor *getDateTimeTextColor() {
	NSDictionary *prefs = loadPrefs();
	NSString *colorString = prefs[@"dateTimeTextColor"];
	UIColor *color = colorFromHex(colorString);
	return color ?: [UIColor grayColor];
}

/* Same again, loads hex string for color of main conv list "Messages" title. Defaults to white. */
UIColor *getConversationListTitleColor() {
	NSDictionary *prefs = loadPrefs();
	NSString *colorString = prefs[@"conversationListTitleColor"];
	UIColor *color = colorFromHex(colorString);
	return color ?: [UIColor whiteColor];
}

UIColor *getInputFieldBackgroundColor() {
    NSDictionary *prefs = loadPrefs();
    NSString *colorString = prefs[@"inputFieldBackgroundColor"];
    UIColor *color = colorFromHex(colorString);
	return color ?: [UIColor whiteColor];
}

UIBlurEffectStyle getInputFieldBlurStyle() {
    NSDictionary *prefs = loadPrefs();
    NSString *style = prefs[@"inputFieldBlurStyle"] ?: @"regular";
    
    if ([style isEqualToString:@"light"]) {
        return UIBlurEffectStyleLight;
    } else if ([style isEqualToString:@"dark"]) {
        return UIBlurEffectStyleDark;
    } else if ([style isEqualToString:@"ultraThinLight"]) {
        return UIBlurEffectStyleSystemUltraThinMaterialLight;
    } else if ([style isEqualToString:@"ultraThinDark"]) {
        return UIBlurEffectStyleSystemUltraThinMaterialDark;
    }
    return UIBlurEffectStyleRegular;
}

/* Gets text input from user to override "Messages" title. Defaults to stock title otherwise. */
static NSString *getConversationListTitle() {
	NSDictionary *prefs = loadPrefs();
	NSString *title = prefs[@"conversationListTitleText"];
	return title.length > 0 ? title : @"Messages";
}

/* Basically applies a gaussian blur to the user selected image. If 0 or negative, returns the original image.
Creates the blur filter, sets the image and the radius of said blur, and crops image to match the size
of the original input image. Converts the CIImage back to a UIImage, and returns the blurred image. */
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

	if (!cgImage) {
		return image;
	}

	UIImage *blurredImage = [UIImage imageWithCGImage:cgImage scale:image.scale orientation:image.imageOrientation];
	CGImageRelease(cgImage);

	return blurredImage;
}

/* This applies custom text colors to labels and image views based on type. 
If CKLabel, sets title text color. If CKDateLabel, sets date/time color. If standard UILabel, sets
message preview color. If UIImageView, sets tint to image, coloring chevron. Checks subviews to ensure
all colors are applied throughout view hierarchy. */
void applyCustomTextColors(UIView *view) {
	if (!isCustomTextColorsEnabled()) return;

	if ([view isKindOfClass:%c(CKLabel)]) {
		UILabel *label = (UILabel *)view;
		label.textColor = getTitleTextColor();
	}
	else if ([view isKindOfClass:%c(CKDateLabel)]) {
		UILabel *label = (UILabel *)view;
		label.textColor = getDateTimeTextColor();
	}
	else if ([view isKindOfClass:[UILabel class]]) {
		UILabel *label = (UILabel *)view;
		label.textColor = getMessagePreviewTextColor();
	}
	else if ([view isKindOfClass:[UIImageView class]]) {
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

static void logToFile(NSString *message) {
    FILE *logFile = fopen("/var/jb/var/mobile/whatamess_debug.log", "a");
    if (logFile) {
        fprintf(logFile, "%s\n", [message UTF8String]);
        fclose(logFile);
    }
}

static UIColor *getSMSSentBubbleColor() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"sentSMSBubbleColor"];
    
    logToFile([NSString stringWithFormat:@"getSMSSentBubbleColor - hex: %@", hexColor]);
    
    if (!hexColor) {
        logToFile(@"No sent color set, returning default blue");
        return [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
    }
    
    UIColor *color = colorFromHex(hexColor);
    logToFile([NSString stringWithFormat:@"Returning sent color: %@", color]);
    return color;
}

static UIColor *getSentBubbleColor() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"sentBubbleColor"];
    
    logToFile([NSString stringWithFormat:@"getSentBubbleColor - hex: %@", hexColor]);
    
    if (!hexColor) {
        logToFile(@"No sent color set, returning default blue");
        return [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
    }
    
    UIColor *color = colorFromHex(hexColor);
    logToFile([NSString stringWithFormat:@"Returning sent color: %@", color]);
    return color;
}

static UIColor *getReceivedBubbleColor() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"receivedBubbleColor"];
    
    logToFile([NSString stringWithFormat:@"getReceivedBubbleColor - hex: %@", hexColor]);
    
    if (!hexColor) {
        logToFile(@"No received color set, returning default gray");
        return [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    }
    
    UIColor *color = colorFromHex(hexColor);
    logToFile([NSString stringWithFormat:@"Returning received color: %@", color]);
    return color;
} 

static UIColor *getReceivedTextColor() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"receivedTextColor"];
    
    if (!hexColor) {
        return nil; // Return nil to use default
    }
    
    return colorFromHex(hexColor);
}

static UIColor *getSentTextColor() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"sentTextColor"];
    
    if (!hexColor) {
        return nil;
    }
    
    return colorFromHex(hexColor);
}

static UIColor *getSMSSentTextColor() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"sentSMSTextColor"];
    
    if (!hexColor) {
        return nil;
    }
    
    return colorFromHex(hexColor);
}

static UIColor *pickTimestampTextColor() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"timestampTextColor"];
    
    if (!hexColor) {
        return nil; // Use default color
    }
    
    return colorFromHex(hexColor);
}

static UIColor *getSystemTintColor() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"systemTintColor"];
    
    if (!hexColor) {
        return nil; // Use default system blue
    }
    
    return colorFromHex(hexColor);
}

static UIColor *getPlaceholderTextColor() {
    NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"placeholderTextColor"];
    if (hexColor) {
        return colorFromHex(hexColor);
    }
    return [UIColor grayColor];
}

static NSString *getPlaceholderText() {
    NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:kPrefsPath];
    NSString *text = prefs[@"placeholderText"];
    if (text && text.length > 0) {
        return text;
    }
    return nil;
}

static UIColor *getMessageInputTextColor() {
    NSDictionary *prefs = [[NSDictionary alloc] initWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"messageInputTextColor"];
    if (hexColor) {
        return colorFromHex(hexColor);
    }
    return [UIColor whiteColor];
}

/* ===========
    HOOKS 
============*/

/* System tint color. */
%hook UIView
- (UIColor *)tintColor {
    if (!isTweakEnabled()) {
        return %orig;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (customTint) {
        // Check if we're in the search bar or keyboard
        UIView *parent = self.superview;
        int levels = 0;
        
        while (parent && levels < 7) {
            // Exclude search bar elements
            if ([parent isKindOfClass:%c(_UISearchBarSearchFieldBackgroundView)] ||
                [parent isKindOfClass:%c(UISearchBar)]) {
                return %orig;
            }
            
            // Exclude keyboard elements
            if ([parent isKindOfClass:%c(UIKBVisualEffectView)] ||
                [parent isKindOfClass:%c(UIInputView)] ||
                [NSStringFromClass([parent class]) containsString:@"Keyboard"] ||
                [NSStringFromClass([parent class]) containsString:@"UIKBInputBackdropView"]) {
                return %orig;
            }
            
            parent = parent.superview;
            levels++;
        }
        
        return customTint;
    }
    
    return %orig;
}
%end

/* Main view controller for Messages conversation list view. Everything inside modifies appearance. */
%hook CKConversationListCollectionViewController

/* Calls original function first. Checks if tweak is enabled. Sets main view and conversation collection view
to clear, allowing custom BG to show. Calls updateBackground to apply colored bg/image bg. Also includes
prefs listener to update bg as prefs are changed. */
-(void)viewDidLoad {
	%orig;

	if (!isTweakEnabled()) {
		return;
	}

	self.view.backgroundColor = [UIColor clearColor];
	self.collectionView.backgroundColor = [UIColor clearColor];

	[self updateBackground];

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(updateBackground)
		name:kPrefsChangedNotification
		object:nil];
}

/* Walks through view's subviews, if its a CKLabel, sets its text color to the custom title color. Calls for
each subview just in case. */
%new
-(void)applyCustomColorsToCKLabelsInView:(UIView *)view {
	for (UIView *subview in view.subviews) {
		if ([subview isKindOfClass:%c(CKLabel)]) {
			CKLabel *label = (CKLabel *)subview;
			label.textColor = getTitleTextColor();
		}
		[self applyCustomColorsToCKLabelsInView:subview];
	}
}

/* Called whenever subview layouts change. Makes subviews transparent if custom image bg is enabled.
Applies custom label colors. */
-(void)viewDidLayoutSubviews {
	%orig;
	
	if (!isTweakEnabled()) {
		return;
	}
	
	if (isConvImageBgEnabled() && !isConvColorBgEnabled()) {
		[self makeSubviewsTransparent:self.view];
		[self makeSubviewsTransparent:self.collectionView];	
	}
	
	[self applyCustomColorsToCKLabelsInView:self.view];
}

/* Clears prefs chache, checks for custom image, and loads if present. If color bg is enabled, creates the
colored view behind all cells. If image bg is enabled, provides the blur option, if added. Adds to both
collection view background and main view so it covers it all. Calls makeSubviewsTransparent to ensure
background subviews are clear and show image. If no bg is set, clears. Finally, reloads collection to show 
changes.*/
%new
-(void)updateBackground {
	clearPrefsCache();

	BOOL hasImage = [[NSFileManager defaultManager] fileExistsAtPath:kImagePath];
	UIImage *bgImage = hasImage ? [UIImage imageWithContentsOfFile:kImagePath] : nil;
	
	if (isConvColorBgEnabled()) {
		UIView *colorView = [[UIView alloc] initWithFrame:self.collectionView.bounds];
		colorView.backgroundColor = getBackgroundColor();
		colorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		self.collectionView.backgroundView = colorView;

	} else if (bgImage && isConvImageBgEnabled()) {
		CGFloat blurAmount = getImageBlurAmount();
		if (blurAmount > 0) {
			bgImage = blurImage(bgImage, blurAmount);
		}
		
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
		[self.view insertSubview:mainBgView atIndex:0];

		[self makeSubviewsTransparent:self.view];
		[self makeSubviewsTransparent:self.collectionView];
	} else {
		self.collectionView.backgroundView = nil;
	}
	
	[self.collectionView reloadData];
}

/* Checks subviews. If view is black/dark and opaque, sets to clear. Helps to show image bg. */
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

/* Removes tweak prefs observer. */
-(void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	%orig;
}
%end

/* Modified cell colors/appearance. */
%hook CKConversationListCollectionViewConversationCell
 
 /* Sets cell bg according to tweak prefs: color (user indicaated), image (clear to allow image to 
 be visible), or clear as default.*/
-(instancetype)initWithFrame:(CGRect)frame {
	if (!isTweakEnabled()) {
		return %orig(frame);
	}
	self = %orig(frame);
	if (self) {
		if (isConvColorBgEnabled()) {
			self.contentView.backgroundColor = getCellColor();
		} else if (isConvImageBgEnabled()) {
			self.backgroundColor = [UIColor clearColor];
			self.contentView.backgroundColor = [UIColor clearColor];
			self.layer.backgroundColor = [UIColor clearColor].CGColor;
		}else{
			self.contentView.backgroundColor = [UIColor clearColor];
		}
	}
	return self;
}

/* Calls applyCustomTextColors to cell to color labels in cell. */
-(void)layoutSubviews {
	%orig;

	if (!isTweakEnabled()) return;

	applyCustomTextColors(self);
}

%end

/* Modifies labels. */
%hook UILabel

- (void)setTextColor:(UIColor *)color {
    if (!isTweakEnabled() || !isCustomTextColorsEnabled()) {
        %orig;
        return;
    }
    
    // First check conversation list cells
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
    
    // Then check timestamp cells (only if NOT in conversation cell)
    UIView *parent = self.superview;
    int levels = 0;
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)] || [parent isKindOfClass:%c(CKTranscriptLabelCell)]) {
            UIColor *timestampColor = pickTimestampTextColor();
            if (timestampColor) {
                %orig(timestampColor);
                return;
            }
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
	%orig;
}

%end

/* Overrides setTintColor to enforce custom tint colors in conv cells. Checks whether the tweak and custom
text colors are enabled. Checks if image view is inside CKConvListCollectionViewConvCell. If in such cell,
sets tint color, if not, calls original method.*/
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
    
    if (!isInConversationCell) {
        %orig;
        return;
    }
    
    %orig(getDateTimeTextColor());
}

- (void)setImage:(UIImage *)image {
    %orig;
    
    if (!isTweakEnabled() || !image) {
        return;
    }
    
    // Check if this is an unread indicator in conversation list
    UIView *parent = self.superview;
    BOOL isUnreadIndicator = NO;
    int levels = 0;
    
    while (parent && levels < 5) {
        if ([parent isKindOfClass:%c(CKConversationListEmbeddedStandardTableViewCell)]) {
            isUnreadIndicator = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isUnreadIndicator) {
        // Only apply to small images (unread indicators are typically 8-12 points)
        // Contact images are much larger (40+ points)
        CGSize imageSize = image.size;
        if (imageSize.width < 20 && imageSize.height < 20) {
            UIColor *customTint = getSystemTintColor();
            if (customTint) {
                // Change rendering mode to template so it respects tint color
                UIImage *tintedImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                %orig(tintedImage);
                self.tintColor = customTint;
            }
        }
    }
}
%end

/* Hooks the navigation bar background and removes any defualt blurs. Creates a new blur effect and expands
it to provide more room for gradient. Gradient mask allows blur to fade smoothly from opaque to transparent,
top to bottom. */
%hook _UIBarBackground
- (void)layoutSubviews {
    %orig;

    if (!isTweakEnabled() || !isModernNavBarEnabled()) {
		%orig;
		return;
	}

    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]]) {
            [sub removeFromSuperview];
        }
    }

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];

    CGRect blurFrame = self.bounds;
    blurFrame.size.height += 55;
    blurView.frame = blurFrame;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self insertSubview:blurView atIndex:0];

    CAGradientLayer *maskLayer = [CAGradientLayer layer];
    maskLayer.frame = blurView.bounds;
    maskLayer.colors = @[
        (id)[UIColor colorWithWhite:1 alpha:1.0].CGColor,
        (id)[UIColor colorWithWhite:1 alpha:0.9].CGColor,
		(id)[UIColor colorWithWhite:1 alpha:0.55].CGColor,
		(id)[UIColor colorWithWhite:1 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:1 alpha:0.0].CGColor
    ];
    maskLayer.locations = @[@0.0, @0.3, @0.6, @0.98, @1.0];
    blurView.layer.mask = maskLayer;
}
%end

/* Targets NavBar Title, only modifying the label titled "Messages" to avoid modifying other name views
across messages app. Replaces the title with a custom user string and sets a custom color. */
%hook _UINavigationBarTitleControl

- (void)layoutSubviews {
    %orig;

    if (!isTweakEnabled()) return;

    for (UIView *sub in self.subviews) {
        if (![sub isKindOfClass:[UILabel class]]) continue;

        UILabel *label = (UILabel *)sub;

        // Only change the title if it's the main Messages title
        if ([label.text isEqualToString:@"Messages"]) {
            label.text = getConversationListTitle();           // Custom text
            label.textColor = getConversationListTitleColor(); // Custom color
        }
    }
}

%end

/* Controls separators between cells. Hides them if toggle is true. Simple enough. */
%hook _UICollectionViewListSeparatorView

- (void) didMoveToWindow {
	%orig;

	if (!isTweakEnabled()) return;

	if (isSeparatorsEnabled()) {
		self.hidden = YES;
		self.alpha = 0.0;
	} else {
		self.hidden = NO;
		self.alpha = 1.0;
	}
}

%end

/* Controls background of search bar. If toggled true, hides background. Othewise, is shown. Simple. */
%hook _UISearchBarSearchFieldBackgroundView

- (void) didMoveToWindow {
	%orig;

	if (!isTweakEnabled()) return;

	if (isSearchBgEnabled()) {
		self.hidden = YES;
	} else {
		self.hidden = NO;
	}
}

%end

/* Handles glow behind pinned conversations. If toggled true, hides. Otherwise, shown. Simple again. */
%hook CKPinnedConversationView

-(void) didMoveToWindow {
	%orig;

	if (!isTweakEnabled()) return;

	for (UIView *sub in self.subviews) {
		if (![sub isKindOfClass:[UIImageView class]]) continue;

		UIImageView *img = (UIImageView *)sub;

		img.hidden = isPinnedGlowEnabled();
		img.alpha = isPinnedGlowEnabled() ? 1.0 : 0.0;
	}
}

%end
 
 /* Hides some views for color/image bg in chats. */
%hook CKTranscriptCollectionViewController

- (void)viewDidLoad {
    %orig;
	self.view.backgroundColor = [UIColor clearColor];
}
/* There was this little weird black box around bubbles that I could never find for the life of me. Found "chatwall"
by ChristopherA8 from back in the iOS 13/14 days and FINALLY found what made it go away. So special thanks for
that and sparing my beginner-level sanity. Also steered me in the direction of what to hide. TYSM 4 open sourcing oml. */
-(BOOL)shouldUseOpaqueMask{
	return NO;
}
%end

 /* Hides some views for color/image bg in chats. */
%hook CKGradientReferenceView
	
-(void)setFrame:(CGRect)arg1 {
	%orig;
	self.backgroundColor = [UIColor clearColor];
}

%end

/* Handles the image and color bg for in chats. Similar to the first hook in the list. Resuses some
same things too, like the blur. */
%hook CKMessagesController

-(void)viewDidLoad {
	%orig;

	if (!isTweakEnabled()) {
		return;
	}

	self.view.backgroundColor = [UIColor clearColor];

	BOOL hasChatImage = [[NSFileManager defaultManager] fileExistsAtPath:kChatImagePath];
	UIImage *chatBgImage = hasChatImage ? [UIImage imageWithContentsOfFile:kChatImagePath] : nil;

	if (isChatColorBgEnabled()) {
		UIView *colorView = [[UIView alloc] initWithFrame:self.view.bounds];
		colorView.backgroundColor = getChatBackgroundColor();
		colorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self.view insertSubview:colorView atIndex:0];
	}

	else if (chatBgImage && isChatImageBgEnabled()) {
		CGFloat blurAmount = getChatImageBlurAmount();
		if (blurAmount > 0) {
			chatBgImage = blurImage(chatBgImage, blurAmount);
		}

		UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.view.bounds];
		imageView.image = chatBgImage;
		imageView.contentMode = UIViewContentModeScaleAspectFill;
		imageView.clipsToBounds = YES;
		imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self.view insertSubview:imageView atIndex:0];
	}

	[[NSNotificationCenter defaultCenter] addObserver:self
		selector:@selector(updateChatBackground)
		name:kPrefsChangedNotification
		object:nil];
}

-(void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	%orig;
}

%end

%hook CKGradientView
- (void)setColors:(NSArray *)colors {
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        %orig;
        return;
    }
    
    // Find parent balloon
    CKColoredBalloonView *parentBalloon = nil;
    UIView *parent = self.superview;
    while (parent) {
        if ([parent isKindOfClass:%c(CKColoredBalloonView)]) {
            parentBalloon = (CKColoredBalloonView *)parent;
            break;
        }
        parent = parent.superview;
    }
    
    if (parentBalloon) {
        UIColor *targetColor = nil;
        
        if (parentBalloon.color == -1) {
            targetColor = getReceivedBubbleColor();
        } else if (parentBalloon.color == 1) {
            targetColor = getSentBubbleColor();
        } else if (parentBalloon.color == 0) { // Changed from 3 to 0
            targetColor = getSMSSentBubbleColor();
        }
        
        if (targetColor) {
            // Replace the colors array with our custom color
            NSArray *customColors = @[targetColor, targetColor];
            %orig(customColors);
            return;
        }
    }
    
    %orig;
}
- (void)didMoveToSuperview {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        return;
    }
    
    // Force color update immediately when added to view hierarchy
    CKColoredBalloonView *parentBalloon = nil;
    UIView *parent = self.superview;
    while (parent) {
        if ([parent isKindOfClass:%c(CKColoredBalloonView)]) {
            parentBalloon = (CKColoredBalloonView *)parent;
            break;
        }
        parent = parent.superview;
    }
    
    if (parentBalloon && (parentBalloon.color == 1 || parentBalloon.color == 0)) { // Changed from 3 to 0
        UIColor *sentColor = nil;
        if (parentBalloon.color == 1) {
            sentColor = getSentBubbleColor();
        } else if (parentBalloon.color == 0) { // Changed from 3 to 0
            sentColor = getSMSSentBubbleColor();
        }
        
        if (sentColor) {
            NSArray *customColors = @[sentColor, sentColor];
            [self setColors:customColors];
            logToFile(@"Forced color update in didMoveToSuperview");
        }
    }
}
- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        return;
    }
    
    // Also force on layout
    CKColoredBalloonView *parentBalloon = nil;
    UIView *parent = self.superview;
    while (parent) {
        if ([parent isKindOfClass:%c(CKColoredBalloonView)]) {
            parentBalloon = (CKColoredBalloonView *)parent;
            break;
        }
        parent = parent.superview;
    }
    
    if (parentBalloon && (parentBalloon.color == 1 || parentBalloon.color == 0)) { // Changed from 3 to 0
        UIColor *sentColor = nil;
        if (parentBalloon.color == 1) {
            sentColor = getSentBubbleColor();
        } else if (parentBalloon.color == 0) { // Changed from 3 to 0
            sentColor = getSMSSentBubbleColor();
        }
        
        if (sentColor) {
            NSArray *currentColors = [self colors];
            
            // Only update if colors don't match
            if (currentColors.count > 0 && ![currentColors[0] isEqual:sentColor]) {
                NSArray *customColors = @[sentColor, sentColor];
                [self setColors:customColors];
                logToFile(@"Fixed bubble in layoutSubviews");
            }
        }
    }
}
%end

%hook CKBalloonImageView
- (void)setImage:(UIImage *)image {
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !image) {
        %orig;
        return;
    }
    if ([self isKindOfClass:%c(CKColoredBalloonView)]) {
        CKColoredBalloonView *coloredSelf = (CKColoredBalloonView *)self;
        if (coloredSelf.color == -1) { // Received message
            UIColor *receivedColor = getReceivedBubbleColor();
            if (receivedColor) {
                UIImageRenderingMode originalMode = image.renderingMode;
                UIEdgeInsets capInsets = image.capInsets;
                UIImageResizingMode resizingMode = image.resizingMode;
                UIEdgeInsets alignmentInsets = image.alignmentRectInsets;
                CGFloat scale = image.scale;
                
                UIGraphicsBeginImageContextWithOptions(image.size, NO, scale);
                CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
                
                // Draw original image first
                [image drawInRect:rect];
                
                // Overlay tint color
                [receivedColor setFill];
                UIRectFillUsingBlendMode(rect, kCGBlendModeSourceAtop);
                
                UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                
                // Adjust alignment insets - balance left and right
                alignmentInsets.left += 6.0;
                alignmentInsets.right -= 8.0; // Give more room on the right
                
                // Restore all properties in the correct order
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
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        return;
    }
    
    if (!self.superview) {
        return;
    }
    
    [self updateTextColorForBalloon];
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        return;
    }
    
    [self updateTextColorForBalloon];
}

- (void)setText:(NSString *)text {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        return;
    }
    
    [self updateTextColorForBalloon];
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        return;
    }
    
    [self updateTextColorForBalloon];
}

%new
- (void)updateTextColorForBalloon {
    // Search for CKTextBalloonView (which inherits from CKColoredBalloonView)
    CKColoredBalloonView *balloonView = nil;
    UIView *parent = self.superview;
    int levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKColoredBalloonView)]) {
            balloonView = (CKColoredBalloonView *)parent;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (balloonView) {
        UIColor *textColor = nil;
        
        if (balloonView.color == -1) {
            textColor = getReceivedTextColor();
        } else if (balloonView.color == 1) {
            textColor = getSentTextColor();
        } else if (balloonView.color == 0) {
            textColor = getSMSSentTextColor();
        }
        
        if (textColor && ![self.textColor isEqual:textColor]) {
            self.textColor = textColor;
        }
    }
}

%end

%hook CKTranscriptStatusCell

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        return;
    }
    
    UIColor *timestampColor = pickTimestampTextColor();
    if (!timestampColor) {
        return;
    }
    
    // The UILabel is a direct child of contentView
    for (UIView *subview in self.contentView.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.textColor = timestampColor;
            logToFile([NSString stringWithFormat:@"Set timestamp color to label: %@", label.text]);
        }
    }
}

%end

%hook CKTranscriptLabelCell

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        return;
    }
    
    // Make sure we're in a chat view, not conversation list
    UIViewController *vc = [self _viewControllerForAncestor];
    if (![vc isKindOfClass:%c(CKTranscriptCollectionViewController)]) {
        return;
    }
    
    UIColor *timestampColor = pickTimestampTextColor();
    if (!timestampColor) {
        return;
    }
    
    // The UILabel is a direct child of contentView
    for (UIView *subview in self.contentView.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.textColor = timestampColor;
        }
    }
}

%end

%hook _UIVisualEffectBackdropView
- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isModernMessageBarEnabled()) {
        return;
    }
    
    // Check if we're in the message input area BUT NOT the keyboard
    UIView *parent = self.superview;
    UIVisualEffectView *effectView = nil;
    BOOL isInMessageInput = NO;
    BOOL isInKeyboard = NO;
    int levels = 0;
    
    while (parent && levels < 15) {
        if ([parent isKindOfClass:[UIVisualEffectView class]] && !effectView) {
            effectView = (UIVisualEffectView *)parent;
        }
        // Check if we're in keyboard first
        if ([parent isKindOfClass:%c(UIKBVisualEffectView)] || 
            [parent isKindOfClass:%c(UIInputView)] ||
            [NSStringFromClass([parent class]) containsString:@"Keyboard"]) {
            isInKeyboard = YES;
            break;
        }
        if ([parent isKindOfClass:%c(CKMessageEntryView)]) {
            isInMessageInput = YES;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (!isInMessageInput || isInKeyboard || !effectView) {
        return;
    }
    
    // Expand the effect view frame upward by 55 points
    CGRect expandedFrame = effectView.frame;
    expandedFrame.origin.y -= 55;
    expandedFrame.size.height += 55;
    effectView.frame = expandedFrame;
    
    // Apply gradient blur to message bar only
    UIBlurEffect *customBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    effectView.effect = customBlur;
    self.alpha = 1.0;
    
    // Apply gradient mask
    CAGradientLayer *maskLayer = [CAGradientLayer layer];
    maskLayer.frame = self.bounds;
    maskLayer.colors = @[
        (id)[UIColor colorWithWhite:0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0.55].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0.9].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:1.0].CGColor
    ];
    maskLayer.locations = @[@0.0, @0.3, @0.6, @0.98, @1.0];
    self.layer.mask = maskLayer;
}
%end

%hook _UIVisualEffectContentView
- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isModernMessageBarEnabled()) {
        return;
    }
    
    // Check if we're in the message input area BUT NOT the keyboard
    UIView *parent = self.superview;
    BOOL isInMessageInput = NO;
    BOOL isInKeyboard = NO;
    int levels = 0;
    
    while (parent && levels < 15) {
        if ([parent isKindOfClass:%c(UIKBVisualEffectView)] || 
            [parent isKindOfClass:%c(UIInputView)] ||
            [NSStringFromClass([parent class]) containsString:@"Keyboard"]) {
            isInKeyboard = YES;
            break;
        }
        if ([parent isKindOfClass:%c(CKMessageEntryView)]) {
            isInMessageInput = YES;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInMessageInput && !isInKeyboard) {
        self.backgroundColor = [UIColor clearColor];
        self.layer.mask = nil;
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled() || !isModernMessageBarEnabled()) {
        %orig;
        return;
    }
    
    // Check if we're in the message input area
    UIView *parent = self.superview;
    BOOL isInMessageInput = NO;
    BOOL isInKeyboard = NO;
    int levels = 0;
    
    while (parent && levels < 15) {
        if ([parent isKindOfClass:%c(UIKBVisualEffectView)] || 
            [parent isKindOfClass:%c(UIInputView)] ||
            [NSStringFromClass([parent class]) containsString:@"Keyboard"]) {
            isInKeyboard = YES;
            break;
        }
        if ([parent isKindOfClass:%c(CKMessageEntryView)]) {
            isInMessageInput = YES;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInMessageInput && !isInKeyboard) {
        %orig([UIColor clearColor]);
        return;
    }
    
    %orig;
}
%end

%hook _UIVisualEffectSubview

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isModernMessageBarEnabled()) {
        return;
    }
    
    // Check if we're in the message input area BUT NOT the keyboard
    UIView *parent = self.superview;
    BOOL isInMessageInput = NO;
    BOOL isInKeyboard = NO;
    int levels = 0;
    
    while (parent && levels < 15) {
        if ([parent isKindOfClass:%c(UIKBVisualEffectView)] || 
            [parent isKindOfClass:%c(UIInputView)] ||
            [NSStringFromClass([parent class]) containsString:@"Keyboard"]) {
            isInKeyboard = YES;
            break;
        }
        if ([parent isKindOfClass:%c(CKMessageEntryView)]) {
            isInMessageInput = YES;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInMessageInput && !isInKeyboard) {
        self.backgroundColor = [UIColor clearColor];
        self.layer.mask = nil;
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled() || !isModernMessageBarEnabled()) {
        %orig;
        return;
    }
    
    // Check if we're in the message input area
    UIView *parent = self.superview;
    BOOL isInMessageInput = NO;
    BOOL isInKeyboard = NO;
    int levels = 0;
    
    while (parent && levels < 15) {
        if ([parent isKindOfClass:%c(UIKBVisualEffectView)] || 
            [parent isKindOfClass:%c(UIInputView)] ||
            [NSStringFromClass([parent class]) containsString:@"Keyboard"]) {
            isInKeyboard = YES;
            break;
        }
        if ([parent isKindOfClass:%c(CKMessageEntryView)]) {
            isInMessageInput = YES;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInMessageInput && !isInKeyboard) {
        %orig([UIColor clearColor]);
        return;
    }
    
    %orig;
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
    
    if (!isTweakEnabled()) {
        return;
    }
    
    if (self.window) {
        [[NSNotificationCenter defaultCenter] addObserver:self
            selector:@selector(applyInputFieldCustomization)
            name:kPrefsChangedNotification
            object:nil];
            
        if (isInputFieldCustomizationEnabled()) {
            [self applyInputFieldCustomization];
        }
    } else {
        [[NSNotificationCenter defaultCenter] removeObserver:self
            name:kPrefsChangedNotification
            object:nil];
    }
}

%new
- (void)applyInputFieldCustomization {
    UIView *inputFieldContainer = nil;
    
    // Strategy 1: Look for UITextView
    UITextView *textView = [self findTextView:self];
    if (textView) {
        inputFieldContainer = textView.superview;
    }
    
    // Strategy 2: Look for rounded corner views
    if (!inputFieldContainer) {
        inputFieldContainer = [self findRoundedView:self];
    }
    
    // Strategy 3: Look for specific class names
    if (!inputFieldContainer) {
        inputFieldContainer = [self findViewByClassName:self];
    }
    
    if (!inputFieldContainer) {
        return;
    }
    
    // Remove any existing blur views (identified by class type)
    NSArray *subviewsCopy = [inputFieldContainer.subviews copy];
    for (UIView *subview in subviewsCopy) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            [subview removeFromSuperview];
        }
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
}

%new
- (UITextView *)findTextView:(UIView *)view {
    if ([view isKindOfClass:[UITextView class]]) {
        return (UITextView *)view;
    }
    
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
        CGRectGetHeight(view.frame) < 60) {
        return view;
    }
    
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
        
        if (CGRectGetHeight(view.frame) > 30 && CGRectGetHeight(view.frame) < 60) {
            return view;
        }
    }
    
    for (UIView *subview in view.subviews) {
        UIView *found = [self findViewByClassName:subview];
        if (found) return found;
    }
    
    return nil;
}

%end

%hook CKMessageEntryRichTextView
- (void)layoutSubviews {
    %orig;
    
    // Handle placeholder customization
    if (isTweakEnabled() && isPlaceholderCustomizationEnabled() && isInputFieldCustomizationEnabled()) {
        // Find and customize the placeholder label
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)subview;
                label.textColor = getPlaceholderTextColor();
                
                NSString *customText = getPlaceholderText();
                if (customText) {
                    label.text = customText;
                }
                break;
            }
        }
    }
    
    // Handle message input text color
    if (isTweakEnabled() && isInputFieldCustomizationEnabled() && isMessageInputTextEnabled()) {
        UIColor *customTextColor = getMessageInputTextColor();
        if (customTextColor) {
            self.textColor = customTextColor;
        }
    }
}

- (void)setTextColor:(UIColor *)textColor {
    if (!isTweakEnabled() && isInputFieldCustomizationEnabled() && isMessageInputTextEnabled()) {
        %orig;
        return;
    }
    
    UIColor *customTextColor = getMessageInputTextColor();
    if (customTextColor) {
        %orig(customTextColor);
        return;
    }
    
    %orig;
}

- (void)setText:(NSString *)text {
    %orig;
    
    if (!isTweakEnabled() && isInputFieldCustomizationEnabled() && isMessageInputTextEnabled()) {
        return;
    }
    
    UIColor *customTextColor = getMessageInputTextColor();
    if (customTextColor) {
        self.textColor = customTextColor;
    }
}
%end

%hook CKEntryViewButton
- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (!customTint) {
        return;
    }
    
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            UIVisualEffectView *effectView = (UIVisualEffectView *)subview;
            
            for (UIView *contentSubview in effectView.contentView.subviews) {
                if ([contentSubview isKindOfClass:[UIButton class]]) {
                    UIButton *button = (UIButton *)contentSubview;
                    
                    // Get current image to identify the send button
                    UIImage *currentImage = [button imageForState:UIControlStateNormal];
                    if (!currentImage) continue;
                    
                    CGFloat imageWidth = currentImage.size.width;
                    CGFloat imageHeight = currentImage.size.height;
                    
                    // The send button is 27.3 x 27.3 - target that size
                    if (imageWidth > 27 && imageWidth < 28 && imageHeight > 27 && imageHeight < 28) {
                        // Set background to custom color
                        button.backgroundColor = customTint;
                        button.layer.cornerRadius = button.bounds.size.width / 2;
                        button.clipsToBounds = YES;
                        
                        // Remove the button's image
                        [button setImage:nil forState:UIControlStateNormal];
                        
                        // Remove any existing arrow overlays
                        for (UIView *btnSubview in [button.subviews copy]) {
                            if ([btnSubview isKindOfClass:[UIImageView class]]) {
                                [btnSubview removeFromSuperview];
                            }
                        }
                        
                        // Use SF Symbol for arrow - slightly larger
                        UIImage *arrowImage = [UIImage systemImageNamed:@"arrow.up"];
                        if (arrowImage) {
                            UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:15 weight:UIImageSymbolWeightSemibold];
                            arrowImage = [arrowImage imageWithConfiguration:config];
                            arrowImage = [arrowImage imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
                            
                            UIImageView *arrowOverlay = [[UIImageView alloc] initWithImage:arrowImage];
                            arrowOverlay.userInteractionEnabled = NO;
                            
                            // Position the arrow - centered (no offset)
                            CGSize buttonSize = button.bounds.size;
                            CGSize arrowSize = arrowOverlay.bounds.size;
                            arrowOverlay.frame = CGRectMake((buttonSize.width - arrowSize.width) / 2,
                                                           (buttonSize.height - arrowSize.height) / 2,
                                                           arrowSize.width,
                                                           arrowSize.height);
                            
                            [button addSubview:arrowOverlay];
                        }
                    }
                }
            }
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Force a layout update when the button appears
    [self setNeedsLayout];
    [self layoutIfNeeded];
}
%end