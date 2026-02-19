#import <Foundation/Foundation.h>
#import "WAMRootListController.h"
#import "WAMBaseListController.h"
#import <spawn.h>

@implementation WAMRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

#pragma mark - Color Pickers

- (void)pickSystemTintColor {
    [self showColorPickerForKey:@"systemTintColor" defaultColor:[UIColor systemBlueColor]];
}

- (void)pickCellTintColor {
    [self showColorPickerForKey:@"cellTintColor" defaultColor:[UIColor systemBlueColor]];
}

#pragma mark - Actions

- (void)respring {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Respring"
        message:@"Are you sure you want to respring?"
        preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"Not Yet"
        style:UIAlertActionStyleCancel handler:nil]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Respring"
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *action) {
            pid_t pid;
            const char *args[] = {"sbreload", NULL};
            posix_spawn(&pid, "/var/jb/usr/bin/sbreload", NULL, NULL, (char *const *)args, NULL);
        }]];

    [self presentViewController:alert animated:YES completion:nil];
}

- (void)discordLink {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://discord.com/users/384917479752990731"] options:@{} completionHandler:nil];
}

- (void)twitterLink {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://x.com/oakstheawesome"] options:@{} completionHandler:nil];
}

- (void)youTubeLink {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://youtube.com/@oakstheawesome"] options:@{} completionHandler:nil];
}

- (void)gitHubLink {
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"https://github.com/OaksTheAwesome/WhatAMess/tree/main"] options:@{} completionHandler:nil];
}

@end
