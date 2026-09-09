#import <Foundation/Foundation.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>
#import "WAMRootListController.h"
#import "WAMBaseListController.h"
#import "WAMPresetGalleryController.h"
#import "WAMPresetModel.h"
#import <spawn.h>
#import <sys/wait.h>

@implementation WAMRootListController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Root" target:self];
    }
    [self applyLiquidAssLock];
    return _specifiers;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reloadSpecifiers];   // re-check LiquidAss installed-ness each time this page is shown
}

#pragma mark - Liquid (Gl)ass Compatibility (Beta)

- (BOOL)isLiquidAssInstalled {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dylibsDir = WAMJBPath(@"/Library/MobileSubstrate/DynamicLibraries");
    NSArray<NSString *> *entries = [fm contentsOfDirectoryAtPath:dylibsDir error:nil];
    for (NSString *name in entries) {
        if ([name.lowercaseString isEqualToString:@"liquidass.dylib"]) return YES;
    }
    return NO;
}

- (void)applyLiquidAssLock {
    BOOL installed = [self isLiquidAssInstalled];
    for (PSSpecifier *spec in _specifiers) {
        if ([spec.properties[@"lightModeKey"] isEqualToString:@"isLiquidAssCompatEnabled"]) {
            [spec setProperty:@(installed) forKey:@"enabled"];
        } else if ([spec.properties[@"label"] isEqualToString:@"Liquid (Gl)ass Compatibility (Beta)"]) {
            NSString *footer = installed
                ? @"Uses Liquid (Gl)ass's glass materials for platters and blurred surfaces where supported, instead of the stock blur. Incomplete and buggy and I honestly don't care enough to perfect, but it was cool to throw in. Inherits glass properties from \"Search Pill\" settings. Could break anytime and doesnt work in lanscape."
                : @"Locked because Liquid (Gl)ass isn't installed. Install it (github.com/winaviation-tweaks/liquidass) to use this option.";
            [spec setProperty:footer forKey:@"footerText"];
        }
    }
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

- (void)browsePresets {
    WAMPresetGalleryController *gallery = [WAMPresetGalleryController new];
    [self.navigationController pushViewController:gallery animated:YES];
}

- (void)killApp {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Kill Messages"
        message:@"Are you sure you want to restart Messages?"
        preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:@"Not Yet"
        style:UIAlertActionStyleCancel handler:nil]];

    [alert addAction:[UIAlertAction actionWithTitle:@"Restart"
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *action) {
            [WAMPresetStore restartMessages];
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
    int result = posix_spawn(&pid, [WAMJBPath(@"/usr/bin/zip") UTF8String], NULL, NULL, (char *const *)args, NULL);
    if (result != 0) return NO;
    int status;
    waitpid(pid, &status, 0);
    return WEXITSTATUS(status) == 0;
}

- (BOOL)isPresetExcludedKey:(NSString *)key {
    if ([key isEqualToString:@"editingDarkMode"]) return YES;
    if ([key isEqualToString:@"isEnabled"]) return YES;
    if ([key isEqualToString:@"chatIdentifierAliases"]) return YES;
    if ([key isEqualToString:@"userPresets"]) return YES;
    if ([key hasPrefix:@"perContact"]) return YES;
    return NO;
}

- (void)exportPreset {
    NSMutableDictionary *prefs = [self readPrefs];
    NSMutableDictionary *presetPrefs = [NSMutableDictionary new];
    for (NSString *key in prefs) {
        if (![self isPresetExcludedKey:key]) {
            presetPrefs[key] = prefs[key];
        }
    }

    NSString *tempDir = [NSTemporaryDirectory() stringByAppendingPathComponent:@"wampreset_export"];
    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:tempDir error:nil];
    [fm createDirectoryAtPath:tempDir withIntermediateDirectories:YES attributes:nil error:nil];

    NSString *plistPath = [tempDir stringByAppendingPathComponent:@"preset.plist"];
    [presetPrefs writeToFile:plistPath atomically:YES];

    NSDictionary *images = @{
        @"background.jpg":           WAMJBPath(@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background.jpg"),
        @"background_dark.jpg":      WAMJBPath(@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background_dark.jpg"),
        @"chat_background.jpg":      WAMJBPath(@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background.jpg"),
        @"chat_background_dark.jpg": WAMJBPath(@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background_dark.jpg")
    };

    for (NSString *destName in images) {
        NSString *sourcePath = images[destName];
        if ([fm fileExistsAtPath:sourcePath]) {
            [fm copyItemAtPath:sourcePath
                        toPath:[tempDir stringByAppendingPathComponent:destName]
                         error:nil];
        }
    }

    NSString *zipPath = [NSTemporaryDirectory() stringByAppendingPathComponent:@"WhatAMess_Preset.wampreset"];
    [fm removeItemAtPath:zipPath error:nil];

    BOOL zipped = [self zipDirectory:tempDir toFile:zipPath];

    if (!zipped) {
        UIAlertController *alert = [UIAlertController
            alertControllerWithTitle:@"Export Failed"
            message:@"Could not create preset file! Please try again."
            preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"OK"
            style:UIAlertActionStyleDefault handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
        return;
    }

    [fm removeItemAtPath:tempDir error:nil];

    NSURL *zipURL = [NSURL fileURLWithPath:zipPath];
    UIActivityViewController *activityVC = [[UIActivityViewController alloc]
        initWithActivityItems:@[zipURL]
        applicationActivities:nil];

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
    int spawnResult = posix_spawn(&pid, [WAMJBPath(@"/usr/bin/unzip") UTF8String], NULL, NULL, (char *const *)args, NULL);
    if (spawnResult != 0) {
        [self showImportError:@"Could not launch unzip."];
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
        [self showImportError:@"Invalid preset file: missing preset.plist!"];
        return;
    }

    NSDictionary *importedPrefs = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    if (!importedPrefs) {
        [self showImportError:@"Could not read preset data!"];
        return;
    }

        NSMutableDictionary *currentPrefs = [self readPrefs];
        NSMutableDictionary *freshPrefs = [NSMutableDictionary new];

        for (NSString *key in currentPrefs) {
            if ([self isPresetExcludedKey:key]) freshPrefs[key] = currentPrefs[key];
        }

        for (NSString *key in importedPrefs) {
            freshPrefs[key] = importedPrefs[key];
        }
        [self writePrefs:freshPrefs];

    NSDictionary *images = @{
        @"background.jpg":           WAMJBPath(@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background.jpg"),
        @"background_dark.jpg":      WAMJBPath(@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background_dark.jpg"),
        @"chat_background.jpg":      WAMJBPath(@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background.jpg"),
        @"chat_background_dark.jpg": WAMJBPath(@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background_dark.jpg")
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
        message:@"Preset applied! Changes may not display correctly until you restart the app. Would you like to restart now?"
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Not Yet"
        style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Restart"
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *action) {
            [WAMPresetStore restartMessages];
            }]];
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller
    didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
    if (urls.count == 0) {
        [self showImportError:@"No file selected!"];
        return;
    }
    [self applyPresetFromURL:urls.firstObject];
}

- (void)showImportError:(NSString *)message {
    UIAlertController *alert = [UIAlertController
        alertControllerWithTitle:@"Import Failed! Check your preset file and try again."
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
        message:@"This will erase ALL your settings! Presets you've saved are kept. This CANNOT be undone!"
        preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel"
        style:UIAlertActionStyleCancel handler:nil]];
    [alert addAction:[UIAlertAction actionWithTitle:@"Yes, Reset"
        style:UIAlertActionStyleDestructive
        handler:^(UIAlertAction *action) {
            NSFileManager *fm = [NSFileManager defaultManager];

            id savedPresets = [self readPrefs][@"userPresets"];

            [fm removeItemAtPath:kWAMPrefsPlistPath error:nil];

            if (savedPresets) [self writePrefs:@{@"userPresets": savedPresets}];

            NSArray *imagePaths = @[
                WAMJBPath(@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background.jpg"),
                WAMJBPath(@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/background_dark.jpg"),
                WAMJBPath(@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background.jpg"),
                WAMJBPath(@"/var/mobile/Library/Preferences/com.oakstheawesome.whatamessprefs/chat_background_dark.jpg")
            ];
            for (NSString *path in imagePaths) {
                [fm removeItemAtPath:path error:nil];
            }

            [self postNotification];
            self->_specifiers = nil;
            [self reloadSpecifiers];

            UIAlertController *done = [UIAlertController
                alertControllerWithTitle:@"Preferences Reset"
                message:@"All settings have been cleared! Restart the app to apply."
                preferredStyle:UIAlertControllerStyleAlert];
            [done addAction:[UIAlertAction actionWithTitle:@"Not Yet"
                style:UIAlertActionStyleCancel handler:nil]];
            [done addAction:[UIAlertAction actionWithTitle:@"Restart"
                style:UIAlertActionStyleDestructive
                handler:^(UIAlertAction *action) {
            [WAMPresetStore restartMessages];
                }]];
            [self presentViewController:done animated:YES completion:nil];
        }]];
    [self presentViewController:alert animated:YES completion:nil];
}

@end
