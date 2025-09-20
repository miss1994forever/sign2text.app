//
//  DictionaryManager.swift
//  sign2text-app
//
//  Created by haojun on 2025/9/12.
//

import Foundation
import SwiftUI
import CloudKit
import AVFoundation

// MARK: - Dictionary Manager

/// Manages the sign language dictionary including local storage and cloud synchronization
class DictionaryManager: ObservableObject {
    @Published var words: [SignLanguageWord] = []
    @Published var isCloudSyncEnabled = false
    @Published var isSyncing = false
    @Published var syncError: String?
    
    private let localStorageManager = LocalStorageManager()
    private let cloudManager = CloudDictionaryManager()
    
    // MARK: - Initialization
    
    init() {
        loadLocalDictionary()
        setupCloudSync()
    }
    
    // MARK: - Public Methods
    
    /// Adds a new word to the dictionary
    func addWord(_ word: SignLanguageWord) {
        words.append(word)
        saveLocalDictionary()
        
        if isCloudSyncEnabled {
            uploadToCloud(word)
        }
    }
    
    /// Adds media file to an existing word
    func addMediaToWord(wordId: UUID, mediaFile: MediaFile) {
        if let index = words.firstIndex(where: { $0.id == wordId }) {
            var updatedWord = words[index]
            var updatedMediaFiles = updatedWord.mediaFiles
            updatedMediaFiles.append(mediaFile)
            
            // Create new word instance with updated media files
            words[index] = SignLanguageWord(
                word: updatedWord.word,
                description: updatedWord.description,
                category: updatedWord.category,
                mediaFiles: updatedMediaFiles,
                addedBy: updatedWord.addedBy
            )
            
            saveLocalDictionary()
            
            if isCloudSyncEnabled {
                uploadMediaToCloud(mediaFile)
            }
        }
    }
    
    /// Removes a word from the dictionary
    func removeWord(_ wordId: UUID) {
        words.removeAll { $0.id == wordId }
        saveLocalDictionary()
        
        if isCloudSyncEnabled {
            removeFromCloud(wordId)
        }
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
    
    /// Loads words (for compatibility with existing DictionaryView)
    func loadWords() {
        loadLocalDictionary()
    }
    
    // MARK: - Cloud Sync Methods
    
    func enableCloudSync() {
        isCloudSyncEnabled = true
        syncWithCloud()
    }
    
    func disableCloudSync() {
        isCloudSyncEnabled = false
    }
    
    private func syncWithCloud() {
        guard isCloudSyncEnabled else { return }
        
        isSyncing = true
        
        Task {
            do {
                let cloudWords = try await cloudManager.fetchAllWords()
                
                DispatchQueue.main.async {
                    // Merge cloud and local data
                    self.mergeCloudData(cloudWords)
                    self.isSyncing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.syncError = error.localizedDescription
                    self.isSyncing = false
                }
            }
        }
    }
    
    private func uploadToCloud(_ word: SignLanguageWord) {
        Task {
            try await cloudManager.uploadWord(word)
        }
    }
    
    private func uploadMediaToCloud(_ mediaFile: MediaFile) {
        Task {
            try await cloudManager.uploadMedia(mediaFile)
        }
    }
    
    private func removeFromCloud(_ wordId: UUID) {
        Task {
            try await cloudManager.removeWord(wordId)
        }
    }
    
    private func mergeCloudData(_ cloudWords: [SignLanguageWord]) {
        // Simple merge strategy - could be enhanced with conflict resolution
        let localWordIds = Set(words.map { $0.id })
        let newCloudWords = cloudWords.filter { !localWordIds.contains($0.id) }
        
        words.append(contentsOf: newCloudWords)
        saveLocalDictionary()
    }
    
    // MARK: - Local Storage Methods
    
    private func loadLocalDictionary() {
        words = localStorageManager.loadWords()
        
        // Load sample words if dictionary is empty
        if words.isEmpty {
            loadSampleWords()
        }
    }
    
    /// Loads sample words for demonstration
    private func loadSampleWords() {
        words = [
            SignLanguageWord(word: "Hello", description: "Basic greeting", category: .greetings),
            SignLanguageWord(
                word: "Thank you", description: "Expression of gratitude", category: .greetings),
            SignLanguageWord(word: "Please", description: "Polite request", category: .greetings),
            SignLanguageWord(word: "Sorry", description: "Apology", category: .emotions),
            SignLanguageWord(word: "Happy", description: "Feeling of joy", category: .emotions),
            SignLanguageWord(word: "Sad", description: "Feeling of sorrow", category: .emotions),
            SignLanguageWord(word: "Water", description: "H2O, liquid to drink", category: .food),
            SignLanguageWord(word: "Food", description: "Something to eat", category: .food),
        ]
        saveLocalDictionary()
    }
    
    private func saveLocalDictionary() {
        localStorageManager.saveWords(words)
    }
    
    private func setupCloudSync() {
        // Check if user has iCloud enabled
        if CloudKitManager.shared.isAvailable {
            isCloudSyncEnabled = true
        }
    }
}

// MARK: - Local Storage Manager

class LocalStorageManager {
    private let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let dictionaryFileName = "sign_language_dictionary.json"
    private let mediaDirectory = "sign_language_media"
    
    private var dictionaryURL: URL {
        documentsDirectory.appendingPathComponent(dictionaryFileName)
    }
    
    private var mediaDirectoryURL: URL {
        documentsDirectory.appendingPathComponent(mediaDirectory)
    }
    
    init() {
        createMediaDirectoryIfNeeded()
    }
    
    func saveWords(_ words: [SignLanguageWord]) {
        do {
            let data = try JSONEncoder().encode(words)
            try data.write(to: dictionaryURL)
        } catch {
            print("Failed to save dictionary: \(error)")
        }
    }
    
    func loadWords() -> [SignLanguageWord] {
        guard FileManager.default.fileExists(atPath: dictionaryURL.path) else {
            return []
        }
        
        do {
            let data = try Data(contentsOf: dictionaryURL)
            return try JSONDecoder().decode([SignLanguageWord].self, from: data)
        } catch {
            print("Failed to load dictionary: \(error)")
            return []
        }
    }
    
    func saveMedia(data: Data, fileName: String) -> String? {
        let fileURL = mediaDirectoryURL.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileURL.path
        } catch {
            print("Failed to save media file: \(error)")
            return nil
        }
    }
    
    func deleteMedia(at path: String) {
        let url = URL(fileURLWithPath: path)
        try? FileManager.default.removeItem(at: url)
    }
    
    private func createMediaDirectoryIfNeeded() {
        if !FileManager.default.fileExists(atPath: mediaDirectoryURL.path) {
            try? FileManager.default.createDirectory(at: mediaDirectoryURL, withIntermediateDirectories: true)
        }
    }
}

// MARK: - Cloud Dictionary Manager

class CloudDictionaryManager {
    private let container = CKContainer.default()
    private let database: CKDatabase
    
    init() {
        database = container.privateCloudDatabase
    }
    
    func fetchAllWords() async throws -> [SignLanguageWord] {
        let query = CKQuery(recordType: "SignLanguageWord", predicate: NSPredicate(value: true))
        let result = try await database.records(matching: query)
        
        return result.matchResults.compactMap { _, result in
            switch result {
            case .success(let record):
                return convertRecordToWord(record)
            case .failure:
                return nil
            }
        }
    }
    
    func uploadWord(_ word: SignLanguageWord) async throws {
        let record = convertWordToRecord(word)
        try await database.save(record)
    }
    
    func uploadMedia(_ mediaFile: MediaFile) async throws {
        // Implementation for uploading media files to CloudKit
        // This would involve creating CKAsset for large files
    }
    
    func removeWord(_ wordId: UUID) async throws {
        let recordID = CKRecord.ID(recordName: wordId.uuidString)
        try await database.deleteRecord(withID: recordID)
    }
    
    private func convertWordToRecord(_ word: SignLanguageWord) -> CKRecord {
        let record = CKRecord(recordType: "SignLanguageWord", recordID: CKRecord.ID(recordName: word.id.uuidString))
        record["word"] = word.word
        record["description"] = word.description
        record["category"] = word.category.rawValue
        record["dateAdded"] = word.dateAdded
        record["addedBy"] = word.addedBy
        return record
    }
    
    private func convertRecordToWord(_ record: CKRecord) -> SignLanguageWord? {
        guard let word = record["word"] as? String,
              let categoryString = record["category"] as? String,
              let category = SignLanguageCategory(rawValue: categoryString),
              let dateAdded = record["dateAdded"] as? Date else {
            return nil
        }
        
        let description = record["description"] as? String
        let addedBy = record["addedBy"] as? String
        
        return SignLanguageWord(
            word: word,
            description: description,
            category: category,
            mediaFiles: [], // Media files would be loaded separately
            addedBy: addedBy
        )
    }
}

// MARK: - CloudKit Manager

class CloudKitManager {
    static let shared = CloudKitManager()
    
    var isAvailable: Bool {
        return FileManager.default.ubiquityIdentityToken != nil
    }
    
    private init() {}
}