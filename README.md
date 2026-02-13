# pro_video_editor iOS portrait videos issue

Minimal reproduction case for .

## Steps to Reproduce

1. Clone this repo
2. Run `flutter pub get`
3. Open `ios/Runner.xcworkspace` and set your signing team
4. Run on a physical iOS device: `flutter run`
5. Pick a video that was recorded in portrait mode
6. Trim and export
7. Observe: The resulting video has the correct dimensions (height and width), but the pixels are all rotated. 

## Expected Behavior

Pixels are not rotated

## Actual Behavior

Pixels are rotated

## Environment

- Flutter: [run `flutter --version`]
- pro_video_editor: 1.5.2
- Device: iPhone 16e
- iOS version: 26.2.1