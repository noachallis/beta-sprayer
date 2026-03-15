import SwiftUI

// ResultsView shows the generated Instagram hashtags.
// The user can tap individual hashtag pills or tap "Open Instagram" to launch
// the Instagram app (or Safari if Instagram isn't installed).
struct ResultsView: View {
    // @ObservedObject watches the existing SearchViewModel — we don't create a new one
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {

                // ── Photo thumbnail ───────────────────────────────────────────
                if let image = viewModel.selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(12)
                        .padding(.horizontal)
                }

                // ── Summary: gym + colours ────────────────────────────────────
                VStack(spacing: 8) {
                    if let gym = viewModel.detectedGym {
                        HStack(spacing: 6) {
                            Image(systemName: "location.fill")
                                .foregroundColor(.orange)
                            Text(gym)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                    }

                    if !viewModel.detectedHoldColours.isEmpty {
                        HoldColourChips(colours: viewModel.detectedHoldColours)
                    }
                }

                Divider().padding(.horizontal)

                // ── Hashtags section ──────────────────────────────────────────
                VStack(alignment: .leading, spacing: 16) {
                    Text("Tap a hashtag to search Instagram for beta:")
                        .font(.headline)
                        .padding(.horizontal)

                    // Big "Open Instagram" button — opens the first hashtag
                    if let firstTag = viewModel.suggestedHashtags.first {
                        Button {
                            viewModel.openInstagram(for: firstTag)
                        } label: {
                            Label("Open Instagram", systemImage: "arrow.up.right.square.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                // Instagram's brand gradient (pink → purple)
                                .background(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 0.91, green: 0.26, blue: 0.53),
                                            Color(red: 0.56, green: 0.18, blue: 0.83)
                                        ],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    // Individual tappable hashtag pills in a wrapping layout
                    FlowLayout(spacing: 8) {
                        ForEach(viewModel.suggestedHashtags, id: \.self) { tag in
                            HashtagPill(tag: tag) {
                                viewModel.openInstagram(for: tag)
                            }
                        }
                    }
                    .padding(.horizontal)
                }

                Spacer(minLength: 20)
            }
            .padding(.vertical)
        }
        .navigationTitle("Find Beta")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Hashtag pill

/// A tappable pill button showing a single hashtag (e.g. "#redholds")
struct HashtagPill: View {
    let tag: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("#\(tag)")
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.purple.opacity(0.12))
                .foregroundColor(.purple)
                .cornerRadius(20)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                )
        }
    }
}

// MARK: - Flow layout

/// A custom layout that arranges views in a left-to-right flow,
/// wrapping onto new lines when there's no more horizontal space —
/// just like how text wraps in a paragraph.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(availableWidth: proposal.width ?? 0, subviews: subviews)
        // Total height = sum of row heights + spacing between rows
        var totalHeight: CGFloat = 0
        for (i, row) in rows.enumerated() {
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            totalHeight += rowHeight
            if i < rows.count - 1 { totalHeight += spacing }
        }
        return CGSize(width: proposal.width ?? 0, height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(availableWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    /// Groups subviews into rows that each fit within `availableWidth`.
    private func computeRows(availableWidth: CGFloat, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var rowWidth: CGFloat = 0

        for subview in subviews {
            let itemWidth = subview.sizeThatFits(.unspecified).width
            // If this item doesn't fit on the current row, start a new row
            if rowWidth + itemWidth > availableWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                rowWidth = 0
            }
            rows[rows.count - 1].append(subview)
            rowWidth += itemWidth + spacing
        }
        return rows
    }
}

#Preview {
    NavigationStack {
        ResultsView(viewModel: SearchViewModel())
    }
}
