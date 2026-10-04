TARGET := iphone:clang:12.4:12.0
ARCHS = arm64

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = TecDuck

TecDuck_FILES = main.m TWAppDelegate.m TWViewController.m
TecDuck_FRAMEWORKS = UIKit WebKit
TecDuck_CFLAGS = -fobjc-arc -Wall -Werror
TecDuck_CODESIGN_FLAGS = -Sentitlements.plist

include $(THEOS_MAKE_PATH)/application.mk
