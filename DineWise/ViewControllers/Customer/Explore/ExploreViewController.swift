//
//  ExploreViewController.swift
//  DineWise
//
//  Created by Muhammad Mahad on 2025-03-22.
//

import UIKit
import AVFoundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

class ExploreViewController: UIViewController,
                             UICollectionViewDelegate,
                             UICollectionViewDataSource,
                             UICollectionViewDelegateFlowLayout {

    @IBOutlet var collectionView: UICollectionView!
    private var authHandle: AuthStateDidChangeListenerHandle?

    // MARK: Firestore model for a remote video row
    struct ExploreVideo {
        let id: String
        let createdByUid: String
        let createdBy: String
        let createdAt: Date?
        let caption: String
        let locationName: String?
        let locationGeo: GeoPoint?
        let likesCount: Int
        let favouritesCount: Int
        let commentsCount: Int
        let storagePath: String?
        let downloadURLString: String?
        var streamURL: URL?
    }

    private enum FeedItem { case remote(ExploreVideo), local(Media) }

    // Data
    var mediaItems: [Media] = []
    private var remoteVideos: [ExploreVideo] = []
    private var feed: [FeedItem] = []

    // Firestore paging
    private let db = Firestore.firestore()
    private var lastDoc: DocumentSnapshot?
    private var isLoadingRemote = false
    private let pageSize = 12

    // Date formatting
    private lazy var dateFmt: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df
    }()

    // ✅ How much to lift the overlay so it clears the tab bar / home indicator
    private var bottomOverlayInset: CGFloat {
        let tabH = tabBarController?.tabBar.frame.height ?? 0
        let safe = view.safeAreaInsets.bottom
        return max(tabH, safe) + 4
    }

    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()

        let ap = UINavigationBarAppearance()
           ap.configureWithOpaqueBackground()
           ap.backgroundColor = .systemBackground
           ap.shadowColor = nil
           navigationItem.standardAppearance = ap
           navigationItem.scrollEdgeAppearance = ap

        if let fl = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            fl.scrollDirection = .vertical
            fl.minimumInteritemSpacing = 0
            fl.minimumLineSpacing = 0
            fl.sectionInset = .zero

            // 🔧 Turn off self-sizing & force full-screen cells
            fl.estimatedItemSize = .zero
            fl.itemSize = view.bounds.size
            fl.invalidateLayout()
            collectionView.contentInsetAdjustmentBehavior = .automatic
        }

        collectionView.isPagingEnabled = true
        collectionView.decelerationRate = .fast
        collectionView.contentInset = .zero
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.showsVerticalScrollIndicator = false
        collectionView.backgroundColor = .black
        view.backgroundColor = .black

        collectionView.delegate = self
        collectionView.dataSource = self

        loadLocalMedia()
        fetchRemotePage(reset: true)
        // 🔁 Reload feed when user logs in/out so counts & flags come from server
            authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
                guard let self = self else { return }
                print("👤 Auth changed. uid =", user?.uid ?? "nil")
                self.fetchRemotePage(reset: true)     // re-query videos (server counters)
            }

            loadLocalMedia()
            fetchRemotePage(reset: true)              // initial load
        }
    

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadLocalMedia()
    }

    // Ensure true edge-to-edge (fixes any storyboard inset/gutter)
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if collectionView.frame != view.bounds { collectionView.frame = view.bounds }
        if let fl = collectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            if fl.itemSize != collectionView.bounds.size {
                fl.itemSize = collectionView.bounds.size
                fl.invalidateLayout()
            }
        }
    }

    // MARK: - Local media
    private func loadLocalMedia() {
        let bundled: [Media] = []
        let userVideos: [Media] = NewVideoManager.shared.getLocalMedia()
        mediaItems = userVideos + bundled
        rebuildFeedAndReload()
    }

    private func rebuildFeedAndReload() {
        feed = remoteVideos.map { .remote($0) } + mediaItems.map { .local($0) }
        collectionView.reloadData()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { self.syncPlaybackToCenter() }
    }

    // MARK: - Firestore listing (paged)
    private func fetchRemotePage(reset: Bool = false) {
        guard !isLoadingRemote else { return }
        isLoadingRemote = true
        if reset {
            lastDoc = nil
            remoteVideos.removeAll()
        }

        var q: Query = db.collection("explore_videos")
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)

        if let last = lastDoc { q = q.start(afterDocument: last) }

        q.getDocuments { [weak self] snap, err in
            guard let self = self else { return }
            self.isLoadingRemote = false
            if let err = err { print("Firestore error:", err); return }
            guard let snap = snap, !snap.isEmpty else { self.lastDoc = nil; return }

            self.lastDoc = snap.documents.last

            var batch: [ExploreVideo] = snap.documents.compactMap { doc in
                let d = doc.data()
                let createdByUid = d["createdByUid"] as? String ?? ""
                let createdBy     = d["createdBy"] as? String ?? ""
                let ts            = d["createdAt"] as? Timestamp
                let caption       = d["caption"] as? String ?? ""
                let locationMap   = d["location"] as? [String: Any]
                let locName       = locationMap?["name"] as? String
                let locGeo        = locationMap?["geo"] as? GeoPoint
                let likes         = d["likesCount"] as? Int ?? 0
                let favs          = d["favouritesCount"] as? Int ?? 0
                let comments      = d["commentsCount"] as? Int ?? 0
                let storagePath   = d["storagePath"] as? String
                let dl            = d["downloadURL"] as? String

                return ExploreVideo(
                    id: doc.documentID,
                    createdByUid: createdByUid,
                    createdBy: createdBy,
                    createdAt: ts?.dateValue(),
                    caption: caption,
                    locationName: locName,
                    locationGeo: locGeo,
                    likesCount: likes,
                    favouritesCount: favs,
                    commentsCount: comments,
                    storagePath: storagePath,
                    downloadURLString: dl,
                    streamURL: nil
                )
            }

            // Resolve stream URLs
            let group = DispatchGroup()
            for i in batch.indices {
                if let urlStr = batch[i].downloadURLString, let url = URL(string: urlStr) {
                    batch[i].streamURL = url
                } else if let storagePath = batch[i].storagePath {
                    group.enter()
                    Storage.storage().reference(withPath: storagePath).downloadURL { url, _ in
                        batch[i].streamURL = url
                        group.leave()
                    }
                }
            }

            group.notify(queue: .main) {
                batch.sort { (a, b) in
                    (a.createdAt ?? .distantPast) > (b.createdAt ?? .distantPast)
                }
                self.remoteVideos.append(contentsOf: batch)
                self.rebuildFeedAndReload()
            }
        }
    }

    // MARK: - UICollectionView
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        feed.count
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "MediaCell",
                                                            for: indexPath) as? MediaCollectionViewCell else {
            return UICollectionViewCell()
        }

        switch feed[indexPath.item] {
        case .local(let item):
            if item.type == .image { cell.configureImage(fileName: item.fileName) }
            else { cell.configureVideo(fileName: item.fileName) }

        case .remote(let video):
            guard let url = video.streamURL else {
                cell.configurePlaceholder()
                return cell
            }

            let dateText = video.createdAt.map { dateFmt.string(from: $0) } ?? ""
            let locationText = video.locationName ?? ""
            let statsText = "♥︎ \(video.likesCount)   ★ \(video.favouritesCount)   💬 \(video.commentsCount)"

            cell.configureStream(url: url)
            cell.setMetadata(
                caption: video.caption,
                username: "@\(video.createdBy)",
                dateText: dateText,
                locationText: locationText,
                statsText: statsText
            )
            cell.setBottomInset(bottomOverlayInset)

            // 🔑 Tell the cell which doc to update (and collection name)
            cell.videoID = video.id
            cell.videosCollectionPath = "explore_videos"

            // ✅ Initial counts; assume not liked/faved until we fetch user flags
            cell.setSocialState(
                isLiked: false,
                likeCount: video.likesCount,
                isFavourited: false,
                favouriteCount: video.favouritesCount,
                commentCount: video.commentsCount
            )

            // ✅ Per-user flags (matches your rules): explore_videos/{videoId}/userFlags/{uid}
            if let uid = Auth.auth().currentUser?.uid {
                let videoRef = db.collection("explore_videos").document(video.id)
                videoRef.collection("userFlags").document(uid).getDocument { snap, _ in
                    let data = snap?.data() ?? [:]
                    let liked = (data["liked"] as? Bool) ?? false
                    let faved = (data["favourited"] as? Bool) ?? false
                    DispatchQueue.main.async {
                        cell.setLikeState(isLiked: liked, count: video.likesCount)              // server counters
                        cell.setFavouriteState(isFavourited: faved, count: video.favouritesCount)
                    }
                }
            } else {
                // Logged out: make sure toggles show off (counters still come from server)
                cell.setLikeState(isLiked: false, count: video.likesCount)
                cell.setFavouriteState(isFavourited: false, count: video.favouritesCount)
            }
                
            
            // 👇 lift overlay above tab bar / home indicator
            cell.setBottomInset(bottomOverlayInset)
        }

        return cell
    }

    // Cell sizing
    func collectionView(_ collectionView: UICollectionView,
                        layout collectionViewLayout: UICollectionViewLayout,
                        sizeForItemAt indexPath: IndexPath) -> CGSize {
        CGSize(width: collectionView.bounds.width, height: collectionView.bounds.height)
    }

    // MARK: - Infinite scroll
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        let y = scrollView.contentOffset.y
        let h = scrollView.contentSize.height
        let frameH = scrollView.bounds.height
        if y > h - 1.8 * frameH, lastDoc != nil, !isLoadingRemote {
            fetchRemotePage(reset: false)
        }
    }

    // MARK: - Pause-on-scroll, play-on-settle
    private func pauseAllVisibleVideos() {
        for cell in collectionView.visibleCells {
            (cell as? MediaCollectionViewCell)?.pauseVideo()
        }
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        pauseAllVisibleVideos()
    }

    func scrollViewWillBeginDecelerating(_ scrollView: UIScrollView) {
        pauseAllVisibleVideos()
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        syncPlaybackToCenter()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate { syncPlaybackToCenter() }
    }

    // MARK: - Playback control (play center, pause others)
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.syncPlaybackToCenter() }
    }

    func collectionView(_ collectionView: UICollectionView,
                        didEndDisplaying cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        (cell as? MediaCollectionViewCell)?.pauseVideo()
    }

    private func syncPlaybackToCenter() {
        let center = CGPoint(x: collectionView.bounds.midX, y: collectionView.bounds.midY)
        let targetIP = collectionView.indexPathForItem(at: center)
        for cell in collectionView.visibleCells {
            guard let mediaCell = cell as? MediaCollectionViewCell else { continue }
            let ip = collectionView.indexPath(for: mediaCell)
            if ip == targetIP { mediaCell.playVideo() } else { mediaCell.pauseVideo() }
        }
    }
}
