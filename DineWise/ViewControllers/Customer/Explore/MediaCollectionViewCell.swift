//
//  MediaCollectionViewCell.swift
//  DineWise
//
//  Created by Muhammad Mahad on 2025-03-22.

import UIKit
import AVFoundation
import ObjectiveC
import FirebaseFirestore
import FirebaseAuth

class MediaCollectionViewCell: UICollectionViewCell, UIGestureRecognizerDelegate {
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var videoView: UIView!
    
    private var queuePlayer: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var playerLayer: AVPlayerLayer?
    private var currentURL: URL?
    
    // Firestore
    private let db = Firestore.firestore()
    var videoID: String? {
        didSet { print("📼 MediaCell videoID set to:", videoID ?? "nil") }
    }

    var videosCollectionPath = "videos"       // <-- customize if needed
    private var uid: String { Auth.auth().currentUser?.uid ?? "guest" }
    
    // Overlay
    private var overlayStack: UIStackView?
    private var overlayBottomConstraint: NSLayoutConstraint?   // 👈 adjustable
    private lazy var captionLabel = makeOverlayLabel(weight: .semibold, size: 18)
    private lazy var userLabel    = makeOverlayLabel(weight: .medium,  size: 14)
    private lazy var metaLabel    = makeOverlayLabel(weight: .regular, size: 13)
    private lazy var statsLabel   = makeOverlayLabel(weight: .regular, size: 13)
    
    private lazy var gradient: CAGradientLayer = {
        let g = CAGradientLayer()
        g.colors = [UIColor.clear.cgColor, UIColor.black.withAlphaComponent(0.65).cgColor]
        g.locations = [0.0, 1.0]
        return g
    }()
    
    // MARK: - Social bar API & UI
    var onLikeTapped: ((MediaCollectionViewCell) -> Void)?
    var onCommentTapped: ((MediaCollectionViewCell) -> Void)?
    var onFavouriteTapped: ((MediaCollectionViewCell) -> Void)?
    
    private var controlBar: UIStackView?
    private var likeButton = UIButton(type: .system)
    private var commentButton = UIButton(type: .system)
    private var favouriteButton = UIButton(type: .system)
    
    private var isLiked = false
    private var isFavourited = false
    private var likeCount: Int = 0
    private var commentCount: Int = 0
    private var favouriteCount: Int = 0
    
    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        imageView.isHidden = false
        videoView.isHidden = true
        
        pauseVideo()
        looper = nil
        queuePlayer = nil
        removePlayerLayer()
        currentURL = nil
        
        videoView.gestureRecognizers?.forEach { videoView.removeGestureRecognizer($0) }
        videoView.subviews.forEach { $0.removeFromSuperview() }
        
        captionLabel.text = nil
        userLabel.text = nil
        metaLabel.text = nil
        statsLabel.text = nil
        
        // reset social state
        isLiked = false
        isFavourited = false
        likeCount = 0
        commentCount = 0
        favouriteCount = 0
        updateControlBarAppearance()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        imageView.frame = contentView.bounds
        videoView.frame = contentView.bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        videoView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        contentView.clipsToBounds = true
        
        playerLayer?.frame = videoView.bounds
        gradient.frame = bounds
        
        controlBar?.layoutIfNeeded()
    }
    
    // MARK: Local image/video helpers (your implementations remain)
    func configureImage(fileName: String) { /* your existing body */ }
    func configureVideo(fileName: String)  { /* your existing body */ }
    
    func configureStream(url: URL) { configurePlayer(with: url) }
    
    func configurePlaceholder() {
        ensureOverlay()
        imageView.isHidden = true
        videoView.isHidden = false
        let v = UIView(frame: videoView.bounds)
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        v.backgroundColor = .black
        v.isUserInteractionEnabled = false
        videoView.addSubview(v)
    }
    
    func setMetadata(caption: String, username: String, dateText: String, locationText: String, statsText: String) {
        ensureOverlay()
        captionLabel.text = caption
        userLabel.text = username
        metaLabel.text = [dateText, locationText].filter { !$0.isEmpty }.joined(separator: " • ")
        statsLabel.text = statsText
    }
    
    /// 👇 Call this from the VC to push the overlay above the tab bar/home indicator
    func setBottomInset(_ inset: CGFloat) {
        ensureOverlay()
        overlayBottomConstraint?.constant = -(16 + inset)
        setNeedsLayout()
    }
    
    // MARK: Public social-state updaters
    func setSocialState(isLiked: Bool, likeCount: Int,
                        isFavourited: Bool, favouriteCount: Int,
                        commentCount: Int) {
        self.isLiked = isLiked
        self.likeCount = max(0, likeCount)
        self.isFavourited = isFavourited
        self.favouriteCount = max(0, favouriteCount)
        self.commentCount = max(0, commentCount)
        updateControlBarAppearance()
    }
    
    func setLikeState(isLiked: Bool, count: Int) {
        self.isLiked = isLiked
        self.likeCount = max(0, count)
        updateControlBarAppearance()
    }
    
    func setFavouriteState(isFavourited: Bool, count: Int) {
        self.isFavourited = isFavourited
        self.favouriteCount = max(0, count)
        updateControlBarAppearance()
    }
    
    func setCommentCount(_ count: Int) {
        self.commentCount = max(0, count)
        updateControlBarAppearance()
    }
    
    func playVideo()  { queuePlayer?.play() }
    func pauseVideo() { queuePlayer?.pause() }
    
    // MARK: Player
    private func configurePlayer(with url: URL) {
        ensureOverlay()
        
        imageView.isHidden = true
        videoView.isHidden = false
        
        pauseVideo()
        looper = nil
        queuePlayer = nil
        removePlayerLayer()
        currentURL = url
        
        let asset = AVAsset(url: url)
        let item  = AVPlayerItem(asset: asset)
        let player = AVQueuePlayer(playerItem: item)
        let looper = AVPlayerLooper(player: player, templateItem: item)
        
        let layer = AVPlayerLayer(player: player)
        layer.frame = videoView.bounds
        layer.videoGravity = .resizeAspectFill
        layer.needsDisplayOnBoundsChange = true
        videoView.layer.addSublayer(layer)
        
        self.queuePlayer = player
        self.looper = looper
        self.playerLayer = layer
        
        // TAP — must not block scroll
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleVideoTap))
        tap.cancelsTouchesInView = false
        tap.delegate = self
        videoView.isUserInteractionEnabled = true
        videoView.addGestureRecognizer(tap)
        
        if let pan = nearestCollectionView()?.panGestureRecognizer {
            tap.require(toFail: pan)   // pan wins if user drags
        }
    }
    
    @objc private func handleVideoTap() {
        if queuePlayer?.timeControlStatus == .playing { queuePlayer?.pause() } else { queuePlayer?.play() }
    }
    
    private func nearestCollectionView() -> UICollectionView? {
        var v: UIView? = self
        while let cur = v {
            if let cv = cur as? UICollectionView { return cv }
            v = cur.superview
        }
        return nil
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool {
        if let pan = nearestCollectionView()?.panGestureRecognizer, other === pan { return true }
        return false
    }
    
    // Overlay
    private func ensureOverlay() {
        if gradient.superlayer == nil {
            layer.addSublayer(gradient)
            gradient.frame = bounds
        }
        if overlayStack == nil {
            // --- Text stack (existing) ---
            let textStack = UIStackView(arrangedSubviews: [captionLabel, userLabel, metaLabel, statsLabel])
            textStack.axis = .vertical
            textStack.spacing = 4
            textStack.translatesAutoresizingMaskIntoConstraints = false
            textStack.isUserInteractionEnabled = false
            
            // --- Control bar with blur background ---
            let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemChromeMaterialDark))
            blur.layer.cornerRadius = 14
            blur.clipsToBounds = true
            blur.translatesAutoresizingMaskIntoConstraints = false
            blur.isUserInteractionEnabled = true
            
            configure(controlButton: likeButton,
                      symbol: "heart", selectedSymbol: "heart.fill",
                      titleProvider: { "\(self.likeCount)" },
                      accessibility: "Like")
            
            configure(controlButton: commentButton,
                      symbol: "text.bubble", selectedSymbol: "text.bubble.fill",
                      titleProvider: { "\(self.commentCount)" },
                      accessibility: "Comments")
            
            configure(controlButton: favouriteButton,
                      symbol: "star", selectedSymbol: "star.fill",
                      titleProvider: { "\(self.favouriteCount)" },
                      accessibility: "Favourite")
            
            likeButton.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                print("👍 Like button tapped")
                self.isLiked.toggle()
                self.likeCount = max(0, self.likeCount + (self.isLiked ? 1 : -1))
                self.bump(self.likeButton)
                self.updateControlBarAppearance()
                self.toggleLikeInFirestore()
                self.onLikeTapped?(self)
            }, for: .touchUpInside)

            
            commentButton.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                self.bump(self.commentButton)
                self.onCommentTapped?(self)
            }, for: .touchUpInside)
            
            favouriteButton.addAction(UIAction { [weak self] _ in
                guard let self = self else { return }
                print("⭐️ Favourite button tapped")
                self.isFavourited.toggle()
                self.favouriteCount = max(0, self.favouriteCount + (self.isFavourited ? 1 : -1))
                self.bump(self.favouriteButton)
                self.updateControlBarAppearance()
                self.toggleFavouriteInFirestore()
                self.onFavouriteTapped?(self)
            }, for: .touchUpInside)

            let controls = UIStackView(arrangedSubviews: [likeButton, commentButton, favouriteButton])
            controls.axis = .horizontal
            controls.alignment = .center
            controls.distribution = .fillEqually
            controls.spacing = 0
            controls.translatesAutoresizingMaskIntoConstraints = false
            blur.contentView.addSubview(controls)
            
            NSLayoutConstraint.activate([
                controls.leadingAnchor.constraint(equalTo: blur.contentView.leadingAnchor),
                controls.trailingAnchor.constraint(equalTo: blur.contentView.trailingAnchor),
                controls.topAnchor.constraint(equalTo: blur.contentView.topAnchor),
                controls.bottomAnchor.constraint(equalTo: blur.contentView.bottomAnchor),
                blur.heightAnchor.constraint(equalToConstant: 44),
            ])
            
            // --- Vertical overlay = [controlBar, textStack] ---
            let stack = UIStackView(arrangedSubviews: [blur, textStack])
            stack.axis = .vertical
            stack.spacing = 10
            stack.translatesAutoresizingMaskIntoConstraints = false
            stack.alignment = .fill  // ✅ ensures blur stretches full width
            contentView.addSubview(stack)
            contentView.bringSubviewToFront(stack)
            
            // 👇 Pin full width to contentView
            overlayBottomConstraint = stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
                overlayBottomConstraint!
            ])
            
            // ✅ Now constrain blur to match stack width (same hierarchy)
            NSLayoutConstraint.activate([
                blur.leadingAnchor.constraint(equalTo: stack.leadingAnchor),
                blur.trailingAnchor.constraint(equalTo: stack.trailingAnchor),
                blur.heightAnchor.constraint(equalToConstant: 44)
            ])
            
            
            captionLabel.isUserInteractionEnabled = false
            userLabel.isUserInteractionEnabled = false
            metaLabel.isUserInteractionEnabled = false
            statsLabel.isUserInteractionEnabled = false
            
            controlBar = controls
            overlayStack = stack
            
            updateControlBarAppearance()
        }
    }
    
    private func bump(_ view: UIView) {
        UIView.animate(withDuration: 0.08, animations: {
            view.transform = CGAffineTransform(scaleX: 0.92, y: 0.92)
        }, completion: { _ in
            UIView.animate(withDuration: 0.10) {
                view.transform = .identity
            }
        })
    }
    
    private func removePlayerLayer() { playerLayer?.removeFromSuperlayer(); playerLayer = nil }
    
    private func makeOverlayLabel(weight: UIFont.Weight, size: CGFloat) -> UILabel {
        let l = UILabel()
        l.font = .systemFont(ofSize: size, weight: weight)
        l.textColor = .white
        l.numberOfLines = 0
        l.shadowColor = UIColor.black.withAlphaComponent(0.35)
        l.shadowOffset = CGSize(width: 0, height: 1)
        return l
    }
    
    // MARK: - Control bar helpers
    
    private func configure(controlButton btn: UIButton,
                           symbol: String,
                           selectedSymbol: String,
                           titleProvider: @escaping () -> String,
                           accessibility: String) {
        
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: symbol)
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 18, weight: .semibold)
        config.imagePlacement = .top
        config.imagePadding = 4
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        config.baseForegroundColor = .white
        config.attributedTitle = AttributedString(titleProvider(), attributes: .init([
            .foregroundColor: UIColor.white,
            .font: UIFont.systemFont(ofSize: 12, weight: .medium)
        ]))
        btn.configuration = config
        btn.tintColor = .white
        btn.accessibilityLabel = accessibility
        btn.setAssociatedSymbols(normal: symbol, selected: selectedSymbol)
    }
    
    private func updateControlBarAppearance() {
        func set(_ btn: UIButton, selected: Bool, count: Int) {
            guard var cfg = btn.configuration else { return }
            let syms = btn.getAssociatedSymbols()
            cfg.image = UIImage(systemName: selected ? syms.selected : syms.normal)
            cfg.baseForegroundColor = selected ? UIColor.systemYellow : UIColor.white
            cfg.attributedTitle = AttributedString("\(count)", attributes: .init([
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 12, weight: .medium)
            ]))
            btn.configuration = cfg
        }
        set(likeButton, selected: isLiked, count: likeCount)
        set(commentButton, selected: false, count: commentCount)
        set(favouriteButton, selected: isFavourited, count: favouriteCount)
    }
    
    // MARK: - Firestore toggles (atomic-ish via batch + FieldValue.increment)
    
    // MARK: - Firestore toggles (atomic-ish via batch + FieldValue.increment)
    
    private func toggleLikeInFirestore() {
        guard let id = videoID else {
            print("⚠️ toggleLikeInFirestore skipped: videoID is nil")
            return
        }
        guard let user = Auth.auth().currentUser else {
            print("⚠️ toggleLikeInFirestore skipped: no authenticated user")
            return
        }
        print("➡️ Starting LIKE write for videoID \(id); isLiked=\(isLiked)")

        let videoRef = db.collection(videosCollectionPath).document(id)
        let flagRef  = videoRef.collection("userFlags").document(user.uid)
        
        let delta: Int64 = isLiked ? 1 : -1
        
        let batch = db.batch()
        batch.setData([
            "liked": self.isLiked,
            "updatedAt": FieldValue.serverTimestamp(),
            "uid": user.uid
        ], forDocument: flagRef, merge: true)
        
        batch.updateData([
            "likesCount": FieldValue.increment(delta)
        ], forDocument: videoRef)
        
        batch.commit { error in
            if let error = error {
                let was = self.isLiked
                self.isLiked.toggle()
                self.likeCount = max(0, self.likeCount + (was ? -1 : 1))
                self.updateControlBarAppearance()
                print("❌ toggleLikeInFirestore error:", error.localizedDescription)
            } else {
                print("✅ Firestore LIKE update succeeded for videoID: \(id)")
            }
        }
    }
    
    private func toggleFavouriteInFirestore() {
        guard let id = videoID else {
            print("⚠️ toggleFavouriteInFirestore skipped: videoID is nil")
            return
        }
        guard let user = Auth.auth().currentUser else {
            print("⚠️ toggleFavouriteInFirestore skipped: no authenticated user")
            return
        }
        print("➡️ Starting FAV write for videoID \(id); isFavourited=\(isFavourited)")

        
        let videoRef = db.collection(videosCollectionPath).document(id)
        let flagRef  = videoRef.collection("userFlags").document(user.uid)
        
        let delta: Int64 = isFavourited ? 1 : -1
        
        let batch = db.batch()
        batch.setData([
            "favourited": self.isFavourited,
            "updatedAt": FieldValue.serverTimestamp(),
            "uid": user.uid
        ], forDocument: flagRef, merge: true)
        
        batch.updateData([
            "favouritesCount": FieldValue.increment(delta)
        ], forDocument: videoRef)
        
        batch.commit { error in
            if let error = error {
                let was = self.isFavourited
                self.isFavourited.toggle()
                self.favouriteCount = max(0, self.favouriteCount + (was ? -1 : 1))
                self.updateControlBarAppearance()
                print("❌ toggleFavouriteInFirestore error:", error.localizedDescription)
            } else {
                print("⭐️ Firestore FAVOURITE update succeeded for videoID: \(id)")
            }
        }
    }
}

// MARK: - UIButton associated symbols
private struct SymbolPair { let normal: String; let selected: String }
private var AssociatedSymbolsKey: UInt8 = 0

private extension UIButton {
    func setAssociatedSymbols(normal: String, selected: String) {
        objc_setAssociatedObject(self, &AssociatedSymbolsKey, SymbolPair(normal: normal, selected: selected), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
    func getAssociatedSymbols() -> SymbolPair {
        (objc_getAssociatedObject(self, &AssociatedSymbolsKey) as? SymbolPair)
        ?? SymbolPair(normal: "circle", selected: "circle.fill")
    }
}
