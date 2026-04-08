// SignLanguageTranslator/services/mockMLService.ts
import { ITranslationService } from './types';

export type TranslationCallback = (text: string) => void;

class MockMLService implements ITranslationService {
  private isRunning: boolean = false;
  private intervalId: NodeJS.Timeout | null = null;
  private currentText: string = '';

  // Mock Chinese phrases that could be returned
  private mockPhrases: string[] = [
    '你好', // Hello
    '谢谢', // Thank you
    '再见', // Goodbye
    '我叫...', // My name is...
    '请问...', // May I ask...
    '对不起', // Sorry
    '没关系', // No problem
    '我需要帮助', // I need help
    '今天天气很好', // The weather is nice today
    '我喜欢学习手语' // I like learning sign language
  ];

  // Start processing "frames" and producing mock translations
  start(onUpdateCallback: TranslationCallback): void {
    this.isRunning = true;
    this.currentText = '';

    // Simulate processing by emitting random phrases at intervals
    this.intervalId = setInterval(() => {
      if (!this.isRunning) return;

      // Add a new phrase or extend the current one
      if (Math.random() > 0.5 || this.currentText === '') {
        const randomPhrase = this.mockPhrases[Math.floor(Math.random() * this.mockPhrases.length)];
        this.currentText = this.currentText 
          ? `${this.currentText} ${randomPhrase}` 
          : randomPhrase;
      } else {
        // Add characters to simulate continuous recognition
        this.currentText += '...';
      }

      onUpdateCallback(this.currentText);
    }, 800); // Update approximately every second
  }

  // Stop processing
  stop(): void {
    this.isRunning = false;
    if (this.intervalId) {
      clearInterval(this.intervalId);
      this.intervalId = null;
    }
  }

  // Clear the current translation
  clear(): void {
    this.currentText = '';
  }
}

export default new MockMLService();