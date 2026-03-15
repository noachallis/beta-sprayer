import SwiftUI
import PhotosUI
import CoreLocation

// SearchViewModel is the "brain" of the app.
// It holds all the state (selected photo, detected colours, detected gym)
// and all the logic (colour detection, gym detection, hashtag building).
//
// @MainActor means all its @Published properties update on the main thread,
// which is required for SwiftUI to refresh the UI correctly.
@MainActor
class SearchViewModel: NSObject, ObservableObject {

    // MARK: - Published state (these drive the UI)

    /// The photo the user selected or captured
    @Published var selectedImage: UIImage?

    /// The PhotosPicker selection (we convert this to a UIImage in loadImage)
    @Published var photosPickerItem: PhotosPickerItem?

    /// Whether to show the camera sheet
    @Published var showCamera = false

    /// Dominant hold colours detected from the photo (e.g. ["red", "blue"])
    @Published var detectedHoldColours: [String] = []

    /// The gym name if the user is inside a known gym, otherwise nil
    @Published var detectedGym: String? = nil

    /// True while the Vision colour analysis is running
    @Published var isAnalysing = false

    // MARK: - Private

    private let locationManager = CLLocationManager()

    // A small helper class to handle CLLocationManagerDelegate callbacks
    // without actor-isolation issues (see LocationDelegate below).
    private let locationDelegate = LocationDelegate()

    // A hardcoded list of known gyms: name, latitude, longitude, radius in metres.
    // Add your local gym here! Coordinates from Google Maps (right-click → copy coords).
    private let knownGyms: [(name: String, lat: Double, lon: Double, radius: Double)] = [
        ("Hardrock Gym",    -33.8688, 151.2093, 500),
        ("Boulder World",   -33.9000, 151.1800, 500),
        ("The Bouldering Warehouse", -33.8720, 151.2000, 500),
        // Add more gyms here...
    ]

    // MARK: - Init

    override init() {
        super.init()
        locationManager.delegate = locationDelegate
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters

        // When the LocationDelegate receives a location, we update detectedGym on the main actor
        locationDelegate.onLocation = { [weak self] location in
            Task { @MainActor [weak self] in
                self?.updateGym(for: location)
            }
        }
    }

    // MARK: - Photo loading (from PhotosPicker)

    /// Called when the user picks a photo from their library
    func loadImage(from item: PhotosPickerItem?) async {
        guard let item else { return }
        // Load the raw image data from the picker item
        if let data = try? await item.loadTransferable(type: Data.self),
           let image = UIImage(data: data) {
            await handleNewImage(image)
        }
    }

    /// Called when the user takes a photo with the camera
    func imageSelected(_ image: UIImage) {
        Task { await handleNewImage(image) }
    }

    private func handleNewImage(_ image: UIImage) async {
        selectedImage = image
        detectedHoldColours = []
        isAnalysing = true
        detectedHoldColours = await detectDominantColours(in: image)
        isAnalysing = false
    }

    // MARK: - Colour detection using CoreImage pixel sampling

    /// Analyses the image and returns the top 1–3 dominant hold colour names.
    private func detectDominantColours(in image: UIImage) async -> [String] {
        // Run the pixel-crunching work off the main thread so the UI stays smooth
        return await Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else { return [] }
            return self.sampleColours(from: image)
        }.value
    }

    /// Resizes the image to 50×50, reads every pixel, maps each to a colour name,
    /// and returns the top colours by frequency.
    private func sampleColours(from image: UIImage) -> [String] {
        let targetSize = CGSize(width: 50, height: 50)

        // Redraw the image at a small size into a known RGBA pixel buffer
        let bytesPerPixel = 4
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)
        let bytesPerRow = width * bytesPerPixel
        var rawData = [UInt8](repeating: 0, count: height * bytesPerRow)

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: &rawData,
                  width: width, height: height,
                  bitsPerComponent: 8,
                  bytesPerRow: bytesPerRow,
                  space: colorSpace,
                  bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue // RGBX — no alpha needed
              ),
              let cgImage = image.cgImage else { return [] }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Count how many pixels map to each colour name
        var colourCounts: [String: Int] = [:]
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = CGFloat(rawData[offset])     / 255.0
                let g = CGFloat(rawData[offset + 1]) / 255.0
                let b = CGFloat(rawData[offset + 2]) / 255.0

                let name = colourName(r: r, g: g, b: b)
                if name != "unknown" {
                    colourCounts[name, default: 0] += 1
                }
            }
        }

        // Return the top 3 most frequent colours
        return colourCounts
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { $0.key }
    }

    /// Maps an RGB colour to a hold colour name using the HSB (hue/saturation/brightness) colour model.
    /// HSB is much easier to work with for colour naming than raw RGB.
    private func colourName(r: CGFloat, g: CGFloat, b: CGFloat) -> String {
        var hue: CGFloat = 0, sat: CGFloat = 0, bri: CGFloat = 0, alpha: CGFloat = 0
        UIColor(red: r, green: g, blue: b, alpha: 1)
            .getHue(&hue, saturation: &sat, brightness: &bri, alpha: &alpha)

        let h = hue * 360 // Convert 0–1 hue to 0–360 degrees

        // White: very bright and almost no colour
        if bri > 0.85 && sat < 0.15 { return "white" }
        // Black: very dark
        if bri < 0.18 { return "black" }
        // Washed-out / grey colours aren't useful for hold detection
        if sat < 0.25 { return "unknown" }

        // Map hue angle to colour name
        switch h {
        case 0..<15:    return "red"
        case 15..<40:   return "orange"
        case 40..<75:   return "yellow"
        case 75..<165:  return "green"
        case 165..<200: return "unknown" // cyan — rarely used for holds
        case 200..<260: return "blue"
        case 260..<290: return "purple"
        case 290..<345: return "pink"
        case 345..<360: return "red"
        default:        return "unknown"
        }
    }

    // MARK: - Location / gym detection

    /// Asks iOS for permission to use location, then requests a one-shot location update.
    func requestLocation() {
        locationManager.requestWhenInUseAuthorization()
        locationManager.requestLocation()
    }

    /// Checks whether the user's location is inside any known gym's radius.
    private func updateGym(for location: CLLocation) {
        let found = knownGyms.first { gym in
            let gymLocation = CLLocation(latitude: gym.lat, longitude: gym.lon)
            return location.distance(from: gymLocation) <= gym.radius
        }
        detectedGym = found?.name
    }

    // MARK: - Instagram hashtag builder

    /// Builds a list of hashtags tailored to the detected gym and hold colours.
    var suggestedHashtags: [String] {
        var tags: [String] = []

        // Gym-specific tags
        if let gym = detectedGym {
            // "Hardrock Gym" → "hardrock" and "hardrockbouldering"
            let slug = gym.lowercased().replacingOccurrences(of: " ", with: "")
            tags.append(slug)
            tags.append("\(slug)bouldering")
        }

        // Colour-specific tags
        for colour in detectedHoldColours {
            tags.append("\(colour)holds")
            tags.append("\(colour)bouldering")
        }

        // Always include generic bouldering beta tags
        tags += ["boulderingbeta", "indoorbouldering", "climbingbeta"]

        // Remove any duplicates while keeping the order
        var seen = Set<String>()
        return tags.filter { seen.insert($0).inserted }
    }

    /// Opens Instagram for a hashtag. Tries the Instagram app first; falls back to the web.
    func openInstagram(for hashtag: String) {
        // The instagram:// deep link opens the Instagram app directly if installed
        let appURL = URL(string: "instagram://tag?name=\(hashtag)")!
        UIApplication.shared.open(appURL) { success in
            if !success {
                // Instagram app not installed — open in Safari instead
                if let webURL = URL(string: "https://www.instagram.com/explore/tags/\(hashtag)/") {
                    UIApplication.shared.open(webURL)
                }
            }
        }
    }
}

// MARK: - Location delegate helper

/// A separate class to receive CLLocationManager callbacks.
/// This avoids Swift concurrency warnings when using @MainActor on SearchViewModel.
private class LocationDelegate: NSObject, CLLocationManagerDelegate {
    var onLocation: ((CLLocation) -> Void)?

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            onLocation?(location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Location unavailable (e.g. no GPS signal, user denied permission) — that's fine,
        // the app just won't detect a gym and will use generic hashtags instead.
    }
}
