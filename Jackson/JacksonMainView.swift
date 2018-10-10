//
//  JacksonMainView.swift
//  Jackson
//
//  Created by Alan Westbrook on 6/30/15.
//  Copyright (c) 2015 rockwood. All rights reserved.
//

import Cocoa

class JacksonMainView: NSView {
    
    weak var playlist: Playlist?
    
    private let filteringOptions = [NSPasteboard.ReadingOptionKey.urlReadingContentsConformToTypes:
        [kUTTypeAudio, kUTTypeFolder]
    ]
    
    private func shouldAllowDrag(_ draggingInfo: NSDraggingInfo) -> Bool {
        var canAccept = false
        if draggingInfo.draggingPasteboard.canReadObject(forClasses: [NSURL.self], options: filteringOptions) {
            canAccept = true
        }
        return canAccept
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        let allow = shouldAllowDrag(sender)
        return allow ? .copy : NSDragOperation()
    }
    
    override func performDragOperation(_ draggingInfo: NSDraggingInfo) -> Bool {
        let pasteBoard = draggingInfo.draggingPasteboard
        
        if let urls = pasteBoard.readObjects(forClasses: [NSURL.self], options: filteringOptions) as? [URL], urls.count > 0 {
            for element in urls {
                if element.hasDirectoryPath {
                    playlist?.addFrom(folder: element)
                }
                else {
                    playlist?.add(urls: [element])
                }
            }
            return true
        }
        return false
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }
}

