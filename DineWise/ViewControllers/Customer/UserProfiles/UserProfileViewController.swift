//
//  UserProfileViewController.swift
//  DineWise
//
//  Created by Muhammad Mahad on 2025-03-25.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

// nav 4 class for setting user profile
//displays logged in user email plus loggout button
class UserProfileViewController: UIViewController {
    @IBOutlet var emailLabel: UILabel!

    @IBAction func  unwindToUserProfileVC(for unwindSegue: UIStoryboardSegue, towards subsequentVC: UIViewController) {
        
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        fetchUserEmail()
    }

    private func fetchUserEmail() {
        if let user = Auth.auth().currentUser {
            emailLabel.text = user.email
        } else {
            emailLabel.text = "Not logged in"
        }
    }

    @IBAction func signOutTapped(_ sender: UIButton) {
        do {
            try Auth.auth().signOut()
            print("User signed out")
            
            // when signing out, it will move to login page
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            if let loginVC = storyboard.instantiateViewController(withIdentifier: "LoginPageController") as? LoginPageController {
                
                let navController = UINavigationController(rootViewController: loginVC)
                
                // nav for signout
                if let sceneDelegate = UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate {
                    sceneDelegate.window?.rootViewController = navController
                }
            }
        } catch {
            print("Error signing out: \(error.localizedDescription)")
        }
    }

}


