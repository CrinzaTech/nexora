//
//  LaunchScreenViewController.swift
//  Runner
//
//  Custom launch screen with gradient background
//

import UIKit

class LaunchScreenViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Create gradient layer
        let gradientLayer = CAGradientLayer()

        // Set gradient colors (lavender to pink)
        let topColor = UIColor(red: 0.655, green: 0.545, blue: 0.98, alpha: 1.0) // #A78BFA
        let bottomColor = UIColor(red: 0.925, green: 0.282, blue: 0.6, alpha: 1.0) // #EC4899

        gradientLayer.colors = [topColor.cgColor, bottomColor.cgColor]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)

        // Set frame
        gradientLayer.frame = view.bounds

        // Add gradient to view
        view.layer.insertSublayer(gradientLayer, at: 0)

        // Create and add logo image view
        let logoImageView = UIImageView()
        logoImageView.contentMode = .scaleAspectFit
        logoImageView.translatesAutoresizingMaskIntoConstraints = false

        // Load the launch image
        if let launchImage = UIImage(named: "LaunchImage") {
            logoImageView.image = launchImage
        } else if let logoImage = UIImage(named: "logo") {
            logoImageView.image = logoImage
        }

        view.addSubview(logoImageView)

        // Center the logo
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            logoImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            logoImageView.widthAnchor.constraint(equalToConstant: 120),
            logoImageView.heightAnchor.constraint(equalToConstant: 120)
        ])
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // Update gradient frame on layout changes
        if let gradientLayer = view.layer.sublayers?.first as? CAGradientLayer {
            gradientLayer.frame = view.bounds
        }
    }
}
