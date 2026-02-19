#import <Foundation/Foundation.h>
#import "WAMChatViewController.h"
#import "WAMBaseListController.h"

@implementation WAMChatViewController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"ChatView" target:self];
    }
    return _specifiers;
}

#pragma mark - Color Pickers

- (void)pickChatBackgroundColor {
    [self showColorPickerForKey:@"chatBackgroundColor" defaultColor:[UIColor blackColor]];
}

- (void)pickMessageBarButtonColor {
    [self showColorPickerForKey:@"messageBarButtonColor" defaultColor:[UIColor systemBlueColor]];
}

- (void)pickLinkPreviewBackgroundColor {
    [self showColorPickerForKey:@"linkPreviewBackgroundColor" defaultColor:[UIColor darkGrayColor]];
}

- (void)pickLinkPreviewTextColor {
    [self showColorPickerForKey:@"linkPreviewTextColor" defaultColor:[UIColor whiteColor]];
}

#pragma mark - Image Picker

- (void)pickChatBgImage {
    [self showImagePickerForDestinationPath:@"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background.jpg"];
}

@end
