//
//  Playlist.swift
//  Jackson
//
//  Created by Alan Westbrook on 7/15/18.
//  Copyright © 2018 rockwood. All rights reserved.
//

import Cocoa

protocol PlaylistDelegate: class {
    func didUpdate(playlist: Playlist, position: Double)
    func didUpdate(playlist: Playlist, index: Int)
    func didUpdate(playlist: Playlist)
}

class Playlist: NSObject, NSTableViewDataSource {
    
    struct Keys {
        static let lastLoaded = "LastFolder"
        static let lastIndex = "LastIndex"
        static let lastProgress = "LastProgress"
    }

    weak var delegate: PlaylistDelegate?
    var lastIndex = 0
    var lastProgress = 0.0
    var songs: [Song] = []
    
    var index: Int = 0 {
        didSet {
            UserDefaults.standard.set(index, forKey: Keys.lastIndex)
            delegate?.didUpdate(playlist: self, index: index)
        }
    }
    
    var nextIndex: Int {
        if songs.count > index + 1 {
            return index + 1
        }
        else {
            return 0
        }
    }
    
    var position: Double = 0 {
        didSet {
            UserDefaults.standard.set(position, forKey: Keys.lastProgress)
            delegate?.didUpdate(playlist: self, position: position)
        }
    }
    
    override init() {
        super.init()
        refreshSongList()
    }
    
    func add(urls: [URL]) {
        let data = urls.map { Song(url: $0) }
        let songSet = Set(songs)
        songs = Array<Song>(songSet.union(data))
        sortSongs()
        
        delegate?.didUpdate(playlist: self)
    }
    
    func addFrom(folder url: URL) {
        loadSongsIn(folder: url)
    }
    
    func delete(at index: Int) {
        songs.remove(at: index)
        delegate?.didUpdate(playlist: self)
        
        if songs.count > 0 {
            if index == songs.count {
                self.index = index - 1
            }
            else {
                self.index = index
            }
        }
    }
    
    func refreshSongList() {
        if let lastLoaded = UserDefaults.standard.url(forKey: Keys.lastLoaded) {
            loadSongsIn(folder: lastLoaded)
        }
        
        let defaults = UserDefaults.standard
        index = defaults.integer(forKey: Keys.lastIndex)
        position = defaults.double(forKey: Keys.lastProgress)
    }

    func advance() {
        index = nextIndex
    }
    
    // MARK: - Private
    
    private func loadSongsIn(folder url: URL) {
        guard let urls = FileManager.default.suburls(at: url) else { return }
        
        UserDefaults.standard.set(url, forKey: Keys.lastLoaded)
        let supported = ["m4a", "mp3", "aac", "flac"]
        let songURLs = urls.compactMap { url -> URL? in
            return supported.contains(url.pathExtension.lowercased()) ? url : nil
        }
        
        add(urls: songURLs)
    }
    
    private func sortSongs() {
        songs.sort { (lhs, rhs) -> Bool in
            return lhs < rhs
        }
    }
    
    // MARK: - TableView Datasource
    
    @objc func numberOfRows(in tableView: NSTableView) -> Int {
        return songs.count
    }

}
