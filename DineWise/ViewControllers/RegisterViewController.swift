//
//  RegisterViewController.swift
//  DineWise
//
//  Created by Carlos Castro on 2025-03-18.
//

import UIKit
import FirebaseAuth
class RegisterViewController: UIViewController {
    @IBOutlet  var emailTextField: UITextField!
        @IBOutlet  var passwordTextField: UITextField!
        @IBOutlet var messageLabel: UILabel!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        messageLabel.text = ""
    }
    @IBAction func registerButtonTapped(_ sender: UIButton) {
            registerUser()
        }
    private func registerUser() {
            guard let email = emailTextField.text, !email.isEmpty,
                  let password = passwordTextField.text, !password.isEmpty else {
                messageLabel.text = "Please fill in all fields."
                messageLabel.textColor = .red
                return
            }

            Auth.auth().createUser(withEmail: email, password: password) { authResult, error in
                if let error = error {
                    self.messageLabel.text = "Error: \(error.localizedDescription)"
                    self.messageLabel.textColor = .red
                } else {
                    self.messageLabel.text = "Registration successful!"
                    self.messageLabel.textColor = .green
                }
            }
        }
    }
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */


