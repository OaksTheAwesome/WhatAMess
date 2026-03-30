#import <Foundation/Foundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "WAMRootListController.h"
#import "WAMBaseListController.h"
#import <spawn.h>
#import <sys/wait.h>

@implementation WAMRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    return _specifiers;
}

#pragma mark - Color Pickers

- (void)pickSystemTintColorLight {
    [self showColorPickerForKeyDirect:@"systemTintColor" defaultColor:[UIColor systemBlueColor]];
}

- (void)pickSystemTintColorDark {
    [self showColorPickerForKeyDirect:@"systemTintColorDark" defaultColor:[UIColor systemBlueColor]];
}

- (void)pickCellTintColorLight {
    [self showColorPickerForKeyDirect:@"cellTintColor" defaultColor:[UIColor systemBlueColor]];
}

- (void)pickCellTintColorDark {
    [self showColorPickerForKeyDirect:@"cellTintColorDark" defaultColor:[UIColor systemBlueColor]];
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

#pragma mark - Preset Export

- (BOOL)zipDirectory:(NSString *)dirPath toFile:(NSString *)zipPath {
    pid_t pid;
    const char *args[] = {
        "zip", "-r", "-j",
        [zipPath UTF8String],
        [dirPath UTF8String],
        NULL
    };
    int result = posix_spawn(&pid, "/var/jb/usr/bin/zip", NULL, NULL, (char *const *)args, NULL);
    if (result != 0) return NO;
    int status;
    waitpid(pid, &status, 0);
    return WEXITSTATUS(status) == 0;
}

- (void)exportPreset {
    // Keys to exclude from the preset
    NSSet *excludedKeys = [NSSet setWithArray:@[
        @"editingDarkMode",
        @"isEnabled"
    ]];

    // Read current prefs and strip excluded keys
    NSMutableDictionary *prefs = [self readPrefs];
    NSMutableDictionary *presetPrefs = [NSMutableDictionary new];
    for (NSString *key in prefs) {
        if (![excludedKeys containsObject:key]) {
            presetPrefs[key] = prefs[key];
        }
    }

    // Create a temp working directory
    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"wampreset_export"];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:tempDir error:nil];
    [fm createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:nil];

    // Write preset.plist
    NSString *plistPath = [tempDir stringByAppendingPathComponent:@"preset.plist"];
    [presetPrefs writeToFile:plistPath atomically:YES];

    // Copy background images if they exist
    NSDictionary *images = @{
        @"background.jpg":           @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background.jpg",
        @"background_dark.jpg":      @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background_dark.jpg",
        @"chat_background.jpg":      @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background.jpg",
        @"chat_background_dark.jpg": @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background_dark.jpg"
    };

    for (NSString *destName in images) {
        NSString *sourcePath = images[destName];
        if ([fm fileExistsAtPath:sourcePath]) {
            [fm copyItemAtPath:sourcePath
                        toPath:[tempDir stringByAppendingPathComponent:destName]
                         error:nil];
        }
    }

    // Zip it all up
    NSString *zipPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"WhatAMess_Preset.wampreset"];
    [fm removeItemAtPath:zipPath error:nil];

    BOOL zipped = [self zipDirectory:tempDir toFile:zipPath];

    if (!zipped) {
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"Export Failed"
            message:@"Could not create preset file. Please try again."
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
            style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    // Clean up temp dir
    [fm removeItemAtPath:tempDir error:nil];

    // Present share sheet
    NSURL *zipURL = [NSURL fileURLWithPath:zipPath];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc]
        initWithActivityItems:@[zipURL]
        applicationActivities:nil];

    // iPad support
    activityVC.popoverPresentationController.sourceView = self.view;
    activityVC.popoverPresentationController.sourceRect = CGRectMake(
        self.view.bounds.size.width / 2,
        self.view.bounds.size.height / 2,
        1, 1
    );

    [self presentViewController:activityVC animated:YES completion:nil];
}

#pragma mark - Preset Import

- (void)importPreset {
    @try {
        UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc]
            initForOpeningContentTypes:@[UTTypeContent, UTTypeData]
            asCopy:YES];
        picker.delegate = self;
        picker.allowsMultipleSelection = NO;
        dispatch_async(dispatch_get_main_queue(), ^{
            [self presentViewController:picker animated:YES completion:nil];
        });
    } @catch (NSException *e) {
        [self showImportError:[NSString stringWithFormat:@"%@: %@", e.name, e.reason]];
    }
}

- (void)applyPresetFromURL:(NSURL *)fileURL {
    NSString *ext = fileURL.pathExtension.lowercaseString;
    if (![ext isEqualToString:@"wampreset"] && ![ext isEqualToString:@"zip"]) {
        [self showImportError:@"Please select a .wampreset or .zip file."];
        return;
    }

    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"wampreset_import"];
    [fm removeItemAtPath:tempDir error:nil];
    [fm createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:nil];

    pid_t pid;
    const char *args[] = {
        "unzip", "-o",
        [fileURL.path UTF8String],
        "-d", [tempDir UTF8String],
        NULL
    };
    int spawnResult = posix_spawn(&pid, "/var/jb/usr/bin/unzip", NULL, NULL, (char *const *)args, NULL);
    if (spawnResult != 0) {
        [self showImportError:@"Could not launch unzip utility."];
        return;
    }
    int status;
    waitpid(pid, &status, 0);
    if (WEXITSTATUS(status) != 0) {
        [self showImportError:@"Could not unzip preset file."];
        return;
    }

    NSString *plistPath = [tempDir stringByAppendingPathComponent:@"preset.plist"];
    if (![fm fileExistsAtPath:plistPath]) {
        [self showImportError:@"Invalid preset file — missing preset.plist."];
        return;
    }

    NSDictionary *importedPrefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    if (!importedPrefs) {
        [self showImportError:@"Could not read preset data."];
        return;
    }

        // Preserve only non-preset keys, then apply imported prefs fresh
        NSMutableDictionary *currentPrefs = [self readPrefs];
        NSMutableDictionary *freshPrefs = [NSMutableDictionary new];

        // Keep only keys that are intentionally excluded from presets
        NSSet *preservedKeys = [NSSet setWithArray:@[@"editingDarkMode", @"isEnabled"]];
        for (NSString *key in preservedKeys) {
            if (currentPrefs[key]) freshPrefs[key] = currentPrefs[key];
        }

        // Apply imported preset on top of the clean slate
        for (NSString *key in importedPrefs) {
            freshPrefs[key] = importedPrefs[key];
        }
        [self writePrefs:freshPrefs];

    // Copy background images if present
    NSDictionary *images = @{
        @"background.jpg":           @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background.jpg",
        @"background_dark.jpg":      @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background_dark.jpg",
        @"chat_background.jpg":      @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background.jpg",
        @"chat_background_dark.jpg": @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background_dark.jpg"
    };

    for (NSString *fileName in images) {
        NSString *sourcePath = [tempDir stringByAppendingPathComponent:fileName];
        if ([fm fileExistsAtPath:sourcePath]) {
            NSString *destPath = images[fileName];
            NSString *destDir = [destPath stringByDeletingLastPathComponent];
            [fm createDirectoryAtPath:destDir withIntermediateDirectories:YES attributes:nil error:nil];
            [fm removeItemAtPath:destPath error:nil];
            [fm copyItemAtPath:sourcePath toPath:destPath error:nil];
        }
    }

    [fm removeItemAtPath:tempDir error:nil];
    [self postNotification];
    _specifiers = nil;
    [self reloadSpecifiers];

    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Preset Imported Sucessfully"
        message:@"Preset applied! Changes may not display correctly until you respring. Would you like to respring now?"
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

- (void)documentPicker:(UIDocumentPickerViewController *)controller
    didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count == 0) {
        [self showImportError:@"No file selected."];
        return;
    }
    [self applyPresetFromURL:urls.firstObject];
}

- (void)showImportError:(NSString *)message {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Import Failed. Check your file and try again."
        message:message
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"OK"
        style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - Reset Preferences

- (void)resetPreferences {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Are you sure you want to reset preferences?"
        message:@"This will erase all your settings. This cannot be undone!"
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
        style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Yes, Reset"
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *action) {
            NSFileManager *fm = [NSFileManager defaultManager];

            // Delete prefs plist
            [fm removeItemAtPath:kWAMPrefsPlistPath error:nil];

            // Delete background images
            NSArray *imagePaths = @[
                @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background.jpg",
                @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background_dark.jpg",
                @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background.jpg",
                @"/var/jb/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background_dark.jpg"
            ];
            for (NSString *path in imagePaths) {
                [fm removeItemAtPath:path error:nil];
            }

            [self postNotification];
            self->_specifiers = nil;
            [self reloadSpecifiers];

            UIAlertController *done = [UIAlertController
                alertControllerWithTitle:@"Preferences Reset"
                message:@"All settings have been cleared. Respring to apply."
                preferredStyle:UIAlertControllerStyleAlert];
            [done addAction:[UIAlertAction actionWithTitle:@"Not Yet"
                style:UIAlertActionStyleCancel handler:nil]];
            [done addAction:[UIAlertAction actionWithTitle:@"Respring"
                style:UIAlertActionStyleDestructive
                handler:^(UIAlertAction *action) {
                    pid_t pid;
                    const char *args[] = {"sbreload", NULL};
                    posix_spawn(&pid, "/var/jb/usr/bin/sbreload", NULL, NULL, (char *const *)args, NULL);
                }]];
            [self presentViewController:done animated:YES completion:nil];
        }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
