//
//  HomeVC.swift
//  BunFight
//
//  Created by Joshua Colley on 07/12/2019.
//  Copyright © 2019 Joshua Colley. All rights reserved.
//

import UIKit
import CoreLocation
import Firebase

class HomeVC: UIViewController {
    
    @IBOutlet weak var locationLabel: UILabel!
    @IBOutlet weak var breadLabel: UILabel!
    @IBOutlet weak var tellUsButton: UIButton!
    @IBOutlet weak var loadingSpinner: UIActivityIndicatorView!
    
    private let db = Firestore.firestore()
    private let collectionName: String = "bread"
    private var breadModels: [Bread]?
    private var currentLocation: String!
    
    lazy var locationManager: CLLocationManager = {
        let manager = CLLocationManager()
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = 5.0
        manager.delegate = self
        return manager
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tellUsButton.isHidden = true
        tellUsButton.addTarget(self, action: #selector(tellUsAction), for: .touchUpInside)
        loadingSpinner.isHidden = true
        
        requestPermission()
        getBreadNames()
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        locationManager.stopUpdatingLocation()
    }
    
    // MARK: - Private Methods
    private func requestPermission() {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined: locationManager.requestAlwaysAuthorization()
        case .authorizedAlways, .authorizedWhenInUse: locationManager.startUpdatingLocation()
        default: break
        }
    }
    
    private func getBreadNames() {
        self.loadingSpinner.isHidden = false
        self.loadingSpinner.startAnimating()
        db.collection(collectionName).getDocuments { (snapshot, error) in
            guard error == nil else { return }
            
            let breadModels = snapshot?.documents.map({ (snap) -> Bread in
                let model = Bread(name: snap.data()["name"] as! String,
                                  locationName: snap.data()["location"] as! String)
                return model
            })
            self.breadModels = breadModels
            self.loadingSpinner.isHidden = true
            self.loadingSpinner.stopAnimating()
        }
    }
    
    private func addBreadName(name: String, location: String) {
        debugPrint("@DEBUG: Name = \(name), Location = \(location)")
        db.collection(collectionName).addDocument(data: [
            "name": name,
            "location": location
        ]) { (error) in
            self.loadingSpinner.isHidden = true
            self.loadingSpinner.stopAnimating()
            guard error == nil else { return }
            self.breadLabel.text = name
            self.getBreadNames()
        }
    }
    
    @objc private func tellUsAction() {
        let alert = UIAlertController(title: "Help us",
                                      message: "What to you call bread in \(currentLocation ?? "")",
                                      preferredStyle: .alert)
        
        alert.addTextField { (field) in
            field.placeholder = "Bread name"
            field.tag = 1001
        }
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Submit", style: .default, handler: { (_) in
            alert.textFields?.forEach({
                if $0.tag == 1001 {
                    self.addBreadName(name: $0.text ?? "", location: self.currentLocation ?? "")
                    self.tellUsButton.isHidden = true
                    self.loadingSpinner.isHidden = false
                    self.loadingSpinner.startAnimating()
                }
            })
        }))
        
        
        self.present(alert, animated: true, completion: nil)
    }
}

// MARK - Location Manager Delegate
extension HomeVC: CLLocationManagerDelegate {
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            let address = CLGeocoder()
            address.reverseGeocodeLocation(location) { (places, error) in
                guard error == nil else { return }
                if let place = places?.first {
                    self.locationLabel.text = "\(place.locality ?? "")"
                    self.currentLocation = place.locality ?? ""
                    if let bread = self.breadModels?.first(where: { $0.locationName == place.locality! }) {
                        self.breadLabel.text = "\(bread.name)"
                        self.tellUsButton.isHidden = true
                    } else {
                        self.breadLabel.text = "Sorry we don't know"
                        self.tellUsButton.isHidden = false
                    }
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways, .authorizedWhenInUse: locationManager.startUpdatingLocation()
        default: locationManager.stopUpdatingLocation()
        }
    }
}


// MARK: - Bread Model
struct Bread {
    var name: String
    var locationName: String
}
