#import <UIKit/UIKit.h>
#import <objc/runtime.h>
#import <WAMTweakInterfaces.h>

/* ===================
  PREFERENCE THINGS 
==================== */

/* Define paths for preferences to save to (in the case of kConvImagePath, where to save image
and how to name it [background.jpg]). Notification is used to post the preference change and update tweak.
In case of messages, no respring is *required*, just close and reopen app a couple of times. I could include a 
button to kill the app or sum but the user could also just swipe the app and reopen it until they see their changes
sooooo...
Just do that or respring bro */
/*--------------------------------------------------------------------------*/
#define kPrefsPath @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs.plist"
#define kConvImagePath @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background.jpg"
#define kChatImagePath @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background.jpg"
#define kPrefsChangedNotification @"com.oakstheawesome.whatamessprefs/prefsChanged"

//These handle loding the preference shi
static NSDictionary *cachedPrefs = nil;

static NSDictionary *loadPrefs() {
	if (!cachedPrefs) {
		cachedPrefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
	}
	return cachedPrefs;
}

/*=======================
	BOOLEAN FUNCTIONS
========================*/
//Enabled? Disabled? Maybe...

BOOL isTweakEnabled() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
	return prefs[@"isEnabled"] ? [prefs[@"isEnabled"] boolValue] : YES;
}

BOOL isModernNavBarEnabled() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"isModernNavBarEnabled"] ? [prefs[@"isModernNavBarEnabled"] boolValue] : YES;
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
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
	return prefs[@"isConvColorBgEnabled"] ? [prefs[@"isConvColorBgEnabled"] boolValue] : YES;
}

BOOL isChatColorBgEnabled() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"isChatColorBgEnabled"] ? [prefs[@"isChatColorBgEnabled"] boolValue] : NO;
}

BOOL isConvImageBgEnabled() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
	return prefs[@"isConvImageBgEnabled"] ? [prefs[@"isConvImageBgEnabled"] boolValue] : NO;
}

BOOL isChatImageBgEnabled() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
	return prefs[@"isChatImageBgEnabled"] ? [prefs[@"isChatImageBgEnabled"] boolValue] : NO;
}

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

BOOL isNavBarCustomizationEnabled() {
    NSDictionary *prefs = loadPrefs();
    return prefs[@"isNavBarCustomizationEnabled"] ? [prefs[@"isNavBarCustomizationEnabled"] boolValue] : NO;
}

BOOL isMessageBarCustomizationEnabled() {
    NSDictionary *prefs = loadPrefs();
    return prefs[@"isMessageBarCustomizationEnabled"] ? [prefs[@"isMessageBarCustomizationEnabled"] boolValue] : NO;
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
//just to get the blur slider set value
CGFloat getImageBlurAmount() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"imageBlurAmount"] ? [prefs[@"imageBlurAmount"] floatValue] : 0.0;
}

CGFloat getChatImageBlurAmount() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"chatImageBlurAmount"] ? [prefs[@"chatImageBlurAmount"] floatValue] : 0.0;
}

/*=================================
	Helper and Getter Functions
=================================*/
//Getters and helpers for colors, text inputs, apply color to text, logging, blurring images, etc.

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

UIColor *getCellColor() {
	NSDictionary *prefs = loadPrefs();
	NSString *colorString = prefs[@"convListCellColor"];
	UIColor *color = colorFromHex(colorString);
	return color ?: [UIColor blackColor];
}

UIColor *getTitleTextColor() {
	NSDictionary *prefs = loadPrefs();
	NSString *colorString = prefs[@"titleTextColor"];
	UIColor *color = colorFromHex(colorString);
	return color ?: [UIColor whiteColor];
}

UIColor *getMessagePreviewTextColor() {
	NSDictionary *prefs = loadPrefs();
	NSString *colorString = prefs[@"messagePreviewTextColor"];
	UIColor *color = colorFromHex(colorString);
	return color ?: [UIColor grayColor];
}

UIColor *getDateTimeTextColor() {
	NSDictionary *prefs = loadPrefs();
	NSString *colorString = prefs[@"dateTimeTextColor"];
	UIColor *color = colorFromHex(colorString);
	return color ?: [UIColor grayColor];
}

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

static NSString *getConversationListTitle() {
	NSDictionary *prefs = loadPrefs();
	NSString *title = prefs[@"conversationListTitleText"];
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

	if (!cgImage) {
		return image;
	}

	UIImage *blurredImage = [UIImage imageWithCGImage:cgImage scale:image.scale orientation:image.imageOrientation];
	CGImageRelease(cgImage);

	return blurredImage;
}

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

static UIColor *getNavBarTintColor() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"navBarTintColor"];
    
    if (!hexColor) {
        return getSystemTintColor(); 
    }
    
    return colorFromHex(hexColor);
}

static UIColor *getMessageBarTintColor() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"messageBarTintColor"];
    
    if (!hexColor) {
        return getSystemTintColor(); 
    }
    
    return colorFromHex(hexColor);
}

static UIColor *getCellBlurTintColor() {
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
    NSString *hexColor = prefs[@"cellTintColor"];
    
    if (!hexColor) {
        return getSystemTintColor(); // Fallback to system tint
    }
    
    return colorFromHex(hexColor);
}

//Logging Function for testing and dumping lol
/*
static void logToFile(NSString *message) {
    FILE *logFile = fopen("/var/jb/var/mobile/whatamess_debug.log", "a");
    if (logFile) {
        fprintf(logFile, "%s\n", [message UTF8String]);
        fclose(logFile);
    }
} */



/*============
==============
    HOOKS 
==============
============*/
//This is where the magic happens baby.
//Maybe ill comment and explain everything but not this release

%hook UIView

- (UIColor *)tintColor {
    if (!isTweakEnabled()) {
        return %orig;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (!customTint) {
        return %orig;
    }
    
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
                    if ([parent isKindOfClass:%c(CKConversationListCollectionViewConversationCell)]) {
                        return %orig;
                    }
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
            [parent isKindOfClass:%c(UISearchBar)]) {
            return %orig;
        }
        
        if ([parent isKindOfClass:%c(UIKBVisualEffectView)] ||
            [parent isKindOfClass:%c(UIInputView)]) {
            return %orig;
        }
        
        NSString *className = NSStringFromClass([parent class]);
        if ([className containsString:@"Keyboard"] ||
            [className containsString:@"UIKBInputBackdropView"]) {
            return %orig;
        }
        
        parent = parent.superview;
        levels++;
    }
    
    return customTint;
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        return;
    }
    
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

%new
-(void)updateBackground {

	BOOL hasImage = [[NSFileManager defaultManager] fileExistsAtPath:kConvImagePath];
	UIImage *bgImage = hasImage ? [UIImage imageWithContentsOfFile:kConvImagePath] : nil;
	
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

-(void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	%orig;
}
%end

%hook CKConversationListCollectionViewConversationCell
 
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

-(void)layoutSubviews {
	%orig;

	if (!isTweakEnabled()) return;

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
            UIColor *customTint = getSystemTintColor();
            if (customTint) {
                %orig(customTint);
                return;
            }
            break;
        }
        
        if ([parent isKindOfClass:%c(CKTranscriptLabelCell)]) {
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
    
    if ([self.text isEqualToString:@"Edited"] && [self.superview isKindOfClass:%c(_UISystemBackgroundView)]) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            %orig(customTint);
            return;
        }
    }
    
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

%hook _UIBarBackground

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    if (isModernNavBarEnabled()) {
        if (self.window) {
            [self ensureBlurExists];
        }
    }
}

- (void)layoutSubviews {
    %orig;

    if (!isTweakEnabled()) {
        return;
    }

    if (isModernNavBarEnabled()) {
        BOOL hasContactView = NO;
        if (self.window) {
            hasContactView = [self findContactViewInWindow:self.window];
        }
        
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
            
            if (hasContactView) {
                blurFrame.origin.y = 1000;
            } else {
                blurFrame.origin.y = 0;
            }
            
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
    
    if (!isNavBarCustomizationEnabled()) {
        return;
    }
    
    UIColor *tintColor = getNavBarTintColor();
    if (!tintColor) {
        return;
    }
    
    BOOL hasContactView = NO;
    if (self.window) {
        hasContactView = [self findContactViewInWindow:self.window];
    }
    
    if (hasContactView) {
        self.alpha = 0.0;
        return;
    } else {
        self.alpha = 1.0;
    }
    
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
                        if (fabs(r1 - r2) < 0.01 && fabs(g1 - g2) < 0.01 && fabs(b1 - b2) < 0.01) {
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
    if (!isTweakEnabled() || !isModernNavBarEnabled()) {
        %orig;
        return;
    }
    
    BOOL hasOurBlur = NO;
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]]) {
            if ([sub.layer.mask isKindOfClass:[CAGradientLayer class]]) {
                hasOurBlur = YES;
                break;
            }
        }
    }
    
    if (hasOurBlur && ([view isKindOfClass:[UIVisualEffectView class]] || [view isKindOfClass:[UIImageView class]])) {
        return;
    }
    
    %orig;
}

- (void)setAlpha:(CGFloat)alpha {
    if (!isTweakEnabled() || isModernNavBarEnabled()) {
        %orig;
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
    
    for (UIView *view in viewsToRemove) {
        [view removeFromSuperview];
    }
}

%new
- (void)ensureBlurExists {
    [self removeSystemViews];
    
    for (UIView *sub in self.subviews) {
        if ([sub isKindOfClass:[UIVisualEffectView class]]) {
            if ([sub.layer.mask isKindOfClass:[CAGradientLayer class]]) {
                return;
            }
        }
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
    blurFrame.size.height += 70;
    blurView.frame = blurFrame;
    blurView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self insertSubview:blurView atIndex:0];

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
    
    maskLayer.actions = @{
        @"position": [NSNull null],
        @"bounds": [NSNull null],
        @"frame": [NSNull null]
    };
    
    blurView.layer.mask = maskLayer;
    
    [CATransaction commit];
}

%end

%hook UINavigationBar

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    if (!isModernNavBarEnabled() && isNavBarCustomizationEnabled()) {
        for (UIView *subview in self.subviews) {
            NSString *className = NSStringFromClass([subview class]);
            
            if ([className isEqualToString:@"_UIBarBackground"]) {
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
    
    if (!isTweakEnabled() || !self.window) {
        return;
    }
    
    if (!isModernNavBarEnabled() && isNavBarCustomizationEnabled()) {
        for (UIView *subview in self.subviews) {
            NSString *className = NSStringFromClass([subview class]);
            
            if ([className isEqualToString:@"_UIBarBackground"]) {
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
            }
            else if (isCustomTextColorsEnabled()) {
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
                    }
                    else if (isCustomTextColorsEnabled()) {
                        label.textColor = getTitleTextColor();
                    }
                }
            }
        }
    }
}

%end

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

%hook CKPinnedConversationView

- (void)didMoveToWindow {
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

%hook CKTranscriptCollectionViewController

- (void)viewDidLoad {
    %orig;
	self.view.backgroundColor = [UIColor clearColor];
}
/* There was this little weird black box around bubbles that I could never find for the life of me. Found chatwall
by ChristopherA8 and  found what made it go away. So special thanks for that and sparing my beginner-level sanity. 
Also steered me in the direction of what to hook/hide. TYSM. */
-(BOOL)shouldUseOpaqueMask{
	return NO;
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

    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) return;
    if (self.frame.size.width <= 0 || self.frame.size.height <= 0) return;

    BOOL isReaction = [self.superview isKindOfClass:objc_getClass("CKAggregateAcknowledgmentBalloonView")];
    if (isReaction) {
        self.hidden = YES;
        return;
    }

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

    [self setColors:@[bubbleColor, bubbleColor]];
}

- (void)setColors:(NSArray *)colors {
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        %orig;
        return;
    }

    BOOL isReaction = [self.superview isKindOfClass:objc_getClass("CKAggregateAcknowledgmentBalloonView")];
    if (isReaction) {
        self.hidden = YES;
        return;
    }

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
    
    NSNumber *isUpdating = objc_getAssociatedObject(self, @selector(setTextColor:));
    if (isUpdating && [isUpdating boolValue]) {
        %orig;
        return;
    }
    
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
    
    NSNumber *isUpdating = objc_getAssociatedObject(self, @selector(setTintColor:));
    if (isUpdating && [isUpdating boolValue]) {
        %orig;
        return;
    }
    
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
    

    UIViewController *vc = [self _viewControllerForAncestor];
    if (![vc isKindOfClass:%c(CKTranscriptCollectionViewController)]) {
        return;
    }
    
    UIColor *timestampColor = pickTimestampTextColor();
    if (!timestampColor) {
        return;
    }
    
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
    
    if (!isTweakEnabled()) {
        return;
    }
    

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

    if (isModernMessageBarEnabled()) {
        effectView.backgroundColor = [UIColor clearColor];
        effectView.contentView.backgroundColor = [UIColor clearColor];
        effectView.opaque = NO;

        self.backgroundColor = [UIColor clearColor];
        self.opaque = NO;

        if (!effectView.effect) {
            effectView.effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleRegular];
        }

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
    
    if (!isMessageBarCustomizationEnabled()) {
        return;
    }
    
    UIColor *tintColor = getMessageBarTintColor();
    if (!tintColor) {
        return;
    }
    
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
                    if (fabs(r1 - r2) < 0.01 && fabs(g1 - g2) < 0.01 && fabs(b1 - b2) < 0.01) {
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
    
    UITextView *textView = [self findTextView:self];
    if (textView) {
        inputFieldContainer = textView.superview;
    }

    if (!inputFieldContainer) {
        inputFieldContainer = [self findRoundedView:self];
    }

    if (!inputFieldContainer) {
        inputFieldContainer = [self findViewByClassName:self];
    }
    
    if (!inputFieldContainer) {
        return;
    }

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
    
    if (isTweakEnabled() && isPlaceholderCustomizationEnabled() && isInputFieldCustomizationEnabled()) {
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
                    
                    for (UIView *btnSubview in [button.subviews copy]) {
                        if ([btnSubview isKindOfClass:[UIImageView class]]) {
                            UIImageView *imageView = (UIImageView *)btnSubview;
                            CGSize frameSize = imageView.frame.size;
                            
                            if (frameSize.width > 27 && frameSize.width < 28 && 
                                frameSize.height > 27 && frameSize.height < 28) {
                                if (!customTint) continue;
                                
                                button.backgroundColor = customTint;
                                button.layer.cornerRadius = button.bounds.size.width / 2;
                                button.clipsToBounds = YES;
                                
                                [imageView removeFromSuperview];
                                
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
                            else if (customizeOtherButtons && buttonColor &&
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

    if (isConvColorBgEnabled()) {
        UIColor *bgColor = getBackgroundColor();
        if (bgColor) {
            self.backgroundColor = bgColor;
            self.backgroundView = nil;
        }
    } else {
        BOOL hasImage = [[NSFileManager defaultManager] fileExistsAtPath:kConvImagePath];
        UIImage *bgImage = hasImage ? [UIImage imageWithContentsOfFile:kConvImagePath] : nil;
        
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

%hook _UITableViewHeaderFooterContentView

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }

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

%hook CNActionView

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
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
    
    if (!isTweakEnabled()) {
        return;
    }
    
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
    
    [self updateIconOpacity];
}

%new
- (void)updateIconOpacity {
    BOOL isDisabled = NO;
    @try {
        id disabled = [self valueForKey:@"disabled"];
        if (disabled) {
            isDisabled = [disabled boolValue];
        }
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

%end

%hook CKTranscriptDetailsResizableCell

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    for (UIView *subview in [self.contentView.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            [subview removeFromSuperview];
        }
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
    
    if (!isTweakEnabled()) {
        return;
    }
    
    for (UIView *subview in self.contentView.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            subview.frame = self.contentView.bounds;
            subview.layer.cornerRadius = self.contentView.layer.cornerRadius;
            
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
}

%end

%hook CKDetailsSharedWithYouCell

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
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
    
    if (!isTweakEnabled()) {
        return;
    }
    
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
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
}

%end

%hook CKBackgroundDecorationView

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    for (UIView *subview in [self.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            [subview removeFromSuperview];
        }
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
    
    if (!isTweakEnabled()) {
        return;
    }
    
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
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
}

%end

%hook CKDetailsChatOptionsCell

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
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
    
    if (!isTweakEnabled()) {
        return;
    }
    
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            subview.frame = self.bounds;
            subview.layer.cornerRadius = 0;
            
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
    
    [[NSNotificationCenter defaultCenter] addObserver:self
        selector:@selector(updateRecipientBackground)
        name:kPrefsChangedNotification
        object:nil];
}

%new
- (void)updateRecipientBackground {
    
    BOOL hasChatImage = [[NSFileManager defaultManager] fileExistsAtPath:kChatImagePath];
    UIImage *chatBgImage = hasChatImage ? [UIImage imageWithContentsOfFile:kChatImagePath] : nil;
    
    for (UIView *subview in [self.subviews copy]) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            UIImageView *imgView = (UIImageView *)subview;
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

%hook UIButtonLabel

- (void)setText:(NSString *)text {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    if ([text isEqualToString:@"Report Junk"]) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            self.textColor = customTint;
        }
        return;
    }
    
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
    
    if ([self.text isEqualToString:@"Report Junk"]) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            self.textColor = customTint;
        }
        return;
    }
    
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
    
    if ([self.text isEqualToString:@"Report Junk"]) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            %orig(customTint);
            return;
        }
    }
    
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
    
    if ([self.text isEqualToString:@"Report Junk"]) {
        UIColor *customTint = getSystemTintColor();
        if (customTint) {
            self.textColor = customTint;
        }
        return;
    }
    
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

        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                subview.tintColor = customTint;
            }
        }
    }
    
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
        
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                subview.tintColor = customTint;
            }
        }
        
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
        
        for (UIView *subview in self.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                subview.tintColor = customTint;
            }
        }
    }
    
    if (isCustomBubbleColorsEnabled()) {
        [self applyGlyphTintRecursively:self];
    }
}

%new
- (void)applyGlyphTintRecursively:(UIView *)view {
    UIColor *glyphTint = [UIColor colorWithWhite:0.85 alpha:1.0];
    UIColor *customGlyphTint = getSystemTintColor();
    
    if (customGlyphTint) {
        CGFloat h, s, b, a;
        if ([customGlyphTint getHue:&h saturation:&s brightness:&b alpha:&a]) {
            s *= 0.2;
            b = MIN(1.0, b + 0.2);
            glyphTint = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
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
    
    NSString *className = NSStringFromClass([view class]);
    if ([className containsString:@"AcknowledgmentGlyphView"]) {
        view.tintColor = glyphTint;
    }

    for (UIView *subview in view.subviews) {
        [self applyGlyphTintRecursively:subview];
    }
}

%end

%hook _UIPlatterClippingView

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    if (self.bounds.size.height < 200) {
        return;
    }
    
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
    
    [self colorReportJunkButton:self withColor:customTint];
}

%new
- (void)colorReportJunkButton:(UIView *)view withColor:(UIColor *)color {
    if ([view isKindOfClass:%c(UIButtonLabel)]) {
        UILabel *label = (UILabel *)view;
        if ([label.text isEqualToString:@"Report Junk"]) {
            label.textColor = color;
        }
    }
    
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
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !self.superview) {
        return;
    }
    
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
    
    UIColor *indicatorColor = [customTint colorWithAlphaComponent:0.75];
    
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
    if ([view isKindOfClass:[UILabel class]]) {
        UILabel *label = (UILabel *)view;
        
        label.textColor = color;
        
        if (label.attributedText) {
            NSMutableAttributedString *attrString = [[NSMutableAttributedString alloc] initWithAttributedString:label.attributedText];
            
            [attrString enumerateAttribute:NSAttachmentAttributeName 
                                   inRange:NSMakeRange(0, attrString.length) 
                                   options:0 
                                usingBlock:^(id value, NSRange range, BOOL *stop) {
                if ([value isKindOfClass:[NSTextAttachment class]]) {
                    NSTextAttachment *attachment = (NSTextAttachment *)value;
                    UIImage *originalImage = attachment.image;
                    
                    if (originalImage) {
                        UIImage *templateImage = [originalImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
                        UIImage *tintedImage = [templateImage imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];
                        attachment.image = tintedImage;
                        
                    }
                }
            }];
            
            [attrString addAttribute:NSForegroundColorAttributeName 
                               value:color 
                               range:NSMakeRange(0, attrString.length)];
            
            label.attributedText = attrString;
        }
    }
    
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
    
    for (UIView *subview in self.contentView.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            button.tintColor = customTint;
            
            [button setNeedsLayout];
            [button layoutIfNeeded];
            
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
    
    for (UIView *subview in self.contentView.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            button.tintColor = customTint;
            
            [button setNeedsLayout];
            [button layoutIfNeeded];
            
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

    CGFloat h, s, b, a;
    if ([accent getHue:&h saturation:&s brightness:&b alpha:&a]) {
        s *= 0.6;
        accent = [[UIColor colorWithHue:h saturation:s brightness:b alpha:1.0] colorWithAlphaComponent:0.6];
    }

    if (self.placeholder) {
        NSDictionary *attributes = @{NSForegroundColorAttributeName: accent};
        self.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.placeholder attributes:attributes];
    }
    
    UIImageView *leftView = (UIImageView *)self.leftView;
    if (leftView && [leftView isKindOfClass:[UIImageView class]]) {
        leftView.tintColor = accent;
    }
    
    if (self.rightView) {
        self.rightView.tintColor = accent;
        
        for (UIView *subview in self.rightView.subviews) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                subview.tintColor = accent;
            }
        }
    }
    
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            subview.tintColor = accent;
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
    
    CGFloat h, s, b, a;
    if ([accent getHue:&h saturation:&s brightness:&b alpha:&a]) {
        s *= 0.6;
        accent = [[UIColor colorWithHue:h saturation:s brightness:b alpha:1.0] colorWithAlphaComponent:0.6];
    }
    
    if (self.placeholder && self.attributedPlaceholder) {
        NSDictionary *attributes = @{NSForegroundColorAttributeName: accent};
        self.attributedPlaceholder = [[NSAttributedString alloc] initWithString:self.placeholder attributes:attributes];
    }
    
    if (self.leftView) {
        self.leftView.tintColor = accent;
    }
    
    if (self.rightView) {
        self.rightView.tintColor = accent;
    }
    
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            subview.tintColor = accent;
        }
    }
}

%end

%hook UISearchBar

- (void)setAlpha:(CGFloat)alpha {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:%c(UISearchTextField)]) {
            UISearchTextField *textField = (UISearchTextField *)subview;

            CGFloat accessoryAlpha = (alpha < 0.1) ? 0.0 : (alpha * 0.6);
            
            if (textField.leftView) {
                textField.leftView.alpha = accessoryAlpha;
            }
            if (textField.rightView) {
                textField.rightView.alpha = accessoryAlpha;
                for (UIView *rvSubview in textField.rightView.subviews) {
                    if ([rvSubview isKindOfClass:[UIImageView class]]) {
                        rvSubview.alpha = accessoryAlpha;
                    }
                }
            }
            
            for (UIView *tfSubview in textField.subviews) {
                if ([tfSubview isKindOfClass:[UIImageView class]]) {
                    tfSubview.alpha = accessoryAlpha;
                }
            }
        }
    }
}

- (void)setTransform:(CGAffineTransform)transform {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:%c(UISearchTextField)]) {
            UISearchTextField *textField = (UISearchTextField *)subview;

            CGFloat accessoryAlpha = (fabs(transform.ty) > 10) ? 0.0 : 0.6;
            
            if (textField.leftView) {
                textField.leftView.alpha = accessoryAlpha;
            }
            if (textField.rightView) {
                textField.rightView.alpha = accessoryAlpha;
                for (UIView *rvSubview in textField.rightView.subviews) {
                    if ([rvSubview isKindOfClass:[UIImageView class]]) {
                        rvSubview.alpha = accessoryAlpha;
                    }
                }
            }
            
            for (UIView *tfSubview in textField.subviews) {
                if ([tfSubview isKindOfClass:[UIImageView class]]) {
                    tfSubview.alpha = accessoryAlpha;
                }
            }
        }
    }
}

%end

%hook CKDetailsSearchResultsTitleHeaderCell

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }

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
                if ([subview isKindOfClass:[UILabel class]]) {
                    UILabel *label = (UILabel *)subview;
                    label.textColor = titleColor;
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
                if ([subview isKindOfClass:[UILabel class]]) {
                    UILabel *label = (UILabel *)subview;
                    label.textColor = titleColor;
                }
            }
        }
    }
}

%end

%hook CKSearchResultsTitleHeaderCell

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
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
                if ([subview isKindOfClass:[UILabel class]]) {
                    UILabel *label = (UILabel *)subview;
                    label.textColor = titleColor;
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
                if ([subview isKindOfClass:[UILabel class]]) {
                    UILabel *label = (UILabel *)subview;
                    label.textColor = titleColor;
                }
            }
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
    
    for (CALayer *sublayer in self.layer.sublayers) {
        if ([sublayer isKindOfClass:%c(CKPinnedConversationActivityItemViewBackdropLayer)]) {
            if (bubbleColor) {
                sublayer.backgroundColor = bubbleColor.CGColor;
            }
        } else if ([sublayer isKindOfClass:%c(CKPinnedConversationActivityItemViewShadowLayer)]) {
            sublayer.opacity = 0.3;
        }
    }
    
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
    
    for (CALayer *sublayer in self.layer.sublayers) {
        if ([sublayer isKindOfClass:%c(CKPinnedConversationActivityItemViewBackdropLayer)]) {
            if (bubbleColor) {
                sublayer.backgroundColor = bubbleColor.CGColor;
            }
        } else if ([sublayer isKindOfClass:%c(CKPinnedConversationActivityItemViewShadowLayer)]) {
            sublayer.opacity = 0.3;
        }
    }
    
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
        
        for (UIView *subview in [self.superview.subviews copy]) {
            if ([subview isKindOfClass:[UIImageView class]]) {
                UIImageView *imgView = (UIImageView *)subview;
                if (imgView.contentMode == UIViewContentModeScaleAspectFill) {
                    [imgView removeFromSuperview];
                }
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
    
    for (UIView *subview in self.subviews) {
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
    
    for (UIView *subview in [self.subviews copy]) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
            [subview removeFromSuperview];
        }
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
    
    if (!isTweakEnabled()) {
        return;
    }
    
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
    
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIVisualEffectView class]]) {
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
}

%end

%hook CKMessageAcknowledgmentPickerBarItemViewPhone

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    UIColor *accentColor = getSystemTintColor();
    if (!accentColor) {
        return;
    }
    
    UIView *selfView = (UIView *)self;
    
    if (selfView.layer.sublayers.count == 3) {
        CALayer *highlightLayer = selfView.layer.sublayers[0];
        
        if (highlightLayer.cornerRadius > 0 && highlightLayer.backgroundColor) {
            UIColor *currentColor = [UIColor colorWithCGColor:highlightLayer.backgroundColor];
            CGFloat r, g, b, a;
            
            if ([currentColor getRed:&r green:&g blue:&b alpha:&a]) {
                BOOL isStockGreen = (r > 0.15 && r < 0.25 && g > 0.75 && g < 0.9 && b > 0.3 && b < 0.4);
                BOOL isStockBlue = (r < 0.1 && g > 0.4 && g < 0.6 && b > 0.9);
                
                if (isStockGreen || isStockBlue) {
                    highlightLayer.backgroundColor = accentColor.CGColor;
                }
            }
        }
    }
}

%end

%hook CKCanvasBackButtonView

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled()) {
        return;
    }
    
    UIColor *customTint = getSystemTintColor();
    if (!customTint) {
        return;
    }
    
    CGFloat h, s, b, a;
    if ([customTint getHue:&h saturation:&s brightness:&b alpha:&a]) {
        s *= 0.5;
        b = MIN(1.0, b * 1.3);
        customTint = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
    }
    
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIView class]]) {
            for (UIView *innerView in subview.subviews) {
                if ([innerView isKindOfClass:[UILabel class]]) {
                    UILabel *label = (UILabel *)innerView;
                    label.textColor = customTint;
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
    
    UIColor *customTint = getSystemTintColor();
    if (!customTint) {
        return;
    }
    
    // Create a lighter version of the accent color
    CGFloat h, s, b, a;
    if ([customTint getHue:&h saturation:&s brightness:&b alpha:&a]) {
        s *= 0.5;
        b = MIN(1.0, b * 1.3);
        customTint = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
    }
    
    // Find the UIView container, then the UILabel inside it
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIView class]]) {
            for (UIView *innerView in subview.subviews) {
                if ([innerView isKindOfClass:[UILabel class]]) {
                    UILabel *label = (UILabel *)innerView;
                    label.textColor = customTint;
                }
            }
        }
    }
}

%end

%hook CKPinnedConversationTypingBubble

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !self.window) {
        return;
    }
    
    UIColor *typingColor = getReceivedBubbleColor();
    if (!typingColor) {
        return;
    }
    
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
            if (b > 0.5) {
                b *= 0.4;
            } else {
                b = MIN(1.0, b * 2.0);
            }
            UIColor *dotColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
            
            if (dotsContainerLayer.sublayers.count > 0) {
                CAReplicatorLayer *replicatorLayer = (CAReplicatorLayer *)dotsContainerLayer.sublayers[0];
                if ([replicatorLayer.sublayers firstObject]) {
                    CALayer *instanceLayer = [replicatorLayer.sublayers firstObject];
                    instanceLayer.backgroundColor = dotColor.CGColor;
                }
            }
        }
    }
}

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        return;
    }
    
    UIColor *typingColor = getReceivedBubbleColor();
    if (!typingColor) {
        return;
    }
    
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
            if (b > 0.5) {
                b *= 0.4;
            } else {
                b = MIN(1.0, b * 2.0);
            }
            UIColor *dotColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
            
            if (dotsContainerLayer.sublayers.count > 0) {
                CAReplicatorLayer *replicatorLayer = (CAReplicatorLayer *)dotsContainerLayer.sublayers[0];
                if ([replicatorLayer.sublayers firstObject]) {
                    CALayer *instanceLayer = [replicatorLayer.sublayers firstObject];
                    instanceLayer.backgroundColor = dotColor.CGColor;
                }
            }
        }
    }
}

%end

%hook CKConversationListTypingIndicatorView

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        return;
    }
    
    UIColor *typingColor = getReceivedBubbleColor();
    if (!typingColor) {
        return;
    }
    
    CALayer *typingLayer = nil;
    @try {
        typingLayer = [self valueForKey:@"typingLayer"];
    } @catch (NSException *e) {
        return;
    }
    
    if (!typingLayer || typingLayer.sublayers.count < 2) {
        return;
    }
    
    CALayer *bubbleContainer = typingLayer.sublayers[0];
    if (bubbleContainer.sublayers.count >= 3) {
        for (CALayer *bubbleLayer in bubbleContainer.sublayers) {
            bubbleLayer.backgroundColor = typingColor.CGColor;
        }
    }
    
    CALayer *dotsContainer = typingLayer.sublayers[1];
    if (dotsContainer.sublayers.count > 0) {
        CAReplicatorLayer *replicatorLayer = (CAReplicatorLayer *)dotsContainer.sublayers[0];
        
        CGFloat h, s, b, a;
        if ([typingColor getHue:&h saturation:&s brightness:&b alpha:&a]) {
            if (b > 0.5) {
                b *= 0.4;
            } else {
                b = MIN(1.0, b * 2.0);
            }
            UIColor *dotColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
            
            if ([replicatorLayer.sublayers firstObject]) {
                CALayer *instanceLayer = [replicatorLayer.sublayers firstObject];
                instanceLayer.backgroundColor = dotColor.CGColor;
            }
        }
    }
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !self.window) {
        return;
    }
    
    UIColor *typingColor = getReceivedBubbleColor();
    if (!typingColor) {
        return;
    }

    CALayer *typingLayer = nil;
    @try {
        typingLayer = [self valueForKey:@"typingLayer"];
    } @catch (NSException *e) {
        return;
    }
    
    if (!typingLayer || typingLayer.sublayers.count < 2) {
        return;
    }
    
    CALayer *bubbleContainer = typingLayer.sublayers[0];
    if (bubbleContainer.sublayers.count >= 3) {
        for (CALayer *bubbleLayer in bubbleContainer.sublayers) {
            bubbleLayer.backgroundColor = typingColor.CGColor;
        }
    }
    
    CALayer *dotsContainer = typingLayer.sublayers[1];
    if (dotsContainer.sublayers.count > 0) {
        CAReplicatorLayer *replicatorLayer = (CAReplicatorLayer *)dotsContainer.sublayers[0];
        
        CGFloat h, s, b, a;
        if ([typingColor getHue:&h saturation:&s brightness:&b alpha:&a]) {
            if (b > 0.5) {
                b *= 0.4;
            } else {
                b = MIN(1.0, b * 2.0);
            }
            UIColor *dotColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
            
            if ([replicatorLayer.sublayers firstObject]) {
                CALayer *instanceLayer = [replicatorLayer.sublayers firstObject];
                instanceLayer.backgroundColor = dotColor.CGColor;
            }
        }
    }
}

%end

%hook CKTypingView

- (void)layoutSubviews {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        return;
    }
    
    [self applyTypingIndicatorColors];
}

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled() || !self.window) {
        return;
    }
    
    [self applyTypingIndicatorColors];
}

- (void)setIndicatorLayer:(CALayer *)layer {
    %orig;
    
    if (!isTweakEnabled() || !isCustomBubbleColorsEnabled()) {
        return;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self applyTypingIndicatorColors];
    });
}

%new
- (void)applyTypingIndicatorColors {
    UIColor *typingColor = getReceivedBubbleColor();
    if (!typingColor) {
        return;
    }
    
    CALayer *indicatorLayer = nil;
    @try {
        indicatorLayer = [self valueForKey:@"indicatorLayer"];
    } @catch (NSException *e) {
        return;
    }
    
    if (!indicatorLayer || indicatorLayer.sublayers.count < 2) {
        return;
    }
    
    CALayer *bubbleContainer = indicatorLayer.sublayers[0];
    if (bubbleContainer.sublayers.count >= 3) {
        for (CALayer *bubbleLayer in bubbleContainer.sublayers) {
            bubbleLayer.backgroundColor = typingColor.CGColor;
        }
    }
    
    CALayer *dotsContainer = indicatorLayer.sublayers[1];
    if (dotsContainer.sublayers.count > 0) {
        CAReplicatorLayer *replicatorLayer = (CAReplicatorLayer *)dotsContainer.sublayers[0];
        
        CGFloat h, s, b, a;
        if ([typingColor getHue:&h saturation:&s brightness:&b alpha:&a]) {
            if (b > 0.5) {
                b *= 0.4;
            } else {
                b = MIN(1.0, b * 2.0);
            }
            UIColor *dotColor = [UIColor colorWithHue:h saturation:s brightness:b alpha:a];
            
            if ([replicatorLayer.sublayers firstObject]) {
                CALayer *instanceLayer = [replicatorLayer.sublayers firstObject];
                instanceLayer.backgroundColor = dotColor.CGColor;
            }
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
    
    CGFloat h, s, b, a;
    if ([customTint getHue:&h saturation:&s brightness:&b alpha:&a]) {
        s = MIN(1.0, s * 1.1);
        
        if (isDarkMode()) {
            b *= 0.5;
        } else {
            b = MIN(1.0, b * 1.2);
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

    CGFloat h, s, b, a;
    if ([customTint getHue:&h saturation:&s brightness:&b alpha:&a]) {
        s = MIN(1.0, s * 1.1);
        
        if (isDarkMode()) {
            b *= 0.5;
        } else {
            b = MIN(1.0, b * 1.2);
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
                b *= 0.5;
            } else {
                b = MIN(1.0, b * 1.2);
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
    
    for (UIView *subview in [contentView.subviews copy]) {
        if ([subview isKindOfClass:[UIImageView class]]) {
            UIImageView *imgView = (UIImageView *)subview;
            if (imgView.frame.origin.x == 0 && imgView.frame.origin.y == 0) {
                [imgView removeFromSuperview];
            }
        }
    }
    
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
    
    for (UIView *subview in self.subviews) {
        if ([subview isKindOfClass:[UIButton class]]) {
            UIButton *button = (UIButton *)subview;
            CGSize buttonSize = button.frame.size;
            
            if (buttonSize.width > 27 && buttonSize.width < 28 && 
                buttonSize.height > 27 && buttonSize.height < 28) {
                
                for (UIView *btnSubview in [button.subviews copy]) {
                    if ([btnSubview isKindOfClass:[UIImageView class]]) {
                        [btnSubview removeFromSuperview];
                        break;
                    }
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
                    arrowOverlay.frame = CGRectMake((buttonSize.width - arrowSize.width) / 2,
                                                   (buttonSize.height - arrowSize.height) / 2,
                                                   arrowSize.width,
                                                   arrowSize.height);
                    
                    [button addSubview:arrowOverlay];
                }
                
                break;
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

- (void)didMoveToWindow {
    %orig;
    
    if (!isTweakEnabled() || !self.window) {
        return;
    }
    
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

    for (UIView *subview in self.subviews) {
        if ([subview class] == [UIView class]) {
            subview.backgroundColor = [UIColor clearColor];
        }
    }
}

%end

