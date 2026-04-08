// SignLanguageTranslator/services/signLanguageService.ts
import mockMLService, { TranslationCallback } from './mockMLService';

export type ServiceError = {
  message: string;
  code: 'API_KEY_MISSING' | 'NETWORK_ERROR' | 'API_ERROR' | 'UNKNOWN_ERROR' | 'CONNECTION_ERROR';
  details?: any;
};

export type ServiceStatus = {
  isError: boolean;
  error?: ServiceError;
  lastSuccessTime?: Date;
  consecutiveFailures: number;
  isConnected: boolean;
  currentRetry: number;
};

// Define this outside the class to avoid TypeScript errors
const processAPIResponse = (prediction: any): string => {
  if (!prediction) return '';
  
  try {
    // Roboflow object detection response format
    if (Array.isArray(prediction.predictions)) {
      // Get the prediction with highest confidence
      const bestPrediction = prediction.predictions
        .sort((a: any, b: any) => b.confidence - a.confidence)[0];
      
      if (bestPrediction) {
        return `${bestPrediction.class} (${(bestPrediction.confidence * 100).toFixed(1)}%)`;
      }
    }
    
    // Return raw prediction text if available
    if (prediction.text) {
      return prediction.text;
    }
    
    // If no structured prediction found, return empty string
    return '';
  } catch (error) {
    console.error('Error formatting prediction:', error);
    return '';
  }
};

class SignLanguageService {
  private isRunning: boolean = false;
  private currentText: string = '';
  private useMock: boolean = false;
  private API_KEY: string = 'YOUR_API_KEY'; // Replace with your actual API key
  private API_URL: string = 'https://serverless.roboflow.com/sign-language-recognition-mmbok/1';
  private status: ServiceStatus = {
    isError: false,
    consecutiveFailures: 0,
    isConnected: false,
    currentRetry: 0
  };
  private onStatusUpdate?: (status: ServiceStatus) => void;

  async processFrame(imageBase64: string): Promise<string> {
    if (this.useMock) {
      return ''; // Should never reach here, mock service handles its own processing
    }

    console.log('Processing frame with SignLanguageService');
    if (this.API_KEY === 'YOUR_API_KEY') {
      this.updateStatus({
        isError: true,
        error: {
          code: 'API_KEY_MISSING',
          message: 'API key not configured'
        },
        consecutiveFailures: this.status.consecutiveFailures + 1
      });
      throw new Error('API key not configured');
    }

    try {
      // Format the image data according to Roboflow's requirements
      const formData = new FormData();
      // Convert base64 to blob
      const base64Data = imageBase64.split(',')[1] || imageBase64;
      const byteCharacters = atob(base64Data);
      const byteNumbers = new Array(byteCharacters.length);
      for (let i = 0; i < byteCharacters.length; i++) {
        byteNumbers[i] = byteCharacters.charCodeAt(i);
      }
      const byteArray = new Uint8Array(byteNumbers);
      const blob = new Blob([byteArray], { type: 'image/jpeg' });
      
      formData.append('file', blob, 'image.jpg');

      const response = await fetch(`${this.API_URL}?api_key=${this.API_KEY}`, {
        method: 'POST',
        body: formData,
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();
      console.log('API Response:', data);
      
      // Reset error status on successful call
      this.updateStatus({
        isError: false,
        lastSuccessTime: new Date(),
        consecutiveFailures: 0
      });
      
      return this.formatPrediction(data);
    } catch (error) {
      console.error('Error processing frame:', error);
      
      const serviceError: ServiceError = {
        code: error instanceof Error && error.message.includes('API key') 
          ? 'API_KEY_MISSING'
          : !navigator.onLine 
          ? 'NETWORK_ERROR'
          : error instanceof Error && error.message.includes('HTTP error')
          ? 'API_ERROR'
          : 'UNKNOWN_ERROR',
        message: error instanceof Error ? error.message : 'Unknown error occurred',
        details: error
      };

      this.updateStatus({
        isError: true,
        error: serviceError,
        consecutiveFailures: this.status.consecutiveFailures + 1
      });

      throw serviceError;
    }
  }

  private formatPrediction(prediction: any): string {
    return processAPIResponse(prediction);
  }

  private updateStatus(newStatus: Partial<ServiceStatus>): void {
    this.status = { ...this.status, ...newStatus };
    if (this.onStatusUpdate) {
      this.onStatusUpdate(this.status);
    }
  }

  getStatus(): ServiceStatus {
    return { ...this.status };
  }

  start(onUpdateCallback: TranslationCallback, onStatusUpdate?: (status: ServiceStatus) => void): void {
    // log information for debugging
    console.log('Starting SignLanguageService with', this.useMock ? 'Mock Service' : 'API Service');
    if (this.useMock) {
      mockMLService.start(onUpdateCallback);
      return;
    }
    this.onStatusUpdate = onStatusUpdate;
    this.isRunning = true;
    this.currentText = '';
    
    // Reset status when starting
    this.updateStatus({
      isError: false,
      consecutiveFailures: 0,
      isConnected: false,
      currentRetry: 0,
      error: undefined
    });
  }

  stop(): void {
    if (this.useMock) {
      mockMLService.stop();
      return;
    }

    this.isRunning = false;
    this.onStatusUpdate = undefined;
  }

  clear(): void {
    if (this.useMock) {
      mockMLService.clear();
      return;
    }

    this.currentText = '';
  }

  public setUseMock(useMock: boolean): void {
    if (this.useMock === useMock) return; // No change needed
    
    // Stop any ongoing translation when switching services
    if (this.isRunning) {
      this.stop();
    }
    
    this.useMock = useMock;
    console.log(`Switched to ${useMock ? 'Mock' : 'API'} service`);
    
    // Reset status
    this.updateStatus({
      isError: false,
      consecutiveFailures: 0,
      error: undefined,
      lastSuccessTime: undefined
    });
  }
}

export default new SignLanguageService();
