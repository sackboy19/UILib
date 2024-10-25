#!/bin/sh

set -e

APP_NAME="UILib.app"

rm -rf build
mkdir -p build/$APP_NAME/Contents
mkdir build/$APP_NAME/Contents/MacOS
mkdir build/$APP_NAME/Contents/Resources
mkdir build/$APP_NAME/Contents/Resources/Base.lproj

cp -r data/Main.storyboardc build/$APP_NAME/Contents/Resources/Base.lproj/Main.storyboardc
cp data/UILib_Info.plist build/$APP_NAME/Contents/Info.plist
plutil -convert binary1 build/$APP_NAME/Contents/Info.plist # convert plist to binary for smaller size

# -Ofast \
clang++ -o build/UILib.app/Contents/MacOS/UILib \
	-fmodules -fobjc-arc \
	-g \
	-W \
	-Wall \
	-Wextra \
	-Wpedantic \
	-Wconversion \
	-Wimplicit-fallthrough \
	-Wmissing-prototypes \
	-Wshadow \
	-Wstrict-prototypes \
	-Wno-unused-parameter \
	-framework Metal \
	-framework MetalKit \
	-framework Cocoa \
	main.mm

xcrun metal \
	-o build/UILib.app/Contents/Resources/shaders.metallib \
	-gline-tables-only -frecord-sources \
	shaders.metal	