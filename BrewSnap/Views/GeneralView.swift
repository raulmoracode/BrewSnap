// GeneralView.swift
// BrewSnap — App info (bundle, version, repos).

import SwiftUI

struct GeneralView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("General").font(.title2.bold()).tracking(-0.4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("Bundle ID", value: "com.raulmorasanchez.BrewSnap")
                    LabeledContent("Version", value: "1.0.0 (MVP)")
                    if let repoURL = URL(string: "https://github.com/raulmoracode/brewsnap") {
                        Link("Repository brewsnap", destination: repoURL)
                    }
                    if let tapURL = URL(string: "https://github.com/raulmoracode/homebrew-tap") {
                        Link("Homebrew tap", destination: tapURL)
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.quaternary, lineWidth: 1))
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .navigationTitle("General")
        .scrollContentBackground(.hidden)
    }
}
