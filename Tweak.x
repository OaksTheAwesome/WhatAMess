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
- (void)createOurBlur;
- (void)removeSystemViews;
- (void)ensureBlurExists;
- (BOOL)findContactViewInWindow:(UIView *)view;
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
- (BOOL)isInsideReactionBubble;
- (void)applyColorRecursively:(UIColor *)color;
@end

@interface CKBalloonImageView : UIImageView
@property (nonatomic, strong) UIImage *image;
@end

@interface CKColoredBalloonView : UIView
@property (nonatomic, assign) int color;
@end

@interface CKBalloonTextView : UITextView
- (void)updateTextColorForBalloon;
- (UIColor *)getCustomTextColor;
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

@interface CKDetailsTableView : UITableView
@end

@interface _UITableViewHeaderFooterContentView : UIView
@end

@interface CNGroupIdentityHeaderContainerView : UIView
- (void)applyContactNameColor;
@end

@interface CKGroupPhotoCell : UIView
@end

@interface CNActionView : UIView
- (void)matchIconToLabelAlpha;
- (void)updateIconOpacity;
@end

@interface CKTranscriptDetailsResizableCell : UICollectionViewCell
@end

@interface CKDetailsSharedWithYouCell : UITableViewCell
@end

@interface CKDetailsChatOptionsCell : UITableViewCell
@end

@interface CKBackgroundDecorationView : UICollectionReusableView
@end

@interface CKRecipientSelectionView : UIView
- (void)updateRecipientBackground;
@end

@interface CKComposeRecipientView : UIView
@end

@interface UITableViewLabel : UILabel
@end

@interface CKQuickActionSaveButton : UIView
@end

@interface UIButtonLabel : UILabel
@end

@interface _UIPlatterClippingView : UIView
@end

@interface _UIPlatterTransformView : UIView
@end

@interface _UISystemBackgroundView : UIView
@end

@interface CKTranscriptReportSpamCell : UIView
- (void)colorReportJunkButton:(UIView *)view withColor:(UIColor *)color;
@end

@interface CKThumbsUpAcknowledgmentGlyphView : UIView
@end

@interface CKAggregateAcknowledgementBalloonView : UIView
- (void)applyGlyphTintRecursively:(UIView *)view;
@end

@interface CKAcknowledgmentGlyphImageView : UIView
@property (nonatomic, strong) UIColor *tintColor;
- (void)setImage:(UIImage *)image;
@end

@interface CKTranscriptUnavailabilityIndicatorCell : UICollectionViewCell
- (void)applyColorToUnavailabilityIndicator:(UIView *)view withColor:(UIColor *)color;
- (void)applyColorToUnavailabilityIndicator:(UIView *)view withColor:(UIColor *)color;
@end

@interface CKSendMenuPresentationPopoverBackdropView : UIView
@end

@interface CKSearchCollectionView : UICollectionView
@end

@interface UINavigationButton : UIView
@end

@interface _UINavigationBarLargeTitleView : UIView
@end

@interface UIViewControllerWrapperView : UIView
@end

@interface CKTranscriptNotifyAnywayButtonCell : UICollectionViewCell
@end

@interface CKEntryViewBlurrableButtonContainer : UIView
@end

@interface LPFlippedView : UIView
@end

@interface LPTextView : UIView
@end

@interface LPImageView : UIView
@end

@interface CKDetailsSearchResultsTitleHeaderCell : UIView
@end

@interface CKSearchResultsTitleHeaderCell : UIView
@end

@interface CKAvatarTitleCollectionReusableView : UIView
@end

@interface CKMessageAcknowledgmentPickerBarView: UIView
@end

@interface CKPinnedConversationSummaryBubble : UIView
@end

@interface CNContactView : UIView
@end

@interface UITableViewWrapperView : UIView
@end

@interface CNContactHeaderDisplayView : UIView
@end

@interface CNContactActionsContainerView : UIView
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

BOOL isMessageBarButtonsEnabled() {
    NSDictionary *prefs = loadPrefs();
    return prefs[@"isMessageBarButtonsEnabled"] ? [prefs[@"isMessageBarButtonsEnabled"] boolValue] : NO;
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

/*
static void logToFile(NSString *message) {
    FILE *logFile = fopen("/var/jb/var/mobile/whatamess_debug.log", "a");
    if (logFile) {
        fprintf(logFile, "%s\n", [message UTF8String]);
        fclose(logFile);
    }
}
*/


static UIColor *getSMSSentBubbleColor() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"sentSMSBubbleColor"];
    
    if (!hexColor) {
        return [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
    }
    
    UIColor *color = colorFromHex(hexColor);
    return color;
}

static UIColor *getSentBubbleColor() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"sentBubbleColor"];
    
    if (!hexColor) {
        return [UIColor colorWithRed:0.0 green:0.478 blue:1.0 alpha:1.0];
    }
    
    UIColor *color = colorFromHex(hexColor);
    return color;
}

static UIColor *getReceivedBubbleColor() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"receivedBubbleColor"];
    
    if (!hexColor) {
        return [UIColor colorWithRed:0.9 green:0.9 blue:0.9 alpha:1.0];
    }
    
    UIColor *color = colorFromHex(hexColor);
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

static UIColor *getMessageBarButtonColor() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"messageBarButtonColor"];
    
    if (!hexColor) {
        return nil;
    }
    
    return colorFromHex(hexColor);
}

static UIColor *getLinkPreviewBackgroundColor() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"linkPreviewBackgroundColor"];
    
    if (!hexColor) {
        return [UIColor colorWithRed:0.1 green:0.1 blue:0.1 alpha:1.0]; // Default dark gray
    }
    
    return colorFromHex(hexColor);
}

static UIColor *getLinkPreviewTextColor() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"linkPreviewTextColor"];
    
    if (!hexColor) {
        return [UIColor whiteColor]; // Default white
    }
    
    return colorFromHex(hexColor);
}

static UIColor *getPinnedBubbleColor() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"pinnedBubbleColor"];
    
    if (!hexColor || [hexColor length] == 0) {
        return getReceivedBubbleColor();
    }
    
    return colorFromHex(hexColor);
}

static UIColor *getPinnedBubbleTextColor() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"pinnedBubbleTextColor"];
    
    if (!hexColor || [hexColor length] == 0) {
        return getReceivedTextColor();
    }
    
    return colorFromHex(hexColor);
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
        // If this is an imageView with a chevron, exclude it
        if ([self isKindOfClass:[UIImageView class]]) {
            UIImageView *imageView = (UIImageView *)self;
            
            // Exclude swipe action icons FIRST
            if (imageView.image) {
                NSString *description = [imageView.image description];
                if ([description containsString:@"trash.fill"] ||
                    [description containsString:@"bell.slash.fill"] ||
                    [description containsString:@"checkmark.message.fill"] ||
                    [description containsString:@"message.badge.fill"]) {
                    return %orig; // Let system handle swipe action colors
                }
            }
            
            CGSize imageSize = imageView.image.size;
            
            // Chevrons are typically taller than wide and positioned on the right
            // Also check if we're in a conversation cell
            UIView *parent = self.superview;
            BOOL isInConvCell = NO;
            int levels = 0;
            
            while (parent && levels < 7) {
                if ([parent isKindOfClass:%c(CKConversationListCollectionViewConversationCell)]) {
                    isInConvCell = YES;
                    break;
                }
                parent = parent.superview;
                levels++;
            }
            
            // If in conv cell and looks like a chevron (taller than wide), use original
            if (isInConvCell && imageSize.height > imageSize.width && imageSize.width < 15) {
                return %orig;
            }
        }
        
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

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        return;
    }
    
    // Check if this is the background view inside the reaction picker
    if ([self class] == [UIView class] && 
        [self.superview isKindOfClass:%c(CKMessageAcknowledgmentPickerBarView)]) {
        UIColor *customColor = getReceivedBubbleColor();
        if (customColor) {
            self.backgroundColor = customColor;
            return;
        }
    }
    
    // Only apply to plain UIView (not subclasses like UIImageView or UIButton)
    if ([self class] == [UIView class] && [self.superview isKindOfClass:%c(CKQuickActionSaveButton)]) {
        UIColor *receivedColor = getReceivedBubbleColor();
        if (receivedColor) {
            self.backgroundColor = receivedColor;
        }
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        %orig;
        return;
    }
    
    // Check if this is the background view inside the reaction picker
    if ([self class] == [UIView class] && 
        [self.superview isKindOfClass:%c(CKMessageAcknowledgmentPickerBarView)]) {
        UIColor *customColor = getReceivedBubbleColor();
        if (customColor) {
            %orig(customColor);
            return;
        }
    }
    
    // Only apply to plain UIView (not subclasses like UIImageView or UIButton)
    if ([self class] == [UIView class] && [self.superview isKindOfClass:%c(CKQuickActionSaveButton)]) {
        UIColor *receivedColor = getReceivedBubbleColor();
        if (receivedColor) {
            %orig(receivedColor);
            return;
        }
    }
    
    %orig;
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
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            // CKTranscriptStatusCell labels use system tint (Edited, GIPHY, etc.)
            UIColor *customTint = getSystemTintColor();
            if (customTint) {
                %orig(customTint);
                return;
            }
            break;
        }
        
        if ([parent isKindOfClass:%c(CKTranscriptLabelCell)]) {
            // CKTranscriptLabelCell labels use timestamp color (Today, dates, etc.)
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
    
    // Check for "Edited" label in iOS 17 (UILabel inside _UISystemBackgroundView)
    if ([self.text isEqualToString:@"Edited"] && [self.superview isKindOfClass:%c(_UISystemBackgroundView)]) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            %orig(customTint);
            return;
        }
    }
    
    // Check for "Edited" label in sent messages (walks up parent hierarchy)
    if ([self.text isEqualToString:@"Edited"]) {
        UIView *parent = self.superview;
        BOOL isInStatusCell = NO;
        int levels = 0;
        
        while (parent && levels < 7) {
            if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
                isInStatusCell = YES;
                break;
            }
            parent = parent.superview;
            levels++;
        }
        
        if (isInStatusCell) {
            UIColor *customTint = getSystemTintColor();
            if (customTint) {
                %orig(customTint);
                return;
            }
        }
    }
    
    %orig;
}

- (void)setText:(NSString *)text {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Handle labels in CKTranscriptStatusCell
    UIView *parent = self.superview;
    BOOL isInStatusCell = NO;
    int levels = 0;
    
    while (parent && levels < 7) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            isInStatusCell = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInStatusCell) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            // If it has attributed text, color the entire string
            if (self.attributedText) {
                NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];
                [attrString addAttribute:NSForegroundColorAttributeName 
                                   value:customTint 
                                   range:NSMakeRange(0, attrString.length)];
                self.attributedText = attrString;
            } else {
                self.textColor = customTint;
            }
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !self.window) {
        return;
    }
    
    // Handle labels in CKTranscriptStatusCell
    UIView *parent = self.superview;
    BOOL isInStatusCell = NO;
    int levels = 0;
    
    while (parent && levels < 7) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            isInStatusCell = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInStatusCell) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            // If it has attributed text, color the entire string
            if (self.attributedText) {
                NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];
                [attrString addAttribute:NSForegroundColorAttributeName 
                                   value:customTint 
                                   range:NSMakeRange(0, attrString.length)];
                self.attributedText = attrString;
            } else {
                self.textColor = customTint;
            }
        }
    }
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Handle labels in CKTranscriptStatusCell
    UIView *parent = self.superview;
    BOOL isInStatusCell = NO;
    int levels = 0;
    
    while (parent && levels < 7) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            isInStatusCell = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInStatusCell) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            // If it has attributed text, color the entire string
            if (self.attributedText) {
                NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithAttributedString:self.attributedText];
                [attrString addAttribute:NSForegroundColorAttributeName 
                                   value:customTint 
                                   range:NSMakeRange(0, attrString.length)];
                self.attributedText = attrString;
            } else {
                self.textColor = customTint;
            }
        }
    }
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
    BOOL isInIndicatorCell = NO;
    int levels = 0;
    
    while (parent && levels < 10) {
        if (levels < 5 && [parent isKindOfClass:%c(CKConversationListEmbeddedStandardTableViewCell)]) {
            isUnreadIndicator = YES;
        }
        
        if ([parent isKindOfClass:%c(CKTranscriptUnavailabilityIndicatorCell)]) {
            isInIndicatorCell = YES;
            break;
        }
        
        parent = parent.superview;
        levels++;
    }
    
    if (isUnreadIndicator) {
        CGSize imageSize = image.size;
        if (imageSize.width < 20 && imageSize.height < 20) {
            UIColor *customTint = getSystemTintColor();
            if (customTint) {
                UIImage *tintedImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                %orig(tintedImage);
                self.tintColor = customTint;
            }
        }
        return;
    }
    
    if (isInIndicatorCell) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            UIColor *indicatorColor = [customTint colorWithAlphaComponent:0.75];
            
            UIImage *templateImage = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            self.image = templateImage;
            self.tintColor = indicatorColor;
        }
    }
}

%end

/* Hooks the navigation bar background and removes any defualt blurs. Creates a new blur effect and expands
it to provide more room for gradient. Gradient mask allows blur to fade smoothly from opaque to transparent,
top to bottom. */
%hook _UIBarBackground

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !isModernNavBarEnabled()) {
        return;
    }
    
    if (self.window) {
        [self ensureBlurExists];
    }
}

- (void)layoutSubviews {
    %orig;

    if (!isTweakEnabled() || !isModernNavBarEnabled()) {
        return;
    }

    // Check if CNContactView is visible in our window
    BOOL hasContactView = NO;
    if (self.window) {
        hasContactView = [self findContactViewInWindow:self.window];
    }
    
    // Always clean up system views first
    [self removeSystemViews];
    
    // Find our blur view
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
        // We have our blur, update its frame
        CGRect blurFrame = self.bounds;
        blurFrame.size.height += 70;
        
        if (hasContactView) {
            // Move off-screen if contact view exists
            blurFrame.origin.y = 1000;
        } else {
            // Normal position
            blurFrame.origin.y = 0;
        }
        
        ourBlur.frame = blurFrame;
        
        // ALWAYS update mask - CRITICAL: disable implicit animations
        [CATransaction begin];
        [CATransaction setDisableActions:YES];
        
        CAGradientLayer *maskLayer = (CAGradientLayer *)ourBlur.layer.mask;
        maskLayer.frame = ourBlur.bounds;
        
        [CATransaction commit];
    } else {
        // Blur is missing, create it
        [self createOurBlur];
    }
    
    self.backgroundColor = [UIColor clearColor];
}

// Block system from adding its own views
- (void)addSubview:(UIView *)view {
    if (!isTweakEnabled() || !isModernNavBarEnabled()) {
        %orig;
        return;
    }
    
    // Check if we already have our blur
    BOOL hasOurBlur = NO;
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]]) {
            if ([sub.layer.mask isKindOfClass:[CAGradientLayer class]]) {
                hasOurBlur = YES;
                break;
            }
        }
    }
    
    // If we have our blur and iOS is trying to add a system blur/image, block it
    if (hasOurBlur && ([view isKindOfClass:[UIVisualEffectView class]] || [view isKindOfClass:[UIImageView class]])) {
        return;
    }
    
    %orig;
}

%new
- (BOOL)findContactViewInWindow:(UIView *)view {
    if ([view isKindOfClass:NSClassFromString(@"CNContactView")]) {
        return YES;
    }
    for (UIView *subview in view.subviews) {
        if ([self findContactViewInWindow:subview]) {
            return YES;
        }
    }
    return NO;
}

%new
- (void)removeSystemViews {
    // Remove any system blur/image views that don't have our gradient mask
    NSMutableArray *viewsToRemove = [NSMutableArray array];
    
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]]) {
            UIVisualEffectView *blurView = (UIVisualEffectView *)sub;
            // If it doesn't have our gradient mask, it's a system blur
            if (![blurView.layer.mask isKindOfClass:[CAGradientLayer class]]) {
                [viewsToRemove addObject:sub];
            }
        } else if ([sub isKindOfClass:[UIImageView class]]) {
            // Remove system image backgrounds
            [viewsToRemove addObject:sub];
        }
    }
    
    for (UIView *view in viewsToRemove) {
        [view removeFromSuperview];
    }
}

%new
- (void)ensureBlurExists {
    [self removeSystemViews];
    
    // Check if we already have our blur
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]]) {
            if ([sub.layer.mask isKindOfClass:[CAGradientLayer class]]) {
                // Already have our blur
                return;
            }
        }
    }
    
    // Create our blur
    [self createOurBlur];
}

%new
- (void)createOurBlur {
    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];

    CGRect blurFrame = self.bounds;
    blurFrame.size.height += 70;
    blurView.frame = blurFrame;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self insertSubview:blurView atIndex:0];

    // Create gradient mask WITHOUT animations
    [CATransaction begin];
    [CATransaction setDisableActions:YES];
    
    CAGradientLayer *maskLayer = [CAGradientLayer layer];
    maskLayer.frame = blurView.bounds;
    maskLayer.colors = @[
        (id)[UIColor colorWithWhite:0 alpha:1.0].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0.9].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0.55].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0.10].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0.0].CGColor
    ];
    maskLayer.locations = @[@0.0, @0.3, @0.6, @0.85, @1.0];
    
    // CRITICAL: Prevent any implicit animations on the mask
    maskLayer.actions = @{
        @"position": [NSNull null],
        @"bounds": [NSNull null],
        @"frame": [NSNull null]
    };
    
    blurView.layer.mask = maskLayer;
    
    [CATransaction commit];
}

%end

/* Targets NavBar Title, only modifying the label titled "Messages" to avoid modifying other name views
across messages app. Replaces the title with a custom user string and sets a custom color. */
%hook _UINavigationBarTitleControl

- (void)layoutSubviews {
    %orig;

    if (!isTweakEnabled()) return;

    // Get the custom conversation list title
    NSString *conversationListTitle = getConversationListTitle();
    
    // Check direct subviews
    for (UIView *sub in self.subviews) {
        // Check if it's a UILabel directly
        if ([sub isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)sub;
            
            // Handle conversation list title specifically (either "Messages" or custom title)
            if ([label.text isEqualToString:@"Messages"] || [label.text isEqualToString:conversationListTitle]) {
                label.text = conversationListTitle;
                label.textColor = getConversationListTitleColor();
            }
            // Apply contact title color to everything else
            else if (isCustomTextColorsEnabled()) {
                label.textColor = getTitleTextColor();
            }
        }
        
        // iOS 17: Check if it's a UIView container with a UILabel inside
        if ([sub isKindOfClass:[UIView class]]) {
            for (UIView *subview in sub.subviews) {
                if ([subview isKindOfClass:[UILabel class]]) {
                    UILabel *label = (UILabel *)subview;
                    
                    // Handle conversation list title specifically (either "Messages" or custom title)
                    if ([label.text isEqualToString:@"Messages"] || [label.text isEqualToString:conversationListTitle]) {
                        label.text = conversationListTitle;
                        label.textColor = getConversationListTitleColor();
                    }
                    // Apply contact title color to everything else
                    else if (isCustomTextColorsEnabled()) {
                        label.textColor = getTitleTextColor();
                    }
                }
            }
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

- (void)didMoveToWindow {
    %orig;

    if (!isTweakEnabled()) return;

    // Hide/show the glow images
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

- (void)layoutSubviews {
    %orig;

    if (!isTweakEnabled() || !isModernMessageBarEnabled()) return;
    if (self.frame.size.width <= 0 || self.frame.size.height <= 0) return;

    // Check if this gradient is inside a reaction bubble
    BOOL isReaction = [self.superview isKindOfClass:objc_getClass("CKAggregateAcknowledgmentBalloonView")];
    if (isReaction) {
        self.hidden = YES; // Hide reaction bubble entirely
        return;
    }

    // Otherwise, normal bubble -> choose user-defined color
    UIColor *bubbleColor = getSentBubbleColor(); // default to sent bubble
    UIView *parent = self.superview;
    while (parent) {
        if ([parent isKindOfClass:objc_getClass("CKColoredBalloonView")]) {
            CKColoredBalloonView *balloon = (CKColoredBalloonView *)parent;
            if (balloon.color == -1) {
                bubbleColor = getReceivedBubbleColor();
            } else if (balloon.color == 1) {
                bubbleColor = getSentBubbleColor();
            } else if (balloon.color == 0) {
                bubbleColor = getSMSSentBubbleColor();
            }
            break;
        }
        parent = parent.superview;
    }

    [self setColors:@[bubbleColor, bubbleColor]]; // Solid color
}

- (void)setColors:(NSArray *)colors {
    if (!isTweakEnabled() || !isModernMessageBarEnabled()) {
        %orig;
        return;
    }

    BOOL isReaction = [self.superview isKindOfClass:objc_getClass("CKAggregateAcknowledgmentBalloonView")];
    if (isReaction) {
        self.hidden = YES; // hide reactions
        return;
    }

    // Force normal bubbles to user-defined color
    UIColor *bubbleColor = getSentBubbleColor();
    UIView *parent = self.superview;
    while (parent) {
        if ([parent isKindOfClass:objc_getClass("CKColoredBalloonView")]) {
            CKColoredBalloonView *balloon = (CKColoredBalloonView *)parent;
            if (balloon.color == -1) {
                bubbleColor = getReceivedBubbleColor();
            } else if (balloon.color == 1) {
                bubbleColor = getSentBubbleColor();
            } else if (balloon.color == 0) {
                bubbleColor = getSMSSentBubbleColor();
            }
            break;
        }
        parent = parent.superview;
    }

    %orig(@[bubbleColor, bubbleColor]);
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

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !self.window) {
        return;
    }
    
    [self updateTextColorForBalloon];
}

- (void)setTextColor:(UIColor *)textColor {
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        %orig;
        return;
    }
    
    // Check if we're currently updating to prevent recursion
    NSNumber *isUpdating = objc_getAssociatedObject(self, @selector(setTextColor:));
    if (isUpdating && [isUpdating boolValue]) {
        %orig;
        return;
    }
    
    // Get the appropriate color for this balloon
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
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        %orig;
        return;
    }
    
    // Check if we're currently updating to prevent recursion
    NSNumber *isUpdating = objc_getAssociatedObject(self, @selector(setTintColor:));
    if (isUpdating && [isUpdating boolValue]) {
        %orig;
        return;
    }
    
    // Get the appropriate color for this balloon
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
    // Check if this is inside a reply balloon
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
    
    // Search for CKColoredBalloonView
    parent = self.superview;
    levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKColoredBalloonView)]) {
            CKColoredBalloonView *balloonView = (CKColoredBalloonView *)parent;
            
            if (balloonView.color == -1) {
                return getReceivedTextColor();
            } else if (balloonView.color == 1) {
                return getSentTextColor();
            } else if (balloonView.color == 0) {
                return getSMSSentTextColor();
            }
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
        
        // Set link text attributes to match the text color
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
        if ([parent isKindOfClass:%c(UIKBVisualEffectView)] || 
            [parent isKindOfClass:%c(UIInputView)] ||
            [NSStringFromClass([parent class]) containsString:@"Keyboard"]) {
            isInKeyboard = YES;
            break;
        }
        if ([parent isKindOfClass:%c(CKMessageEntryView)]) {
            isInMessageInput = YES;
        }
        if ([parent isKindOfClass:%c(CKSearchResultsTitleHeaderCell)]) {
            self.hidden = YES;
        }
        parent = parent.superview;
        levels++;
    }
    
    // Check if we're in CNActionView inside CNContactView
    parent = self.superview;
    BOOL isInActionView = NO;
    BOOL isInContactView = NO;
    levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:NSClassFromString(@"CNActionView")]) {
            isInActionView = YES;
        }
        if ([parent isKindOfClass:NSClassFromString(@"CNContactView")]) {
            isInContactView = YES;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInActionView && isInContactView) {
        self.hidden = YES;
        return;
    }
    
    if (!isInMessageInput || isInKeyboard || !effectView) {
        return;
    }

    // PREVENT BLACK FLASH
    effectView.backgroundColor = [UIColor clearColor];
    effectView.contentView.backgroundColor = [UIColor clearColor];
    effectView.opaque = NO;

    self.backgroundColor = [UIColor clearColor];
    self.opaque = NO;

    // FORCE EFFECT TO EXIST BEFORE FIRST DRAW
    if (!effectView.effect) {
        effectView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    }

    // DISABLE IMPLICIT ANIMATIONS (FRAME EXPANSION)
    [CATransaction begin];
    [CATransaction setDisableActions:YES];

    // Expand the effect view frame upward by 55 points
    CGRect expandedFrame = effectView.frame;
    expandedFrame.origin.y -= 70;
    expandedFrame.size.height += 70;
    effectView.frame = expandedFrame;

    [CATransaction commit];

    self.alpha = 1.0;
    
    // Apply gradient mask
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
}

- (void)willMoveToSuperview:(UIView *)newSuperview {
    %orig;

    if (!newSuperview) return;
    if (!isTweakEnabled() || !isModernMessageBarEnabled()) return;

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

        if ([parent isKindOfClass:%c(CKMessageEntryView)]) {
            isInMessageInput = YES;
        }

        parent = parent.superview;
        levels++;
    }

    if (!isInMessageInput || isInKeyboard || !effectView) return;

    effectView.opaque = NO;
    effectView.backgroundColor = [UIColor clearColor];
    effectView.contentView.backgroundColor = [UIColor clearColor];

    if (!effectView.effect) {
        effectView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled() || !isModernMessageBarEnabled()) {
        %orig;
        return;
    }
    
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
        if ([className isEqualToString:@"CKMessageEntryView"]) {
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

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled() || !isModernMessageBarEnabled()) {
        %orig;
        return;
    }
    
    // Check parent hierarchy
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
        if ([className isEqualToString:@"CKMessageEntryView"]) {
            isInMessageInput = YES;
        }
		if ([className isEqualToString:@"_UIBarBackground"]) {
			self.alpha = 0.0;
		}
        parent = parent.superview;
        levels++;
    }
    
    if (isInMessageInput && !isInKeyboard) {
        // Always force clear color, regardless of what iOS is trying to set
        %orig([UIColor clearColor]);
        return;
    }
    
    %orig;
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isModernMessageBarEnabled()) {
        return;
    }
    
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
        if ([className isEqualToString:@"CKMessageEntryView"]) {
            isInMessageInput = YES;
        }
		if ([className isEqualToString:@"_UIBarBackground"]) {
			self.alpha = 0.0;
		}
        parent = parent.superview;
        levels++;
    }
    
    if (isInMessageInput && !isInKeyboard) {
        self.backgroundColor = [UIColor clearColor];
    }
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !isModernMessageBarEnabled()) {
        return;
    }
    
    // Check parent hierarchy
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
        if ([className isEqualToString:@"CKMessageEntryView"]) {
            isInMessageInput = YES;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInMessageInput && !isInKeyboard) {
        self.backgroundColor = [UIColor clearColor];
    }
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
    UIColor *buttonColor = getMessageBarButtonColor();
    BOOL customizeOtherButtons = isMessageBarButtonsEnabled();
    
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            UIVisualEffectView *effectView = (UIVisualEffectView *)subview;
            
            for (UIView *contentSubview in effectView.contentView.subviews) {
                if ([contentSubview isKindOfClass:[UIButton class]]) {
                    UIButton *button = (UIButton *)contentSubview;
                    
                    // Look for UIImageViews inside the button
                    for (UIView *btnSubview in [button.subviews copy]) {
                        if ([btnSubview isKindOfClass:[UIImageView class]]) {
                            UIImageView *imageView = (UIImageView *)btnSubview;
                            CGSize frameSize = imageView.frame.size;
                            
                            // Send button arrow (27.3 x 27.3)
                            if (frameSize.width > 27 && frameSize.width < 28 && 
                                frameSize.height > 27 && frameSize.height < 28) {
                                if (!customTint) continue;
                                
                                // Set background to custom color
                                button.backgroundColor = customTint;
                                button.layer.cornerRadius = button.bounds.size.width / 2;
                                button.clipsToBounds = YES;
                                
                                // Remove this imageView
                                [imageView removeFromSuperview];
                                
                                // Create arrow overlay
                                UIImage *arrowImage = [UIImage systemImageNamed:@"arrow.up"];
                                if (arrowImage) {
                                    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold];
                                    arrowImage = [arrowImage imageWithConfiguration:config];
                                    arrowImage = [arrowImage imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
                                    
                                    UIImageView *arrowOverlay = [[UIImageView alloc] initWithImage:arrowImage];
                                    arrowOverlay.userInteractionEnabled = NO;
                                    
                                    CGSize buttonSize = button.bounds.size;
                                    CGSize arrowSize = arrowOverlay.bounds.size;
                                    arrowOverlay.frame = CGRectMake((buttonSize.width - arrowSize.width) / 2,
                                                                   (buttonSize.height - arrowSize.height) / 2,
                                                                   arrowSize.width,
                                                                   arrowSize.height);
                                    
                                    [button addSubview:arrowOverlay];
                                }
                            }
                            // Camera button (36 x 36) or App drawer button (41 x 32)
                            else if (customizeOtherButtons && buttonColor &&
                                     ((frameSize.width > 35 && frameSize.width < 37 && frameSize.height > 35 && frameSize.height < 37) ||
                                      (frameSize.width > 40 && frameSize.width < 42 && frameSize.height > 31 && frameSize.height < 33))) {
                                
                                // Get the original image and frame
                                UIImage *originalImage = imageView.image;
                                CGRect originalFrame = imageView.frame;
                                
                                if (!originalImage) continue;
                                
                                // Create colored version of the image
                                UIImage *coloredImage = [originalImage imageWithTintColor:buttonColor renderingMode:UIImageRenderingModeAlwaysOriginal];
                                
                                // Create a COMPLETELY NEW imageView with the colored image
                                UIImageView *newImageView = [[UIImageView alloc] initWithImage:coloredImage];
                                newImageView.contentMode = imageView.contentMode;
                                newImageView.userInteractionEnabled = NO;
                                
                                // Remove old imageView
                                [imageView removeFromSuperview];
                                
                                // Convert frame to self (CKEntryViewButton) coordinate system
                                CGRect frameInButton = originalFrame;
                                CGRect frameInEffectContent = [button convertRect:frameInButton toView:effectView.contentView];
                                CGRect frameInEffect = [effectView.contentView convertRect:frameInEffectContent toView:effectView];
                                CGRect frameInSelf = [effectView convertRect:frameInEffect toView:self];
                                
                                newImageView.frame = frameInSelf;
                                
                                // Add the NEW imageView directly to CKEntryViewButton
                                [self addSubview:newImageView];
                                
                            }
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
    
    [self setNeedsLayout];
    [self layoutIfNeeded];
}
%end

%hook CKDetailsTableView

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Apply the same background logic as chat view
    BOOL hasChatImage = [[NSFileManager defaultManager] fileExistsAtPath:kChatImagePath];
    UIImage *chatBgImage = hasChatImage ? [UIImage imageWithContentsOfFile:kChatImagePath] : nil;
    
    if (isChatColorBgEnabled()) {
        self.backgroundColor = getChatBackgroundColor();
    }
    else if (chatBgImage && isChatImageBgEnabled()) {
        CGFloat blurAmount = getChatImageBlurAmount();
        if (blurAmount > 0) {
            chatBgImage = blurImage(chatBgImage, blurAmount);
        }
        
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        imageView.image = chatBgImage;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.backgroundView = imageView;
    }
    
    // Listen for preference changes
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(updateDetailsBackground)
        name:kPrefsChangedNotification
        object:nil];
}

%end

%hook CKSearchCollectionView
- (void)didMoveToWindow {
    %orig;

    if (!isTweakEnabled()) {
        return;
    }

    // Check if we're in CKDetailsTableView
    UIView *parent = self.superview;
    BOOL isInDetailsView = NO;
    int levels = 0;

    while (parent && levels < 15) {
        if ([parent isKindOfClass:%c(CKDetailsTableView)]) {
            isInDetailsView = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }

    if (isInDetailsView) {
        self.backgroundColor = [UIColor clearColor];
        return;
    }

    // Apply conversation list background for main search view
    if (isConvColorBgEnabled()) {
        UIColor *bgColor = getBackgroundColor();
        if (bgColor) {
            self.backgroundColor = bgColor;
            self.backgroundView = nil; // Remove any image background
        }
    } else {
        // Apply image background from file path
        BOOL hasImage = [[NSFileManager defaultManager] fileExistsAtPath:kImagePath];
        UIImage *bgImage = hasImage ? [UIImage imageWithContentsOfFile:kImagePath] : nil;
        
        if (bgImage) {
            CGFloat blurAmount = getImageBlurAmount();
            if (blurAmount > 0) {
                bgImage = blurImage(bgImage, blurAmount);
            }
            
            UIImageView *imageView = [[UIImageView alloc] initWithImage:bgImage];
            imageView.contentMode = UIViewContentModeScaleAspectFill;
            imageView.clipsToBounds = YES;
            imageView.frame = self.bounds;
            imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            
            self.backgroundView = imageView;
            self.backgroundColor = [UIColor clearColor];
        }
    }
}
%end

/* Hook for table header/footer content view - make transparent */
%hook _UITableViewHeaderFooterContentView

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Check if we're in the details view
    UIView *parent = self.superview;
    BOOL isInDetailsView = NO;
    int levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKDetailsTableView)]) {
            isInDetailsView = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInDetailsView) {
        self.backgroundColor = [UIColor clearColor];
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled()) {
        %orig;
        return;
    }
    
    // Check if we're in the details view
    UIView *parent = self.superview;
    BOOL isInDetailsView = NO;
    int levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKDetailsTableView)]) {
            isInDetailsView = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInDetailsView) {
        %orig([UIColor clearColor]);
        return;
    }
    
    %orig;
}

%end

/* Hook for contact header container view - make transparent */
%hook CNGroupIdentityHeaderContainerView

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    self.backgroundColor = [UIColor clearColor];

	if (isCustomTextColorsEnabled()) {
        [self applyContactNameColor];
    }
}

%new
- (void)applyContactNameColor {

	    UIColor *titleColor = getTitleTextColor();
    if (!titleColor) {
        return;
    }
    
    // Navigate through the stack view hierarchy to find the label
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIStackView class]]) {
            UIStackView *outerStack = (UIStackView *)subview;
            
            for (UIView *innerView in outerStack.arrangedSubviews) {
                if ([innerView isKindOfClass:[UIStackView class]]) {
                    UIStackView *innerStack = (UIStackView *)innerView;
                    
                    for (UIView *stackItem in innerStack.arrangedSubviews) {
                        if ([stackItem isKindOfClass:[UILabel class]]) {
                            UILabel *label = (UILabel *)stackItem;
                            label.textColor = titleColor;
                        }
                    }
                }
            }
        }
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled()) {
        %orig;
        return;
    }
    
    %orig([UIColor clearColor]);

}

%end

%hook CKGroupPhotoCell

- (void) didMoveToWindow {
	%orig;

	if (!isTweakEnabled()) {
		return;
	}

	self.backgroundColor = [UIColor clearColor];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled()) {
        %orig;
        return;
    }
    
    %orig([UIColor clearColor]);
}

%end

/* Hook for CNActionView - apply thinner blur */
%hook CNActionView

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Remove any existing blur views WE added
    for (UIView *subview in [self.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 12345) {
            [subview removeFromSuperview];
        }
    }
    
    // Create and add thinner blur effect
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = self.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.layer.cornerRadius = self.layer.cornerRadius;
    blurView.clipsToBounds = YES;
    blurView.userInteractionEnabled = NO;
    blurView.tag = 12345;
    
    [self insertSubview:blurView atIndex:0];
    self.backgroundColor = [UIColor clearColor];
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Update blur view frame
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]] && subview.tag == 12345) {
            subview.frame = self.bounds;
            subview.layer.cornerRadius = self.layer.cornerRadius;
            break;
        }
    }
    
    [self updateIconOpacity];
}

%new
- (void)updateIconOpacity {
    // Check if disabled
    BOOL isDisabled = NO;
    @try {
        id disabled = [self valueForKey:@"disabled"];
        if (disabled) {
            isDisabled = [disabled boolValue];
        }
    } @catch (NSException *e) {
        isDisabled = !self.userInteractionEnabled;
    }
    
    // Find and update icon
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

%end

/* Hook for CKTranscriptDetailsResizableCell - apply thinner blur */
%hook CKTranscriptDetailsResizableCell

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Remove any existing blur views from contentView
    for (UIView *subview in [self.contentView.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            [subview removeFromSuperview];
        }
    }
    
    // Create and add thinner blur effect
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = self.contentView.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.layer.cornerRadius = self.contentView.layer.cornerRadius;
    blurView.clipsToBounds = YES;
    
    [self.contentView insertSubview:blurView atIndex:0];
    self.contentView.backgroundColor = [UIColor clearColor];
    self.backgroundColor = [UIColor clearColor];
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Update blur view frame if it exists
    for (UIView *subview in self.contentView.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            subview.frame = self.contentView.bounds;
            subview.layer.cornerRadius = self.contentView.layer.cornerRadius;
            break;
        }
    }
}

%end

/* Hook for CKDetailsSharedWithYouCell - apply thinner blur, fixed to cover entire cell */
%hook CKDetailsSharedWithYouCell

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Remove any existing blur views - check both self and contentView
    for (UIView *subview in [self.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            [subview removeFromSuperview];
        }
    }
    for (UIView *subview in [self.contentView.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            [subview removeFromSuperview];
        }
    }
    
    // Create and add thinner blur effect to self (not contentView) to cover entire cell
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = self.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.layer.cornerRadius = self.layer.cornerRadius;
    blurView.clipsToBounds = YES;
    
    [self insertSubview:blurView atIndex:0];
    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Update blur view frame if it exists
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            subview.frame = self.bounds;
            subview.layer.cornerRadius = self.layer.cornerRadius;
            break;
        }
    }
}

%end

/* Hook for CKBackgroundDecorationView - apply thinner blur */
%hook CKBackgroundDecorationView

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Remove any existing blur views
    for (UIView *subview in [self.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            [subview removeFromSuperview];
        }
    }
    
    // Create and add thinner blur effect
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = self.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.layer.cornerRadius = self.layer.cornerRadius;
    blurView.clipsToBounds = YES;
    
    [self insertSubview:blurView atIndex:0];
    self.backgroundColor = [UIColor clearColor];
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Update blur view frame if it exists
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            subview.frame = self.bounds;
            subview.layer.cornerRadius = self.layer.cornerRadius;
            break;
        }
    }
}

%end

/* Hook for CKDetailsChatOptionsCell - apply thinner blur */
/* Hook for CKDetailsChatOptionsCell - apply thinner blur, fixed to cover entire cell */
%hook CKDetailsChatOptionsCell
- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Remove any existing blur views - check both self and contentView
    for (UIView *subview in [self.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            [subview removeFromSuperview];
        }
    }
    for (UIView *subview in [self.contentView.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            [subview removeFromSuperview];
        }
    }
    
    // Create and add thinner blur effect to self (not contentView) to cover entire cell
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = self.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    // Don't set corner radius on blur view - let cell's clipping handle it
    blurView.layer.cornerRadius = 0;
    blurView.clipsToBounds = NO;
    
    [self insertSubview:blurView atIndex:0];
    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];
    
    // Ensure the cell itself clips to its bounds with its corner radius
    self.clipsToBounds = YES;
}
- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Update blur view frame if it exists
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            subview.frame = self.bounds;
            // Keep corner radius at 0 so blur extends to edges
            subview.layer.cornerRadius = 0;
            break;
        }
    }
    
    // Make sure cell clips to its bounds
    self.clipsToBounds = YES;
}
%end

%hook CKRecipientSelectionView

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    [self updateRecipientBackground];
    
    // Listen for preference changes
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(updateRecipientBackground)
        name:kPrefsChangedNotification
        object:nil];
}

%new
- (void)updateRecipientBackground {
    clearPrefsCache();
    
    // Apply the same background logic as chat view
    BOOL hasChatImage = [[NSFileManager defaultManager] fileExistsAtPath:kChatImagePath];
    UIImage *chatBgImage = hasChatImage ? [UIImage imageWithContentsOfFile:kChatImagePath] : nil;
    
    // Remove any existing background image views
    for (UIView *subview in [self.subviews copy]) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            UIImageView *imgView = (UIImageView *)subview;
            // Check if it's a background image (large, positioned at origin)
            if (CGRectEqualToRect(imgView.frame, self.bounds) || (imgView.frame.origin.x == 0 && imgView.frame.origin.y == 0)) {
                [imgView removeFromSuperview];
            }
        }
    }
    
    if (isChatColorBgEnabled()) {
        self.backgroundColor = getChatBackgroundColor();
    }
    else if (chatBgImage && isChatImageBgEnabled()) {
        CGFloat blurAmount = getChatImageBlurAmount();
        if (blurAmount > 0) {
            chatBgImage = blurImage(chatBgImage, blurAmount);
        }
        
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
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Update background image frame if it exists
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

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    %orig;
}

%end

%hook CKComposeRecipientView

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    self.backgroundColor = [UIColor clearColor];
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled()) {
        %orig;
        return;
    }
    
    %orig([UIColor clearColor]);
}

%end

%hook UITableViewLabel

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (!customTint) {
        return;
    }
    
    // Don't change if text is red
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    if (self.textColor && [self.textColor getRed:&red green:&green blue:&blue alpha:&alpha]) {
        if (red > 0.7 && green < 0.3 && blue < 0.3) {
            return;
        }
    }
    
    self.textColor = customTint;
}

- (void)setTextColor:(UIColor *)color {
    if (!isTweakEnabled()) {
        %orig;
        return;
    }
    
    // Check if the incoming color is red
    CGFloat red = 0, green = 0, blue = 0, alpha = 0;
    if (color && [color getRed:&red green:&green blue:&blue alpha:&alpha]) {
        if (red > 0.7 && green < 0.3 && blue < 0.3) {
            %orig;
            return;
        }
    }
    
    UIColor *customTint = getSystemTintColor();
    if (customTint) {
        %orig(customTint);
        return;
    }
    
    %orig;
}
%end

%hook UISwitch

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (customTint) {
        self.onTintColor = customTint;
    }
}

- (void)setOn:(BOOL)on animated:(BOOL)animated {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (customTint) {
        self.onTintColor = customTint;
    }
}

%end

/* Hook for UIButtonLabel - apply custom tint color to "Edited" text */
%hook UIButtonLabel

- (void)setText:(NSString *)text {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Handle Report Junk button
    if ([text isEqualToString:@"Report Junk"]) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            self.textColor = customTint;
        }
        return;
    }
    
    // Existing CKTranscriptStatusCell logic
    UIView *parent = self.superview;
    BOOL isInStatusCell = NO;
    int levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            isInStatusCell = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInStatusCell) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            self.textColor = customTint;
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Handle Report Junk button
    if ([self.text isEqualToString:@"Report Junk"]) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            self.textColor = customTint;
        }
        return;
    }
    
    // Existing CKTranscriptStatusCell logic
    UIView *parent = self.superview;
    BOOL isInStatusCell = NO;
    int levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            isInStatusCell = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInStatusCell) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            self.textColor = customTint;
        }
    }
}

- (void)setTextColor:(UIColor *)color {
    if (!isTweakEnabled()) {
        %orig;
        return;
    }
    
    // Handle Report Junk button - force our color
    if ([self.text isEqualToString:@"Report Junk"]) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            %orig(customTint);
            return;
        }
    }
    
    // Existing CKTranscriptStatusCell logic
    UIView *parent = self.superview;
    BOOL isInStatusCell = NO;
    int levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            isInStatusCell = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInStatusCell) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            %orig(customTint);
            return;
        }
    }
    
    %orig;
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Handle Report Junk button
    if ([self.text isEqualToString:@"Report Junk"]) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            self.textColor = customTint;
        }
        return;
    }
    
    // Existing CKTranscriptStatusCell logic
    UIView *parent = self.superview;
    BOOL isInStatusCell = NO;
    int levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            isInStatusCell = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInStatusCell) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            self.textColor = customTint;
        }
    }
}

%end

%hook UIButton

- (void)setTintColor:(UIColor *)color {
    if (!isTweakEnabled()) {
        %orig;
        return;
    }
    
    // Check if we're in a CKTranscriptStatusCell
    UIView *parent = self.superview;
    BOOL isInStatusCell = NO;
    int levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            isInStatusCell = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInStatusCell) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            %orig(customTint);
            return;
        }
    }
    
    %orig;
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Check if we're in a CKTranscriptStatusCell
    UIView *parent = self.superview;
    BOOL isInStatusCell = NO;
    int levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            isInStatusCell = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInStatusCell) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            self.tintColor = customTint;
            
            // Also set the color on the button label directly
            for (UIView *subview in self.subviews) {
                if ([subview isKindOfClass:%c(UIButtonLabel)]) {
                    [(UILabel *)subview setTextColor:customTint];
                }
            }
        }
    }
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Check if we're in a CKTranscriptStatusCell
    UIView *parent = self.superview;
    BOOL isInStatusCell = NO;
    int levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(CKTranscriptStatusCell)]) {
            isInStatusCell = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInStatusCell) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            self.tintColor = customTint;
            
            // Also set the color on the button label directly
            for (UIView *subview in self.subviews) {
                if ([subview isKindOfClass:%c(UIButtonLabel)]) {
                    [(UILabel *)subview setTextColor:customTint];
                }
            }
        }
    }
}

%end

%hook CKAggregateAcknowledgementBalloonView

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (customTint) {
        self.tintColor = customTint;
        
        // Apply tint to all UIImageView subviews
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                subview.tintColor = customTint;
            }
        }
    }
    
    // Handle glyph coloring if custom bubble colors are enabled
    if (isCustomBubbleColorsEnabled()) {
        [self applyGlyphTintRecursively:self];
    }
}

- (void)setTintColor:(UIColor *)color {
    if (!isTweakEnabled()) {
        %orig;
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (customTint) {
        %orig(customTint);
        
        // Apply tint to all UIImageView subviews
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                subview.tintColor = customTint;
            }
        }
        
        // Handle glyph coloring if custom bubble colors are enabled
        if (isCustomBubbleColorsEnabled()) {
            [self applyGlyphTintRecursively:self];
        }
        return;
    }
    
    %orig;
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (customTint) {
        self.tintColor = customTint;
        
        // Apply tint to all UIImageView subviews
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                subview.tintColor = customTint;
            }
        }
    }
    
    // Handle glyph coloring if custom bubble colors are enabled
    if (isCustomBubbleColorsEnabled()) {
        [self applyGlyphTintRecursively:self];
    }
}

%new
- (void)applyGlyphTintRecursively:(UIView *)view {
    // Get lightened, desaturated system tint for glyphs
    UIColor *glyphTint = [UIColor colorWithWhite:0.85 alpha:1.0]; // fallback
    UIColor *customGlyphTint = getSystemTintColor();
    
    if (customGlyphTint) {
        CGFloat h, s, b, a;
        if ([customGlyphTint getHue:&h saturation:&s brightness:&b alpha:&a]) {
            s *= 0.2;              // desaturate to 30%
            b = MIN(1.0, b + 0.2); // lighten by 40%
            glyphTint = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
        }
    }
    
    // Apply to CKAcknowledgmentGlyphImageView
    if ([view isKindOfClass:%c(CKAcknowledgmentGlyphImageView)]) {
        view.tintColor = glyphTint;
        
        // Force template rendering via KVC
        UIImage *img = [view valueForKey:@"_image"];
        if (img && img.renderingMode != UIImageRenderingModeAlwaysTemplate) {
            img = [img imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            [view setValue:img forKey:@"_image"];
        }
    }
    
    // Also try CKThumbsUpAcknowledgmentGlyphView and similar
    NSString *className = NSStringFromClass([view class]);
    if ([className containsString:@"AcknowledgmentGlyphView"]) {
        view.tintColor = glyphTint;
    }
    
    // Recurse through all subviews
    for (UIView *subview in view.subviews) {
        [self applyGlyphTintRecursively:subview];
    }
}

%end

/* Hook for _UIPlatterClippingView - apply background to 3D touch previews */
%hook _UIPlatterClippingView

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Only apply if the view is large enough (full preview, not the small box)
    if (self.bounds.size.height < 200) {
        return;
    }
    
    // Apply the same background logic as chat view
    BOOL hasChatImage = [[NSFileManager defaultManager] fileExistsAtPath:kChatImagePath];
    UIImage *chatBgImage = hasChatImage ? [UIImage imageWithContentsOfFile:kChatImagePath] : nil;
    
    if (isChatColorBgEnabled()) {
        self.backgroundColor = getChatBackgroundColor();
    }
    else if (chatBgImage && isChatImageBgEnabled()) {
        CGFloat blurAmount = getChatImageBlurAmount();
        if (blurAmount > 0) {
            chatBgImage = blurImage(chatBgImage, blurAmount);
        }
        
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.bounds];
        imageView.image = chatBgImage;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self insertSubview:imageView atIndex:0];
        
        self.backgroundColor = [UIColor clearColor];
    }
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // If view is small (collapsed), remove any background images
    if (self.bounds.size.height < 200) {
        for (UIView *subview in [self.subviews copy]) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                UIImageView *imgView = (UIImageView *)subview;
                if (imgView.frame.origin.x == 0 && imgView.frame.origin.y == 0) {
                    [imgView removeFromSuperview];
                }
            }
        }
        self.backgroundColor = [UIColor clearColor];
        return;
    }
    
    // Check if we already have a background image
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
    
    // If no background image exists but we should have one, add it
    if (!hasBackgroundImage) {
        BOOL hasChatImage = [[NSFileManager defaultManager] fileExistsAtPath:kChatImagePath];
        UIImage *chatBgImage = hasChatImage ? [UIImage imageWithContentsOfFile:kChatImagePath] : nil;
        
        if (isChatColorBgEnabled()) {
            self.backgroundColor = getChatBackgroundColor();
        }
        else if (chatBgImage && isChatImageBgEnabled()) {
            CGFloat blurAmount = getChatImageBlurAmount();
            if (blurAmount > 0) {
                chatBgImage = blurImage(chatBgImage, blurAmount);
            }
            
            UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.bounds];
            imageView.image = chatBgImage;
            imageView.contentMode = UIViewContentModeScaleAspectFill;
            imageView.clipsToBounds = YES;
            imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self insertSubview:imageView atIndex:0];
            
            self.backgroundColor = [UIColor clearColor];
        }
    }
}

%end

%hook _UISystemBackgroundView

- (void)setConfiguration:(id)configuration {
    %orig(configuration);

    if (!isTweakEnabled()) return;

    // Hide ONLY the drawable UIView subview
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
    
    if (!isTweakEnabled()) {
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (!customTint) {
        return;
    }
    
    // Find and color the Report Junk button
    [self colorReportJunkButton:self withColor:customTint];
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !self.window) {
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (!customTint) {
        return;
    }
    
    // Find and color the Report Junk button
    [self colorReportJunkButton:self withColor:customTint];
}

%new
- (void)colorReportJunkButton:(UIView *)view withColor:(UIColor *)color {
    // Check if this view is a UIButtonLabel with "Report Junk" text
    if ([view isKindOfClass:%c(UIButtonLabel)]) {
        UILabel *label = (UILabel *)view;
        if ([label.text isEqualToString:@"Report Junk"]) {
            label.textColor = color;
        }
    }
    
    // Recursively check all subviews
    for (UIView *subview in view.subviews) {
        [self colorReportJunkButton:subview withColor:color];
    }
}

%end

%hook CKAcknowledgmentGlyphImageView

- (void)setImage:(UIImage *)image {
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !image) {
        %orig;
        return;
    }
    
    // Get lightened, desaturated system tint
    UIColor *glyphTint = [UIColor colorWithWhite:0.85 alpha:1.0];
    UIColor *customGlyphTint = getSystemTintColor();
    
    if (customGlyphTint) {
        CGFloat h, s, b, a;
        if ([customGlyphTint getHue:&h saturation:&s brightness:&b alpha:&a]) {
            s *= 0.3;
            b = MIN(1.0, b + 0.4);
            glyphTint = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
        }
    }
    
    // Create a tinted version of the image using Core Graphics
    UIGraphicsBeginImageContextWithOptions(image.size, NO, image.scale);
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    // Flip the context because Core Graphics uses a different coordinate system
    CGContextTranslateCTM(context, 0, image.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    // Draw the image
    CGRect rect = CGRectMake(0, 0, image.size.width, image.size.height);
    CGContextDrawImage(context, rect, image.CGImage);
    
    // Apply the tint color using blend mode
    CGContextSetBlendMode(context, kCGBlendModeSourceIn);
    [glyphTint setFill];
    CGContextFillRect(context, rect);
    
    UIImage *tintedImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    %orig(tintedImage);
}

- (void)didMoveToSuperview {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !self.superview) {
        return;
    }
    
    // Force image refresh
    UIImage *currentImage = [self valueForKey:@"_image"];
    if (currentImage) {
        [self setImage:currentImage];
    }
}

%end

%hook CKThumbsUpAcknowledgmentGlyphView

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !self.window || !isCustomBubbleColorsEnabled()) {
        return;
    }
    
    // Get lightened, desaturated system tint
    UIColor *glyphTint = [UIColor colorWithWhite:0.85 alpha:1.0];
    UIColor *customGlyphTint = getSystemTintColor();
    
    if (customGlyphTint) {
        CGFloat h, s, b, a;
        if ([customGlyphTint getHue:&h saturation:&s brightness:&b alpha:&a]) {
            s *= 0.3;
            b = MIN(1.0, b + 0.4);
            glyphTint = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
        }
    }
    
    self.tintColor = glyphTint;
    
    // Apply to all subviews
    for (UIView *subview in self.subviews) {
        subview.tintColor = glyphTint;
    }
}

%end

%hook CKTranscriptUnavailabilityIndicatorCell

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (!customTint) {
        return;
    }
    
    // Apply alpha to the tint color
    UIColor *indicatorColor = [customTint colorWithAlphaComponent:0.75];
    
    // Find and color the label and icon
    [self applyColorToUnavailabilityIndicator:self.contentView withColor:indicatorColor];
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !self.window) {
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (!customTint) {
        return;
    }
    
    UIColor *indicatorColor = [customTint colorWithAlphaComponent:0.75];
    [self applyColorToUnavailabilityIndicator:self.contentView withColor:indicatorColor];
}

%new
- (void)applyColorToUnavailabilityIndicator:(UIView *)view withColor:(UIColor *)color {
    // Check if this view is a UILabel
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        
        // Set the text color
        label.textColor = color;
        
        // Check if the label has attributed text (which contains the moon icon)
        if (label.attributedText) {
            NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithAttributedString:label.attributedText];
            
            // Enumerate through the attributed string to find NSTextAttachment
            [attrString enumerateAttribute:NSAttachmentAttributeName 
                                   inRange:NSMakeRange(0, attrString.length) 
                                   options:0 
                                usingBlock:^(id value, NSRange range, BOOL *stop) {
                if ([value isKindOfClass:[NSTextAttachment class]]) {
                    NSTextAttachment *attachment = (NSTextAttachment *)value;
                    UIImage *originalImage = attachment.image;
                    
                    if (originalImage) {
                        // Create template version and tint it
                        UIImage *templateImage = [originalImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                        UIImage *tintedImage = [templateImage imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];
                        attachment.image = tintedImage;
                        
                    }
                }
            }];
            
            // Apply foreground color to text
            [attrString addAttribute:NSForegroundColorAttributeName 
                               value:color 
                               range:NSMakeRange(0, attrString.length)];
            
            label.attributedText = attrString;
        }
    }
    
    // Recursively check all subviews
    for (UIView *subview in view.subviews) {
        [self applyColorToUnavailabilityIndicator:subview withColor:color];
    }
}

%end

%hook UINavigationButton

- (void)setTintColor:(UIColor *)color {
    if (!isTweakEnabled()) {
        %orig;
        return;
    }
    
    // Check if we're in the search bar
    UIView *parent = self.superview;
    BOOL isInSearchBar = NO;
    int levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(_UISearchBarSearchContainerView)] ||
            [parent isKindOfClass:%c(UISearchBarBackground)]) {
            isInSearchBar = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInSearchBar) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            %orig(customTint);
            return;
        }
    }
    
    %orig;
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !self.window) {
        return;
    }
    
    // Check if we're in the search bar
    UIView *parent = self.superview;
    BOOL isInSearchBar = NO;
    int levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(_UISearchBarSearchContainerView)] ||
            [parent isKindOfClass:%c(UISearchBarBackground)]) {
            isInSearchBar = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (isInSearchBar) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            self.tintColor = customTint;
        }
    }
}

%end

%hook CKTranscriptNotifyAnywayButtonCell

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (!customTint) {
        return;
    }
    
    // Find and color the Notify Anyway button
    for (UIView *subview in self.contentView.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            button.tintColor = customTint;
            
            // Force update the button's appearance
            [button setNeedsLayout];
            [button layoutIfNeeded];
            
            // Also apply to button label if it exists
            for (UIView *btnSubview in button.subviews) {
                if ([btnSubview isKindOfClass:%c(UIButtonLabel)]) {
                    [(UILabel *)btnSubview setTextColor:customTint];
                }
            }
            break;
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !self.window) {
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (!customTint) {
        return;
    }
    
    // Find and color the Notify Anyway button
    for (UIView *subview in self.contentView.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            button.tintColor = customTint;
            
            // Force update the button's appearance
            [button setNeedsLayout];
            [button layoutIfNeeded];
            
            // Also apply to button label if it exists
            for (UIView *btnSubview in button.subviews) {
                if ([btnSubview isKindOfClass:%c(UIButtonLabel)]) {
                    [(UILabel *)btnSubview setTextColor:customTint];
                }
            }
            break;
        }
    }
}

- (void)didMoveToSuperview {
    %orig;
    
    if (!isTweakEnabled() || !self.superview) {
        return;
    }
    
    // Trigger a layout update after a brief delay to ensure the button is fully configured
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [self setNeedsLayout];
        [self layoutIfNeeded];
    });
}

- (void)willMoveToWindow:(UIWindow *)newWindow {
    %orig;
    
    if (!isTweakEnabled() || !newWindow) {
        return;
    }
    
    // Schedule a layout update for when the cell appears
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsLayout];
        [self layoutIfNeeded];
    });
}

- (void)prepareForReuse {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Force relayout when cell is reused
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setNeedsLayout];
        [self layoutIfNeeded];
    });
}

%end

%hook UISearchTextField

- (void)didMoveToWindow {
    %orig;

    if (!isTweakEnabled()) {
        return;
    }

    if (!self.window) return;

    UIColor *accent = getSystemTintColor();
    if (!accent) return;

    // Desaturate and reduce opacity
    CGFloat h, s, b, a;
    if ([accent getHue:&h saturation:&s brightness:&b alpha:&a]) {
        s *= 0.6; // Reduce saturation to 60%
        accent = [[UIColor colorWithHue:h saturation:s brightness:b alpha:1.0] colorWithAlphaComponent:0.6]; // 60% opacity
    }

    // Set placeholder color using attributed string
    if (self.placeholder) {
        NSDictionary *attributes = @{NSForegroundColorAttributeName: accent};
        self.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.placeholder attributes:attributes];
    }
    
    // Color the search icon (magnifying glass)
    UIImageView *leftView = (UIImageView *)self.leftView;
    if (leftView && [leftView isKindOfClass:[UIImageView class]]) {
        leftView.tintColor = accent;
        leftView.alpha = 0.6;
    }
    
    // Color any other icons (like microphone on the right)
    if (self.rightView) {
        self.rightView.tintColor = accent;
        self.rightView.alpha = 0.6;
        
        // Also check for nested image views
        for (UIView *subview in self.rightView.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                subview.tintColor = accent;
                subview.alpha = 0.6;
            }
        }
    }
    
    // Apply tint to all imageViews in the text field
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            subview.tintColor = accent;
            subview.alpha = 0.6;
        }
    }
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    UIColor *accent = getSystemTintColor();
    if (!accent) return;
    
    // Desaturate and reduce opacity
    CGFloat h, s, b, a;
    if ([accent getHue:&h saturation:&s brightness:&b alpha:&a]) {
        s *= 0.6; // Reduce saturation to 60%
        accent = [[UIColor colorWithHue:h saturation:s brightness:b alpha:1.0] colorWithAlphaComponent:0.6]; // 60% opacity
    }
    
    // Reapply placeholder color
    if (self.placeholder && self.attributedPlaceholder) {
        NSDictionary *attributes = @{NSForegroundColorAttributeName: accent};
        self.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.placeholder attributes:attributes];
    }
    
    if (self.leftView) {
        self.leftView.tintColor = accent;
        self.leftView.alpha = 0.6;
    }
    
    if (self.rightView) {
        self.rightView.tintColor = accent;
        self.rightView.alpha = 0.6;
    }
    
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            subview.tintColor = accent;
            subview.alpha = 0.6;
        }
    }
}

%end

%hook CKDetailsSearchResultsTitleHeaderCell

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isCustomTextColorsEnabled()) {
        return;
    }
    
    UIColor *titleColor = getTitleTextColor();
    if (!titleColor) {
        return;
    }
    
    // Find and color UILabels in this cell
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.textColor = titleColor;
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !isCustomTextColorsEnabled() || !self.window) {
        return;
    }
    
    UIColor *titleColor = getTitleTextColor();
    if (!titleColor) {
        return;
    }
    
    // Find and color UILabels in this cell
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.textColor = titleColor;
        }
    }
}

%end

%hook CKSearchResultsTitleHeaderCell

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isCustomTextColorsEnabled()) {
        return;
    }
    
    UIColor *titleColor = getTitleTextColor();
    if (!titleColor) {
        return;
    }
    
    // Find and color UILabels in this cell
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.textColor = titleColor;
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !isCustomTextColorsEnabled() || !self.window) {
        return;
    }
    
    UIColor *titleColor = getTitleTextColor();
    if (!titleColor) {
        return;
    }
    
    // Find and color UILabels in this cell
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.textColor = titleColor;
        }
    }
}

%end

%hook CKAvatarTitleCollectionReusableView

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isCustomTextColorsEnabled()) {
        return;
    }
    
    UIColor *titleColor = getTitleTextColor();
    if (!titleColor) {
        return;
    }
    
    // Find and color CKLabels in this view
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:%c(CKLabel)]) {
            CKLabel *label = (CKLabel *)subview;
            label.textColor = titleColor;
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !isCustomTextColorsEnabled() || !self.window) {
        return;
    }
    
    UIColor *titleColor = getTitleTextColor();
    if (!titleColor) {
        return;
    }
    
    // Find and color CKLabels in this view
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:%c(CKLabel)]) {
            CKLabel *label = (CKLabel *)subview;
            label.textColor = titleColor;
        }
    }
}

%end

%hook CKMessageAcknowledgmentPickerBarView

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        return;
    }
    
    UIColor *customColor = getReceivedBubbleColor();
    if (!customColor) {
        return;
    }
    
    // Color all sublayers (including the tail)
    for (CALayer *sublayer in self.layer.sublayers) {
        sublayer.backgroundColor = customColor.CGColor;
    }
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !self.window) {
        return;
    }
    
    UIColor *customColor = getReceivedBubbleColor();
    if (!customColor) {
        return;
    }
    
    // Color all sublayers (including the tail)
    for (CALayer *sublayer in self.layer.sublayers) {
        sublayer.backgroundColor = customColor.CGColor;
    }
}

%end

%hook CKPinnedConversationSummaryBubble

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        return;
    }
    
    UIColor *bubbleColor = getPinnedBubbleColor();
    UIColor *textColor = getPinnedBubbleTextColor();
    
    if (!bubbleColor && !textColor) {
        return;
    }
    
    // Color the backdrop layer (bubble background) and reduce shadow
    for (CALayer *sublayer in self.layer.sublayers) {
        if ([sublayer isKindOfClass:%c(CKPinnedConversationActivityItemViewBackdropLayer)]) {
            if (bubbleColor) {
                sublayer.backgroundColor = bubbleColor.CGColor;
            }
        } else if ([sublayer isKindOfClass:%c(CKPinnedConversationActivityItemViewShadowLayer)]) {
            // Reduce shadow opacity (default is usually 1.0, try 0.3 or 0.2)
            sublayer.opacity = 0.3;
        }
    }
    
    // Color the text label
    if (textColor) {
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)subview;
                label.textColor = textColor;
            }
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !self.window) {
        return;
    }
    
    UIColor *bubbleColor = getPinnedBubbleColor();
    UIColor *textColor = getPinnedBubbleTextColor();
    
    if (!bubbleColor && !textColor) {
        return;
    }
    
    // Color the backdrop layer (bubble background) and reduce shadow
    for (CALayer *sublayer in self.layer.sublayers) {
        if ([sublayer isKindOfClass:%c(CKPinnedConversationActivityItemViewBackdropLayer)]) {
            if (bubbleColor) {
                sublayer.backgroundColor = bubbleColor.CGColor;
            }
        } else if ([sublayer isKindOfClass:%c(CKPinnedConversationActivityItemViewShadowLayer)]) {
            // Reduce shadow opacity
            sublayer.opacity = 0.3;
        }
    }
    
    // Color the text label
    if (textColor) {
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UILabel class]]) {
                UILabel *label = (UILabel *)subview;
                label.textColor = textColor;
            }
        }
    }
}

%end

%hook CNContactView

- (void)didMoveToSuperview {
    %orig;
    
    if (!isTweakEnabled() || !self.superview) {
        return;
    }
    
    self.backgroundColor = [UIColor clearColor];
    
    BOOL hasChatImage = [[NSFileManager defaultManager] fileExistsAtPath:kChatImagePath];
    UIImage *chatBgImage = hasChatImage ? [UIImage imageWithContentsOfFile:kChatImagePath] : nil;
    
    if (isChatColorBgEnabled()) {
        self.backgroundColor = getChatBackgroundColor();
    }
    else if (chatBgImage && isChatImageBgEnabled()) {
        CGFloat blurAmount = getChatImageBlurAmount();
        if (blurAmount > 0) {
            chatBgImage = blurImage(chatBgImage, blurAmount);
        }
        
        // Remove any existing background images from superview
        for (UIView *subview in [self.superview.subviews copy]) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                UIImageView *imgView = (UIImageView *)subview;
                if (imgView.contentMode == UIViewContentModeScaleAspectFill) {
                    [imgView removeFromSuperview];
                }
            }
        }
        
        // Insert image at index 0 of superview
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.frame];
        imageView.image = chatBgImage;
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        imageView.userInteractionEnabled = NO;
        [self.superview insertSubview:imageView atIndex:0];
        
        // Make CNContactView transparent
        self.backgroundColor = [UIColor clearColor];
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled()) {
        %orig;
        return;
    }
    
    if (isChatColorBgEnabled()) {
        %orig(getChatBackgroundColor());
    } else if (isChatImageBgEnabled()) {
        %orig([UIColor clearColor]);
    } else {
        %orig([UIColor clearColor]);
    }
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Update background image in superview if it exists
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
}

%end

%hook UITableViewWrapperView

- (void)didMoveToSuperview {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
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
    
    if (!isTweakEnabled() || !isCustomTextColorsEnabled()) {
        return;
    }
    
    UIColor *titleColor = getTitleTextColor();
    if (!titleColor) {
        return;
    }
    
    // Find and color the UILabel with the contact name
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            label.textColor = titleColor;
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    self.backgroundColor = [UIColor clearColor];
    
    if (isCustomTextColorsEnabled()) {
        UIColor *titleColor = getTitleTextColor();
        if (titleColor) {
            for (UIView *subview in self.subviews) {
                if ([subview isKindOfClass:[UILabel class]]) {
                    UILabel *label = (UILabel *)subview;
                    label.textColor = titleColor;
                }
            }
        }
    }
}

%end

%hook CNContactActionsContainerView

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    self.backgroundColor = [UIColor clearColor];
    
    // Find and hide the separator
    for (UIView *subview in self.subviews) {
        // Check for separator views (usually UIView with small height)
        if ([subview class] == [UIView class] && subview.frame.size.height < 2) {
            subview.hidden = YES;
            subview.alpha = 0.0;
        }
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled()) {
        %orig;
        return;
    }
    
    %orig([UIColor clearColor]);
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Re-hide separator after layout
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
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Check if we're inside CNContactView
    UIView *parent = self.superview;
    BOOL isInContactView = NO;
    int levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:NSClassFromString(@"CNContactView")]) {
            isInContactView = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (!isInContactView) {
        return;
    }
    
    // Remove any existing blur views
    for (UIView *subview in [self.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            [subview removeFromSuperview];
        }
    }
    
    // Create and add blur effect to self (not contentView)
    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.frame = self.bounds;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    blurView.layer.cornerRadius = self.layer.cornerRadius;
    blurView.clipsToBounds = YES;
    
    [self insertSubview:blurView atIndex:0];
    self.backgroundColor = [UIColor clearColor];
    self.contentView.backgroundColor = [UIColor clearColor];
    self.clipsToBounds = YES;
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Check if we're inside CNContactView
    UIView *parent = self.superview;
    BOOL isInContactView = NO;
    int levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:NSClassFromString(@"CNContactView")]) {
            isInContactView = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (!isInContactView) {
        return;
    }
    
    // Update blur view frame
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            subview.frame = self.bounds;
            subview.layer.cornerRadius = self.layer.cornerRadius;
            break;
        }
    }
}

%end



/* iOS 17 Specific Hooks */

%hook CKSendMenuPresentationPopoverBackdropView

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !isiOS17OrHigher()) {
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (!customTint) {
        return;
    }
    
    // Create an adjusted version of the accent color based on light/dark mode
    CGFloat h, s, b, a;
    if ([customTint getHue:&h saturation:&s brightness:&b alpha:&a]) {
        // Adjust saturation slightly (increase by 10%)
        s = MIN(1.0, s * 1.1);
        
        // Adjust brightness based on light/dark mode
        if (isDarkMode()) {
            b *= 0.5; // Darken to 50% brightness in dark mode
        } else {
            b = MIN(1.0, b * 1.2); // Lighten to 150% brightness in light mode
        }
        
        UIColor *adjustedColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
        self.backgroundColor = adjustedColor;
    }
}

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled() || !isiOS17OrHigher()) {
        %orig;
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (!customTint) {
        %orig;
        return;
    }
    
    // Create an adjusted version of the accent color based on light/dark mode
    CGFloat h, s, b, a;
    if ([customTint getHue:&h saturation:&s brightness:&b alpha:&a]) {
        s = MIN(1.0, s * 1.1);
        
        if (isDarkMode()) {
            b *= 0.5; // Darken to 50% in dark mode
        } else {
            b = MIN(1.0, b * 1.2); // Lighten to 150% in light mode
        }
        
        UIColor *adjustedColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
        %orig(adjustedColor);
        return;
    }
    
    %orig;
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isiOS17OrHigher()) {
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (!customTint) {
        return;
    }
    
    // Verify we're in the correct view hierarchy
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
    
    if (isCorrectHierarchy) {
        CGFloat h, s, b, a;
        if ([customTint getHue:&h saturation:&s brightness:&b alpha:&a]) {
            s = MIN(1.0, s * 1.1);
            
            if (isDarkMode()) {
                b *= 0.5; // Darken to 50% in dark mode
            } else {
                b = MIN(1.0, b * 1.2); // Lighten to 150% in light mode
            }
            
            UIColor *adjustedColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
            self.backgroundColor = adjustedColor;
        }
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    %orig;
    
    if (!isTweakEnabled() || !isiOS17OrHigher()) {
        return;
    }
    
    // Reapply color when switching between light/dark mode
    if (@available(iOS 13.0, *)) {
        if (self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle) {
            [self setNeedsLayout];
        }
    }
}

%end

%hook _UINavigationBarLargeTitleView

- (void)layoutSubviews {
    %orig;

    if (!isTweakEnabled() || !isiOS17OrHigher()) return;

    // Find the UILabel in the large title view
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            if ([label.text isEqualToString:@"Messages"]) {
                label.text = getConversationListTitle();
                label.textColor = getConversationListTitleColor();
            }
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !isiOS17OrHigher()) return;
    
    // Apply immediately when view appears
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            if ([label.text isEqualToString:@"Messages"]) {
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
    
    if (!isTweakEnabled() || !isiOS17OrHigher()) {
        return;
    }
    
    if (!self.window) {
        return;
    }
    
    // Check if this is the "No Conversation Selected" view by examining the hierarchy
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
    
    if (!isNoConversationView) {
        return;
    }
    
    // Find the UIView child (the actual content view)
    UIView *contentView = nil;
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIView class]] && 
            ![subview isKindOfClass:[UIImageView class]]) {
            contentView = subview;
            break;
        }
    }
    
    if (!contentView) {
        return;
    }
    
    // Remove any existing background images
    for (UIView *subview in [contentView.subviews copy]) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            UIImageView *imgView = (UIImageView *)subview;
            if (imgView.frame.origin.x == 0 && imgView.frame.origin.y == 0) {
                [imgView removeFromSuperview];
            }
        }
    }
    
    // Apply the same background logic as chat view
    BOOL hasChatImage = [[NSFileManager defaultManager] fileExistsAtPath:kChatImagePath];
    UIImage *chatBgImage = hasChatImage ? [UIImage imageWithContentsOfFile:kChatImagePath] : nil;
    
    if (isChatColorBgEnabled()) {
        contentView.backgroundColor = getChatBackgroundColor();
    }
    else if (chatBgImage && isChatImageBgEnabled()) {
        CGFloat blurAmount = getChatImageBlurAmount();
        if (blurAmount > 0) {
            chatBgImage = blurImage(chatBgImage, blurAmount);
        }
        
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
    
    if (!isTweakEnabled() || isiOS17OrHigher()) {
        return;
    }
    
    // Check if this is the "No Conversation Selected" view
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
    
    if (!isNoConversationView) {
        return;
    }
    
    // Update background image frame if it exists
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIView class]]) {
            for (UIView *bgView in subview.subviews) {
                if ([bgView isKindOfClass:[UIImageView class]]) {
                    UIImageView *imgView = (UIImageView *)bgView;
                    if (imgView.frame.origin.x == 0 && imgView.frame.origin.y == 0) {
                        imgView.frame = subview.bounds;
                    }
                }
            }
        }
    }
}

%end

%hook CKEntryViewBlurrableButtonContainer

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isiOS17OrHigher()) {
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (!customTint) {
        return;
    }
    
    // Find the button directly (it's a direct subview)
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            CGSize buttonSize = button.frame.size;
            
            // Send button is 27.5 x 27.5
            if (buttonSize.width > 27 && buttonSize.width < 28 && 
                buttonSize.height > 27 && buttonSize.height < 28) {
                
                // Find and remove the existing UIImageView
                for (UIView *btnSubview in [button.subviews copy]) {
                    if ([btnSubview isKindOfClass:[UIImageView class]]) {
                        [btnSubview removeFromSuperview];
                        break;
                    }
                }
                
                // Set background to custom color
                button.backgroundColor = customTint;
                button.layer.cornerRadius = buttonSize.width / 2;
                button.clipsToBounds = YES;
                
                // Create arrow overlay
                UIImage *arrowImage = [UIImage systemImageNamed:@"arrow.up"];
                if (arrowImage) {
                    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:13 weight:UIImageSymbolWeightSemibold];
                    arrowImage = [arrowImage imageWithConfiguration:config];
                    arrowImage = [arrowImage imageWithTintColor:[UIColor whiteColor] renderingMode:UIImageRenderingModeAlwaysOriginal];
                    
                    UIImageView *arrowOverlay = [[UIImageView alloc] initWithImage:arrowImage];
                    arrowOverlay.userInteractionEnabled = NO;
                    
                    CGSize arrowSize = arrowOverlay.bounds.size;
                    arrowOverlay.frame = CGRectMake((buttonSize.width - arrowSize.width) / 2,
                                                   (buttonSize.height - arrowSize.height) / 2,
                                                   arrowSize.width,
                                                   arrowSize.height);
                    
                    [button addSubview:arrowOverlay];
                }
                
                break; // Found and processed the send button, exit loop
            }
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !isiOS17OrHigher() || !self.window) {
        return;
    }
    
    [self setNeedsLayout];
    [self layoutIfNeeded];
}

%end

%hook LPFlippedView

- (void)setBackgroundColor:(UIColor *)backgroundColor {
    if (!isTweakEnabled()) {
        %orig;
        return;
    }
    
    UIColor *customLinkColor = getLinkPreviewBackgroundColor();
    if (customLinkColor) {
        %orig(customLinkColor);
        return;
    }
    
    %orig;
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !self.window) {
        return;
    }
    
    UIColor *customLinkColor = getLinkPreviewBackgroundColor();
    if (customLinkColor) {
        self.backgroundColor = customLinkColor;
    }
}

%end

%hook LPTextView

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Check if we're inside LPFlippedView hierarchy
    UIView *parent = self.superview;
    BOOL isInLinkPreview = NO;
    int levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(LPFlippedView)]) {
            isInLinkPreview = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (!isInLinkPreview) {
        return;
    }
    
    UIColor *headerColor = getLinkPreviewTextColor();
    if (!headerColor) {
        return;
    }
    
    // Apply colors to UILabels
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            
            // Determine if this is header or subtext based on font size
            // Header text is typically larger
            if (label.font.pointSize > 14) {
                // This is the header
                label.textColor = headerColor;
            } else {
                // This is the subtext - desaturate and add transparency
                CGFloat h, s, b, a;
                if ([headerColor getHue:&h saturation:&s brightness:&b alpha:&a]) {
                    s *= 0.6; // Reduce saturation to 60%
                    UIColor *subtextColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:0.7];
                    label.textColor = subtextColor;
                }
            }
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !self.window) {
        return;
    }
    
    // Check if we're inside LPFlippedView hierarchy
    UIView *parent = self.superview;
    BOOL isInLinkPreview = NO;
    int levels = 0;
    
    while (parent && levels < 10) {
        if ([parent isKindOfClass:%c(LPFlippedView)]) {
            isInLinkPreview = YES;
            break;
        }
        parent = parent.superview;
        levels++;
    }
    
    if (!isInLinkPreview) {
        return;
    }
    
    UIColor *headerColor = getLinkPreviewTextColor();
    if (!headerColor) {
        return;
    }
    
    // Apply colors to UILabels
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UILabel class]]) {
            UILabel *label = (UILabel *)subview;
            
            if (label.font.pointSize > 14) {
                label.textColor = headerColor;
            } else {
                CGFloat h, s, b, a;
                if ([headerColor getHue:&h saturation:&s brightness:&b alpha:&a]) {
                    s *= 0.6;
                    UIColor *subtextColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:0.7];
                    label.textColor = subtextColor;
                }
            }
        }
    }
}

%end

%hook LPImageView

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    // Make all UIView subviews transparent
    for (UIView *subview in self.subviews) {
        if ([subview class] == [UIView class]) {
            subview.backgroundColor = [UIColor clearColor];
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !self.window) {
        return;
    }
    
    // Make all UIView subviews transparent
    for (UIView *subview in self.subviews) {
        if ([subview class] == [UIView class]) {
            subview.backgroundColor = [UIColor clearColor];
        }
    }
}

%end

