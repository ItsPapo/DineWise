//
//  PostReviewViewController.swift
//  DineWise
//
//  Created by Carlos Castro on 2025-04-02.
//

import UIKit
import AVFoundation
import UniformTypeIdentifiers
import FirebaseStorage
import FirebaseAuth
import FirebaseFirestore
import CoreLocation
import MapKit

class PostReviewViewController: UIViewController,
                                UIImagePickerControllerDelegate,
                                UINavigationControllerDelegate,
                                UITextViewDelegate,
                                UITextFieldDelegate,
                                UITableViewDataSource,
                                UITableViewDelegate,
                                MKLocalSearchCompleterDelegate {
  // ✅ added
    // Autocomplete
    private let searchCompleter = MKLocalSearchCompleter()
    private var suggestions: [MKLocalSearchCompletion] = []

    // Simple dropdown table below the location text field
    private var suggestionsTable: UITableView?
    private var suggestionsHeightConstraint: NSLayoutConstraint?

    // MARK: - Outlets
    @IBOutlet weak var captionTextView: UITextView!
    @IBOutlet weak var videoPreview: UIView!
    @IBOutlet weak var locationTextField: UITextField!   // ✅ added

    // Stable local copy we will preview & upload
    private var savedLocalVideoURL: URL?

    private var player: AVPlayer?
    private var playerLayer: AVPlayerLayer?

    // Placeholder for the caption text view
    private var captionPlaceholderLabel: UILabel!

    // Draft metadata (set these from your UI if you have fields)
    var draftCaption: String = ""
    var draftLocationName: String?
    var draftLat: Double?
    var draftLng: Double?

    // Location (used for optional current-location or geocoding)
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()

    // MARK: - Firestore
    private let db = Firestore.firestore()
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        suggestions.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let id = "SuggestionCell"
        let cell = tableView.dequeueReusableCell(withIdentifier: id) ??
                   UITableViewCell(style: .subtitle, reuseIdentifier: id)
        let s = suggestions[indexPath.row]
        cell.textLabel?.text = s.title
        cell.detailTextLabel?.text = s.subtitle
        cell.textLabel?.numberOfLines = 1
        cell.detailTextLabel?.numberOfLines = 1
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let completion = suggestions[indexPath.row]
        resolveCompletionToCoordinate(completion)
    }
    private func resolveCompletionToCoordinate(_ completion: MKLocalSearchCompletion) {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        search.start { [weak self] response, error in
            guard let self = self else { return }
            if let error = error {
                print("🔎 MKLocalSearch error:", error.localizedDescription)
                self.locationTextField?.text = completion.title
                self.draftLocationName = completion.title
                self.draftLat = nil
                self.draftLng = nil
                self.hideSuggestions()
                return
            }
            if let item = response?.mapItems.first, let loc = item.placemark.location {
                let name = item.name ?? completion.title
                self.locationTextField?.text = name
                self.draftLocationName = name
                self.draftLat = loc.coordinate.latitude
                self.draftLng = loc.coordinate.longitude
                print("📍 Selected: \(name) @ \(self.draftLat!), \(self.draftLng!)")
            } else {
                self.locationTextField?.text = completion.title
                self.draftLocationName = completion.title
                self.draftLat = nil
                self.draftLng = nil
            }
            self.hideSuggestions()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // If you later add GPS capture, this prepares the manager (harmless to keep now)
        setupLocation()
        
        // UITextView setup
        captionTextView.delegate = self
        setupCaptionPlaceholder()
        
        // ✅ UITextField setup
        locationTextField?.delegate = self
        locationTextField?.placeholder = "Add a location (e.g. Kensington, Toronto)"
        locationTextField?.addTarget(self, action: #selector(locationTextChanged), for: .editingChanged)
        // MapKit search completer
        searchCompleter.delegate = self
        searchCompleter.resultTypes = [.address, .pointOfInterest]

        // If you want nearby-biased results (optional)
        if let loc = locationManager.location {
            let span = MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
            searchCompleter.region = MKCoordinateRegion(center: loc.coordinate, span: span)
            
        }

        // Build the suggestions table below the text field
    
        installSuggestionsTable()
        if let table = suggestionsTable { view.bringSubviewToFront(table) }  // ⬅️ add this

        // Dismiss suggestions on background tap (optional)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)

    }

    // MARK: - Placeholder
    private func setupCaptionPlaceholder() {
        captionPlaceholderLabel = UILabel()
        captionPlaceholderLabel.text = "Add a caption…"
        captionPlaceholderLabel.font = captionTextView.font
        captionPlaceholderLabel.textColor = .secondaryLabel
        captionPlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false
        captionPlaceholderLabel.isUserInteractionEnabled = false

        captionTextView.addSubview(captionPlaceholderLabel)

        // Pin to the text container insets
        NSLayoutConstraint.activate([
            captionPlaceholderLabel.leadingAnchor.constraint(
                equalTo: captionTextView.leadingAnchor,
                constant: captionTextView.textContainerInset.left + 5
            ),
            captionPlaceholderLabel.topAnchor.constraint(
                equalTo: captionTextView.topAnchor,
                constant: captionTextView.textContainerInset.top
            )
        ])

        captionPlaceholderLabel.isHidden = !(captionTextView.text?.isEmpty ?? true)
    }

    // Keep placeholder state + draftCaption updated
    func textViewDidChange(_ textView: UITextView) {
        draftCaption = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        captionPlaceholderLabel.isHidden = !textView.text.isEmpty
    }

    // Dismiss keyboard on Return and (optionally) enforce a character limit
    func textView(_ textView: UITextView,
                  shouldChangeTextIn range: NSRange,
                  replacementText text: String) -> Bool {
        // Dismiss on Return
        if text == "\n" {
            textView.resignFirstResponder()
            return false
        }
        // Optional limit (140). Comment this block out if you don't want a limit.
        let limit = 140
        let current = textView.text ?? ""
        guard let r = Range(range, in: current) else { return true }
        let updated = current.replacingCharacters(in: r, with: text)
        return updated.count <= limit
    }

    // MARK: - Location text handling (typed by user)
    @objc private func locationTextChanged() {
        let txt = locationTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        draftLocationName = txt.isEmpty ? nil : txt
        draftLat = nil
        draftLng = nil

        if txt.isEmpty {
            suggestions = []
            suggestionsTable?.reloadData()
            hideSuggestions()
        } else {
            searchCompleter.queryFragment = txt
        }
    }
    private func installSuggestionsTable() {
        let table = UITableView(frame: .zero, style: .plain)
        table.translatesAutoresizingMaskIntoConstraints = false
        table.dataSource = self
        table.delegate = self
        table.isHidden = true
        table.layer.cornerRadius = 10
        table.clipsToBounds = true

        view.addSubview(table)
        suggestionsTable = table

        guard let tf = locationTextField else { return }
        NSLayoutConstraint.activate([
            table.topAnchor.constraint(equalTo: tf.bottomAnchor, constant: 6),
            table.leadingAnchor.constraint(equalTo: tf.leadingAnchor),
            table.trailingAnchor.constraint(equalTo: tf.trailingAnchor)
        ])
        let h = table.heightAnchor.constraint(equalToConstant: 0)
        h.isActive = true
        suggestionsHeightConstraint = h
    }

    private func showSuggestions() {
        guard let table = suggestionsTable else { return }
        table.isHidden = false
        let rows = min(suggestions.count, 6)
        suggestionsHeightConstraint?.constant = CGFloat(rows) * 44.0
        table.layoutIfNeeded()
    }
    // MARK: - MKLocalSearchCompleterDelegate
    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        suggestions = completer.results
        suggestionsTable?.reloadData()
        if !suggestions.isEmpty {
            showSuggestions()
        } else {
            hideSuggestions()
        }
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        print("🔎 completer error:", error.localizedDescription)
        suggestions = []
        suggestionsTable?.reloadData()
        hideSuggestions()
    }

    private func hideSuggestions() {
        suggestionsHeightConstraint?.constant = 0
        suggestionsTable?.isHidden = true
    }

    @objc private func handleBackgroundTap() {
        view.endEditing(true)
        hideSuggestions()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    // Best-effort geocode: if successful, set lat/lng; if not, keep just the name
    private func geocodeDraftLocationIfNeeded(completion: @escaping () -> Void) {
        // If we already have coordinates (e.g., from a GPS flow), skip
        if draftLat != nil && draftLng != nil { completion(); return }

        // If no name, nothing to do
        guard let name = draftLocationName, !name.isEmpty else { completion(); return }

        geocoder.cancelGeocode()
        geocoder.geocodeAddressString(name) { [weak self] placemarks, error in
            guard let self = self else { return }
            if let loc = placemarks?.first?.location {
                self.draftLat = loc.coordinate.latitude
                self.draftLng = loc.coordinate.longitude
                print("🗺️ Geocoded '\(name)' → \(self.draftLat!), \(self.draftLng!)")
            } else {
                print("⚠️ Couldn’t geocode '\(name)': \(error?.localizedDescription ?? "no match")")
            }
            completion()
        }
    }

    // MARK: - Auth debug helper
    private func logAuthState(where tag: String) {
        if let u = Auth.auth().currentUser {
            let providers = u.providerData.map { $0.providerID }.joined(separator: ",")
            print("[\(tag)] uid=\(u.uid) isAnonymous=\(u.isAnonymous) providers=[\(providers)]")
        } else {
            print("\(tag)] No Firebase user")
        }
    }

    // MARK: - Auth gate (no guests)
    private func requireSignedInNonGuest(_ onOK: @escaping () -> Void) {
        logAuthState(where: "gate")
        if let user = Auth.auth().currentUser, !user.isAnonymous {
            onOK()
        } else {
            let a = UIAlertController(title: "Sign In Required",
                                      message: "Guests can’t upload. Please sign in or create an account.",
                                      preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            a.addAction(UIAlertAction(title: "Sign In", style: .default, handler: { [weak self] _ in
                self?.presentSignIn()
            }))
            present(a, animated: true)
        }
    }

    /// TODO: Present your real sign-in UI here.
    private func presentSignIn() {
        // e.g. present(LoginViewController(), animated: true)
        print("🔐 TODO: Present your sign-in UI.")
    }

    // MARK: - Submit/Upload to Firebase Storage + Firestore
    @IBAction func submitReviewTapped(_ sender: UIButton) {
        // Pull the latest text from the text view
        draftCaption = captionTextView.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // Keep the latest typed location
        draftLocationName = locationTextField?.text?.trimmingCharacters(in: .whitespacesAndNewlines)

        requireSignedInNonGuest { [weak self] in
            guard let self = self else { return }
            self.logAuthState(where: "submit")

            guard let fileURL = self.savedLocalVideoURL else {
                let alert = UIAlertController(title: "No Video",
                                              message: "Please record or choose a video first.",
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
                return
            }

            if self.draftCaption.isEmpty {
                let a = UIAlertController(title: "Add a caption",
                                          message: "Please enter a caption before posting.",
                                          preferredStyle: .alert)
                a.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(a, animated: true)
                return
            }

            // ✅ Best-effort geocode typed location, then upload
            self.geocodeDraftLocationIfNeeded {
                self.uploadToFirebase(fileURL: fileURL)
            }
        }
    }

    // MARK: - Upload + Create Firestore doc
    private func uploadToFirebase(fileURL: URL) {
        // Hard gate here too (extra safety)
        guard let user = Auth.auth().currentUser, !user.isAnonymous else {
            let a = UIAlertController(title: "Sign In Required",
                                      message: "Guests can’t upload. Please sign in and try again.",
                                      preferredStyle: .alert)
            a.addAction(UIAlertAction(title: "OK", style: .default))
            present(a, animated: true)
            return
        }
        logAuthState(where: "upload")

        let uid = user.uid
        let username = (user.displayName?.isEmpty == false) ? user.displayName! : "user-\(uid.prefix(6))"

        // Unique name; keep original ext
        let ts = Int(Date().timeIntervalSince1970)
        let ext = fileURL.pathExtension.isEmpty ? "mov" : fileURL.pathExtension.lowercased()
        let fileName = "video_\(ts).\(ext)"

        // Store under the signed-in user's folder (original layout)
        let storagePath = "videos/\(uid)/\(fileName)"
        let ref = Storage.storage().reference(withPath: storagePath)

        // Metadata
        let meta = StorageMetadata()
        meta.contentType = (ext == "mp4") ? "video/mp4" : "video/quicktime"
        meta.customMetadata = ["ownerId": uid, "createdAt": "\(ts)"]

        // Optional: local file info
        let sizeBytes = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? NSNumber)?.int64Value ?? 0
        let asset = AVURLAsset(url: fileURL)
        let duration = CMTimeGetSeconds(asset.duration)
        let durationSec = duration.isFinite ? duration : 0

        print("Starting upload:", storagePath)
        let task = ref.putFile(from: fileURL, metadata: meta) { [weak self] _, error in
            guard let self = self else { return }
            if let error = error {
                print("Upload failed:", error)
                let alert = UIAlertController(title: "Upload Failed",
                                              message: error.localizedDescription,
                                              preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
                return
            }
            print("Upload complete:", storagePath)

            // Get streamable HTTPS URL then create Firestore doc
            ref.downloadURL { url, urlErr in
                guard let downloadURL = url, urlErr == nil else {
                    print("⚠️ Could not get downloadURL:", urlErr?.localizedDescription ?? "unknown")
                    // We still create a doc with storagePath so the app can resolve later, if needed
                    self.createExploreVideoDoc(
                        createdByUid: uid,
                        createdBy: username,
                        caption: self.draftCaption,
                        storagePath: storagePath,
                        downloadURL: nil,
                        sizeBytes: sizeBytes,
                        durationSec: durationSec
                    )
                    return
                }

                self.createExploreVideoDoc(
                    createdByUid: uid,
                    createdBy: username,
                    caption: self.draftCaption,
                    storagePath: storagePath,
                    downloadURL: downloadURL.absoluteString,
                    sizeBytes: sizeBytes,
                    durationSec: durationSec
                )
            }

            // Optionally add to local feed immediately
            NewVideoManager.shared.addVideo(url: fileURL)

            // Notify other screens to refresh
            NotificationCenter.default.post(name: .videoUploadedToStorage, object: nil)

            // Pop back
            self.navigationController?.popViewController(animated: true)
        }

        // Progress (log; wire to a UIProgressView if desired)
        task.observe(.progress) { snap in
            if let p = snap.progress {
                print("📤 Uploading… \(Int(p.fractionCompleted * 100))%")
            }
        }
        task.observe(.failure) { snap in
            if let err = snap.error { print(" Upload error:", err) }
        }
    }

    // MARK: - Create Firestore document in /explore_videos
    private func createExploreVideoDoc(createdByUid: String,
                                       createdBy: String,
                                       caption: String,
                                       storagePath: String,
                                       downloadURL: String?,
                                       sizeBytes: Int64,
                                       durationSec: Double) {
        let docRef = db.collection("explore_videos").document() // auto-id

        var data: [String: Any] = [
            "createdByUid": createdByUid,
            "createdBy": createdBy,
            "createdAt": FieldValue.serverTimestamp(),
            "caption": caption,
            "storagePath": storagePath,
            "contentType": (storagePath.hasSuffix(".mp4") ? "video/mp4" : "video/quicktime"),
            "sizeBytes": sizeBytes,
            "durationSec": durationSec,
            "likesCount": 0,
            "favouritesCount": 0,
            "commentsCount": 0
        ]

        if let dl = downloadURL {
            data["downloadURL"] = dl
        }

        // Optional location map (typed + best-effort geocoded)
        if let name = draftLocationName, !name.isEmpty {
            if let lat = draftLat, let lng = draftLng {
                data["location"] = [
                    "name": name,
                    "geo": GeoPoint(latitude: lat, longitude: lng)
                ]
            } else {
                data["location"] = ["name": name]
            }
        }

        docRef.setData(data) { err in
            if let err = err {
                print("Firestore setData failed:", err)
            } else {
                print("📝 Firestore doc created at /explore_videos/\(docRef.documentID)")
            }
        }
    }

    // MARK: - Add Video
    @IBAction func addVideoTapped(_ sender: UIButton) {
        requireSignedInNonGuest { [weak self] in
            guard let self = self else { return }
            self.logAuthState(where: "addVideo")
            let alert = UIAlertController(title: "Attach Video", message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Record Video", style: .default) { _ in self.openCamera() })
            alert.addAction(UIAlertAction(title: "Choose from Library", style: .default) { _ in self.openLibrary() })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self.present(alert, animated: true)
        }
    }

    // MARK: - Camera / Library
    func openCamera() {
    #if targetEnvironment(simulator)
        let alert = UIAlertController(title: "Camera Not Available",
                                      message: "Recording video is only available on a real device.",
                                      preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
    #else
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            let alert = UIAlertController(title: "Camera Not Available",
                                          message: "Your device does not support video recording.",
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .camera
        picker.mediaTypes = [UTType.movie.identifier]
        picker.cameraCaptureMode = .video
        picker.videoQuality = .typeMedium
        present(picker, animated: true)
    #endif
    }

    func openLibrary() {
        let picker = UIImagePickerController()
        picker.delegate = self
        picker.sourceType = .photoLibrary
        picker.mediaTypes = [UTType.movie.identifier]
        picker.videoQuality = .typeMedium
        present(picker, animated: true)
    }

    // MARK: - Picker Result
    func imagePickerController(_ picker: UIImagePickerController,
                               didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        defer { picker.dismiss(animated: true) }

        guard let mediaURL = info[.mediaURL] as? URL else { return }
        print(" Selected video:", mediaURL.lastPathComponent)

        // Save a stable copy to Documents (so we can preview & upload reliably)
        if let saved = saveVideoToDocumentsDirectory(from: mediaURL) {
            savedLocalVideoURL = saved
            print(" Saved to Documents:", saved.lastPathComponent)
            previewVideo(url: saved)   // preview the saved copy
        } else {
            print("Failed to persist video")
        }
    }

    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true)
    }

    // MARK: - Save picked file to Documents
    private func saveVideoToDocumentsDirectory(from sourceURL: URL) -> URL? {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first!
        let ext = sourceURL.pathExtension.isEmpty ? "mov" : sourceURL.pathExtension
        let destURL = docs.appendingPathComponent(UUID().uuidString).appendingPathExtension(ext)

        do {
            if fm.fileExists(atPath: destURL.path) {
                try fm.removeItem(at: destURL)
            }
            try fm.copyItem(at: sourceURL, to: destURL)
            return destURL
        } catch {
            print(" Error copying video:", error)
            return nil
        }
    }

    // MARK: - Preview
    private func previewVideo(url: URL) {
        player?.pause()
        playerLayer?.removeFromSuperlayer()

        let player = AVPlayer(url: url)
        let layer = AVPlayerLayer(player: player)
        layer.frame = videoPreview.bounds
        layer.videoGravity = .resizeAspectFill

        videoPreview.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        videoPreview.layer.addSublayer(layer)

        self.player = player
        self.playerLayer = layer

        // Tap to toggle
        videoPreview.gestureRecognizers?.forEach { videoPreview.removeGestureRecognizer($0) }
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleVideoTap))
        videoPreview.isUserInteractionEnabled = true
        videoPreview.addGestureRecognizer(tap)

        player.play()
    }

    @objc private func handleVideoTap() {
        guard let player = player else { return }
        (player.timeControlStatus == .playing) ? player.pause() : player.play()
    }

    // MARK: - Basic location setup (optional future "Use my location" button)
    private func setupLocation() {
        locationManager.delegate = nil   // not using GPS flow yet; set when you add it
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }
}

// notify Explore to refresh remote list
extension Notification.Name {
    static let videoUploadedToStorage = Notification.Name("VideoUploadedToStorage")
}
