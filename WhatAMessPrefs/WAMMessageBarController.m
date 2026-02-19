#import <Foundation/Foundation.h>
#import "WAMMessageBarController.h"
#import "WAMBaseListController.h"

@implementation WAMMessageBarController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"MessageBar" target:self];
    }
    return _specifiers;
}

#pragma mark - Color Pickers

- (void)pickInputFieldBackgroundColor {
    [self showColorPickerForKey:@"inputFieldBackgroundColor" defaultColor:[UIColor darkGrayColor]];
}

- (void)pickPlaceholderTextColor {
    [self showColorPickerForKey:@"placeholderTextColor" defaultColor:[UIColor grayColor]];
}

- (void)pickMessageInputTextColor {
    [self showColorPickerForKey:@"messageInputTextColor" defaultColor:[UIColor grayColor]];
}

- (void)pickMessageBarTintColor {
    [self showColorPickerForKey:@"messageBarTintColor" defaultColor:[UIColor systemBlueColor]];
}

@end