#import <UIKit/UIKit.h>

@interface CKConversationListCollectionView : UICollectionView
@end

static BOOL isEnabled;

%hook CKConversationListCollectionView

-(void) viewDidLoad {
	NSUserDefaults *bundleDefaults = [[NSUserDefaults alloc] initWithSuiteName:@"com.oakstheawesome.whatamessprefs"];
	isEnabled = [bundleDefaults objectForKey:@"isEnabled"] ? [bundleDefaults boolForKey:@"isEnabled"] : YES;

	if (!isEnabled) {
		%orig;
		return;
	}
}

%end