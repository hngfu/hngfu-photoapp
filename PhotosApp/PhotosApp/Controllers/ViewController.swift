//
//  ViewController.swift
//  PhotosApp
//
//  Created by 조재흥 on 19. 6. 12..
//  Copyright © 2019 hngfu. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    @IBOutlet weak var photosCollectionView: UICollectionView!
    @IBOutlet weak var doneButton: UIBarButtonItem!
    
    private let photoManager = PhotoManager()
    private var previousPreheatRect = CGRect.zero
    private let thumbnailSize = CGSize(width: Configuration.Image.width,
                                       height: Configuration.Image.height)
    
    private var makeVideoActionIsAvailable: Bool {
        guard let selectedIndexPaths = photosCollectionView.indexPathsForSelectedItems else { return false }
        let enabledCount = 3
        return enabledCount <= selectedIndexPaths.count
    }
    private var revertActionIsAvailable: Bool {
        guard let selectedIndexPaths = photosCollectionView.indexPathsForSelectedItems,
            selectedIndexPaths.count == 1,
            let indexPath = selectedIndexPaths.first,
            photoManager.isModified(indexPath) else { return false }
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        photosCollectionView.delegate = self
        photosCollectionView.dataSource = self
        photosCollectionView.allowsMultipleSelection = true
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(deleteItems),
                                               name: .photoDidDeleted,
                                               object: photoManager)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(insertItems),
                                               name: .photoDidInserted,
                                               object: photoManager)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(changeItems),
                                               name: .photoDidChanged,
                                               object: photoManager)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(moveItems),
                                               name: .photoDidMoved,
                                               object: photoManager)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(reloadItem),
                                               name: .notIncrementalChanges,
                                               object: photoManager)
    }
    
    @objc func deleteItems(_ noti: Notification) {
        guard let userInfo = noti.userInfo,
            let paths = userInfo[UserInfoKey.removedPaths] as? [IndexPath] else { return }
        DispatchQueue.main.async {
            self.photosCollectionView.deleteItems(at: paths)
        }
    }
    
    @objc func insertItems(_ noti: Notification) {
        guard let userInfo = noti.userInfo,
            let paths = userInfo[UserInfoKey.insertedPaths] as? [IndexPath] else { return }
        DispatchQueue.main.async {
            self.photosCollectionView.insertItems(at: paths)
        }
    }
    
    @objc func changeItems(_ noti: Notification) {
        guard let userInfo = noti.userInfo,
            let paths = userInfo[UserInfoKey.changedPaths] as? [IndexPath] else { return }
        DispatchQueue.main.async {
            self.photosCollectionView.reloadItems(at: paths)
        }
    }
    
    @objc func moveItems(_ noti: Notification) {
        guard let userInfo = noti.userInfo,
            let (fromIndex, toIndex) = userInfo[UserInfoKey.movedPaths] as? (Int, Int) else { return }
        DispatchQueue.main.async {
            self.photosCollectionView.moveItem(at: IndexPath(item: fromIndex, section: 0),
                                               to: IndexPath(item: toIndex, section: 0))
        }
    }
    
    @objc func reloadItem(_ noti: Notification) {
        DispatchQueue.main.async {
            self.photosCollectionView.reloadData()
        }
    }
    
    @IBAction func tapEditButton(_ sender: UIBarButtonItem) {
        let menu = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        let cancelAction = UIAlertAction(title: Configuration.ActionSheet.Title.cancel,
                                         style: .cancel)
        let makeVideoAction = UIAlertAction(title: Configuration.ActionSheet.Title.makeVideo,
                                            style: .default) { _ in self.makeVideo() }
        let applyFilterAction = UIAlertAction(title: Configuration.ActionSheet.Title.applyFilter,
                                              style: .default) { _ in self.applyFilter() }
        let revertAction = UIAlertAction(title: Configuration.ActionSheet.Title.revert,
                                         style: .default) { _ in self.revert() }
        
        makeVideoAction.isEnabled = makeVideoActionIsAvailable
        revertAction.isEnabled = revertActionIsAvailable
        
        menu.addAction(cancelAction)
        menu.addAction(makeVideoAction)
        menu.addAction(applyFilterAction)
        menu.addAction(revertAction)
        
        self.present(menu, animated: true, completion: nil)
    }
    
    @IBAction func tapAddButton(_ sender: UIBarButtonItem) {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = .init(width: Configuration.DoodleViewController.Item.width,
                                height: Configuration.DoodleViewController.Item.height)
        layout.scrollDirection = .vertical
        let doodleViewController = DoodleViewController(collectionViewLayout: layout)
        let navigationController = UINavigationController(rootViewController: doodleViewController)
        self.present(navigationController, animated: true, completion: nil)
    }
    
    private func makeVideo() {
        guard let selectedIndices = photosCollectionView.indexPathsForSelectedItems else { return }
        let images = photoManager.images(for: selectedIndices, size: .init(width: Configuration.Video.width,
                                                                           height: Configuration.Video.height))
        let maker = VideoMaker(width: Configuration.Video.width,
                               height: Configuration.Video.height,
                               second: Configuration.Video.playTime)
        maker.makeVideo(from: images)
    }
    
    private func applyFilter() {
        guard let selectedIndices = photosCollectionView.indexPathsForSelectedItems else { return }
        photoManager.applyFilter(to: selectedIndices)
    }
    
    private func revert() {
        guard let selectedIndices = photosCollectionView.indexPathsForSelectedItems else { return }
        photoManager.revert(by: selectedIndices)
    }
}

extension ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photoManager.count()
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: PhotosCollectionViewCell.identifier,
                                                      for: indexPath)
        guard let photoCell = cell as? PhotosCollectionViewCell else { return cell }
        let resultHandler = { (image: UIImage?, _: [AnyHashable: Any]?) -> Void in
            photoCell.photoImageView.image = image
        }
        photoManager.requestImage(with: indexPath.item, completion: resultHandler)
        if let livePhotoImage = photoManager.livePhotoImage(for: indexPath.item) {
            photoCell.livePhotobadgeImageView.image = livePhotoImage
        }
        return photoCell
    }
}

extension ViewController: UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return thumbnailSize
    }
    
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCachedAssets()
    }
    
    private func updateCachedAssets() {
        let visibleRect = CGRect(origin: photosCollectionView.contentOffset,
                                 size: photosCollectionView.bounds.size)
        let preheatRect = visibleRect.insetBy(dx: 0, dy: -0.5 * visibleRect.height)
        
        let delta = abs(preheatRect.midY - previousPreheatRect.midY)
        guard delta > view.bounds.height / 3 else { return }
        let (addedRect, removedRect) = differencesBetweenRects(previousPreheatRect, preheatRect)
        guard let addedIndexPaths = photosCollectionView.indexPathsForElements(in: addedRect),
            let removedIndexPaths = photosCollectionView.indexPathsForElements(in: removedRect) else { return }
        photoManager.startCachingImages(for: addedIndexPaths)
        photoManager.stopCachingImages(for: removedIndexPaths)

        previousPreheatRect = preheatRect
    }
    
    private func differencesBetweenRects(_ old: CGRect, _ new: CGRect) -> (added: CGRect, removed: CGRect) {
        if old.intersects(new) {
            let added: CGRect
            let removed: CGRect
            if new.maxY > old.maxY {
                added = CGRect(x: new.origin.x, y: old.maxY,
                               width: new.width, height: new.maxY - old.maxY)
                removed = CGRect(x: new.origin.x, y: old.minY,
                                 width: new.width, height: new.minY - old.minY)
            } else {
                added = CGRect(x: new.origin.x, y: new.minY,
                               width: new.width, height: old.minY - new.minY)
                removed = CGRect(x: new.origin.x, y: new.maxY,
                                 width: new.width, height: old.maxY - new.maxY)
            }
            return (added, removed)
        } else {
            return (new, old)
        }
    }
}

extension UICollectionView {
    func indexPathsForElements(in rect: CGRect) -> [IndexPath]? {
        guard let allLayoutAttributes = collectionViewLayout.layoutAttributesForElements(in: rect) else { return nil }
        return allLayoutAttributes.map { $0.indexPath }
    }
}
