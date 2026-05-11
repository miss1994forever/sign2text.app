//
//  DictionaryManager.swift
//  sign2text-app
//
//  Created by haojun on 2025/9/12.
//

import Foundation
import SwiftUI

// MARK: - Dictionary Manager

enum DictionaryDataset: String, CaseIterable, Identifiable {
    case cslDaily = "csl-daily"
    case phoenix = "phoenix"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cslDaily:
            return "CSL-Daily"
        case .phoenix:
            return "PHOENIX"
        }
    }

    var subtitle: String {
        switch self {
        case .cslDaily:
            return "800 curated CSL-Daily entries"
        case .phoenix:
            return "1115 PHOENIX weather gloss entries"
        }
    }

    var storageKey: String {
        "SavedSignLanguageWords.\(rawValue)"
    }
}

/// Manages the sign language dictionary with simplified, safe implementation
class DictionaryManager: ObservableObject {
    @Published var words: [SignLanguageWord] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isCloudSyncEnabled = false
    @Published var isSyncing = false
    @Published var syncError: String?
    @Published var selectedDataset: DictionaryDataset
    
    private let userDefaults = UserDefaults.standard
    private let selectedDatasetKey = "SelectedSignLanguageDataset"
    
    // MARK: - Initialization
    
    init() {
        selectedDataset = DictionaryDataset(
            rawValue: userDefaults.string(forKey: selectedDatasetKey) ?? ""
        ) ?? .cslDaily
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
            
            let loadedWords = self.loadWordsFromUserDefaults(for: self.selectedDataset)
            let builtInWords = loadedWords.isEmpty
                ? DictionaryCatalogLoader.loadWords(for: self.selectedDataset) : []
            let resolvedWords = loadedWords.isEmpty ? builtInWords : loadedWords
            
            DispatchQueue.main.async {
                self.words = resolvedWords
                self.isLoading = false

                if self.words.isEmpty {
                    self.errorMessage = "Failed to load the \(self.selectedDataset.title) dictionary."
                }
                
                print("📚 Successfully loaded \(self.words.count) words")
            }
        }
    }

    func selectDataset(_ dataset: DictionaryDataset) {
        guard dataset != selectedDataset else { return }
        selectedDataset = dataset
        userDefaults.set(dataset.rawValue, forKey: selectedDatasetKey)
        loadWords()
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
        loadWordsFromUserDefaults(for: selectedDataset)
    }

    private func loadWordsFromUserDefaults(for dataset: DictionaryDataset) -> [SignLanguageWord] {
        print("📚 Loading words from UserDefaults for \(dataset.rawValue)...")
        
        guard let data = userDefaults.data(forKey: dataset.storageKey) else {
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
            userDefaults.removeObject(forKey: dataset.storageKey)
            
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
            userDefaults.set(data, forKey: selectedDataset.storageKey)
            userDefaults.synchronize() // Force save
            print("📚 Successfully saved words to UserDefaults")
        } catch {
            print("📚 Failed to save words: \(error.localizedDescription)")
            DispatchQueue.main.async { [weak self] in
                self?.errorMessage = "Failed to save dictionary changes."
            }
        }
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

private enum DictionaryCatalogLoader {
    private static let cslCSVFallbackPath = "/root/autodl-tmp/sign2text.app/backend/vocabulary/csl_daily_800.csv"
    private static let phoenixVocabFallbackPath = "/root/autodl-tmp/datasets/phoenix_2014t/phoenix_iso_with_blank.vocab"

    static func loadWords(for dataset: DictionaryDataset) -> [SignLanguageWord] {
        switch dataset {
        case .cslDaily:
            return loadCSLDailyWords()
        case .phoenix:
            return loadPhoenixWords()
        }
    }

    private static func loadCSLDailyWords() -> [SignLanguageWord] {
        guard let csvText = loadTextResource(
            resourceName: "csl_daily_800",
            fileExtension: "csv",
            fallbackPath: cslCSVFallbackPath
        ) else {
            return []
        }

        let rows = parseCSV(csvText)
        guard let header = rows.first else { return [] }
        let dataRows = rows.dropFirst()

        return dataRows.compactMap { row in
            guard row.count == header.count else { return nil }
            let record = Dictionary(uniqueKeysWithValues: zip(header, row))
            guard
                let gloss = record["gloss"],
                let rankText = record["rank"],
                let rank = Int(rankText),
                let trainTokenText = record["train_token_count"],
                let trainTokenCount = Int(trainTokenText),
                let allTokenText = record["all_token_count"],
                let allTokenCount = Int(allTokenText)
            else {
                return nil
            }

            let coverageText = formatCoverage(record["cumulative_train_token_coverage"])
            let description = "CSL-Daily rank #\(rank) · train \(trainTokenCount) · total \(allTokenCount) · coverage \(coverageText)"

            return SignLanguageWord(
                word: gloss,
                description: description,
                category: categoryForCSLDailyGloss(gloss),
                mediaFiles: [generatedImage(dataset: .cslDaily, word: gloss)],
                addedBy: DictionaryDataset.cslDaily.title
            )
        }
    }

    private static func loadPhoenixWords() -> [SignLanguageWord] {
        guard let rawData = loadDataResource(
            resourceName: "phoenix_iso_with_blank",
            fileExtension: "vocab",
            fallbackPath: phoenixVocabFallbackPath
        ) else {
            return []
        }

        guard
            let object = try? JSONSerialization.jsonObject(with: rawData),
            let tokens = object as? [String]
        else {
            return []
        }

        return tokens
            .filter { !$0.isEmpty && !$0.hasPrefix("<") }
            .enumerated()
            .map { offset, token in
                let normalized = humanizePhoenixToken(token)
                let description = "PHOENIX weather gloss #\(offset + 1) · \(normalized)"
                return SignLanguageWord(
                    word: token,
                    description: description,
                    category: categoryForPhoenixGloss(token),
                    mediaFiles: [generatedImage(dataset: .phoenix, word: token)],
                    addedBy: DictionaryDataset.phoenix.title
                )
            }
    }

    private static func loadTextResource(
        resourceName: String,
        fileExtension: String,
        fallbackPath: String
    ) -> String? {
        if let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) {
            return try? String(contentsOf: url, encoding: .utf8)
        }

        return try? String(contentsOfFile: fallbackPath, encoding: .utf8)
    }

    private static func loadDataResource(
        resourceName: String,
        fileExtension: String,
        fallbackPath: String
    ) -> Data? {
        if let url = Bundle.main.url(forResource: resourceName, withExtension: fileExtension) {
            return try? Data(contentsOf: url)
        }

        return try? Data(contentsOf: URL(fileURLWithPath: fallbackPath))
    }

    private static func parseCSV(_ text: String) -> [[String]] {
        text
            .split(whereSeparator: \ .isNewline)
            .map {
                $0.split(separator: ",", omittingEmptySubsequences: false)
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            }
    }

    private static func formatCoverage(_ value: String?) -> String {
        guard let value, let doubleValue = Double(value) else {
            return "n/a"
        }

        return String(format: "%.1f%%", doubleValue * 100)
    }

    private static func categoryForCSLDailyGloss(_ gloss: String) -> SignLanguageCategory {
        if Int(gloss) != nil {
            return .numbers
        }

        if ["妈妈", "爸爸"].contains(gloss) {
            return .family
        }

        if ["吃", "喝", "东西", "钱"].contains(gloss) {
            return .food
        }

        if ["今天", "时间", "年"].contains(gloss) {
            return .time
        }

        if ["看", "说", "做", "买", "给", "学", "工作", "去"].contains(gloss) {
            return .actions
        }

        return .general
    }

    private static func categoryForPhoenixGloss(_ gloss: String) -> SignLanguageCategory {
        let token = gloss.lowercased()

        if [
            "eins", "zwei", "drei", "vier", "fuenf", "sechs", "sieben", "acht", "neun",
            "zehn", "elf", "zwoelf", "dreizehn", "vierzehn", "fuenfzehn", "sechzehn",
            "siebzehn", "achtzehn", "neunzehn", "zwanzig", "dreissig", "vierzig", "fuenfzig"
        ].contains(token) {
            return .numbers
        }

        if [
            "morgen", "heute", "abend", "nacht", "mittag", "montag", "dienstag", "mittwoch",
            "donnerstag", "freitag", "samstag", "sonntag", "woche", "wochenende"
        ].contains(token) {
            return .time
        }

        if ["kommen", "gehen", "steigen", "sinken", "wehen", "schneien", "zeigen-bildschirm"].contains(token) {
            return .actions
        }

        return .general
    }

    private static func humanizePhoenixToken(_ token: String) -> String {
        token
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
    }

    private static func generatedImage(dataset: DictionaryDataset, word: String) -> MediaFile {
        let sanitizedWord = word
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "/", with: "-")

        return MediaFile(
            fileName: "\(dataset.rawValue)-\(sanitizedWord).png",
            type: .image,
            localPath: "generated://\(dataset.rawValue)/\(sanitizedWord)",
            cloudURL: nil,
            fileSize: 0,
            duration: nil,
            thumbnail: nil,
            dateCreated: Date(),
            isCloudSynced: false
        )
    }
}