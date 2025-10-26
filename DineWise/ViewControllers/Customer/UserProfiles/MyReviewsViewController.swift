//
//  MyReviewsViewController.swift
//  DineWise
//
//  Created by Muhammad Mahad on 2025-03-25.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth

// user profile subpage 2 for showing customer comments
// using firestore to get the data in a tablw view
class MyReviewsViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
   // var reviews: [String] = [] 
    var reviews: [(id: String, rating: Double, text: String)] = []

    @IBOutlet var tableView: UITableView!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.delegate = self
        tableView.dataSource = self
        
      // writeReviewToFirestore() //just testing
        fetchReviews()
    }
    
    // MARK: - Fetch Reviews from Firestore
    func fetchReviews() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Not logged in")
            return
        }
        
        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("reviews").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching reviews: \(error.localizedDescription)")
                return
            }
            
            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("No reviews found")
                return
            }

            self.reviews = documents.compactMap { document -> (id: String, rating: Double, text: String)? in
                guard let rating = document.data()["rating"] as? Double,
                let text = document.data()["text"] as? String else {
                    return nil
                }
                return (id: document.documentID, rating: rating, text: text)
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "ReviewCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ReviewCell")
        
       // cell.textLabel?.text = reviews[indexPath.row]
        let review = reviews[indexPath.row]


        if let ratingLabel = cell.viewWithTag(1) as? UILabel {
            ratingLabel.text = "Rating: \(review.rating)"
        }
                
        if let reviewTextLabel = cell.viewWithTag(2) as? UILabel {
            reviewTextLabel.text = review.text
        }
 
        cell.textLabel?.font = UIFont.systemFont(ofSize: 16, weight: .bold)
        cell.detailTextLabel?.font = UIFont.systemFont(ofSize: 14)
        cell.textLabel?.textColor = .black
        cell.detailTextLabel?.textColor = .darkGray
            
       cell.layoutMargins = UIEdgeInsets(top: 10, left: 15, bottom: 10, right: 15)
        return cell
    }
    
    // MARK: - UITableViewDelegate Methods
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let reviewToDelete = reviews[indexPath.row]
            deleteReview(reviewToDelete)
            
            reviews.remove(at: indexPath.row)
            
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

    // MARK: - Delete Review from Firestore
    func deleteReview(_ review: (id: String, rating: Double, text: String)) {
            guard let userId = Auth.auth().currentUser?.uid else {
                print("Not logged in")
                return
            }

            let db = Firestore.firestore()

            let reviewRef = db.collection("users").document(userId).collection("reviews").document(review.id)
            reviewRef.delete { error in
                if let error = error {
                    print("Error deleting review: \(error.localizedDescription)")
                } else {
                    print("Review deleted successfully.")
                }
            }
        }

    
    func writeReviewToFirestore() {
           guard let userId = Auth.auth().currentUser?.uid else {
               print("Not logged in")
               return
           }
           
           let db = Firestore.firestore()
           
           // Prepare the data for the new review
           let reviewData: [String: Any] = [
            "rating": 4.0,
               "text": "Amazing place for Burgers!"
           ]
           
           let reviewsRef = db.collection("users").document(userId).collection("reviews")
           
           reviewsRef.addDocument(data: reviewData) { error in
               if let error = error {
                   print("Error writing review: \(error.localizedDescription)")
               } else {
                   print("Review successfully written to Firestore!")
                   self.fetchReviews()  // Refresh the reviews after writing
               }
           }
       }
   }
