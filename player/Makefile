TARGET := iphone:clang:10.3:7.0
ARCHS = armv7

include $(THEOS)/makefiles/common.mk

APPLICATION_NAME = Player
Player_FILES = main.m
Player_FRAMEWORKS = UIKit Foundation CoreGraphics
Player_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/application.mk
