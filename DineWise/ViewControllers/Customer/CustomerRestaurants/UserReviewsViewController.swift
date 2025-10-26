//
//  UserReviewsViewController.swift
//  DineWise
//
//  Created by Muhammad Mahad on 2025-03-22.
//

import UIKit
import FirebaseFirestore

// class for restaurant specific reviews

class UserReviewsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    var reviews: [(rating: Double, text: String)] = []
    var restaurantId: String?
    var restaurantName: String?
    
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor.clear
        
        let rating: Double = 4.5 // only to test 
        let text: String = "This restaurant is amazing! The food was great."
            

        writeReviewToFirestore(rating: rating, text: text)
        //writeReviewToFirestore()
        fetchReviewsForRestaurant()
    }
    
    // MARK: - Fetch Reviews for a Specific Restaurant
    func fetchReviewsForRestaurant() {
        guard let restaurantId = restaurantId else {
            print("No restaurant ID provided")
            return
        }
        
        let db = Firestore.firestore()
        db.collection("restaurants").document(restaurantId).collection("reviews").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching reviews: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("No reviews found")
                return
            }
            
            self.reviews = documents.compactMap { document -> (rating: Double, text: String)? in
                guard let rating = document.data()["rating"] as? Double,
                      let text = document.data()["text"] as? String else {
                    return nil
                }
                return (rating: rating, text: text)
            }
            
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    
    // MARK: - UITableViewDataSource Methods
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 100
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return reviews.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "RestReviewCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "RestReviewCell")
        
        let review = reviews[indexPath.row]
        
        if let ratingLabel = cell.viewWithTag(1) as? UILabel {
            ratingLabel.text = "Rating: \(review.rating)"
        }
        
        if let reviewTextLabel = cell.viewWithTag(2) as? UILabel {
            reviewTextLabel.text = review.text
        }
        
        cell.layoutMargins = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        return cell
    }

    // MARK: - Write Review to Firestore
    func writeReviewToFirestore(rating: Double, text: String) {
        guard let restaurantId = restaurantId else {
            print("No restaurant ID provided")
            return
        }
        
        let db = Firestore.firestore()
        
        // Prepare the data for the new review
        let reviewData: [String: Any] = [
            "rating": rating,
            "text": text
        ]
        
        let reviewsRef = db.collection("restaurants").document(restaurantId).collection("reviews")
        
        reviewsRef.addDocument(data: reviewData) { error in
            if let error = error {
                print("Error writing review: \(error.localizedDescription)")
            } else {
                print("Review successfully written to Firestore!")
                self.fetchReviewsForRestaurant()
            }
        }
    }
}
