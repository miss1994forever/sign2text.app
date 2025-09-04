// SignLanguageTranslator/services/types.ts
export interface ITranslationService {
  start(onUpdateCallback: (text: string) => void, onStatusUpdate?: (status: any) => void): void;
  stop(): void;
  clear(): void;
  processFrame?(imageBase64: string): Promise<string>;
}
