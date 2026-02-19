#import <Foundation/Foundation.h>
#import "WAMChatBubbleController.h"
#import "WAMBaseListController.h"

@implementation WAMChatBubbleController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Bubbles" target:self];
    }
    return _specifiers;
}

#pragma mark - Color Pickers

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

@end