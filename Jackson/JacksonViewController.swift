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
            return "\(url.lastPathComponent) / \(String(describing: track)) / \(String(describing: album))"
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

func <(lhs:SongData, rhs:SongData) -> Bool {
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
        
    return lhs.url.absoluteString < rhs.url.absoluteString
}

// MARK: -
// MARK: - View Controller

class JacksonViewController: NSViewController, SongDelegate, NSTableViewDataSource, NSTableViewDelegate, AVAudioPlayerDelegate {
    

    @IBOutlet var tableView:NSTableView!
    @IBOutlet var playPause:NSButton!
    @IBOutlet var progressBar:NSSlider!
    @IBOutlet var totalTime:NSTextField!
    @IBOutlet var currentTime:NSTextField!
    @IBOutlet var playMenuItem:NSMenuItem!
    
    var mainView:JacksonMainView {
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
        // Do view setup here.
        
        mainView.registerForDraggedTypes([.fileURL])
        mainView.songDelegate = self
        
        NotificationCenter.default.addObserver(self, selector: #selector(tableSelectionChanged(note:)), name: NSTableView.selectionDidChangeNotification, object: tableView)
        totalTime.stringValue = ""
        currentTime.stringValue = ""
        progressBar.doubleValue = 0
        progressBar.maxValue = 0
        progressBar.isEnabled = false
    }

    func deleteBackward(sender: AnyObject?) {
        deleteSelectedSong()
    }
    
    // MARK: - Song Delegate 
    
    func add(songURLs: [URL]) {
        let data = songURLs.map { SongData(url: $0) }
        let songSet = Set(songs)
        songs = Array<SongData>(songSet.union(data))
        sortSongs()
        
        tableView.reloadData()
        startPlayer()
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
        var result:AVAudioPlayer?
        do {
            result = try AVAudioPlayer(contentsOf: songs[index].url)
        } catch {
            result = nil
        }
        
        result?.delegate = self
        result?.prepareToPlay()
        
        return result
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        advanceToNextSong()
    }
    
    // MARK: - Private
    
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
