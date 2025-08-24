//
//  MarkdownViewer.swift
//  Kyozo
//
//  Viewer for Markdown virtual files
//

import MarkdownUI
import SwiftUI

struct MDViewer: View {
  let content: VFSContent
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      ScrollView {
        Markdown(content.content)
          .markdownTheme(.kyozo)
          .padding()
      }
      .navigationTitle(fileName)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .navigationBarTrailing) {
          Button("Done") {
            dismiss()
          }
        }
      }
    }
  }

  private var fileName: String {
    URL(fileURLWithPath: content.path).lastPathComponent
  }
}

// MARK: - Markdown Theme

extension Theme {
  static let kyozo = Theme()
    .text {
      ForegroundColor(.primary)
      FontSize(16)
    }
    .code {
      FontFamilyVariant(.monospaced)
      FontSize(14)
      BackgroundColor(Color(.systemGray6))
    }
    .strong {
      FontWeight(.semibold)
    }
    .link {
      ForegroundColor(.accentColor)
    }
    .heading1 { configuration in
      VStack(alignment: .leading, spacing: 8) {
        configuration.label
          .font(.largeTitle)
          .fontWeight(.bold)
        Divider()
      }
      .padding(.vertical, 8)
    }
    .heading2 { configuration in
      configuration.label
        .font(.title2)
        .fontWeight(.semibold)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    .heading3 { configuration in
      configuration.label
        .font(.title3)
        .fontWeight(.medium)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }
    .codeBlock { configuration in
      VStack(alignment: .leading, spacing: 0) {
        if let language = configuration.language {
          HStack {
            Text(language)
              .font(.caption)
              .foregroundColor(.secondary)
            Spacer()
            Button(action: {
              UIPasteboard.general.string = configuration.content
            }) {
              Image(systemName: "doc.on.doc")
                .font(.caption)
            }
          }
          .padding(.horizontal, 12)
          .padding(.vertical, 8)
          .background(Color(.systemGray5))
        }

        ScrollView(.horizontal, showsIndicators: false) {
          configuration.label
            .padding(12)
        }
        .background(Color(.systemGray6))
      }
      .cornerRadius(8)
      .padding(.vertical, 4)
    }
    .blockquote { configuration in
      HStack(spacing: 12) {
        Rectangle()
          .fill(Color.accentColor.opacity(0.5))
          .frame(width: 4)
        configuration.label
          .foregroundColor(.secondary)
      }
      .padding(.leading, 8)
      .padding(.vertical, 4)
    }
    .listItem { configuration in
      HStack(alignment: .top, spacing: 8) {
        Text(configuration.childDepth == 0 ? "•" : "◦")
          .foregroundColor(.secondary)
        configuration.label
      }
    }
}
