//
//  FavouritesViewController.swift
//  DineWise
//
//  Created by Muhammad Mahad on 2025-03-24.
//

import UIKit
import FirebaseFirestore
import FirebaseAuth
import WebKit

// user profile subpage 1 for showing customer favourite foods
// using firestore to get the data in a tablw view
class FavouritesViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {

    @IBOutlet var tableView: UITableView!
    var favourites: [(foodId: String, foodImageUrl: String, restaurantName: String, foodName: String, location: String)] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        // Set the data source and delegate for the table view
        tableView.delegate = self
        tableView.dataSource = self
        tableView.backgroundColor = UIColor.clear

        //writeFavouriteToFirestore();
        fetchFavourites()
    }

    // MARK: - Fetch Favourites from Firestore
    func fetchFavourites() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Not logged in")
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(userId).collection("favourites").getDocuments { (snapshot, error) in
            if let error = error {
                print("Error fetching favourites: \(error.localizedDescription)")
                return
            }

            guard let documents = snapshot?.documents, !documents.isEmpty else {
                print("No favourites found")
                return
            }

            // Parse favourite data from Firestore documents
            self.favourites = documents.compactMap { document -> (String, String, String, String, String)? in
                guard let foodImageUrl = document.data()["foodImageUrl"] as? String,
                      let restaurantName = document.data()["restaurantName"] as? String,
                      let foodName = document.data()["foodName"] as? String,
                      let location = document.data()["location"] as? String,
                      let foodId = document.documentID as? String else {
                    return nil
                }
                return (foodId, foodImageUrl, restaurantName, foodName, location)
            }

            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }

    // MARK: - UITableViewDataSource Methods
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return favourites.count
    }
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {  // type height and pick heightforrowat
        return 150
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        // Dequeue a reusable cell
        let cell = tableView.dequeueReusableCell(withIdentifier: "FavouriteCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "FavouriteCell")

        // Get the favourite for the current row
        let favourite = favourites[indexPath.row]


        if let foodNameLabel = cell.viewWithTag(2) as? UILabel {
                   foodNameLabel.text = favourite.foodName
               }
               
               // Set restaurant name in label (Tag = 3)
               if let restaurantNameLabel = cell.viewWithTag(3) as? UILabel {
                   restaurantNameLabel.text = favourite.restaurantName
               }

        if let webView = cell.viewWithTag(1) as? WKWebView {
                    if let url = URL(string: favourite.foodImageUrl) {
                        let request = URLRequest(url: url)
                        webView.load(request)
                    }
                }
        return cell
    }

    // MARK: - UITableViewDelegate Methods
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true  // Allow swipe-to-delete
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            let favouriteToDelete = favourites[indexPath.row]
            deleteFavourite(favouriteToDelete)
            favourites.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
    }

    // MARK: - Delete Favourite from Firestore
    func deleteFavourite(_ favourite: (foodId: String, foodImageUrl: String, restaurantName: String, foodName: String, location: String)) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Not logged in")
            return
        }

        let db = Firestore.firestore()

        let favouriteRef = db.collection("users").document(userId).collection("favourites").document(favourite.foodId)

        favouriteRef.delete { error in
            if let error = error {
                print("Error deleting favourite: \(error.localizedDescription)")
            } else {
                print("Favourite deleted successfully.")
            }
        }
    }
    
    func writeFavouriteToFirestore() {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("Not logged in")
            return
        }

        let db = Firestore.firestore()

        // Prepare the data for the new favourite
        let favouriteData: [String: Any] = [
            "foodImageUrl": "https://images.immediate.co.uk/production/volatile/sites/30/2020/08/chorizo-mozarella-gnocchi-bake-cropped-9ab73a3.jpg?quality=90&webp=true&resize=300,272",
            "restaurantName": "Burger Restaurant",
            "foodName": "Firecracker Burger",
            "location": "67 Huron Street, Toronto"
        ]

        let favouritesRef = db.collection("users").document(userId).collection("favourites")

        favouritesRef.addDocument(data: favouriteData) { error in
            if let error = error {
                print("Error writing favourite: \(error.localizedDescription)")
            } else {
                print("Favourite successfully written to Firestore!")
                self.fetchFavourites()  // Refresh the favourites after writing
            }
        }
    }

}

