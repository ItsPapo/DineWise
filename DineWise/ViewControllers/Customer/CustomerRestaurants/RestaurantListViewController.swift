//
//  RestaurantListViewController.swift
//  DineWise
//
//  Created by Muhammad Mahad on 2025-04-06.
//


import UIKit

//class for explore Restaurants to display multiple restaurants using collection view
class RestaurantListViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {
    
    let restaurantData = RestaurantDetails()
    @IBOutlet var collectionView1: UICollectionView!
    let reuseIdentifierFeatured = "FeaturedCell"
    
    @IBAction func  unwindToRestaurantListVC(for unwindSegue: UIStoryboardSegue, towards subsequentVC: UIViewController) {
        
    }
    
    var selectedRestaurant: (name: String, image: String)?

    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        if (collectionView == self.collectionView1)
        {
            
            return restaurantData.restaurantNames.count
        }
        
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        if (collectionView == self.collectionView1){
            let cell : RestaurantCollectionViewCell = collectionView.dequeueReusableCell(withReuseIdentifier: self.reuseIdentifierFeatured, for: indexPath as IndexPath) as! RestaurantCollectionViewCell
            
            let  imageFilename = restaurantData.restaurantImages[indexPath.row]
            cell.featuredImage.image = UIImage(named: imageFilename)
            cell.lblRestaurantName.text = restaurantData.restaurantNames[indexPath.row]
            
            let tapGesture = UITapGestureRecognizer(target: self, action: #selector(didTapRestaurantImage(_:)))
            cell.addGestureRecognizer(tapGesture)
            cell.isUserInteractionEnabled = true
            
            return cell
        }
        
        return UICollectionViewCell()
    }
    
    @objc func didTapRestaurantImage(_ sender: UITapGestureRecognizer) {
        if let cell = sender.view as? UICollectionViewCell,
           let indexPath = collectionView1.indexPath(for: cell) {
            // Get selected restaurant data
            let selectedName = restaurantData.restaurantNames[indexPath.row]
            let selectedImage = restaurantData.restaurantImages[indexPath.row]
            selectedRestaurant = (name: selectedName, image: selectedImage)
            
            // Navigate to RestaurantProfileViewController
            performSegue(withIdentifier: "showRestaurantProfile", sender: self)
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showRestaurantProfile",
           let profileVC = segue.destination as? RestaurantProfileViewController {
            profileVC.restaurantName = selectedRestaurant?.name
            profileVC.restaurantImage = selectedRestaurant?.image
        }
    }
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        
        return 1
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAtIndex section: Int) -> UIEdgeInsets {
        return UIEdgeInsets(top: 0.0, left: 50.0, bottom: 0.0, right: 50.0)
    }
    
   
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 15
    }
    
    func collectionView(collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAtIndex section: Int) -> CGFloat {
        return 20   }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        collectionView1.delegate = self
        collectionView1.dataSource = self
        collectionView1.backgroundColor = UIColor.clear
        
        if let flowLayout = collectionView1.collectionViewLayout as? UICollectionViewFlowLayout {
            flowLayout.sectionInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
            flowLayout.minimumLineSpacing = 20
            flowLayout.minimumInteritemSpacing = 15
        }
    }
}
    
