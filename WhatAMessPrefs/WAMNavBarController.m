#import <Foundation/Foundation.h>
#import "WAMNavBarController.h"
#import "WAMBaseListController.h"

@implementation WAMNavBarController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"NavBar" target:self];
    }
    return _specifiers;
}

#pragma mark - Color Pickers

- (void)pickNavBarTintColor {
    [self showColorPickerForKey:@"navBarTintColor" defaultColor:[UIColor systemBlueColor]];
}

- (void)pickChatContactNameColor {
    [self showColorPickerForKey:@"chatContactNameColor" defaultColor:[UIColor whiteColor]];
}

@end