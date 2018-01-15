//
//  ViewController.swift
//  AmsConcurrency
//
//  Created by Użytkownik Gość on 12.01.2018.
//  Copyright © 2018 Użytkownik Gość. All rights reserved.
//

import UIKit

class ViewController: UITableViewController, URLSessionDownloadDelegate {

    let images = [
        "https://upload.wikimedia.org/wikipedia/commons/0/04/Dyck,_Anthony_van_-_Family_Portrait.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/c/ce/Petrus_Christus_-_Portrait_of_a_Young_Woman_-_Google_Art_Project.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/3/36/Quentin_Matsys_-_A_Grotesque_old_woman.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/c/c8/Valmy_Battle_painting.jpg"
    ]
    
    var fdQueue: [FacedetectQueueItem] = [];
    var timer: TimeInterval = 0.0;
    var entities = [URLSessionDownloadTask]()
    
    var downloadState: [String: DownloadState] = [:]
    var bgFacedetection: [String: UIBackgroundTaskIdentifier] = [:]
    var bgThumb: [String: UIBackgroundTaskIdentifier] = [:]

    var handlers: [String: () -> Swift.Void] = [:]
    var reachedHalf = [String: Bool]()
    
    @IBAction func onClickStart(_ sender: Any) {
        timer = Date().timeIntervalSince1970
        for img in images {
           downloadFile(stringUrl: img)
        }
    }
   
  
    public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return images.count;
    }
    
    public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: UITableViewCellStyle.subtitle, reuseIdentifier: "cell");
        let img = images[indexPath.row];
        
        let downloadState = self.downloadState[img];
        
        cell.textLabel?.text = downloadState?.task?.originalRequest?.url?.lastPathComponent;
        cell.detailTextLabel?.text = downloadState?.detail;
        if downloadState?.image != nil {
            cell.imageView?.image = downloadState?.image!
        }
        
        return (cell);
    }
    
    // Trigger image download
    func downloadFile(stringUrl: String){
        
        print("\(elapsedTime()) started download of file \(stringUrl)")
        
        let url = URL(string: stringUrl)
        let request = URLRequest(url: url!)
        let config = URLSessionConfiguration.background(withIdentifier: "pic.download.\(stringUrl).\(Date().timeIntervalSince1970)")
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        
        let task = session.downloadTask(with: request)
        task.resume()
        
        self.downloadState[stringUrl] = (DownloadState(task: task, detail: "Started downloading", image: nil))
        self.tableView.reloadData()
        
    }
    
    func elapsedTime() -> Double {
        return (round((Date().timeIntervalSince1970 - timer)*10000)/10000);
    }

    // Face detection
    func faceDetect(path: String, url: String){
        
        DispatchQueue.global(qos: .background).async {
       
          if self.bgFacedetection[path] == nil {
            
            self.bgFacedetection[path] = UIApplication.shared.beginBackgroundTask { [weak self] in
                UIApplication.shared.endBackgroundTask((self?.bgFacedetection[path]!)!)
            }
            
            // ------------
            let uiimage = UIImage(contentsOfFile: path)
            
            print("\(self.elapsedTime()) started FC of file \(path)")
            self.updateTask(url: url, desc: "Face detection started")
            
            let detector = CIDetector(ofType: "CIDetectorTypeFace", context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
            
            let image = CIImage(image: uiimage!)
            let features = detector?.features(in: image!)
            let count = (features != nil) ? features!.count : 0
            
            print("\(self.elapsedTime()) finished FC of file \(path) detected count: \(count)")
            self.updateTask(url: url, desc: "Face detection finished, found: \(count)")
            // ------------
            
            UIApplication.shared.endBackgroundTask(self.bgFacedetection[path]!)
            self.bgFacedetection[path] = nil;
            
          }
       }
    }
    
    // Generate thumbnail and update image
    func updateImage(downloadTask: URLSessionDownloadTask, image: UIImage){
        
        DispatchQueue.global(qos: .background).async {
            let path = (downloadTask.originalRequest?.url?.absoluteString)!
            
            if self.bgThumb[path] == nil {
                
                self.bgThumb[path] = UIApplication.shared.beginBackgroundTask { [weak self] in
                    UIApplication.shared.endBackgroundTask((self?.bgThumb[path]!)!)
                }
                
                // ------------ Generate thumbnail -------
                let destinationSize = CGSize(width: 50, height: 50)
                let point = CGPoint(x: 0, y: 0)
                UIGraphicsBeginImageContext(destinationSize);
                let rect = CGRect(origin: point, size: destinationSize)
                image.draw(in: rect)
                let newImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                
                self.downloadState[path]?.image = newImage;
                
                // ------------
                
                UIApplication.shared.endBackgroundTask(self.bgThumb[path]!)
                self.bgThumb[path] = nil;
                
                DispatchQueue.main.async {
                    self.tableView.reloadData()
                }
                
            }
        }
    }
    
    // Update table row detail
    func updateTask(url: String, desc: String){
        self.downloadState[url]?.detail = desc;
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
    }
    
    // Update table row detail
    func updateTask(downloadTask: URLSessionDownloadTask, desc: String){
        self.updateTask(url: (downloadTask.originalRequest?.url?.absoluteString)!, desc: desc)
    }
    
    // Handle finish downloading
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                           didFinishDownloadingTo location: URL){
        
        print("\(elapsedTime()) finished download of file \(location)")
        self.updateTask(downloadTask: downloadTask, desc: "Downloading has finished")
        
        let docDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]

        // Generate path
        var path = docDir.appending("/").appending((downloadTask.response?.suggestedFilename)!)
        let fileManager = FileManager.default
        
        if(fileManager.fileExists(atPath: path)){
            path = docDir.appending("/").appending(String(Date().timeIntervalSince1970)).appending((downloadTask.response?.suggestedFilename)!)
        }
        
        let pathUrl = URL(fileURLWithPath:path)
        
        do {
           try fileManager.moveItem(at: location, to: pathUrl)
            
            print("\(elapsedTime()) finished copying file \(path)")
            
            let image = UIImage(contentsOfFile: path)
            
            self.updateTask(downloadTask: downloadTask, desc: "Face detection started")
            self.updateImage(downloadTask: downloadTask, image: image!)
            
            // Run or schedule face detection
            let url = (downloadTask.originalRequest?.url?.absoluteString)!
            if(UIApplication.shared.applicationState == .active){
                faceDetect(path: path, url: url)
            }
            else if(UIApplication.shared.applicationState == .background){
                print("Scheduled face detection, when app will be active again")
                self.fdQueue.append(FacedetectQueueItem(url: url, filePath: path));
            }
            else {
                print("Scheduled face detection, app in different state")
                self.fdQueue.append(FacedetectQueueItem(url: url, filePath: path));
            }
            
        }
        catch {
            let serror = error as NSError
            print("Could not save \(serror.localizedDescription)")
        }
              
    }
    
    
    public func queueCompleteHandler(id: String, cb: @escaping () -> Swift.Void){
        handlers[id] = cb;
    }
    
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("Finished events for \(session)")
        let identifier = session.configuration.identifier!
        if let handler = handlers[identifier] {
            handlers.removeValue(forKey: identifier)
            handler()
        }
    }
    
    // Run queue after app resumes
    public func handleAppActive(){
        
        DispatchQueue.main.async {
            self.tableView.reloadData();
        }
        
        print("Running FD queue \(self.fdQueue.count)")
        while self.fdQueue.count > 0 {
            let item = self.fdQueue.popLast()!
            faceDetect(path: item.filePath, url: item.url)
        }
        
    }
    
    // Handle download progress
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64){
        
        let url = downloadTask.currentRequest?.url
        let downloadRatio = Double(totalBytesWritten)/Double(totalBytesExpectedToWrite);
        self.updateTask(downloadTask: downloadTask, desc: "Downloaded \(Int(round(downloadRatio*100)))%")
        
        if downloadRatio >= 0.5 && reachedHalf[url!.absoluteString] == nil {
            reachedHalf[url!.absoluteString] = true
            print("\(elapsedTime()) donwloaded 50% \(url)")
        }
        
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
         NotificationCenter.default.addObserver(self, selector: #selector(handleAppActive), name: NSNotification.Name.UIApplicationDidBecomeActive, object: nil)
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

