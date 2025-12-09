#import <UIKit/UIKit.h>

@interface CKConversationListCollectionViewController : UICollectionViewController
-(void)updateBackground;
-(void)makeSubviewsTransparent:(UIView *)view;
- (void)applyCustomColorsToCKLabelsInView:(UIView *)view;
@end

@interface _UINavigationBarContentView : UIView
@end

@interface _UIBarBackground : UIView
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

#define kPrefsPath @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs.plist"
#define kImagePath @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background.jpg"
#define kPrefsChangedNotification @"com.oakstheawesome.whatamessprefs/prefsChanged"

static NSDictionary *cachedPrefs = nil;

static NSDictionary *loadPrefs() {
	if (!cachedPrefs) {
		cachedPrefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
	}
	return cachedPrefs;
}

static void clearPrefsCache() {
	cachedPrefs = nil;
}

BOOL isTweakEnabled() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
	return prefs[@"isEnabled"] ? [prefs[@"isEnabled"] boolValue] : YES;
}

BOOL isConvColorBgEnabled() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
	return prefs[@"isConvColorBgEnabled"] ? [prefs[@"isConvColorBgEnabled"] boolValue] : YES;
}

BOOL isConvImageBgEnabled() {
	NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath];
	return prefs[@"isConvImageBgEnabled"] ? [prefs[@"isConvImageBgEnabled"] boolValue] : NO;
}

BOOL isCustomTextColorsEnabled() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"isCustomTextColorsEnabled"] ? [prefs[@"isCustomTextColorsEnabled"] boolValue] : NO;
}

CGFloat getImageBlurAmount() {
	NSDictionary *prefs = loadPrefs();
	return prefs[@"imageBlurAmount"] ? [prefs[@"imageBlurAmount"] floatValue] : 0.0;
}

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

UIColor *getBackgroundColor() {
	NSDictionary *prefs = loadPrefs();
	NSString *colorString = prefs[@"convListBackgroundColor"];
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
	%orig;
}

%end

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

%hook _UINavigationBarContentView

- (void)didAddSubview:(UIView *)subview {
    %orig;

    if (!isTweakEnabled()) return;

    // Only apply to _UIButtonBarButton instances
    if ([subview isKindOfClass:NSClassFromString(@"_UIButtonBarButton")]) {

        // Check for our bubble already
        BOOL hasBubble = NO;
        for (UIView *v in self.subviews) {
            if (v.tag == 9999) { // Arbitrary tag to identify our bubble
                hasBubble = YES;
                break;
            }
        }
        if (hasBubble) return;

        // Create a blur effect bubble
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial];
        UIVisualEffectView *bubble = [[UIVisualEffectView alloc] initWithEffect:blur];

        // Round it
        bubble.layer.cornerRadius = 18; // adjust radius
        bubble.layer.masksToBounds = YES;

        // Slightly smaller than button, behind it
        CGRect buttonFrame = subview.frame;
        CGFloat padding = 6;
        bubble.frame = CGRectMake(
            buttonFrame.origin.x - padding,
            buttonFrame.origin.y - padding,
            buttonFrame.size.width + 2*padding,
            buttonFrame.size.height + 2*padding
        );

        bubble.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;

        // Place behind the button
        [self insertSubview:bubble belowSubview:subview];

        // Tag for future reference
        bubble.tag = 9999;
    }
}

%end




