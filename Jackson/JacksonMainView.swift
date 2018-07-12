//
//  JacksonMainView.swift
//  Jackson
//
//  Created by Alan Westbrook on 6/30/15.
//  Copyright (c) 2015 rockwood. All rights reserved.
//

import Cocoa

protocol SongDelegate {
    func add(urls :[URL])
    func addFrom(folder url: URL)
}

class JacksonMainView: NSView {
    
    var songDelegate: SongDelegate?

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let pboard = sender.draggingPasteboard
        
        // What a shit-show of an API
        
        // Do you have an url? thanks I'll convert the string you return for it, as I have to as it's a reference string to a file resource URI
        if let item = pboard.propertyList(forType: .fileURL) as? String,
            let url = URL(string: item) {
            do {
                // Sure, throw an undocumented exception
                if try url.checkResourceIsReachable() {
                    
                    // give us all your values that really is a single value type, and throw another undocumented exception while you are at it
                    let values = try url.resourceValues(forKeys: [.isDirectoryKey])
                    
                    // Sure, it's an optional bool.
                    if let isDirectory = values.isDirectory,
                        isDirectory {
                        return .copy
                    }
                }
            } catch {
                // nothing
            }
        }
        
        return []
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        
        let pboard = sender.draggingPasteboard
        
        guard let items = pboard.pasteboardItems else { return false }

        for item in items {
            if let element = item.string(forType: .fileURL),
                let dirURL = URL(string: element) {
                songDelegate?.addFrom(folder: dirURL)
            }
        }
        
        return true
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }
}

