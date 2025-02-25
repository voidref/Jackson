//
//  Playlist.swift
//  Jackson
//
//  Created by Alan Westbrook on 7/15/18.
//  Copyright © 2018 rockwood. All rights reserved.
//

import Cocoa

protocol PlaylistDelegate: AnyObject {
    func didUpdate(playlist: Playlist, position: Double)
    func didUpdate(playlist: Playlist, index: Int)
    func didUpdate(playlist: Playlist)
}

class Playlist: NSObject, NSTableViewDataSource {
    
    struct Keys {
        static let lastLoaded = "LastFolder" // Remove inna while.
        static let currentPlaylist = "Current"
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
        loadSongs()
    }
    
    func add(urls: [URL]) {
        let data = urls.map { Song(url: $0) }
        let songSet = Set(songs)
        songs = Array<Song>(songSet.union(data))
        sortSongs()
        
        songsUpdated()
    }
    
    func addFrom(folder url: URL) {
        loadSongsIn(folder: url)
    }
    
    func delete(at index: Int) {
        songs.remove(at: index)
        songsUpdated()
        
        if songs.count > 0 {
            if index == songs.count {
                self.index = index - 1
            }
            else {
                self.index = index
            }
        }
    }
    
    func deleteAll() {
        songs.removeAll()
        songsUpdated()
        self.index = 0
    }
    
    func loadSongs() {
        
        let defaults = UserDefaults.standard

        // Tech debt, remove this when our userbase has pretty much all
        // updated to the new version
        if let lastLoaded = defaults.url(forKey: Keys.lastLoaded) {
            loadSongsIn(folder: lastLoaded)
            defaults.removeObject(forKey: Keys.lastLoaded)
        }
        else {
            loadPlaylist()
        }

        index = defaults.integer(forKey: Keys.lastIndex)
        position = defaults.double(forKey: Keys.lastProgress)
    }

    func advance() {
        index = nextIndex
    }
    
    // MARK: - Private
    
    private func loadSongsIn(folder url: URL) {
        guard let urls = FileManager.default.suburls(at: url) else { return }
        
        let supported = ["m4a", "mp3", "aac", "flac", "wav"]
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
    
    private func songsUpdated() {
        delegate?.didUpdate(playlist: self)
        savePlaylist()
    }
    
    private func loadPlaylist() {
        let decoder = JSONDecoder()
        let defaults = UserDefaults.standard
        if let songsData = defaults.object(forKey: Keys.currentPlaylist) as? Data,
            let songsActual = try? decoder.decode([Song].self, from: songsData) {
            songs = songsActual
        }
    }
    
    private func savePlaylist() {
        let encoder = JSONEncoder()
        if let coded = try? encoder.encode(songs) {
            UserDefaults.standard.set(coded, forKey: Keys.currentPlaylist)
        }

        // Remove as above when we don't think anyone will have the 'old' version of the app.
         UserDefaults.standard.removeObject(forKey: Keys.lastLoaded)
    }

    // MARK: - TableView Datasource
    
    @objc func numberOfRows(in tableView: NSTableView) -> Int {
        return songs.count
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
