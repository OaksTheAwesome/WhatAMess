#import <UIKit/UIKit.h>

@interface CKConversationListCollectionViewController : UICollectionViewController
-(void)updateBackground;
@end

#define kPrefsPath @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs.plist"
#define kImagePath @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background.jpg"
#define kPrefsChangedNotification @"com.oakstheawesome.whatamessprefs/prefsChanged"

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

%hook CKConversationListCollectionViewController

-(void) viewDidLoad {
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
-(void)updateBackground {
	BOOL hasImage = [[NSFileManager defaultManager] fileExistsAtPath:kImagePath];
	UIImage *bgImage = hasImage ? [UIImage imageWithContentsOfFile:kImagePath] : nil;
	
	// Color overrides image
	if (isConvColorBgEnabled()) {
		UIView *colorView = [[UIView alloc] initWithFrame:self.collectionView.bounds];
		colorView.backgroundColor = [UIColor blueColor];
		colorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		
		self.collectionView.backgroundView = colorView;
	} else if (bgImage && isConvImageBgEnabled()) {
		UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.collectionView.bounds];
		imageView.image = bgImage;
		imageView.contentMode = UIViewContentModeScaleAspectFill;
		imageView.clipsToBounds = YES;
		imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		
		self.collectionView.backgroundView = imageView;
	} else {
		self.collectionView.backgroundView = nil;
	}
	
	[self.collectionView reloadData];
}

-(void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	%orig;
}

%end

@interface CKConversationListCollectionViewConversationCell : UICollectionViewCell
@end

%hook CKConversationListCollectionViewConversationCell

-(instancetype)initWithFrame:(CGRect)frame {
	if (!isTweakEnabled()) {
		return %orig(frame);
	}
	self = %orig(frame);
	if (self) {
		// Color overrides image
		if (isConvColorBgEnabled()) {
			self.contentView.backgroundColor = [UIColor redColor];
		} else if (isConvImageBgEnabled()) {
			self.backgroundColor = [UIColor clearColor];
			self.contentView.backgroundColor = [UIColor clearColor];
			self.layer.backgroundColor = [UIColor clearColor].CGColor;
		}
	}
	return self;
}


%end
