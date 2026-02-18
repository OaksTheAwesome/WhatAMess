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

- (void)pickSMSSentBubbleColor {
    [self showColorPickerForKey:@"sentSMSBubbleColor" defaultColor:[UIColor systemGreenColor]];
}

- (void)pickSentBubbleColor {
    [self showColorPickerForKey:@"sentBubbleColor" defaultColor:[UIColor systemBlueColor]];
}

- (void)pickReceivedBubbleColor {
    [self showColorPickerForKey:@"receivedBubbleColor" defaultColor:[UIColor darkGrayColor]];
}

- (void)pickReceivedTextColor {
    [self showColorPickerForKey:@"receivedTextColor" defaultColor:[UIColor whiteColor]];
}

- (void)pickSentTextColor {
    [self showColorPickerForKey:@"sentTextColor" defaultColor:[UIColor whiteColor]];
}

- (void)pickSMSSentTextColor {
    [self showColorPickerForKey:@"sentSMSTextColor" defaultColor:[UIColor whiteColor]];
}

- (void)pickTimestampTextColor {
    [self showColorPickerForKey:@"timestampTextColor" defaultColor:[UIColor grayColor]];
}

- (void)pickInputFieldBackgroundColor {
    [self showColorPickerForKey:@"inputFieldBackgroundColor" defaultColor:[UIColor darkGrayColor]];
}

- (void)pickPlaceholderTextColor {
    [self showColorPickerForKey:@"placeholderTextColor" defaultColor:[UIColor grayColor]];
}

- (void)pickMessageInputTextColor {
    [self showColorPickerForKey:@"messageInputTextColor" defaultColor:[UIColor whiteColor]];
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

- (void)pickMessageBarTintColor {
    [self showColorPickerForKey:@"messageBarTintColor" defaultColor:[UIColor systemBlueColor]];
}

#pragma mark - Image Picker

- (void)pickChatBgImage {
    [self showImagePickerForDestinationPath:@"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background.jpg"];
}

@end
