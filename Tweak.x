#import <UIKit/UIKit.h>

/*Interfaces, declare to hook certain things. Ex: Want to change label colors, hook CKLabel,
inherits attributes from UILabel*/
/*---------------------------------------------------*/
@interface CKConversationListCollectionViewController : UICollectionViewController
-(void)updateBackground;
-(void)makeSubviewsTransparent:(UIView *)view;
- (void)applyCustomColorsToCKLabelsInView:(UIView *)view;
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

/* ===================
  PREFERENCE THINGS 
==================== */

/* Define paths for preferences to save to (in the case of kImagePath, where to save image
and how to name it [background.jpg]). Notification is used to post the preference change and update tweak.
In case of messages, no respring is *required*, just close and reopen app a couple of times. */
/*--------------------------------------------------------------------------*/
#define kPrefsPath @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs.plist"
#define kImagePath @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background.jpg"
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

/* Checks if conversation list image background is enabled. Reads directly from prefs. Defaults to NO. */
BOOL isConvImageBgEnabled() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
	return prefs[@"isConvImageBgEnabled"] ? [prefs[@"isConvImageBgEnabled"] boolValue] : NO;
}

/* Checks if custom text colors should be enabled. Uses loadPrefs, defaults to NO. */
BOOL isCustomTextColorsEnabled() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"isCustomTextColorsEnabled"] ? [prefs[@"isCustomTextColorsEnabled"] boolValue] : NO;
}

/* Checks the amount of blur to apply to image based on user slider input. 
Uses loadPrefs, defaults to 0.0 (no blurring). */
CGFloat getImageBlurAmount() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"imageBlurAmount"] ? [prefs[@"imageBlurAmount"] floatValue] : 0.0;
}

/* Checks if input string is nil/empty. If it is, returns nil. If hex string has a leading "#", removes
that and ensures scanner only sees hex digits. Converts the hex string to an int. NSScanner parses string
into a numeric value. Then extracts RGB components and returns a useable UIColor. */
UIColor *colorFromHex(NSString *hexString) {
	if (!hexString || [hexString length] == 0) return nil;

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

/* Loads prefs, reads background color hex from prefs string "convListBackgroundColor". Converts to 
UIColor using colorFromHex, and defaults to black otherwise. */
UIColor *getBackgroundColor() {
	NSDictionary *prefs = loadPrefs();
	NSString *colorString = prefs[@"convListBackgroundColor"];
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

	CIFilter *blurFilter = [CIFilter filterWithName:@"CIGaussianBlur"];
	[blurFilter setValue:inputImage forKey:kCIInputImageKey];
	[blurFilter setValue:@(blurAmount) forKey:kCIInputRadiusKey];

	CIImage *outputImage = [blurFilter outputImage];

	CGRect extent = [inputImage extent];
	outputImage = [outputImage imageByCroppingToRect:extent];

	CGImageRef cgImage = [context createCGImage:outputImage fromRect:extent];
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

/* ===========
    HOOKS 
============*/

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
 
 /* Overrides label color when inside a cell. Checks label types and applies accoring colors from prefs.
 Ensures all labels in cells follow tweak's color settings. */
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
	%orig;
}

%end

/* Overrides setTintColor to enforce custom tint colors in conv cells. Checks whether the tweak and custom
text colors are enabled. Checks if image view is inside CKConvListCollectionViewConvCell. If in such cell,
sets tint color, if not, calls original method.*/
%hook UIImageView

-(void)setTintColor:(UIColor *)color {
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

%end

/* Hooks the navigation bar background and removes any defualt blurs. Creates a new blur effect and expands
it to provide more room for gradient. Gradient mask allows blur to fade smoothly from opaque to transparent,
top to bottom. */
%hook _UIBarBackground
- (void)layoutSubviews {
    %orig;

    if (!isTweakEnabled()) return;

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
        (id)[UIColor colorWithWhite:0 alpha:1.0].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0.9].CGColor,
		(id)[UIColor colorWithWhite:0 alpha:0.55].CGColor,
		(id)[UIColor colorWithWhite:0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:0 alpha:0.0].CGColor
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