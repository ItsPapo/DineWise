//
//  RestaurantLoginViewController.swift
//  DineWise
//
//  Created by Carlos Castro on 2025-03-18.
//

import UIKit
import FirebaseAuth

class RestaurantLoginViewController: UIViewController {

    @IBOutlet var emailTextField: UITextField!
        @IBOutlet var passwordTextField: UITextField!
        @IBOutlet var messageLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        messageLabel.text = ""
        // Do any additional setup after loading the view.
    }
    @IBAction func loginButtonTapped(_ sender: UIButton) {
            loginUser()
        }
    private func loginUser() {
            guard let email = emailTextField.text, !email.isEmpty,
                  let password = passwordTextField.text, !password.isEmpty else {
                messageLabel.text = "Please fill in all fields."
                messageLabel.textColor = .red
                return
            }

            // MARK: Firebase Login
            Auth.auth().signIn(withEmail: email, password: password) { result, error in
                if let error = error {
                    self.messageLabel.text = "Error: \(error.localizedDescription)"
                    self.messageLabel.textColor = .orange
                } else {
                    self.messageLabel.text = "Login successful!"
                    self.messageLabel.textColor = .green
                    
                }
            }
        }
// MARK: Transition to Home Screen After Login
       
    }
