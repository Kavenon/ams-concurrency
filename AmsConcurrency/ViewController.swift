//
//  ViewController.swift
//  AmsConcurrency
//
//  Created by Użytkownik Gość on 12.01.2018.
//  Copyright © 2018 Użytkownik Gość. All rights reserved.
//

import UIKit

class ViewController: UIViewController, URLSessionDownloadDelegate {

    let images = [
        "https://upload.wikimedia.org/wikipedia/commons/0/04/Dyck,_Anthony_van_-_Family_Portrait.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/0/06/Master_of_Flémalle_-_Portrait_of_a_Fat_Man_-_Google_Art_Project_(331318).jpg",
        "https://upload.wikimedia.org/wikipedia/commons/c/ce/Petrus_Christus_-_Portrait_of_a_Young_Woman_-_Google_Art_Project.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/3/36/Quentin_Matsys_-_A_Grotesque_old_woman.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/c/c8/Valmy_Battle_painting.jpg"
    ]
    
    var timer: TimeInterval = 0.0;
    
    @IBAction func onStart(_ sender: Any) {
        timer = Date().timeIntervalSince1970
        downloadFile(stringUrl: images[0])
    }
    
    func downloadFile(stringUrl: String){
        
        print("\(elapsedTime()) started download of file \(stringUrl)")
        
        let url = URL(string: stringUrl)
        let request = URLRequest(url: url!)
        let config = URLSessionConfiguration.background(withIdentifier: "pic.download.\(stringUrl)")
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        
        let task = session.downloadTask(with: request)
        task.resume()
        
    }
    
    func elapsedTime() -> Double {
        return Date().timeIntervalSince1970 - timer;
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                           didFinishDownloadingTo location: URL){
        
        print("\(elapsedTime()) finished download of file \(location)")
        let docDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]

        var path = docDir.appending("/myflies/").appending((downloadTask.response?.suggestedFilename)!)
        let fileManager = FileManager.default
        
        if(fileManager.fileExists(atPath: path)){
            path = docDir.appending("/myflies/").appending(String(Date().timeIntervalSince1970)).appending((downloadTask.response?.suggestedFilename)!)
        }
        
        let pathUrl = URL(string:path)
        
        try? fileManager.copyItem(at: location, to: pathUrl!)
        try? fileManager.removeItem(at: location)
        
        print("\(elapsedTime()) finished copying file \(path)")

              
    }
    
   
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64){
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

