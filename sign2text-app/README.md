# SignScribe - Real-time Sign Language Translation App

SignScribe is an iOS application that uses real-time computer vision to translate sign language gestures into text. The app is built with SwiftUI and designed to be extensible for different AI models.

## Project Structure

```
sign2text-app/
├── sign2text-app/                    # Main app source code
│   ├── SignLanguageApp.swift         # Main app entry point
│   ├── Models.swift                  # Data models and types
│   ├── CameraManager.swift           # Camera handling and frame capture
│   ├── CameraPreview.swift           # Camera UI components
│   ├── TranslationService.swift      # Translation logic with AI model support
│   ├── ContentView.swift             # Main translation screen
│   ├── DictionaryView.swift          # Dictionary management screen
│   ├── SettingsView.swift            # App settings and configuration
│   ├── Info.plist                    # App configuration and permissions
│   └── Assets.xcassets/              # App icons and assets
├── Scripts/                          # Build and setup scripts
└── README.md                         # This file
```

## Features

### Current Features
- ✅ Real-time camera preview
- ✅ Camera permission handling
- ✅ Dummy translation service (for development)
- ✅ Translation history
- ✅ Dictionary management (UI ready)
- ✅ Settings and configuration
- ✅ Export functionality

### Planned Features
- 🔄 CV-SLT AI model integration
- 🔄 Custom dictionary training
- 🔄 Multi-language support
- 🔄 Cloud synchronization

## Architecture

### Core Components

#### 1. Models (`Models.swift`)
Defines all data structures used throughout the app:
- `SignLanguageRecognition`: Represents a detected sign with confidence
- `SignLanguageWord`: Dictionary entry for custom signs
- `TranslationSession`: Tracks translation sessions
- `CameraFrame`: Wraps camera frame data
- `ModelConfiguration`: AI model settings

#### 2. Camera System (`CameraManager.swift`, `CameraPreview.swift`)
- `SignLanguageCameraManager`: Handles camera lifecycle, permissions, and frame capture
- `CameraPreview`: SwiftUI wrapper for camera preview
- `CameraOverlay`: Real-time status indicators
- Optimized for 30fps processing with frame skipping

#### 3. Translation Service (`TranslationService.swift`)
- Protocol-based design for easy AI model swapping
- `DummyTranslationModel`: Development/testing implementation
- `CVSLTModel`: Placeholder for CV-SLT integration
- Real-time frame processing with confidence filtering

#### 4. User Interface
- `ContentView.swift`: Main translation interface
- `DictionaryView.swift`: Custom dictionary management
- `SettingsView.swift`: App configuration and model selection

## Setup Instructions

### Prerequisites
- Xcode 15.0+
- iOS 16.0+
- Physical iOS device (camera required)

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd sign2text-app
   ```

2. **Open in Xcode**
   ```bash
   open sign2text-app.xcodeproj
   ```

3. **Configure signing**
   - Select your development team in project settings
   - Update bundle identifier if needed

4. **Build and run**
   - Connect an iOS device
   - Select your device as the run destination
   - Press Cmd+R to build and run

### Camera Permissions

The app requires camera access for real-time sign language detection. The permission request is handled automatically, but you can also:

1. Go to iOS Settings > Privacy & Security > Camera
2. Find "SignScribe" and enable camera access

## AI Model Integration

### Current Implementation

The app uses a dummy translation service for development. It simulates real-time translation with preset Chinese phrases to demonstrate the UI and data flow.

### CV-SLT Integration (Planned)

The architecture is designed to easily integrate the CV-SLT model from https://github.com/rzhao-zhsq/CV-SLT:

1. **Model Loading**: `CVSLTModel` class in `TranslationService.swift`
2. **Frame Processing**: Optimized pipeline for real-time inference
3. **Configuration**: Model settings in `ModelConfiguration`

#### Integration Steps:
1. Convert CV-SLT model to Core ML format
2. Add model file to Xcode project
3. Implement `CVSLTModel.loadModel()` and `CVSLTModel.processFrame()`
4. Update model configuration parameters

### Custom Model Support

To add a new translation model:

1. Implement `SignLanguageTranslationModel` protocol
2. Add model type to `TranslationModelFactory`
3. Create corresponding `ModelConfiguration`
4. Update settings UI to include new model option

## Development

### Building

```bash
# Clean build folder
xcodebuild clean -project sign2text-app.xcodeproj

# Build for device
xcodebuild -project sign2text-app.xcodeproj -scheme sign2text-app -destination 'generic/platform=iOS' build

# Build for simulator (limited functionality)
xcodebuild -project sign2text-app.xcodeproj -scheme sign2text-app -destination 'platform=iOS Simulator,name=iPhone 15' build
```

### Testing

The app includes basic unit tests and UI tests:

```bash
# Run tests
xcodebuild test -project sign2text-app.xcodeproj -scheme sign2text-app -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Debugging

1. **Camera Issues**: Check permissions and device capability
2. **Translation Issues**: Verify model loading and frame processing
3. **Performance**: Monitor frame rates and processing times in debug console

## Configuration

### App Settings (`AppSettings`)
- Model selection (Dummy/CV-SLT)
- Camera position (front/back)
- Frame rate (15/24/30 FPS)
- Translation language
- Feedback preferences

### Model Configuration (`ModelConfiguration`)
- Confidence threshold
- Input image size
- Maximum detections per frame
- Processing parameters

## Data Storage

### Local Storage
- Translation history: JSON files in Documents directory
- Dictionary words: Local JSON storage
- App settings: UserDefaults

### Privacy
- All processing happens on-device
- No data is sent to external servers
- Camera frames are processed in real-time and not stored

## Troubleshooting

### Common Issues

1. **Camera not working**
   - Ensure camera permissions are granted
   - Test on physical device (simulator has limited camera support)

2. **Build errors**
   - Clean build folder (Product > Clean Build Folder)
   - Delete derived data
   - Restart Xcode

3. **Translation not working**
   - Check model loading status in settings
   - Verify camera is active
   - Ensure good lighting conditions

### Performance Optimization

- Frame skipping: Processes every 3rd frame by default
- Model inference: Async processing on background queue
- UI updates: Batched on main queue
- Memory management: Automatic cleanup of old frames

## Contributing

### Code Style
- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add documentation comments for public APIs
- Organize code with MARK: comments

### Testing
- Add unit tests for new models
- Test camera functionality on multiple devices
- Verify UI responsiveness during processing

## License

[Add your license information here]

## Acknowledgments

- CV-SLT project: https://github.com/rzhao-zhsq/CV-SLT
- SwiftUI community for UI components
- Apple's AVFoundation and Vision frameworks