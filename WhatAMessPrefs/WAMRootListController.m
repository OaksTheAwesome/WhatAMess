#import <Foundation/Foundation.h>
#import "WAMRootListController.h"

@implementation WAMRootListController

- (NSArray *)specifiers {
	if (!_specifiers) {
		_specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
	}

	return _specifiers;
}

-(void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];

	CFNotificationCenterPostNotification(
		CFNotificationCenterGetDarwinNotifyCenter(),
		CFSTR("com.oakstheawesome.whatamessprefs/prefsChanged"),
		NULL, NULL, YES
	);
}

//Image picker junk, this sucked to make and I had to use some ChatGPT :(
- (void)pickConvListBgImage {
    UIImagePickerController *picker = [[UIImagePickerController alloc] init];
    picker.delegate = (id<UINavigationControllerDelegate, UIImagePickerControllerDelegate>)self;
    picker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;

   	UIWindowScene *scene = (UIWindowScene *)[UIApplication sharedApplication].connectedScenes.allObjects.firstObject;
    UIWindow *window = scene.windows.firstObject;
    UIViewController *rootVC = window.rootViewController;

    [rootVC presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<NSString *,id> *)info {
    UIImage *image = info[UIImagePickerControllerOriginalImage];
	if (!image) {
		[picker dismissViewControllerAnimated:YES completion:nil];
		return;
	}

    NSString *dirPath = @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs";
    if (![[NSFileManager defaultManager] fileExistsAtPath:dirPath]) {
        [[NSFileManager defaultManager] createDirectoryAtPath:dirPath
        withIntermediateDirectories:YES attributes:nil error:nil];
    }

    NSString *path = [dirPath stringByAppendingPathComponent:@"background.jpg"];
    NSData *data = UIImageJPEGRepresentation(image, 0.9);
    [data writeToFile:path atomically:YES];

    [picker dismissViewControllerAnimated:YES completion:nil];

	CFNotificationCenterPostNotification(
		CFNotificationCenterGetDarwinNotifyCenter(),
		CFSTR("com.oakstheawesome.whatamessprefs/prefsChanged"),
		NULL, NULL, YES
	);
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [picker dismissViewControllerAnimated:YES completion:nil];
}

@end