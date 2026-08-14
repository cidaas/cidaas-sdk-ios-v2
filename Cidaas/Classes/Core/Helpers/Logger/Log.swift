//
//  Log.swift
//  sdkiOS
//
//  Created by ganesh on 25/07/18.
//  Copyright © 2018 Cidaas. All rights reserved.
//

import Foundation

open class Log {
    
    ///The max size a log file can be in Kilobytes. Default is 1024 (1 MB)
    open var maxFileSize: UInt64 = 1024
    
    ///The max number of log file that will be stored. Once this point is reached, the oldest file is deleted.
    open var maxFileCount = 20
    
    ///The directory in which the log files will be writt en
    open var directory = Log.defaultDirectory()
    
    //The name of the log files.
    open var name = "cidaassdkerrorlog"
    
    ///logging singleton
    open class var logger: Log {
        
        struct Static {
            static let instance: Log = Log()
        }
        return Static.instance
    }
    
    //the date formatter
    var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .medium
        return formatter
    }
    
    ///write content to the current log file.
    open func write(_ text: String,cname:String? = nil) {
        
        var filename = name
        
        if let cname = cname
        {
            filename = cname
        }
        
        let path = "\(directory)/\(logName(0,cname: filename))"
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: path) {
            do {
                try "".write(toFile: path, atomically: true, encoding: String.Encoding.utf8)
            } catch _ {
            }
        }
        if let fileHandle = FileHandle(forWritingAtPath: path) {
            let dateStr = dateFormatter.string(from: Date())
            let writeText = "[\(dateStr)]: \(text)\n"
            fileHandle.seekToEndOfFile()
            fileHandle.write(writeText.data(using: String.Encoding.utf8)!)
            fileHandle.closeFile()
            //print(writeText, terminator: "")
            cleanup(cname)
        }
    }
    ///do the checks and cleanup
    func cleanup(_ cname:String? = nil) {
        var filename = name
        
        if let cname = cname
        {
            filename = cname
        }
        
        let path = "\(directory)/\(logName(0,cname: filename))"
        let size = fileSize(path)
        let maxSize: UInt64 = maxFileSize*1024
        if size > 0 && size >= maxSize && maxSize > 0  {
            rename(0)
        }
        
        if maxFileCount > 0
        {
            //delete the oldest file
            
            let filemanager:FileManager = FileManager()
            let files = filemanager.enumerator(atPath: directory)
            
            var fileNames : [String] = []
            
            while let file = files?.nextObject() {
                //print(file)
                let _filename = (file as! String)
                if _filename.hasPrefix(filename)
                {
                    fileNames.append(_filename)
                }
            }
            
            if fileNames.count > maxFileCount
            {
                for n in fileNames
                {
                    let deletePath = "\(directory)/\(n)"
                    let fileManager = FileManager.default
                    do {
                        try fileManager.removeItem(atPath: deletePath)
                    } catch _ {
                    }
                }
            }
        }
    }
    
    ///check the size of a file
    func fileSize(_ path: String) -> UInt64 {
        let fileManager = FileManager.default
        let attrs: NSDictionary? = try! fileManager.attributesOfItem(atPath: path) as NSDictionary?
        if let dict = attrs {
            return dict.fileSize()
        }
        return 0
    }
    
    ///Recursive method call to rename log files
    func rename(_ index: Int) {
        let fileManager = FileManager.default
        let path = "\(directory)/\(logName(index))"
        let newPath = "\(directory)/\(logName(index+1))"
        if fileManager.fileExists(atPath: newPath) {
            rename(index+1)
        }
        do {
            try fileManager.moveItem(atPath: path, toPath: newPath)
        } catch _ {
        }
    }
    
    ///gets the log name
    func logName(_ num :Int,cname:String? = nil) -> String {
        var filename = name
        
        if let cname = cname
        {
            filename = cname
        }
        return "\(filename)-\(num).log"
    }
    
    ///get the default log directory
    class func defaultDirectory() -> String {
        var path = ""
        let fileManager = FileManager.default
        #if os(iOS)
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        path = "\(paths[0])/Logs"
        #elseif os(OSX)
        let urls = fileManager.URLsForDirectory(.LibraryDirectory, inDomains: .UserDomainMask)
        if let url = urls.last {
            if let p = url.path {
                path = "\(p)/Logs"
            }
        }
        #endif
        if !fileManager.fileExists(atPath: path) && path != ""  {
            do {
                try fileManager.createDirectory(atPath: path, withIntermediateDirectories: false, attributes: nil)
            } catch _ {
            }
        }
        return path
    }
    
}

///a free function to make writing to the log much nicer
public func logw(_ text: String,cname:String?=nil) {
    guard DBHelper.shared.getEnableLog() == true else { return }
    print(text)
    Log.logger.write(text,cname: cname)
}
