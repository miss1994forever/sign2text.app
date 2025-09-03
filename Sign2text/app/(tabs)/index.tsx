// SignLanguageTranslator/app/(tabs)/index.tsx
import React, { useEffect, useState } from 'react';
import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import CameraView from '../../components/CameraView';
import TranslationDisplay from '../../components/TranslationDisplay';
import mockMLService from '../../services/mockMLService';

export default function SignLanguageTranslator() {
  const [translatedText, setTranslatedText] = useState('');
  const [isTranslating, setIsTranslating] = useState(false);

  // Clean up the ML service when component unmounts
  useEffect(() => {
    return () => {
      mockMLService.stop();
    };
  }, []);

  const startTranslation = () => {
    setIsTranslating(true);
    mockMLService.start((newText) => {
      setTranslatedText(newText);
    });
  };

  const stopTranslation = () => {
    setIsTranslating(false);
    mockMLService.stop();
  };

  const clearTranslation = () => {
    setTranslatedText('');
    mockMLService.clear();
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={styles.content}>
        <CameraView isActive={isTranslating} />
        <TranslationDisplay text={translatedText} />

        <View style={styles.controlsContainer}>
          {!isTranslating ? (
            <TouchableOpacity
              style={[styles.button, styles.startButton]}
              onPress={startTranslation}
            >
              <Text style={styles.buttonText}>开始翻译</Text>
            </TouchableOpacity>
          ) : (
            <TouchableOpacity
              style={[styles.button, styles.stopButton]}
              onPress={stopTranslation}
            >
              <Text style={styles.buttonText}>停止翻译</Text>
            </TouchableOpacity>
          )}

          <TouchableOpacity
            style={[styles.button, styles.clearButton]}
            onPress={clearTranslation}
            disabled={isTranslating}
            opacity={isTranslating ? 0.5 : 1}
          >
            <Text style={styles.buttonText}>清除</Text>
          </TouchableOpacity>
        </View>
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#F5FCFF',
  },
  content: {
    flex: 1,
    padding: 10,
  },
  controlsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    padding: 20,
  },
  button: {
    paddingVertical: 12,
    paddingHorizontal: 25,
    borderRadius: 25,
  },
  startButton: {
    backgroundColor: '#4CAF50',
  },
  stopButton: {
    backgroundColor: '#F44336',
  },
  clearButton: {
    backgroundColor: '#2196F3',
  },
  buttonText: {
    color: 'white',
    fontWeight: 'bold',
  },
});