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

// The button platters require Modern NavBar, so grey out their toggle when Modern NavBar is off (in the
// current editing mode) — mirrors the search-background lock on the Conversation List page. Bottom Screen
// Blur has no meaning without the platters (it dresses up the platter's own bottom search bar), so it's
// locked to the platter toggle the same way.
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
        [self reloadSpecifiers];   // re-grey the platter / bottom-blur toggles immediately
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
