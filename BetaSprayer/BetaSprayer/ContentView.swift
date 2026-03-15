import SwiftUI
import PhotosUI

// ContentView is the home screen of Beta Sprayer.
// It shows the camera/library buttons, the selected photo, detected hold colours,
// the detected gym, and a "Find Beta" button to navigate to results.
struct ContentView: View {
    // @StateObject creates the SearchViewModel once and keeps it alive for the life of this view
    @StateObject private var viewModel = SearchViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // ── Header ────────────────────────────────────────────────
                    VStack(spacing: 8) {
                        Image(systemName: "figure.climbing")
                            .font(.system(size: 64))
                            .foregroundColor(.blue)

                        Text("Beta Sprayer")
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        Text("Photograph a boulder problem to find beta videos on Instagram.")
                            .font(.subheadline)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .padding(.top, 20)

                    // ── Gym detection banner ──────────────────────────────────
                    GymBanner(viewModel: viewModel)

                    // ── Photo capture buttons ─────────────────────────────────
                    VStack(spacing: 12) {
                        // Camera button (requires a real iPhone — won't work in Simulator)
                        Button {
                            viewModel.showCamera = true
                        } label: {
                            Label("Take Photo", systemImage: "camera.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }

                        // Photo library picker
                        PhotosPicker(selection: $viewModel.photosPickerItem, matching: .images) {
                            Label("Choose from Library", systemImage: "photo.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                    }
                    .padding(.horizontal)

                    // ── Selected photo + analysis ─────────────────────────────
                    if let image = viewModel.selectedImage {
                        // Show the selected photo
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 250)
                            .cornerRadius(12)
                            .padding(.horizontal)

                        // While analysing: spinner
                        // After analysis: colour chips
                        if viewModel.isAnalysing {
                            HStack(spacing: 8) {
                                ProgressView()
                                Text("Detecting hold colours…")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        } else if !viewModel.detectedHoldColours.isEmpty {
                            HoldColourChips(colours: viewModel.detectedHoldColours)
                        }

                        // "Find Beta" navigates to the results screen
                        NavigationLink(destination: ResultsView(viewModel: viewModel)) {
                            Label("Find Beta", systemImage: "magnifyingglass")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }

                    Spacer(minLength: 20)
                }
            }
            // Show the camera as a full-screen sheet
            .sheet(isPresented: $viewModel.showCamera) {
                // We use a custom Binding so that when CameraView sets the image,
                // we also trigger the colour analysis.
                CameraView(image: Binding(
                    get: { viewModel.selectedImage },
                    set: { if let img = $0 { viewModel.imageSelected(img) } }
                ))
            }
            // When the user picks a photo from the library, load + analyse it
            .onChange(of: viewModel.photosPickerItem) { _, newItem in
                Task { await viewModel.loadImage(from: newItem) }
            }
            // Ask for location when the screen appears (to detect the gym)
            .onAppear {
                viewModel.requestLocation()
            }
        }
    }
}

// MARK: - Gym banner

/// Shows the detected gym name with a location pin, or a "no gym" message.
struct GymBanner: View {
    @ObservedObject var viewModel: SearchViewModel

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
                .foregroundColor(.orange)
            if let gym = viewModel.detectedGym {
                Text(gym)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            } else {
                Text("No gym detected nearby")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Hold colour chips

/// Shows a row of colour chips (e.g. 🔴 Red  🔵 Blue) for the detected hold colours.
struct HoldColourChips: View {
    let colours: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detected hold colours:")
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal)

            // Scrollable row of chips in case there are many colours
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(colours, id: \.self) { colour in
                        HStack(spacing: 6) {
                            // Coloured dot
                            Circle()
                                .fill(swiftUIColor(for: colour))
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(Color.gray.opacity(0.4), lineWidth: 1))
                            Text(colour.capitalized)
                                .font(.subheadline)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(20)
                    }
                }
                .padding(.horizontal)
            }
        }
    }

    /// Converts a colour name string to a SwiftUI Color
    func swiftUIColor(for name: String) -> Color {
        switch name {
        case "red":    return .red
        case "blue":   return .blue
        case "yellow": return .yellow
        case "green":  return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink":   return .pink
        case "black":  return Color(.label) // uses black in light mode, white in dark mode
        case "white":  return Color(.systemBackground)
        default:       return .gray
        }
    }
}

#Preview {
    ContentView()
}
