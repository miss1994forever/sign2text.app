/* SignLanguageTranslator/components/SignLanguage/CameraView.tsx */
import { CameraType, CameraView as ExpoCameraView, useCameraPermissions } from 'expo-camera';
import React from 'react';
import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';

type CameraViewProps = {
  isActive: boolean;
};

// Rename the component to avoid duplicate declaration error
function CameraViewComponent({ isActive }: CameraViewProps) {
  const [facing, setFacing] = React.useState<CameraType>('front');
  const [permission, requestPermission] = useCameraPermissions();

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

  function toggleCameraFacing() {
    setFacing(current => (current === 'back' ? 'front' : 'back'));
  }

  return (
    <View style={styles.container}>
      {/* CameraView does not support children, so use absolute positioning for overlays */}
      <ExpoCameraView style={styles.camera} facing={facing} />
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
}

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