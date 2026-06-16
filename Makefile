TARGET := iphone:clang:latest:14.0
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

TWEAK_NAME = ThetaCrack

ThetaCrack_FILES = src/Tweak.m src/TweakCrypto.m src/TweakHTTP.m src/TweakUI.m
ThetaCrack_CFLAGS = -fobjc-arc
ThetaCrack_FRAMEWORKS = Foundation UIKit

include $(THEOS_MAKE_PATH)/tweak.mk
