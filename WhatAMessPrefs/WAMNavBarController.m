#import <Foundation/Foundation.h>
#import "WAMNavBarController.h"
#import "WAMBaseListController.h"

@implementation WAMNavBarController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"NavBar" target:self];
    }
    [self applyPlatterLock];
    return _specifiers;
}

- (void)applyPlatterLock {
    NSDictionary *prefs = [self readPrefs];
    BOOL modern = [prefs[[self keyForBase:@"isModernNavBarEnabled"]] boolValue];
    BOOL platters = modern && [prefs[[self keyForBase:@"isNavButtonBlurEnabled"]] boolValue];
    for (PSSpecifier *spec in _specifiers) {
        NSString *key = spec.properties[@"lightModeKey"];
        if ([key isEqualToString:@"isNavButtonBlurEnabled"])
            [spec setProperty:@(modern) forKey:@"enabled"];
        else if ([key isEqualToString:@"isBottomBlurEnabled"] ||
                 [spec.properties[@"action"] isEqualToString:@"pickBottomBlurTintColor"])
            [spec setProperty:@(platters) forKey:@"enabled"];
    }
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    [super setPreferenceValue:value specifier:specifier];
    NSString *key = specifier.properties[@"lightModeKey"];
    if ([key isEqualToString:@"isModernNavBarEnabled"] || [key isEqualToString:@"isNavButtonBlurEnabled"])
        [self reloadSpecifiers];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];
}

#pragma mark - Color Pickers

- (void)pickNavBarTintColor {
    [self showColorPickerForKey:@"navBarTintColor" defaultColor:[UIColor systemBlueColor]];
}

- (void)pickChatContactNameColor {
    [self showColorPickerForKey:@"chatContactNameColor" defaultColor:[UIColor whiteColor]];
}

- (void)pickNavPlatterColor {
    [self showColorPickerForKey:@"navPlatterColor" defaultColor:[UIColor colorWithWhite:1.0 alpha:0.25]];
}

- (void)pickBottomBlurTintColor {
    [self showColorPickerForKey:@"bottomBlurTintColor" defaultColor:[UIColor colorWithWhite:0.0 alpha:0.25]];
}

@end
