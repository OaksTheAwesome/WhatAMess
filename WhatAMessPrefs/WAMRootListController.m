#import <Foundation/Foundation.h>
#import "WAMRootListController.h"
#import <spawn.h>

@implementation WAMRootListController {
	NSString *_currentColorKey;
}
 /* Essentially sets up prefences in Settings? */
- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return _specifiers;
}

 /* Runs before settings view disappears. Sends notification to be seen by other processes to know if
 a preference has been changed. Signals tweak to reload settings following leaving settings pane. */
- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	
	// Post notification when leaving settings
	CFNotificationCenterPostNotification(
		CFNotificationCenterGetDarwinNotifyCenter(),
		CFSTR("com.oakstheawesome.whatamessprefs/prefsChanged"),
		NULL, NULL, YES
	);
}

/* Resping method lol */
- (void)respring {
	/* Confirmation alert dialog */
	UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Respring"
		message:@"Are you sure you want to respring?"
		preferredStyle:UIAlertControllerStyleAlert];
	
	[alert addAction:[UIAlertAction actionWithTitle:@"Not Yet" style:UIAlertActionStyleCancel handler:nil]];
	
	[alert addAction:[UIAlertAction actionWithTitle:@"Respring" style:UIAlertActionStyleDestructive handler:^(UIAlertAction *action) {
		/* reload sb */
		pid_t pid;
		const char* args[] = {"sbreload", NULL};
		posix_spawn(&pid, "/var/jb/usr/bin/sbreload", NULL, NULL, (char* const*)args, NULL);
	}]];
	
	[self presentViewController:alert animated:YES completion:nil];
}


@end