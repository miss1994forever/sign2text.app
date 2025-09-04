// SignLanguageTranslator/components/SignLanguage/SignLanguageDetector.tsx
import { Ionicons } from '@expo/vector-icons';
import React, { useEffect, useRef, useState } from 'react';
import { ActivityIndicator, StyleSheet, TouchableOpacity, View } from 'react-native';
import signLanguageService from '../services/signLanguageService';
import CameraView from './CameraView';
import TranslationDisplay from './TranslationDisplay';

const styles = StyleSheet.create({
  container: {
    flex: 1,
  },
  cameraButton: {
    position: 'absolute',
    bottom: 30,
    alignSelf: 'center',
    width: 70,
    height: 70,
    borderRadius: 35,
    backgroundColor: 'white',
    justifyContent: 'center',
    alignItems: 'center',
    shadowColor: '#000',
    shadowOffset: {
      width: 0,
      height: 2,
    },
    shadowOpacity: 0.25,
    shadowRadius: 3.84,
    elevation: 5,
  },
  loadingOverlay: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
    bottom: 0,
    backgroundColor: 'rgba(0,0,0,0.3)',
    justifyContent: 'center',
    alignItems: 'center',
  }
});

export default function SignLanguageDetector() {
  const cameraRef = useRef<Camera>(null);
  const [isActive, setIsActive] = useState(false);
  const [translatedText, setTranslatedText] = useState('');
  const [isProcessing, setIsProcessing] = useState(false);

  useEffect(() => {
    signLanguageService.start((text) => {
      setTranslatedText(text);
    });

    return () => {
      signLanguageService.stop();
    };
  }, []);

  const handlePhotoTaken = async (base64: string) => {
    try {
      console.log('Processing photo...');
      const result = await signLanguageService.processFrame(base64);
      if (result) {
        setTranslatedText(result);
      }
    } catch (error) {
      console.error('Error processing frame:', error);
    }
  };

  const handleTakePhoto = async () => {
    if (cameraRef.current && !isProcessing) {
      try {
        setIsProcessing(true);
        const photo = await cameraRef.current.takePictureAsync({
          base64: true,
          quality: 0.5,
          exif: false,
          skipProcessing: true
        });
        
        if (photo.base64) {
          await handlePhotoTaken(photo.base64);
        }
      } catch (error) {
        console.error('Error taking photo:', error);
      } finally {
        setIsProcessing(false);
      }
    }
  };

  return (
    <View style={styles.container}>
      <CameraView 
        ref={cameraRef}
        isActive={isActive}
        onPhotoTaken={handlePhotoTaken}
      />
      <TranslationDisplay text={translatedText} />
      
      <TouchableOpacity 
        style={styles.cameraButton}
        onPress={handleTakePhoto}
        disabled={isProcessing}
      >
        <Ionicons 
          name="camera" 
          size={32} 
          color={isProcessing ? '#999' : '#000'} 
        />
      </TouchableOpacity>

      {isProcessing && (
        <View style={styles.loadingOverlay}>
          <ActivityIndicator size="large" color="#ffffff" />
        </View>
      )}
    </View>
  );
}