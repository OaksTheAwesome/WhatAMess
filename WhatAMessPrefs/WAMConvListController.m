#import <Foundation/Foundation.h>
#import "WAMConvListController.h"
#import "WAMBaseListController.h"

@implementation WAMConvListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"ConvList" target:self];
    }
    for (PSSpecifier *spec in _specifiers) {
        NSString *baseKey = spec.properties[@"lightModeKey"];
        if (!baseKey) continue;
        spec.properties[@"key"] = [self keyForBase:baseKey];
    }
    return _specifiers;
}

#pragma mark - Color Pickers

- (void)pickBackgroundColor {
    [self showColorPickerForKey:@"convListBackgroundColor" defaultColor:[UIColor blackColor]];
}

- (void)pickCellColor {
    [self showColorPickerForKey:@"convListCellColor" defaultColor:[UIColor blackColor]];
}

- (void)pickTitleColor {
    [self showColorPickerForKey:@"titleTextColor" defaultColor:[UIColor whiteColor]];
}

- (void)pickMessagePreviewColor {
    [self showColorPickerForKey:@"messagePreviewTextColor" defaultColor:[UIColor grayColor]];
}

- (void)pickDateTimeColor {
    [self showColorPickerForKey:@"dateTimeTextColor" defaultColor:[UIColor grayColor]];
}

- (void)pickPinnedBubbleColor {
    [self showColorPickerForKey:@"pinnedBubbleColor" defaultColor:[UIColor darkGrayColor]];
}

- (void)pickPinnedBubbleTextColor {
    [self showColorPickerForKey:@"pinnedBubbleTextColor" defaultColor:[UIColor whiteColor]];
}

- (void)pickConversationListTitleColor {
    [self showColorPickerForKey:@"conversationListTitleColor" defaultColor:[UIColor whiteColor]];
}

#pragma mark - Image Picker

- (void)pickConvListBgImage {
    NSString *path = [self isEditingDarkMode]
        ? @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background_dark.jpg"
        : @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background.jpg";
    [self showImagePickerForDestinationPath:path];
}

@end
