#import <UIKit/UIKit.h>

@interface CKConversationListCollectionViewController : UICollectionViewController
@end

static BOOL isEnabled;

%hook CKConversationListCollectionViewController

-(void) viewDidLoad {
	NSUserDefaults *bundleDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs"];
	isEnabled = [bundleDefaults objectForKey:@"isEnabled"] ? [bundleDefaults boolForKey:@"isEnabled"] : YES;

	if (!isEnabled) {
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
