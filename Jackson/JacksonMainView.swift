//
//  JacksonMainView.swift
//  Jackson
//
//  Created by Alan Westbrook on 6/30/15.
//  Copyright (c) 2015 rockwood. All rights reserved.
//

import Cocoa

protocol SongDelegate {
    func add(songURLs :[URL])
}

class JacksonMainView: NSView {

    struct Keys {
        static let lastLoaded = "lastFolder"
    }
    
    var songDelegate: SongDelegate? {
        didSet {
            if let lastLoaded = UserDefaults.standard.url(forKey: Keys.lastLoaded) {
                loadSongsInFolder(with: lastLoaded)
            }
        }
    }

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
                loadSongsInFolder(with: dirURL);
            }
        }
        
        return true
    }
    
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
        return true
    }
    
    private func loadSongsInFolder(with url: URL) {
        guard let urls = FileManager.default.suburls(at: url) else { return }

        UserDefaults.standard.set(url, forKey: Keys.lastLoaded)
        let supported = ["m4a", "mp3", "aac", "flac"]
        let songURLs = urls.compactMap { url -> URL? in
            return supported.contains(url.pathExtension.lowercased()) ? url : nil
        }
        
        songDelegate?.add(songURLs: songURLs)
    }

}


extension FileManager {
    
    func suburls(at url: URL) -> [URL]? {
        
        let urls =
        enumerator(atPath: url.path)?.compactMap { e -> URL? in
            
            guard let s = e as? String else { return nil }
            let relativeURL = URL(fileURLWithPath: s, relativeTo: url)
            return relativeURL.absoluteURL
        }
        
        return urls
    }
}
