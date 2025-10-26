//
//  RestaurantProfileViewController.swift
//  DineWise
//
//  Created by Muhammad Mahad on 2025-03-25.
//

import UIKit

// individual restaurant profile class
class RestaurantProfileViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {

    @IBOutlet var restaurantImageView: UIImageView!
    @IBOutlet var restaurantNameLabel: UILabel!
    @IBOutlet var restaurantDescriptionLabel: UILabel!

    @IBOutlet var foodCollectionView: UICollectionView!
    
    var restaurantName: String?
    var restaurantImage: String?
    var restaurantDescription: String?
    
    override func viewDidLoad() {
        super.viewDidLoad()

        restaurantNameLabel.text = restaurantName
        if let imageName = restaurantImage {
            restaurantImageView.image = UIImage(named: imageName) // main display image
        }
        
        if let description = restaurantDescription {
                    restaurantDescriptionLabel.text = description // Set the restaurant description
        }
        
        if let flowLayout = foodCollectionView.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.sectionInset = UIEdgeInsets(top: 40, left: 40, bottom: 20, right: 40)
            flowLayout.minimumLineSpacing = 10
            flowLayout.minimumInteritemSpacing = 10
            flowLayout.itemSize = CGSize(width: 100, height: 100)
        }
        
        foodCollectionView.reloadData()
    }
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return 4
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FoodCell", for: indexPath) as! FoodCollectionViewCell
        
        let foodImages = ["cuisine.png", "food1.png", "food2.png", "food3.png"]

        cell.foodImageView.image = UIImage(named: foodImages[indexPath.row])
        cell.foodImageView.contentMode = .scaleAspectFill
        cell.foodImageView.clipsToBounds = true
        return cell
    }

    // Handle food item selection
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        print("Tap works! Index: \(indexPath.row)")
    }
}
