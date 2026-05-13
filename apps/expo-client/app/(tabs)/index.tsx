// SignLanguageTranslator/app/(tabs)/index.tsx
import React, { useEffect, useState } from 'react';
import { StyleSheet, Text, TouchableOpacity, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import CameraView from '../../components/CameraView';
import TranslationDisplay from '../../components/TranslationDisplay';
import mockMLService from '../../services/mockMLService';
import signLanguageService, { ServiceStatus } from '../../services/signLanguageService';
import { ITranslationService } from '../../services/types';

export default function SignLanguageTranslator() {
  const [translatedText, setTranslatedText] = useState('');
  const [isTranslating, setIsTranslating] = useState(false);
  const [useMockService, setUseMockService] = useState(true);
  const [serviceStatus, setServiceStatus] = useState<ServiceStatus>({
    isError: false,
    consecutiveFailures: 0,
    isConnected: false,
    currentRetry: 0
  });

  const currentService = (useMockService ? mockMLService : signLanguageService) as ITranslationService;

  // Clean up the ML service when component unmounts
  useEffect(() => {
    return () => {
      currentService.stop();
    };
  }, [currentService]);

  const startTranslation = () => {
    // log information for debugging
    console.log('Starting translation with', useMockService ? 'Mock Service' : 'API Service');
    setIsTranslating(true);
    currentService.start(
      (newText) => {
        setTranslatedText(newText);
      },
      !useMockService ? (status) => {
        setServiceStatus(status);
        // Auto-stop if too many consecutive failures
        if (status.consecutiveFailures > 5) {
          stopTranslation();
        }
      } : undefined
    );
  };

  const stopTranslation = () => {
    setIsTranslating(false);
    currentService.stop();
  };

  const clearTranslation = () => {
    setTranslatedText('');
    currentService.clear();
  };

  const toggleService = () => {
    if (isTranslating) {
      currentService.stop();
    }
    // Stop the current service and explicitly set the mock mode
    signLanguageService.setUseMock(!useMockService);
    setUseMockService(!useMockService);
  };

  return (
    <SafeAreaView style={styles.container}>
      <View style={[
        styles.serviceIndicator,
        useMockService ? styles.mockIndicator : styles.apiIndicator,
        !useMockService && serviceStatus.isError && styles.errorIndicator
      ]}>
        <View style={styles.serviceStatusRow}>
          <Text style={[
            styles.serviceIndicatorText,
            !useMockService && serviceStatus.isError && styles.errorText
          ]}>
            {useMockService 
              ? '📱 模拟服务模式' 
              : serviceStatus.isError 
                ? '⚠️ API服务异常' 
                : serviceStatus.isConnected
                  ? '🌐 API服务已连接'
                  : '🔄 API服务连接中...'}
          </Text>
          {!useMockService && (
            <View style={styles.statusDot}>
              <View style={[
                styles.dot,
                serviceStatus.isError 
                  ? styles.errorDot 
                  : serviceStatus.isConnected 
                    ? styles.successDot
                    : styles.connectingDot,
                serviceStatus.currentRetry > 0 && styles.pulsingDot
              ]} />
            </View>
          )}
        </View>
        
        {!useMockService && (
          <View style={styles.statusDetails}>
            <Text style={[
              styles.serviceIndicatorSubtext,
              serviceStatus.isError && styles.errorText
            ]}>
              {serviceStatus.isError ? (
                <>
                  {serviceStatus.error?.code === 'API_KEY_MISSING' && '未配置API密钥'}
                  {serviceStatus.error?.code === 'NETWORK_ERROR' && '网络连接失败'}
                  {serviceStatus.error?.code === 'API_ERROR' && 'API请求失败'}
                  {serviceStatus.error?.code === 'CONNECTION_ERROR' && 'API连接失败'}
                  {serviceStatus.error?.code === 'UNKNOWN_ERROR' && '服务异常'}
                  {serviceStatus.currentRetry > 0 && ` (重试第${serviceStatus.currentRetry}次)`}
                  {serviceStatus.consecutiveFailures > 0 && ` [连续${serviceStatus.consecutiveFailures}次失败]`}
                </>
              ) : (
                <>
                  {serviceStatus.isConnected ? (
                    serviceStatus.lastSuccessTime 
                      ? `最近成功: ${new Date(serviceStatus.lastSuccessTime).toLocaleTimeString()}`
                      : '等待首次识别...'
                  ) : (
                    '正在连接API服务...'
                  )}
                </>
              )}
            </Text>
            {serviceStatus.isError && serviceStatus.error?.message && (
              <Text style={styles.errorDetailsText}>
                错误详情: {serviceStatus.error.message}
              </Text>
            )}
          </View>
        )}
      </View>

      <View style={styles.content}>
        <CameraView isActive={isTranslating} />
        <TranslationDisplay text={translatedText} />
        
        {!useMockService && serviceStatus.isError && (
          <View style={styles.errorContainer}>
            <Text style={styles.errorText}>
              {serviceStatus.error?.code === 'API_KEY_MISSING' && '请配置API密钥'}
              {serviceStatus.error?.code === 'NETWORK_ERROR' && '网络连接错误'}
              {serviceStatus.error?.code === 'API_ERROR' && 'API服务错误'}
              {serviceStatus.error?.code === 'UNKNOWN_ERROR' && '未知错误'}
            </Text>
            <Text style={styles.errorDetails}>
              {serviceStatus.error?.message}
            </Text>
          </View>
        )}

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
            style={[
              styles.button,
              styles.clearButton,
              isTranslating && styles.disabledButton
            ]}
            onPress={clearTranslation}
            disabled={isTranslating}
          >
            <Text style={styles.buttonText}>清除</Text>
          </TouchableOpacity>

          <TouchableOpacity
            style={[
              styles.button,
              styles.toggleButton,
              useMockService ? styles.toggleToApiButton : styles.toggleToMockButton
            ]}
            onPress={toggleService}
          >
            <Text style={styles.buttonText}>
              {useMockService ? '切换到API服务 🌐' : '切换到模拟服务 📱'}
            </Text>
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
  serviceIndicator: {
    padding: 12,
    marginHorizontal: 10,
    marginTop: 10,
    borderRadius: 8,
    borderWidth: 2,
  },
  serviceStatusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    marginBottom: 4,
  },
  statusDetails: {
    alignItems: 'center',
  },
  mockIndicator: {
    backgroundColor: '#e8f5e9',
    borderColor: '#81c784',
  },
  apiIndicator: {
    backgroundColor: '#e3f2fd',
    borderColor: '#64b5f6',
  },
  errorIndicator: {
    backgroundColor: '#fff3e0',
    borderColor: '#ff9800',
  },
  serviceIndicatorText: {
    fontSize: 18,
    fontWeight: 'bold',
    color: '#2e7d32',
  },
  serviceIndicatorSubtext: {
    fontSize: 14,
    color: '#1565c0',
    marginTop: 4,
  },
  statusDot: {
    marginLeft: 8,
    marginRight: 4,
  },
  dot: {
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  successDot: {
    backgroundColor: '#4caf50',
  },
  errorDot: {
    backgroundColor: '#f44336',
  },
  connectingDot: {
    backgroundColor: '#ff9800',
  },
  pulsingDot: {
    opacity: 0.7,
  },
  errorDetailsText: {
    fontSize: 12,
    color: '#d32f2f',
    marginTop: 4,
  },
  content: {
    flex: 1,
    padding: 10,
  },
  errorContainer: {
    backgroundColor: '#ffebee',
    padding: 10,
    margin: 10,
    borderRadius: 8,
    borderWidth: 1,
    borderColor: '#ef9a9a',
  },
  errorText: {
    color: '#c62828',
    fontSize: 16,
    fontWeight: 'bold',
    marginBottom: 4,
  },
  errorDetails: {
    color: '#e53935',
    fontSize: 14,
  },
  controlsContainer: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    padding: 20,
    flexWrap: 'wrap',
    gap: 10,
  },
  button: {
    paddingVertical: 12,
    paddingHorizontal: 25,
    borderRadius: 25,
    minWidth: 100,
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
  toggleButton: {
    paddingHorizontal: 20,
    marginTop: 10,
  },
  toggleToApiButton: {
    backgroundColor: '#1976D2',  // Blue for API
  },
  toggleToMockButton: {
    backgroundColor: '#388E3C',  // Green for Mock
  },
  disabledButton: {
    opacity: 0.5,
  },
  buttonText: {
    color: 'white',
    fontWeight: 'bold',
    textAlign: 'center',
    fontSize: 16,
  },
});