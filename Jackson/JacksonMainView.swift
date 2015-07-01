//
//  JacksonMainView.swift
//  Jackson
//
//  Created by Alan Westbrook on 6/30/15.
//  Copyright (c) 2015 rockwood. All rights reserved.
//

import Cocoa

protocol SongUpdateDelegate {
    func songsUpdated()
}

class JacksonMainView: NSView {

    var songDelegate:SongUpdateDelegate?
    var songPaths:[String] = []
    override func drawRect(dirtyRect: NSRect) {
        super.drawRect(dirtyRect)

        // Drawing code here.
    }
    
    override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
        let pboard = sender.draggingPasteboard()
        
        for path in pboard.propertyListForType(NSFilenamesPboardType) as! NSArray {
            let pathStr = path as! String
            
            var isDir:ObjCBool = false
            if NSFileManager.defaultManager().fileExistsAtPath(pathStr, isDirectory: &isDir) {
                if isDir.boolValue == true {
                    return NSDragOperation.Copy
                }
            }
        }
        
        return NSDragOperation.None
    }
    
    override func performDragOperation(sender: NSDraggingInfo) -> Bool {
        
        let pboard = sender.draggingPasteboard()
        
        for path in pboard.propertyListForType(NSFilenamesPboardType) as! NSArray {
            let pathStr = path as! String
            
            if let paths = NSFileManager.defaultManager().subpathsOfDirectoryAtPath(pathStr, error: nil) as? [String] {
                for path in paths {
                    let ext = path.pathExtension.lowercaseString
                    if ext == "m4a" || ext == "mp3" {
                        songPaths.append(pathStr.stringByAppendingPathComponent(path))
                    }
                }
            }
        }
        
        songDelegate?.songsUpdated()
        return true
    }
    
    override func prepareForDragOperation(sender: NSDraggingInfo) -> Bool {
        return true
    }
    
    override func viewWillMoveToWindow(newWindow: NSWindow?) {
        registerForDraggedTypes([NSFilenamesPboardType])
    }
}
