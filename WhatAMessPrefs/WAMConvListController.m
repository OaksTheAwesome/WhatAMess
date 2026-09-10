#import <Foundation/Foundation.h>
#import "WAMConvListController.h"
#import "WAMBaseListController.h"
#import "WAMPresetModel.h"
#import "WAMGradientBuilderController.h"

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
    [self applySearchBgLock];
    return _specifiers;
}

- (void)applySearchBgLock {
    BOOL platters = [[self readPrefs][[self keyForBase:@"isNavButtonBlurEnabled"]] boolValue]
                 && [[self readPrefs][[self keyForBase:@"isModernNavBarEnabled"]] boolValue];
    for (PSSpecifier *spec in _specifiers) {
        if (![spec.properties[@"key"] isEqualToString:@"isSearchBgEnabled"]) continue;
        [spec setProperty:@(!platters) forKey:@"enabled"];
        if (platters && ![[self readPrefs][@"isSearchBgEnabled"] boolValue]) {
            [self saveValue:@YES forKey:@"isSearchBgEnabled"];
            [self postNotification];
        }
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
}

#pragma mark - Color Pickers

- (void)createConvGradient {
    BOOL dark = [self isEditingDarkMode];
    WAMGradientBuilderController *b = [[WAMGradientBuilderController alloc] initWithStops:nil];
    b.onDone = ^(NSArray<NSString *> *stops, WAMGradientDirection direction){
        if (stops.count >= 2) [WAMPresetStore setGradientBackground:stops direction:direction chat:NO dark:dark];
        [self dismissViewControllerAnimated:YES completion:nil];
    };
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:b];
    [self presentViewController:nav animated:YES completion:nil];
}

- (void)pickBackgroundColor {
    [self showColorPickerForKey:@"convListBackgroundColor" defaultColor:[UIColor blackColor]];
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
        ? WAMJBPath(@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background_dark.jpg")
        : WAMJBPath(@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background.jpg");
    [self showImagePickerForDestinationPath:path];
}

@end
