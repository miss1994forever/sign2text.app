//
//  DictionaryManager.swift
//  sign2text-app
//
//  Created by haojun on 2025/9/12.
//

import Foundation
import SwiftUI

// MARK: - Dictionary Manager

/// Manages the sign language dictionary with simplified, safe implementation
class DictionaryManager: ObservableObject {
    @Published var words: [SignLanguageWord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isCloudSyncEnabled = false
    @Published var isSyncing = false
    @Published var syncError: String?
    
    private let userDefaults = UserDefaults.standard
    private let wordsKey = "SavedSignLanguageWords"
    private let seedManifestName = "csl_daily_top800_dictionary_seed"
    
    // MARK: - Initialization
    
    init() {
        print("📚 Initializing DictionaryManager...")
        loadWords()
    }
    
    // MARK: - Public Methods
    
    /// Loads words from storage
    func loadWords() {
        print("📚 Loading words...")
        isLoading = true
        errorMessage = nil
        
        // Load on background queue to avoid blocking UI
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            
            let savedWords = self.loadWordsFromUserDefaults()
            let loadedWords = self.shouldReplaceWithSeed(savedWords)
                ? (self.loadSeedWords() ?? savedWords)
                : savedWords
            
            DispatchQueue.main.async {
                self.words = loadedWords
                self.isLoading = false
                
                // Add sample words if dictionary is empty and no seed dictionary is bundled.
                if self.words.isEmpty {
                    self.loadSampleWords()
                }
                
                print("📚 Successfully loaded \(self.words.count) words")
            }
        }
    }
    
    /// Adds a new word to the dictionary
    func addWord(_ word: SignLanguageWord) {
        print("📚 Adding new word: \(word.word)")
        words.append(word)
        saveWords()
    }
    
    /// Removes a word from the dictionary
    func removeWord(_ wordId: UUID) {
        print("📚 Removing word with ID: \(wordId)")
        words.removeAll { $0.id == wordId }
        saveWords()
    }
    
    /// Searches words in the dictionary
    func searchWords(_ query: String) -> [SignLanguageWord] {
        if query.isEmpty {
            return words
        }
        return words.filter { 
            $0.word.lowercased().contains(query.lowercased()) ||
            ($0.description?.lowercased().contains(query.lowercased()) ?? false)
        }
    }
    
    /// Gets words by category
    func getWords(in category: SignLanguageCategory) -> [SignLanguageWord] {
        return words.filter { $0.category == category }
    }
    
    // MARK: - Private Methods
    
    private func loadWordsFromUserDefaults() -> [SignLanguageWord] {
        print("📚 Loading words from UserDefaults...")
        
        guard let data = userDefaults.data(forKey: wordsKey) else {
            print("📚 No saved dictionary data found")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            let words = try decoder.decode([SignLanguageWord].self, from: data)
            print("📚 Successfully decoded \(words.count) words from storage")
            return words
        } catch {
            print("📚 Failed to decode words: \(error.localizedDescription)")
            
            // Clear corrupted data
            userDefaults.removeObject(forKey: wordsKey)
            
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Failed to load saved dictionary. Starting fresh."
            }
            return []
        }
    }
    
    private func saveWords() {
        print("📚 Saving \(words.count) words to storage...")
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(words)
            userDefaults.set(data, forKey: wordsKey)
            userDefaults.synchronize() // Force save
            print("📚 Successfully saved words to UserDefaults")
        } catch {
            print("📚 Failed to save words: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Failed to save dictionary changes."
            }
        }
    }

    private func shouldReplaceWithSeed(_ words: [SignLanguageWord]) -> Bool {
        guard seedManifestURL() != nil else { return false }
        if words.isEmpty { return true }

        let looksLikeDefaultSamples = words.count <= 7
            && words.allSatisfy { $0.mediaFiles.isEmpty && $0.addedBy == "System" }
        return looksLikeDefaultSamples
    }

    private func loadSeedWords() -> [SignLanguageWord]? {
        guard let manifestURL = seedManifestURL() else {
            print("📚 No bundled CSL-Daily dictionary seed found")
            return nil
        }

        do {
            let data = try Data(contentsOf: manifestURL)
            let manifest = try JSONDecoder().decode(DictionarySeedManifest.self, from: data)
            let words = manifest.entries.map { entry in
                SignLanguageWord(
                    word: entry.word,
                    description: entry.description,
                    category: SignLanguageCategory(rawValue: entry.category) ?? .general,
                    mediaFiles: entry.mediaFiles.map { media in
                        MediaFile(
                            fileName: media.fileName,
                            type: MediaFile.MediaType(rawValue: media.type) ?? .image,
                            localPath: media.localPath,
                            cloudURL: media.cloudURL,
                            fileSize: media.fileSize,
                            duration: media.duration,
                            thumbnail: media.thumbnail,
                            dateCreated: Date(),
                            isCloudSynced: false
                        )
                    },
                    addedBy: "CSL-Daily"
                )
            }
            print("📚 Loaded \(words.count) CSL-Daily seed words from \(manifestURL.path)")
            return words
        } catch {
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Failed to load CSL-Daily dictionary seed."
            }
            print("📚 Failed to load seed dictionary: \(error.localizedDescription)")
            return nil
        }
    }

    private func seedManifestURL() -> URL? {
        if let bundled = Bundle.main.url(
            forResource: seedManifestName,
            withExtension: "json",
            subdirectory: "DictionarySeed"
        ) {
            return bundled
        }

        let documentsSeed = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("DictionarySeed")
            .appendingPathComponent("\(seedManifestName).json")
        if let documentsSeed, FileManager.default.fileExists(atPath: documentsSeed.path) {
            return documentsSeed
        }

        return nil
    }
    
    private func loadSampleWords() {
        print("📚 Loading sample words...")
        
        let sampleWords: [SignLanguageWord] = [
            SignLanguageWord(
                word: "Hello", 
                description: "Basic greeting", 
                category: .greetings, 
                addedBy: "System"
            ),
            SignLanguageWord(
                word: "Thank you", 
                description: "Expression of gratitude", 
                category: .greetings, 
                addedBy: "System"
            ),
            SignLanguageWord(
                word: "Please", 
                description: "Polite request", 
                category: .greetings, 
                addedBy: "System"
            ),
            SignLanguageWord(
                word: "Sorry", 
                description: "Apology", 
                category: .emotions, 
                addedBy: "System"
            ),
            SignLanguageWord(
                word: "Happy", 
                description: "Feeling of joy", 
                category: .emotions, 
                addedBy: "System"
            ),
            SignLanguageWord(
                word: "Water", 
                description: "H2O, liquid to drink", 
                category: .food, 
                addedBy: "System"
            ),
            SignLanguageWord(
                word: "Food", 
                description: "Something to eat", 
                category: .food, 
                addedBy: "System"
            )
        ]
        
        words = sampleWords
        saveWords()
        print("📚 Loaded \(sampleWords.count) sample words")
    }
    
    // MARK: - Cloud Sync Methods (Simplified)
    
    func enableCloudSync() {
        isCloudSyncEnabled = true
        print("📚 Cloud sync enabled")
    }
    
    func disableCloudSync() {
        isCloudSyncEnabled = false
        print("📚 Cloud sync disabled")
    }
}

private struct DictionarySeedManifest: Decodable {
    let entries: [DictionarySeedEntry]
}

private struct DictionarySeedEntry: Decodable {
    let word: String
    let description: String?
    let category: String
    let mediaFiles: [DictionarySeedMediaFile]
}

private struct DictionarySeedMediaFile: Decodable {
    let fileName: String
    let type: String
    let localPath: String?
    let cloudURL: String?
    let fileSize: Int64
    let duration: TimeInterval?
    let thumbnail: String?
}
