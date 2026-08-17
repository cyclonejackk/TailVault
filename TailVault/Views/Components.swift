//
//  Components.swift
//  TailVault
//
//  Shared small views: pet avatar, fondness picker, tag editor.
//

import SwiftUI

// MARK: - Avatar

struct PetAvatar: View {
    let pet: Pet
    var size: CGFloat = 44
    @AppStorage("tintTheme") private var tintTheme: TintTheme = .sky

    var body: some View {
        Group {
            if let data = pet.photoData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(placeholderColor.gradient)
                    Image(systemName: SpeciesCatalog.symbol(for: pet.species))
                        .font(.system(size: size * 0.42, weight: .medium))
                        .foregroundStyle(.white)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay {
            // Subtle accent ring — skipped in mono for the stock look.
            if tintTheme != .mono {
                Circle().strokeBorder(
                    LinearGradient(
                        colors: [tintTheme.accent.opacity(0.7), tintTheme.accent.opacity(0.15)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: max(1.5, size * 0.035)
                )
            }
        }
    }

    /// Stable color per pet so placeholders are tell-apart-able.
    private var placeholderColor: Color {
        let palette: [Color] = [.orange, .indigo, .teal, .pink, .brown, .purple, .mint, .blue]
        let index = abs(pet.name.hashValue) % palette.count
        return palette[index]
    }
}

// MARK: - Fondness picker row

struct FondnessPicker: View {
    let title: String
    @Binding var value: Fondness

    var body: some View {
        Picker(title, selection: $value) {
            ForEach(Fondness.allCases) { f in
                Text("\(f.emoji) \(f.label)").tag(f)
            }
        }
    }
}

// MARK: - Editable string-list ("tags") field

/// Edits an array of strings as comma-separated text — used for
/// hiding spots, toys, conditions, allergies.
struct TagListField: View {
    let title: String
    let prompt: String
    @Binding var items: [String]

    var body: some View {
        TextField(
            title,
            text: Binding(
                get: { items.joined(separator: ", ") },
                set: { newValue in
                    items = newValue
                        .split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                }
            ),
            prompt: Text(prompt),
            axis: .vertical
        )
    }
}

// MARK: - Labeled detail row

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        if !value.isEmpty {
            LabeledContent(label, value: value)
        }
    }
}
