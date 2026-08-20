# Screen - Responsive Design System

The `Screen` class provides responsive sizing utilities that scale UI elements based on device dimensions. It maintains aspect ratio consistency across different screen sizes using the Figma design dimensions as a baseline.

## Overview

- **Design Baseline**: 360px (width) × 812px (height) - Standard mobile phone dimensions from Figma
- **Scaling Method**: Proportional scaling based on actual device dimensions
- **Initialization**: Must call `adaptDeviceScreenSize()` from the root widget's build method

## Configuration

```dart
// Default Figma design dimensions
static num FIGMA_DESIGN_WIDTH = 360;   // Mobile phone width
static num FIGMA_DESIGN_HEIGHT = 812;  // Mobile phone height
```

## Core Methods

### `adaptDeviceScreenSize(BuildContext context)`
Initializes screen dimensions based on actual device size. **Call this in your root widget or first screen**.

```dart
@override
Widget build(BuildContext context) {
  Screen().adaptDeviceScreenSize(context);
  // Now all Screen methods will use correct device dimensions
  return Scaffold(...);
}
```

### `getSize(double px)`
Universal scaling - scales based on smaller of width/height ratio to maintain aspect ratio.

```dart
double size = Screen.getSize(20);  // Scales 20px proportionally
```

### `getHorizontalSize(double px)`
Scales based on device width only.

```dart
double width = Screen.getHorizontalSize(100);  // Scales 100px based on width
```

### `getVerticalSize(double px)`
Scales based on device height only.

```dart
double height = Screen.getVerticalSize(50);  // Scales 50px based on height
```

### `getFontSize(double px)`
Scales font sizes based on device width. **Clamped between 8.0 and 56.0 to prevent extreme sizes**.

```dart
double fontSize = Screen.getFontSize(16);  // Scales 16px for text
```

### `getScaleFactor()`
Returns the scaling factor used for sizing calculations.

```dart
double factor = Screen.getScaleFactor();
// On 360px wide device: ~1.0
// On 720px wide device: ~2.0
```

## Padding & Margin Methods

### `getPadding()` / `getMargin()`
Create responsive edge insets with optional all, horizontal, vertical, or specific side values.

```dart
// All sides equal
padding: Screen.getPadding(all: 16),

// Horizontal and vertical
padding: Screen.getPadding(horizontal: 20, vertical: 12),

// Specific sides
padding: Screen.getPadding(left: 10, top: 15, right: 10, bottom: 15),
```

**Precedence**: Specific side > horizontal/vertical > all

## Accessing Dimensions

```dart
// Get current device dimensions
double screenWidth = Screen.width;
double screenHeight = Screen.height;

// Get safe area height (excluding status bar and notch)
double safeHeight = Screen.getSafeHeight(context);
```

## Usage Examples

### Responsive Container
```dart
Container(
  width: Screen.getHorizontalSize(200),
  height: Screen.getVerticalSize(150),
  padding: Screen.getPadding(all: 16),
  child: Text('Responsive', style: TextStyle(
    fontSize: Screen.getFontSize(18),
  )),
)
```

### Responsive Row with Spacing
```dart
Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Container(
      width: Screen.getHorizontalSize(150),
      height: Screen.getSize(50),
      color: Colors.blue,
    ),
    SizedBox(width: Screen.getHorizontalSize(20)),
    Container(
      width: Screen.getHorizontalSize(150),
      height: Screen.getSize(50),
      color: Colors.red,
    ),
  ],
)
```

### Responsive Text with Padding
```dart
Text(
  'Hello, World!',
  style: AppTypography.h5SemiBold.copyWith(
    fontSize: Screen.getFontSize(24),
  ),
)
```

## Design Ratios Reference

For a 360×812 device (Figma baseline):
| Device Width | Scale Factor | Example: 16px becomes |
|---|---|---|
| 180px | 0.5× | 8px |
| 360px | 1.0× | 16px |
| 540px | 1.5× | 24px |
| 720px | 2.0× | 32px |

## Important Notes

- **Initialize early**: Call `adaptDeviceScreenSize()` in your root widget build method
- **FontSize clamping**: Font sizes are clamped to 8.0-56.0 range for readability
- **Aspect ratio**: Use `getSize()` for elements that need to maintain aspect ratio across devices
- **Text scaling**: Use `getFontSize()` for all typography to ensure text scales appropriately
- **Padding/Margin**: Use responsive padding methods for consistent spacing across screen sizes

## Troubleshooting

### Fonts appearing very small
- Ensure `adaptDeviceScreenSize()` is called in your root widget build method
- Check that Screen._width is being initialized (defaults to 360 as of latest update)

### Elements too large or too small
- Use appropriate scaling method: `getSize()` for proportional, `getHorizontalSize()`/`getVerticalSize()` for directional
- Check Figma design dimensions match your device baseline

### Inconsistent spacing
- Use `getPadding()` and `getMargin()` instead of hardcoded values
- Ensure precedence rules are followed for EdgeInsets
