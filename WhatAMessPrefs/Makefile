TARGET := iphone:clang:16.5:15.0

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = WhatAMessPrefs

WhatAMessPrefs_FILES = WAMRootListController.m \
					WAMConvListController.m \
					WAMChatViewController.m \
					WAMBaseListController.m \
					WAMNavBarController.m \
					WAMMessageBarController.m \
					WAMChatBubbleController.m \
					WAMAdvancedTintController.m \
					WAMBannerCell.m \
					WAMPresetGalleryController.m \
					../WAMPresetModel.m \
					../WAMPresetPreviewView.m \
					../WAMPresetCardView.m \
					../WAMGradientBuilderController.m

WhatAMessPrefs_FRAMEWORKS = UIKit UniformTypeIdentifiers
WhatAMessPrefs_PRIVATE_FRAMEWORKS = Preferences
WhatAMessPrefs_INSTALL_PATH = /Library/PreferenceBundles
WhatAMessPrefs_CFLAGS = -fobjc-arc -I..

include $(THEOS_MAKE_PATH)/bundle.mk
