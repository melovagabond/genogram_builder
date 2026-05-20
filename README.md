# Genogram Builder

A clinical genogram builder implementing the full Bowen standard symbol set.
Targets Android tablet primarily, with iOS, web, and desktop support planned.

## Features

- Full Bowen standard node symbols: male (square), female (circle), unknown (diamond)
- Deceased overlay, pregnancy, miscarriage, abortion, stillbirth, identical/fraternal twins
- Per-person markers: substance abuse, mental illness, physical illness, abuse perpetrator/victim, adopted, foster, index person
- 15 relationship line types across structural and emotional categories
- Auto-layout by generation (set generation field per person: 0=focal, -1=parent, 1=child, etc.)
- Pan, pinch-zoom, drag nodes -- touch optimized
- JSON export/import for backup and restore
- PDF export with legend strip
- 200 person maximum (configurable in `genogram_state.dart`)

## Getting Started

### Prerequisites

- Flutter 3.10+
- Dart 3.0+
- For Android: Android SDK / Android Studio
- For iOS: macOS with Xcode 15+

### Install dependencies

```bash
flutter pub get
```

### Run

```bash
# Android
flutter run -d android

# iOS simulator
flutter run -d iPhone

# Web
flutter run -d chrome

# List available devices
flutter devices
```

### Build

```bash
# Android debug APK (no signing needed)
flutter build apk --debug

# Android release APK (requires keystore setup -- see below)
flutter build apk --release

# iOS (no-codesign, for local testing)
flutter build ios --no-codesign

# Web
flutter build web --web-renderer canvaskit
```

## GitHub Actions CI/CD

Push a version tag to trigger builds for all platforms:

```bash
git tag v1.0.0
git push origin v1.0.0
```

This triggers the build workflow which:
1. Builds Android APK + AAB
2. Builds iOS IPA (if signing secrets are configured)
3. Builds web bundle
4. Creates a GitHub Release with all artifacts attached

### Required Secrets

Configure these in your repo: **Settings > Secrets and variables > Actions**

#### Android release signing (optional -- debug APK works without)

| Secret | Value |
|--------|-------|
| `ANDROID_KEYSTORE` | Base64-encoded `.jks` keystore file |
| `ANDROID_KEY_ALIAS` | Key alias in the keystore |
| `ANDROID_KEY_PASSWORD` | Key password |
| `ANDROID_STORE_PASSWORD` | Keystore password |

Generate a keystore:
```bash
keytool -genkey -v -keystore release.jks -alias genogram \
  -keyalg RSA -keysize 2048 -validity 10000

# Base64 encode for the secret
base64 -i release.jks | pbcopy
```

#### iOS signing (optional -- unsigned build works without)

| Secret | Value |
|--------|-------|
| `IOS_CERTIFICATE_P12` | Base64-encoded `.p12` distribution certificate |
| `IOS_CERTIFICATE_PASSWORD` | Certificate password |
| `IOS_PROVISIONING_PROFILE` | Base64-encoded `.mobileprovision` ad-hoc profile |

Steps:
1. Create an ad-hoc provisioning profile in Apple Developer portal
2. Download and base64-encode both the `.p12` and `.mobileprovision`
3. Update `ios/ExportOptions.plist` with your team ID and bundle ID
4. Update bundle ID in `ios/Runner/Info.plist`

```bash
# Encode for secrets
base64 -i cert.p12 | pbcopy
base64 -i profile.mobileprovision | pbcopy
```

## Project Structure

```
lib/
  main.dart                    # Entry point, Provider setup
  models/
    person.dart                # Person data model + markers
    relationship.dart          # Relationship model + all Bowen types
    genogram_state.dart        # Top-level state container
  providers/
    genogram_provider.dart     # Single ChangeNotifier -- all state mutations
  painters/
    node_painter.dart          # CustomPainter for person nodes
    relation_painter.dart      # CustomPainter for relationship lines
  widgets/
    canvas_widget.dart         # Main canvas + gesture handling + edit sheets
    relationship_picker.dart   # Bottom sheet for selecting relationship type
    toolbar.dart               # (unused -- app bar built in main_screen)
  screens/
    main_screen.dart           # Root scaffold, app bar, FAB, status bar
  services/
    export_service.dart        # PDF export via pdf + printing packages
    json_export_service.dart   # JSON export via share_plus
    import_service.dart        # JSON import via file_picker
  constants/
    app_theme.dart             # Colors, sizing constants, ThemeData
```

## Usage

### Adding people

- Toolbar buttons: `+ Male`, `+ Female`, `+ ?`
- Or tap the `+` FAB (bottom right) for the expandable quick-add menu

### Editing a person

- Double-tap any node to open the edit sheet
- Or long-press for the context menu

### Connecting people

1. Tap **Link** in the toolbar
2. Tap the source person (orange ring appears)
3. Tap the target person
4. Pick relationship type from the bottom sheet

### Auto-layout

1. Set the **Generation** field for each person (0 = focal generation, -1 = parents, -2 = grandparents, 1 = children, 2 = grandchildren)
2. Tap **Layout** in toolbar
3. Tap **Fit** to zoom to fit the result

### Export/Import

- **Export JSON**: shares the genogram as a `.json` file (use as backup)
- **Import JSON**: opens file picker, loads a previously exported `.json`
- **Export PDF**: opens the print/share dialog with a rendered PDF

## Configuration

Change the max node limit in `lib/models/genogram_state.dart`:

```dart
static const int maxNodes = 200;
```

## License

MIT
