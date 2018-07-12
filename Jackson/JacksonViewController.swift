//
//  JacksonViewController.swift
//  Jackson
//
//  Created by Alan Westbrook on 6/30/15.
//  Copyright (c) 2015 rockwood. All rights reserved.
//

import Cocoa
import AVFoundation
import AudioToolbox

// MARK: Model Item
struct SongData : CustomStringConvertible, Comparable, Hashable {
    var url:URL
    var track:Int?
    var album:String?
    
    var description:String {
        get {
            let trackStr = track == nil ? "no track data"
                : String(describing: track)
            
            return "\(url.lastPathComponent) / \(trackStr) / \(album ?? "no album data")"
        }
    }

    var hashValue: Int {
        get {
            return pPath.hashValue
        }
    }

    init(url: URL) {
        self.url = url
        
        var fileID:AudioFileID? = nil
        //let url = NSURL(fileURLWithPath: path) as CFURL
        AudioFileOpenURL(url as CFURL, .readPermission, AudioFileTypeID(0), &fileID)
        
        if fileID != nil {
            var dict:CFDictionary = [:] as CFDictionary
            var piDataSize:UInt32 = UInt32(MemoryLayout<CFDictionary.Type>.size)
            
            //  Populates a CFDictionary with the ID3 tag properties
            _ = AudioFileGetProperty(fileID!, AudioFilePropertyID(kAudioFilePropertyInfoDictionary), &piDataSize, &dict)
            
            let info = dict as! Dictionary<String, String>

            if let trackFuckery = info[kAFInfoDictionary_TrackNumber] {
                let trackInfo = trackFuckery.components(separatedBy: "/")
                track = Int(trackInfo[0])
            }
            
            album = info[kAFInfoDictionary_Album]
        }
    }
}

func ==(lhs:SongData, rhs:SongData) -> Bool {
    return lhs.url == rhs.url &&
        lhs.track == rhs.track &&
        lhs.album == lhs.album
}

func tagSorting(_ lhs: SongData, _ rhs: SongData) -> Bool? {
    if let aLeft = lhs.album {
        if let aRight = rhs.album {
            if let tLeft = lhs.track {
                if let tRight = rhs.track {
                    if aRight == aLeft {
                        return tLeft < tRight
                    }
                    else {
                        return aLeft < aRight
                    }
                }
            }
            else if rhs.track != nil {
                return false
            }
            else {
                return aLeft < aRight
            }
        }
    }
    else if rhs.album != nil {
        return false
    }

    return nil
}

func <(lhs:SongData, rhs:SongData) -> Bool {
    if JacksonViewController.hasTagOrganization {
        if let sortOrder = tagSorting(lhs, rhs) {
            return sortOrder
        }
    }
    
    return lhs.url.lastPathComponent < rhs.url.lastPathComponent
}

// MARK: -
// MARK: - View Controller

class JacksonViewController: NSViewController, SongDelegate,
    NSTableViewDataSource, NSTableViewDelegate, AVAudioPlayerDelegate {
    
    
    struct Keys {
        static let lastLoaded = "lastFolder"
    }

    static let hasTagOrganization = false
    
    @IBOutlet var tableView:NSTableView!
    @IBOutlet var playPause:NSButton!
    @IBOutlet var progressBar:NSSlider!
    @IBOutlet var totalTime:NSTextField!
    @IBOutlet var currentTime:NSTextField!
    @IBOutlet var playMenuItem:NSMenuItem!
    
    var mainView: JacksonMainView {
        get {
            return view as! JacksonMainView
        }
    }
    
    private var player:AVAudioPlayer? { 
        didSet {
            if let player = player {
                totalTime.stringValue = timeFormatter.string(from: player.duration)!
                currentTime.stringValue = timeFormatter.string(from: player.currentTime)!
                progressBar.isEnabled = true
                progressBar.maxValue = player.duration
                progressBar.doubleValue = 0
                
                if nil == updatePoller {
                    updatePoller = Timer.scheduledTimer(timeInterval: 1.0 / 20.0, target: self, selector: #selector(JacksonViewController.updateDisplay), userInfo: nil, repeats: true)
                }
            }
        }
    }
    
    private var nextPlayer:AVAudioPlayer?
    private var songs:[SongData] = []
    private var updatePoller:Timer?
    private var playing = false
    
    private lazy var timeFormatter:DateComponentsFormatter = {
        var formatter = DateComponentsFormatter()
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        formatter.allowedUnits = [.minute, .second]
        return formatter
    }()
    
    private var songIndex = 0 {
        didSet {
            tableView.selectRowIndexes(NSIndexSet(index: songIndex) as IndexSet, byExtendingSelection: false)
            tableView.scrollRowToVisible(songIndex)
        }
    }
    
    // MARK: - Overrides
    override var acceptsFirstResponder:Bool { get { return true } }
    
    override func keyUp(with theEvent: NSEvent) {
        if theEvent.keyCode == 49 {
            togglePlayPause()
        }
        else {
            super.keyUp(with: theEvent)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mainView.registerForDraggedTypes([.fileURL])
        mainView.songDelegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(tableSelectionChanged(note:)), name: NSTableView.selectionDidChangeNotification, object: tableView)
        totalTime.stringValue = ""
        currentTime.stringValue = ""
        progressBar.doubleValue = 0
        progressBar.maxValue = 0
        progressBar.isEnabled = false
        
        refreshSongList()
        tableView.becomeFirstResponder()
    }

    func deleteBackward(sender: AnyObject?) {
        deleteSelectedSong()
    }
    
    // MARK: - Song Delegate 
    
    func add(urls: [URL]) {
        let data = urls.map { SongData(url: $0) }
        let songSet = Set(songs)
        songs = Array<SongData>(songSet.union(data))
        sortSongs()
        
        tableView.reloadData()
        startPlayer()
    }
    
    func addFrom(folder url: URL) {
        loadSongsIn(folder: url)
    }
    
    // MARK: - TableViewness
    
    @objc func numberOfRows(in tableView: NSTableView) -> Int {
        return songs.count
    }

    @objc func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {

        var field:NSTextField? = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: "rowView"), owner: self) as? NSTextField
        
        if nil == field {
            field = NSTextField(frame: NSZeroRect)
            field?.isBordered = false
            field?.identifier = NSUserInterfaceItemIdentifier(rawValue: "rowView")
            field?.isEditable = false
        }
        
        field?.stringValue = songs[row].url.deletingPathExtension().lastPathComponent
        
        return field
    }
    
    
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        return true
    }
    
    func tableView(tableView:NSTableView, rowSelected:Int) {
        
    }
    
    @objc func tableSelectionChanged(note: NSNotification) {
        let index = tableView.selectedRow

        if index == -1 {
            // empty space clicked.
            return
        }

        if index != songIndex {
            nextPlayer = avPlayerForSongIndex(index: index)
            // Bit of a hack, advance updates the index, so we have to pretend we were on the previous one.
            songIndex = index - 1
            
            advanceToNextSong()
        }
    }
    
    // MARK: - Actions
    
    @IBAction func showInFinderMenuInvoked(sender: NSMenuItem) {
        showCurrentSongInFinder()
    }
    
    @IBAction func playMenuInvoked(sender: NSMenuItem) {
        togglePlayPause()
    }

    @IBAction func playPauseClicked(button:NSButton) {
        togglePlayPause()
    }

    @IBAction func sliderClicked(sender: NSSlider) {
        currentTime.stringValue = timeFormatter.string(from: sender.doubleValue)!
        player?.currentTime = sender.doubleValue
    }
    
    @IBAction func refreshMenuInvoked(sender: NSMenuItem) {
        refreshSongList()
    }
    
    // MARK: - AVAudioPlayer
    
    private func startPlayer() {
        if nil == player && songs.count > 0 {
            
            var index = 0
            while player == nil && index < songs.count {
                player = avPlayerForSongIndex(index: songIndex)
                index += 1
            }
            
            player?.play()
            updatePlayPause()

            if songs.count > index {
                nextPlayer = avPlayerForSongIndex(index: index)
            }
            
            songIndex = 0
        }
    }
    
    func avPlayerForSongIndex(index: Int) -> AVAudioPlayer? {
        
        guard let result = try? AVAudioPlayer(contentsOf: songs[index].url) else {
            return nil
        }
        
        result.delegate = self
        result.prepareToPlay()
        
        return result
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        advanceToNextSong()
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

    private func refreshSongList() {
        if let lastLoaded = UserDefaults.standard.url(forKey: Keys.lastLoaded) {
            loadSongsIn(folder: lastLoaded)
        }
    }
    
    private func sortSongs() {
        songs.sort { (lhs, rhs) -> Bool in
            return lhs < rhs
        }
    }
    
    private func advanceToNextSong() {
        songIndex += 1

        player = nextPlayer
        
        if playing {
            player?.play()
        }
        
        if songIndex == songs.count {
            songIndex = 0
        }
        
        var nextIndex = songIndex + 1
        if nextIndex == songs.count {
            nextIndex = 0
        }
        
        if songs.count > 0 {
            nextPlayer = avPlayerForSongIndex(index: nextIndex)
        }
        else {
            nextPlayer = nil
            player = nil
        }
    }
    
    private func updatePlayPause() {
        if let player = player {
            var title = NSLocalizedString("Play", comment: "play button title")
            if player.isPlaying {
                title = NSLocalizedString("Pause", comment: "pause button title")
            }
            
            playPause.title = title
            playMenuItem.title = title
            playing = player.isPlaying
        }
    }
    
    private func deleteSelectedSong() {
        if tableView.selectedRow != -1 {
            songs.remove(at: tableView.selectedRow)
            songIndex -= 1
            tableView.reloadData()
            advanceToNextSong()
        }
    }
    
    @objc private func updateDisplay() {
        if let player = player {
            currentTime.stringValue = timeFormatter.string(from: player.currentTime)!
            progressBar.doubleValue = player.currentTime
        }
    }
    
    private func togglePlayPause() {
        if let player = player {
            if player.isPlaying {
                player.pause()
            }
            else {
                player.play()
            }
            
            playing = player.isPlaying
        }
        updatePlayPause()        
    }
    
    private func showCurrentSongInFinder() {
        if songs.count < 1 { return }

        let item = songs[songIndex]
        guard let path = item.url.absoluteString.removingPercentEncoding,
            let lastSlashIndex = path.lastIndex(of: "/")else {
            print("bad path")
            return
        }
        
        let root = String(path.prefix(through: lastSlashIndex))
        
        NSWorkspace.shared.openFile(root)
        if false == NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: root) {
            print("unable to select \(path), for some unknown reason, thanks Apple")
        }
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
