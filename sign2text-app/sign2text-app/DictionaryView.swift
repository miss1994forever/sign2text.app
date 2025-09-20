//
//  DictionaryView.swift
//  sign2text-app
//
//  Created by haojun on 2025/9/3.
//

import PhotosUI
import SwiftUI

#if canImport(UIKit)
    import UIKit
#endif

// MARK: - Dictionary View

struct DictionaryView: View {
    // MARK: - State Properties
    @Environment(\.dismiss) private var dismiss
    @StateObject private var dictionaryManager = DictionaryManager()
    @EnvironmentObject var themeManager: ThemeManager

    @State private var searchText = ""
    @State private var selectedCategory: SignLanguageCategory = .general
    @State private var showingAddWordSheet = false
    @State private var showingImagePicker = false
    @State private var selectedImages: [String] = []  // Store image paths instead of image objects

    // MARK: - Computed Properties

    private var filteredWords: [SignLanguageWord] {
        let filtered = dictionaryManager.words.filter { word in
            // Filter by category
            (selectedCategory == .general || word.category == selectedCategory)
                // Filter by search text
                && (searchText.isEmpty || word.word.lowercased().contains(searchText.lowercased())
                    || word.description?.lowercased().contains(searchText.lowercased()) == true)
        }

        return filtered.sorted { $0.word < $1.word }
    }

    // MARK: - View Body

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with search and filters
                headerSection

                // Content area
                if filteredWords.isEmpty {
                    emptyStateView
                } else {
                    wordListView
                }

                Spacer()

                // Add new word button
                addWordButton
            }
            .navigationTitle("Sign Dictionary")
            .navigationBarTitleDisplayMode(.large)
            .background(themeManager.colors.background)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.colors.primaryText)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Import from Photos") {
                            // TODO: Implement import functionality
                        }

                        Button("Export Dictionary") {
                            // TODO: Implement export functionality
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(themeManager.colors.primaryText)
                    }
                }
            }
            .sheet(isPresented: $showingAddWordSheet) {
                AddWordView(
                    dictionaryManager: dictionaryManager,
                    selectedImages: $selectedImages
                )
                .environmentObject(themeManager)
            }
            .photosPicker(
                isPresented: $showingImagePicker,
                selection: Binding.constant([]),
                maxSelectionCount: 5,
                matching: .images
            )
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        .onAppear {
            dictionaryManager.loadWords()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 12) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(themeManager.colors.secondaryText)

                TextField("Search words...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                    .foregroundColor(themeManager.colors.primaryText)

                if !searchText.isEmpty {
                    Button("Clear") {
                        searchText = ""
                    }
                    .font(.caption)
                    .foregroundColor(themeManager.colors.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(themeManager.colors.secondaryBackground)
            .cornerRadius(10)

            // Category filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SignLanguageCategory.allCases, id: \.self) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selectedCategory == category,
                            themeManager: themeManager
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(themeManager.colors.background)
    }

    // MARK: - Word List View

    private var wordListView: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)
                ],
                spacing: 12
            ) {
                ForEach(filteredWords) { word in
                    WordCard(word: word, themeManager: themeManager) {
                        // TODO: Handle word tap (show details, edit, etc.)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "book.closed")
                .font(.system(size: 60))
                .foregroundColor(themeManager.colors.secondaryText)

            Text("No Words Found")
                .font(.title2)
                .fontWeight(.medium)
                .foregroundColor(themeManager.colors.primaryText)

            if searchText.isEmpty {
                Text(
                    "Start building your sign language dictionary by adding new words and their corresponding images."
                )
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            } else {
                Text("Try adjusting your search or category filter.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            if searchText.isEmpty {
                Button("Add Your First Word") {
                    showingAddWordSheet = true
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(themeManager.colors.background)
    }

    // MARK: - Add Word Button

    private var addWordButton: some View {
        Button(action: {
            showingAddWordSheet = true
        }) {
            HStack {
                Image(systemName: "plus")
                Text("Add New Word")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(themeManager.colors.accent)
            .cornerRadius(12)
        }
        .padding()
        .background(themeManager.colors.background)
    }
}

// MARK: - Category Chip Component

struct CategoryChip: View {
    let category: SignLanguageCategory
    let isSelected: Bool
    let themeManager: ThemeManager
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: category.icon)
                    .font(.caption)

                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isSelected ? themeManager.colors.accent : themeManager.colors.secondaryBackground
            )
            .foregroundColor(
                isSelected ? .white : themeManager.colors.primaryText
            )
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Word Card Component

struct WordCard: View {
    let word: SignLanguageWord
    let themeManager: ThemeManager
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Image placeholder or actual image
                RoundedRectangle(cornerRadius: 8)
                    .fill(themeManager.colors.secondaryBackground)
                    .frame(height: 120)
                    .overlay(
                        VStack {
                            Image(systemName: "photo")
                                .font(.title)
                                .foregroundColor(themeManager.colors.secondaryText)
                            Text("No Image")
                                .font(.caption)
                                .foregroundColor(themeManager.colors.secondaryText)
                        }
                    )

                // Word information
                VStack(alignment: .leading, spacing: 4) {
                    Text(word.word)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(themeManager.colors.primaryText)
                        .lineLimit(1)

                    if let description = word.description, !description.isEmpty {
                        Text(description)
                            .font(.caption)
                            .foregroundColor(themeManager.colors.secondaryText)
                            .lineLimit(2)
                    }

                    HStack {
                        Image(systemName: word.category.icon)
                            .font(.caption)

                        Text(word.category.rawValue)
                            .font(.caption)
                            .foregroundColor(themeManager.colors.secondaryText)

                        Spacer()

                        Text("No images")
                            .font(.caption2)
                            .foregroundColor(themeManager.colors.secondaryText)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(12)
            .background(themeManager.colors.cardBackground)
            .cornerRadius(12)
            .shadow(color: themeManager.colors.shadow, radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Add Word View

struct AddWordView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var dictionaryManager: DictionaryManager
    @Binding var selectedImages: [String]
    @EnvironmentObject var themeManager: ThemeManager

    @State private var wordText = ""
    @State private var wordDescription = ""
    @State private var selectedCategory: SignLanguageCategory = .general
    @State private var showingImagePicker = false
    @State private var photoPickerItems: [String] = []

    var body: some View {
        NavigationView {
            Form {
                Section("Word Information") {
                    TextField("Word or phrase", text: $wordText)
                        .font(.body)
                        .foregroundColor(themeManager.colors.primaryText)

                    TextField("Description (optional)", text: $wordDescription, axis: .vertical)
                        .lineLimit(2...4)
                        .font(.body)
                        .foregroundColor(themeManager.colors.primaryText)

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(SignLanguageCategory.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.rawValue)
                            }
                            .tag(category)
                        }
                    }
                }

                Section("Reference Images") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Add images showing how to perform this sign")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Button {
                            // This would open photo picker in a real implementation
                        } label: {
                            HStack {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text("Select Images")
                            }
                            .foregroundColor(.blue)
                        }

                        // Placeholder for selected images
                        Text("No images selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 20)
                    }
                }

                Section {
                    Text(
                        "Note: Images will be processed to extract key features for sign language recognition. Good lighting and clear hand positions improve recognition accuracy."
                    )
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .background(themeManager.colors.background)
            .navigationTitle("Add New Word")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.colors.primaryText)
                }

                ToolbarItem(placement: .primaryAction) {
                    Button("Save") {
                        saveWord()
                    }
                    .disabled(wordText.isEmpty)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.colors.accent)
                }
            }
        }
        .preferredColorScheme(themeManager.currentTheme.colorScheme)
        #if os(iOS)
            .navigationViewStyle(StackNavigationViewStyle())
        #endif
    }

    private func saveWord() {
        let newWord = SignLanguageWord(
            word: wordText.trimmingCharacters(in: .whitespacesAndNewlines),
            description: wordDescription.isEmpty
                ? nil : wordDescription.trimmingCharacters(in: .whitespacesAndNewlines),
            category: selectedCategory,
            addedBy: "User"  // TODO: Get actual user info
        )

        dictionaryManager.addWord(newWord)
        dismiss()
    }
}

// MARK: - Preview Provider

struct DictionaryView_Previews: PreviewProvider {
    static var previews: some View {
        DictionaryView()
    }
}

