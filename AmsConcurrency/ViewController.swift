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
        "https://upload.wikimedia.org/wikipedia/commons/0/06/Master_of_Flémalle_-_Portrait_of_a_Fat_Man_-_Google_Art_Project_(331318).jpg",
        "https://upload.wikimedia.org/wikipedia/commons/c/ce/Petrus_Christus_-_Portrait_of_a_Young_Woman_-_Google_Art_Project.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/3/36/Quentin_Matsys_-_A_Grotesque_old_woman.jpg",
        "https://upload.wikimedia.org/wikipedia/commons/c/c8/Valmy_Battle_painting.jpg"
    ]
    var fdQueue: [String] = [];
    
    var timer: TimeInterval = 0.0;
    var entities = [URLSessionDownloadTask]()
    
    var downloadState: [String: DownloadState] = [:]
    var bgFacedetection: [String: UIBackgroundTaskIdentifier] = [:]
    
    @IBAction func onClickStart(_ sender: Any) {
        timer = Date().timeIntervalSince1970
        downloadFile(stringUrl: images[0])
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
    
    
    func downloadFile(stringUrl: String){
        
        print("\(elapsedTime()) started download of file \(stringUrl)")
        
        let url = URL(string: stringUrl)
        let request = URLRequest(url: url!)
        let config = URLSessionConfiguration.background(withIdentifier: "pic.download.\(stringUrl)")
        let session = URLSession(configuration: config, delegate: self, delegateQueue: OperationQueue.main)
        
        let task = session.downloadTask(with: request)
        task.resume()
        
        self.downloadState[stringUrl] = (DownloadState(task: task, detail: "Started downloading", image: nil))
        self.tableView.reloadData()
        
    }
    
    func elapsedTime() -> Double {
        return (round((Date().timeIntervalSince1970 - timer)*10000)/10000);
    }

    func faceDetect(path: String){
        
        print("START FACE DETECT")
        DispatchQueue.global(qos: .background).async {
        print("INSIDE FACE DETECT")
        if self.bgFacedetection[path] == nil {
            
            self.bgFacedetection[path] = UIApplication.shared.beginBackgroundTask { [weak self] in
                UIApplication.shared.endBackgroundTask((self?.bgFacedetection[path]!)!)
            }
            
            let uiimage = UIImage(contentsOfFile: path)
            
            print("\(self.elapsedTime()) started FC of file \(path)")
            
            let detector = CIDetector(ofType: "CIDetectorTypeFace", context: nil, options: [CIDetectorAccuracy: CIDetectorAccuracyHigh])
            
            let image = CIImage(image: uiimage!)
            let features = detector?.features(in: image!)
            let count = (features != nil) ? features!.count : 0
            
            print("\(self.elapsedTime()) finished FC of file \(path) detected count: \(count)")
            self.updateTask(url: path, desc: "Face detection finished, found: \(count)")
            
            UIApplication.shared.endBackgroundTask(self.bgFacedetection[path]!)
            self.bgFacedetection[path] = nil;
            
        }
       }
        print("AFTER FACE DETECT")
      
    }
    
    func updateImage(downloadTask: URLSessionDownloadTask, image: UIImage){
        DispatchQueue.main.async {
            self.downloadState[(downloadTask.originalRequest?.url?.absoluteString)!]?.image = image;
            self.tableView.reloadData()
        }
    }
    
    func updateTask(url: String, desc: String){
        DispatchQueue.main.async {
            self.downloadState[url]?.detail = desc;
            self.tableView.reloadData()
        }
        
    }
    
    func updateTask(downloadTask: URLSessionDownloadTask, desc: String){
        DispatchQueue.main.async {
            self.downloadState[(downloadTask.originalRequest?.url?.absoluteString)!]?.detail = desc;
            self.tableView.reloadData()
        }
        
    }
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                           didFinishDownloadingTo location: URL){
        
        print("\(elapsedTime()) finished download of file \(location)")
        self.updateTask(downloadTask: downloadTask, desc: "Downloading has finished")
        
        let docDir = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]

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
            
            if(UIApplication.shared.applicationState == .active){
                faceDetect(path: path)
            }
            else if(UIApplication.shared.applicationState == .background){
                print("scheduled for background")
                self.fdQueue.append(path);
            }
            
            
        }
        catch {
            let serror = error as NSError
            print("Could not save \(serror.localizedDescription)")
        }
        
        
              
    }
    
    var handlers: [String: () -> Swift.Void] = [:]
    
    public func queueCompleteHandler(id: String, cb: @escaping () -> Swift.Void){
        handlers[id] = cb;
        
    }
    public func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        print("finish events for \(session)")
        let identifier = session.configuration.identifier!
        if let handler = handlers[identifier] {
            print("FIRED HANDLER")
            handlers.removeValue(forKey: identifier)
            handler()
        }
        
        
    }
    
    public func handleAppActive(){
        print("Running FD queue")
        DispatchQueue.main.async {
            self.tableView.reloadData();
        }
        while self.fdQueue.count > 0 {
            faceDetect(path: self.fdQueue.popLast()!)
        }
        
    }
    
    var reachedHalf = [URL: Bool]()
    
    public func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64){
        
        let url = downloadTask.currentRequest?.url
        let downloadRatio = Double(totalBytesWritten)/Double(totalBytesExpectedToWrite);
        self.updateTask(downloadTask: downloadTask, desc: "Downloaded \(Int(round(downloadRatio*100)))%")
        
        if downloadRatio >= 0.5 && reachedHalf[url!] == nil {
            reachedHalf[url!] = true
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

