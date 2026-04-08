/* SignLanguageTranslator/components/SignLanguage/CameraView.tsx */
import { CameraType, CameraView as ExpoCameraView, useCameraPermissions } from 'expo-camera';
import React from 'react';
import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';

type CameraViewProps = {
  isActive: boolean;
  onPhotoTaken?: (base64: string) => void;
};

// Create a forwardRef component to properly handle camera ref
const CameraViewComponent = React.forwardRef<ExpoCameraView, CameraViewProps>(({ isActive, onPhotoTaken }, ref) => {
  const [facing, setFacing] = React.useState<CameraType>('front');
  const [permission, requestPermission] = useCameraPermissions();

  // Function to take a photo - defined outside of useEffect to avoid recreation
  const takePhoto = React.useCallback(async () => {
    const camera = ref as React.RefObject<ExpoCameraView>;
    if (!camera?.current || !onPhotoTaken) return;

    try {
      const photo = await camera.current.takePictureAsync({
        base64: true,
        quality: 0.5,
        exif: false, // Don't include EXIF data to reduce payload size
        skipProcessing: true // Get raw data faster
      });

      if (photo.base64) {
        onPhotoTaken(photo.base64);
      }
    } catch (error) {
      console.error('Error taking photo:', error);
    }
  }, [onPhotoTaken]);

  // Start taking photos when isActive becomes true
  React.useEffect(() => {
    let interval: ReturnType<typeof setInterval>;

    if (isActive && onPhotoTaken) {
      interval = setInterval(takePhoto, 1000);
    }

    return () => {
      if (interval) {
        clearInterval(interval);
      }
    };
  }, [isActive, takePhoto, onPhotoTaken]);

  const toggleCameraFacing = React.useCallback(() => {
    setFacing(current => (current === 'back' ? 'front' : 'back'));
  }, []);

  if (!permission) {
    // Camera permissions are still loading.
    return (
      <View style={styles.container}>
        <Text style={styles.message}>Loading camera permissions...</Text>
      </View>
    );
  }

  if (!permission.granted) {
    // Camera permissions are not granted yet.
    return (
      <View style={styles.container}>
        <Text style={styles.message}>We need your permission to show the camera</Text>
        <TouchableOpacity style={styles.permissionButton} onPress={requestPermission}>
          <Text style={styles.permissionButtonText}>Grant permission</Text>
        </TouchableOpacity>
      </View>
    );
  }

  return (
    <View style={styles.container}>
      <ExpoCameraView
        ref={ref}
        style={styles.camera}
        facing={facing}
      />
      <View style={StyleSheet.absoluteFill}>
        <View style={styles.buttonContainer}>
          <TouchableOpacity style={styles.button} onPress={toggleCameraFacing}>
            <Text style={styles.text}>Flip Camera</Text>
          </TouchableOpacity>
        </View>
        {isActive && (
          <View style={styles.activeIndicator}>
            <Text style={styles.activeText}>Translating...</Text>
          </View>
        )}
      </View>
    </View>
  );
});

export default CameraViewComponent;

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    borderRadius: 10,
    overflow: 'hidden',
    backgroundColor: '#e1e1e1',
  },
  message: {
    textAlign: 'center',
    paddingBottom: 10,
  },
  camera: {
    flex: 1,
  },
  buttonContainer: {
    flex: 1,
    flexDirection: 'row',
    backgroundColor: 'transparent',
    margin: 20,
  },
  button: {
    flex: 1,
    alignSelf: 'flex-end',
    alignItems: 'center',
  },
  text: {
    fontSize: 18,
    fontWeight: 'bold',
    color: 'white',
    textShadowColor: 'rgba(0, 0, 0, 0.75)',
    textShadowOffset: { width: -1, height: 1 },
    textShadowRadius: 10,
  },
  permissionButton: {
    backgroundColor: '#4CAF50',
    padding: 10,
    borderRadius: 5,
    margin: 20,
    alignSelf: 'center',
  },
  permissionButtonText: {
    color: 'white',
    fontWeight: 'bold',
  },
  activeIndicator: {
    position: 'absolute',
    top: 10,
    right: 10,
    backgroundColor: 'rgba(255, 0, 0, 0.7)',
    padding: 8,
    borderRadius: 20,
  },
  activeText: {
    color: 'white',
    fontWeight: 'bold',
  }
});