#import <UIKit/UIKit.h>

@interface CKConversationListCollectionViewController : UICollectionViewController
@end

static BOOL isEnabled;

BOOL isTweakEnabled() {
	if (isEnabled) {
		return isEnabled;
	}

	NSUserDefaults *bundleDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs"];
	isEnabled = [bundleDefaults objectForKey:@"isEnabled"] ? [bundleDefaults boolForKey:@"isEnabled"] : YES;

	return isEnabled;

}

BOOL isConvColorBgEnabled() {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs"];
    return [prefs objectForKey:@"isConvColorBgEnabled"] ? [prefs boolForKey:@"isConvColorBgEnabled"] : YES;
}

BOOL isConvImageBgEnabled() {
    NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs"];
    return [prefs objectForKey:@"isConvImageBgEnabled"] ? [prefs boolForKey:@"isConvImageBgEnabled"] : NO;
}

%hook CKConversationListCollectionViewController

-(void) viewDidLoad {
	if (!isTweakEnabled()) {
		%orig;
		return;
	}

	%orig;

	self.view.backgroundColor = [UIColor clearColor];
	self.collectionView.backgroundColor = [UIColor clearColor];

	NSString *imagePath = @"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background.jpg";
	BOOL hasImage = [[NSFileManager defaultManager] fileExistsAtPath:imagePath];

	for (UIView *sub in self.view.subviews) {
		if (sub.tag == 999) [sub removeFromSuperview];
	}

	UIView *convlistView = nil;
	
		else if (isConvColorBgEnabled()) {
			UIView *convlistView = [[UIView alloc] initWithFrame:self.collectionView.bounds];
			convlistView.backgroundColor = [UIColor blueColor];
			convlistView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	
			self.collectionView.backgroundView = convlistView;
		}
	
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
		if (isConvImageBgEnabled()) {
			self.backgroundColor = [UIColor clearColor];
			self.contentView.backgroundColor = [UIColor clearColor];
			self.layer.backgroundColor = [UIColor clearColor].CGColor;
		} else if (isConvColorBgEnabled()) {
			self.contentView.backgroundColor = [UIColor redColor];
		}
	}
	return self;
}


%end



