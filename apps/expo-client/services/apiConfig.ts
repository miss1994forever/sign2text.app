// SignLanguageTranslator/services/apiConfig.ts
export const API_CONFIG = {
  MAX_RETRIES: 3,
  RETRY_DELAY: 1000, // 1 second
  CONNECTION_TIMEOUT: 10000, // 10 seconds
  MIN_CONFIDENCE: 0.5, // 50% confidence threshold
};

export const testAPIConnection = async (apiKey: string, apiUrl: string): Promise<boolean> => {
  try {
    const response = await fetch(`${apiUrl}?api_key=${apiKey}`, {
      method: 'HEAD',
      timeout: API_CONFIG.CONNECTION_TIMEOUT,
    });
    return response.ok;
  } catch (error) {
    console.error('API connection test failed:', error);
    return false;
  }
};
