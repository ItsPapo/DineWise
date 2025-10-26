//
//  CustomerLoginController.swift
//  DineWise
//
//  Created by Carlos Castro on 2025-03-18.
//

import UIKit
import FirebaseAuth

class CustomerLoginController: UIViewController {
    @IBOutlet var emailTextField: UITextField!
    @IBOutlet var passwordTextField: UITextField!
    @IBOutlet var messageLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        messageLabel.text = ""
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

        // Firebase Login
        Auth.auth().signIn(withEmail: email, password: password) { result, error in
            if let error = error {
                self.messageLabel.text = "Error: \(error.localizedDescription)"
                self.messageLabel.textColor = .orange
            } else {
                self.messageLabel.text = "Login successful!"
                self.messageLabel.textColor = .green

                // Transition to Tab Bar Controller after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let storyboard = UIStoryboard(name: "Main", bundle: nil)
                    if let tabBarController = storyboard.instantiateViewController(withIdentifier: "MainTabBarController") as? UITabBarController {
                        tabBarController.modalPresentationStyle = .fullScreen
                        
                        // Set root view controller
                        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                           let sceneDelegate = windowScene.delegate as? UIWindowSceneDelegate,
                           let window = sceneDelegate.window {
                            window?.rootViewController = tabBarController
                            window?.makeKeyAndVisible()
                        }
                    }
                }
            }
        }
    }
}
