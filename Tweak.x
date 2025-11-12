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
	UIView *convlistView = [[UIView alloc] init];
	convlistView.backgroundColor = [UIColor blueColor];
	convlistView.translatesAutoresizingMaskIntoConstraints = false;
	[self.view addSubview:convlistView];

	[convlistView.topAnchor constraintEqualToAnchor: self.view.topAnchor].active = true;
	[convlistView.widthAnchor constraintEqualToConstant:100].active = YES;
	[convlistView.heightAnchor constraintEqualToConstant:100].active = YES;
}

%end
