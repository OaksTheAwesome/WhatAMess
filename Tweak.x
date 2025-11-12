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

%hook CKConversationListCollectionViewController

-(void) viewDidLoad {
	if (!isTweakEnabled()) {
		%orig;
		return;
	}

	%orig;
	UIView *convlistView = [[UIView alloc] initWithFrame:self.collectionView.bounds];
	convlistView.backgroundColor = [UIColor blueColor];
	convlistView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	
	self.collectionView.backgroundView = convlistView;
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
		self.contentView.backgroundColor = [UIColor redColor];
	}
	return self;
}


%end



