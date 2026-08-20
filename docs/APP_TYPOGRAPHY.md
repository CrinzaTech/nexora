# AppTypography - Typography System

The `AppTypography` class defines all text styles used throughout the application. It provides a centralized, scalable typography system with consistent font families, weights, sizes, and spacing.

## Overview

- **Font Family**: DM Sans (Google Fonts)
- **Base Scaling**: Uses `Screen.getFontSize()` for responsive font sizing
- **Color System**: Integrated with `AppColors` for semantic color use
- **Line Heights**: Proportional to font size for readable line spacing
- **Letter Spacing**: Consistent 0.24 across most styles

## Heading Styles

Hierarchical heading sizes from H1 (largest) to H6 (smallest).

### H1 - Main Headings
```dart
AppTypography.h1Medium       // 48px, Weight: 500
AppTypography.h1SemiBold     // 48px, Weight: 600 (Recommended)
AppTypography.h1Bold         // 48px, Weight: 700

// Usage: Page titles, major sections
Text('Welcome', style: AppTypography.h1SemiBold)
```

### H2 - Section Headings
```dart
AppTypography.h2Medium       // 40px, Weight: 500
AppTypography.h2SemiBold     // 40px, Weight: 600 (Recommended)
AppTypography.h2Bold         // 40px, Weight: 700

// Usage: Section titles, important headers
Text('Featured Courses', style: AppTypography.h2SemiBold)
```

### H3 - Subsection Headings
```dart
AppTypography.h3Medium       // 32px, Weight: 500
AppTypography.h3SemiBold     // 32px, Weight: 600 (Recommended)
AppTypography.h3Bold         // 32px, Weight: 700

// Usage: Card titles, subsection headers
Text('Course Details', style: AppTypography.h3SemiBold)
```

### H4 - Card/Content Headings
```dart
AppTypography.h4Medium       // 24px, Weight: 500
AppTypography.h4SemiBold     // 24px, Weight: 600 (Recommended)
AppTypography.h4Bold         // 24px, Weight: 700

// Usage: Card titles, important content headings
Text('Course Name', style: AppTypography.h4SemiBold)
```

### H5 - Subheadings
```dart
AppTypography.h5Medium       // 20px, Weight: 500
AppTypography.h5SemiBold     // 20px, Weight: 600 (Recommended)
AppTypography.h5Bold         // 20px, Weight: 700

// Usage: Feature titles, list section headers
Text('What you\'ll learn', style: AppTypography.h5SemiBold)
```

### H6 - Minor Headings
```dart
AppTypography.h6Medium       // 18px, Weight: 500
AppTypography.h6SemiBold     // 18px, Weight: 600 (Recommended)
AppTypography.h6Bold         // 18px, Weight: 700

// Usage: Field labels, small section headers
Text('Description', style: AppTypography.h6SemiBold)
```

## Body Text Styles

General content text in various sizes.

### Body Text Extra Large (18px)
```dart
AppTypography.bodyTextXtraLargeMedium    // Weight: 500
AppTypography.bodyTextXtraLargeSemiBold  // Weight: 600 (Recommended)
AppTypography.bodyTextXtraLargeBold      // Weight: 700

// Usage: Important body content
Text('Course instructor: John Doe', style: AppTypography.bodyTextXtraLargeSemiBold)
```

### Body Text Large (16px)
```dart
AppTypography.bodyTextLargeMedium        // Weight: 500
AppTypography.bodyTextLargeSemiBold      // Weight: 600 (Recommended)
AppTypography.bodyTextLargeBold          // Weight: 700

// Usage: Primary body text, descriptions
Text('This course teaches modern Flutter development...', 
  style: AppTypography.bodyTextLargeSemiBold)
```

### Body Text Medium (14px)
```dart
AppTypography.bodyTextMedium             // Weight: 500
AppTypography.bodyTextSemiBold           // Weight: 600
AppTypography.bodyTextBold               // Weight: 700

// Usage: Regular body text, default content
Text('Price: ₹999', style: AppTypography.bodyTextMedium)
```

### Body Text Small (12px)
```dart
AppTypography.bodyTextSmallMedium        // Weight: 500
AppTypography.bodyTextSmallSemiBold      // Weight: 600
AppTypography.bodyTextSmallBold          // Weight: 700

// Usage: Secondary content, hints
Text('Course duration: 4 weeks', style: AppTypography.bodyTextSmallMedium)
```

### Body Text Extra Small (10px)
```dart
AppTypography.bodyTextXtraSmallMedium    // Weight: 500
AppTypography.bodyTextXtraSmallSemiBold  // Weight: 600
AppTypography.bodyTextXtraSmallBold      // Weight: 700

// Usage: Captions, timestamps, footnotes
Text('Updated 2 hours ago', style: AppTypography.bodyTextXtraSmallMedium)
```

## Button Styles

Styles optimized for button text with increased letter spacing.

```dart
AppTypography.buttonLarge      // 16px, Weight: 600, Letter Spacing: 0.5
AppTypography.buttonMedium     // 14px, Weight: 600, Letter Spacing: 0.5
AppTypography.buttonSmall      // 12px, Weight: 600, Letter Spacing: 0.5

// Usage:
Text('Sign In', style: AppTypography.buttonLarge)
Text('Add to Cart', style: AppTypography.buttonMedium)
Text('Close', style: AppTypography.buttonSmall)
```

## Label Styles

Styles for form labels and small interface text.

```dart
AppTypography.labelLarge       // 14px, Weight: 500, Letter Spacing: 0.1
AppTypography.labelMedium      // 12px, Weight: 500, Letter Spacing: 0.1
AppTypography.labelSmall       // 10px, Weight: 500, Letter Spacing: 0.1

// Usage:
Text('Full Name', style: AppTypography.labelLarge)
Text('Email', style: AppTypography.labelMedium)
Text('Required', style: AppTypography.labelSmall)
```

## Usage Examples

### Basic Text
```dart
Text(
  'Welcome to Crinza',
  style: AppTypography.h2SemiBold,
)
```

### Customizing Style
```dart
Text(
  'Special Price',
  style: AppTypography.h4SemiBold.copyWith(
    color: AppColors.secondary,
    fontSize: Screen.getFontSize(20),
  ),
)
```

### Text with Dynamic Color
```dart
Text(
  'Course Description',
  style: AppTypography.bodyTextLargeMedium.copyWith(
    color: AppColors.mutedTextPrimary,
    height: 1.6,
  ),
)
```

### Multi-Line Text
```dart
Text(
  'Lorem ipsum dolor sit amet, consectetur adipiscing elit.',
  style: AppTypography.bodyTextMedium.copyWith(
    height: 1.5,  // Line height multiplier
  ),
  maxLines: 3,
  overflow: TextOverflow.ellipsis,
)
```

### Combining with Screen Sizing
```dart
Text(
  'Dynamic Heading',
  style: AppTypography.h5SemiBold.copyWith(
    fontSize: Screen.getFontSize(18),
    color: AppColors.primary,
  ),
)
```

## Typography Hierarchy Reference

| Level | Style | Size | Weight | Usage |
|-------|-------|------|--------|-------|
| H1 | h1SemiBold | 48px | 600 | Page titles |
| H2 | h2SemiBold | 40px | 600 | Section titles |
| H3 | h3SemiBold | 32px | 600 | Subsection titles |
| H4 | h4SemiBold | 24px | 600 | Card titles |
| H5 | h5SemiBold | 20px | 600 | Feature titles |
| H6 | h6SemiBold | 18px | 600 | Field labels |
| Body Large | bodyTextLargeSemiBold | 16px | 600 | Primary content |
| Body Medium | bodyTextMedium | 14px | 500 | Regular content |
| Body Small | bodyTextSmallMedium | 12px | 500 | Secondary content |
| Button | buttonMedium | 14px | 600 | Button text |
| Label | labelLarge | 14px | 500 | Form labels |

## Design Tokens

### Font Family
- **Primary**: DM Sans (Google Fonts)

### Font Weights
- **Medium (500)**: Regular content
- **SemiBold (600)**: Emphasis, recommended default
- **Bold (700)**: Strong emphasis, headings

### Letter Spacing
- **0.24**: Most styles (slight increase for readability)
- **0.5**: Buttons (increased for prominence)
- **0.1**: Labels (tighter for compact appearance)

### Line Heights
- Proportional to font size: `height: baseSize / fontSize`
- Example: H1 has `height: 56/48 ≈ 1.17` for comfortable reading

## Best Practices

1. **Use semantic styles**: Pick the style that matches semantic purpose, not just size
2. **Maintain hierarchy**: Use h1→h6 for heading levels in logical order
3. **Color consistency**: Use `AppColors` with typography, not hardcoded colors
4. **Responsive fonts**: Always use `Screen.getFontSize()` if customizing font sizes
5. **Consistency**: Use predefined styles instead of creating custom TextStyles
6. **Contrast**: Ensure sufficient contrast between text and background
7. **Accessibility**: Minimum font size should be 12px for body text

## Common Patterns

### Page Title + Description
```dart
Column(
  children: [
    Text('Welcome', style: AppTypography.h2SemiBold),
    SizedBox(height: 8),
    Text('Explore our courses', 
      style: AppTypography.bodyTextLargeMedium.copyWith(
        color: AppColors.mutedTextPrimary,
      ),
    ),
  ],
)
```

### Card with Title and Subtitle
```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Course Title', style: AppTypography.h4SemiBold),
    SizedBox(height: 4),
    Text('by Instructor Name', 
      style: AppTypography.bodyTextSmallMedium.copyWith(
        color: AppColors.mutedTextPrimary,
      ),
    ),
  ],
)
```

### Form Field Label
```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('Email Address', style: AppTypography.labelLarge),
    SizedBox(height: 8),
    TextField(
      decoration: InputDecoration(hintText: 'Enter your email'),
    ),
  ],
)
```
