#import "WAMAdvancedTintController.h"

@implementation WAMAdvancedTintController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"AdvancedTint" target:self];
    }
    return _specifiers;
}

- (void)pickUnreadDot {
    [self showColorPickerForKey:@"advancedUnreadDotColor" defaultColor:[UIColor systemBlueColor]];
}
- (void)pickSwitchTint {
    [self showColorPickerForKey:@"advancedSwitchTintColor" defaultColor:[UIColor systemBlueColor]];
}
- (void)pickSearchField {
    [self showColorPickerForKey:@"advancedSearchFieldColor" defaultColor:[UIColor systemBlueColor]];
}
- (void)pickStatusCell {
    [self showColorPickerForKey:@"advancedStatusCellColor" defaultColor:[UIColor systemBlueColor]];
}
- (void)pickTableLabel {
    [self showColorPickerForKey:@"advancedTableLabelColor" defaultColor:[UIColor systemBlueColor]];
}
- (void)pickReactionHighlight {
    [self showColorPickerForKey:@"advancedReactionHighlightColor" defaultColor:[UIColor systemBlueColor]];
}
- (void)pickReactionGlyph {
    [self showColorPickerForKey:@"advancedReactionGlyphColor" defaultColor:[UIColor systemBlueColor]];
}
- (void)pickNavButton {
    [self showColorPickerForKey:@"advancedNavButtonColor" defaultColor:[UIColor systemBlueColor]];
}
- (void)pickContactAction {
    [self showColorPickerForKey:@"advancedContactActionColor" defaultColor:[UIColor systemBlueColor]];
}
- (void)pickReactionBalloon {
    [self showColorPickerForKey:@"advancedReactionBalloonColor" defaultColor:[UIColor systemBlueColor]];
}

@end