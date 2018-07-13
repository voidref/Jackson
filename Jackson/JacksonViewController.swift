//
//  JacksonViewController.swift
//  Jackson
//
//  Created by Alan Westbrook on 6/30/15.
//  Copyright (c) 2015 rockwood. All rights reserved.
//

import Cocoa
import AVFoundation


// MARK: -
// MARK: - View Controller

class JacksonViewController: NSViewController, SongDelegate,
    NSTableViewDataSource, NSTableViewDelegate, AVAudioPlayerDelegate {
    
    struct Keys {
        static let lastLoaded = "LastFolder"
        static let lastIndex = "LastIndex"
        static let lastProgress = "LastProgress"
        static let volume = "Volume"
    }

    static let hasTagOrganization = false
    
    @IBOutlet var tableView: NSTableView!
    @IBOutlet var playPause: NSButton!
    @IBOutlet var progressBar: NSSlider!
    @IBOutlet var totalTime: NSTextField!
    @IBOutlet var currentTime: NSTextField!
    @IBOutlet var playMenuItem: NSMenuItem!
    @IBOutlet var volumeMenuItem: NSMenuItem!

    
    var mainView: JacksonMainView {
        get {
            return view as! JacksonMainView
        }
    }
    
    private var player: AVAudioPlayer? {
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
    
    private var nextPlayer: AVAudioPlayer?
    private var songs: [Song] = []
    private var updatePoller: Timer?
    private var playing = false
    
    private lazy var timeFormatter: DateComponentsFormatter = {
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
            
            UserDefaults.standard.set(songIndex, forKey: Keys.lastIndex)
        }
    }
    
    private var volume: Float = 0.5 {
        didSet {
            UserDefaults.standard.set(volume, forKey: Keys.volume)
            
            player?.setVolume(volume, fadeDuration: 0.1)
            volumeMenuItem.title = "\(Int(volume * 100))%"
        }
    }
    
    private var position: Double = 0 {
        didSet {
            UserDefaults.standard.set(position, forKey: Keys.lastProgress)
            
            progressBar.doubleValue = position
            if let stringTime = timeFormatter.string(from: position) {
                currentTime.stringValue = stringTime
            }
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
        
        let defaults = UserDefaults.standard
        
        volume = defaults.float(forKey: Keys.volume)
        if volume <= 0 { volume = 0.5 }
        
        refreshSongList()
        tableView.becomeFirstResponder()

        songIndex = defaults.integer(forKey: Keys.lastIndex)
        position = defaults.double(forKey: Keys.lastProgress)
        
        startPlayer()
    }

    // MARK: - Song Delegate
    
    func add(urls: [URL]) {
        let data = urls.map { Song(url: $0) }
        let songSet = Set(songs)
        songs = Array<Song>(songSet.union(data))
        sortSongs()
        
        tableView.reloadData()
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
        player?.currentTime = sender.doubleValue
    }
    
    @IBAction func refreshMenuInvoked(sender: NSMenuItem) {
        refreshSongList()
    }
    
    @IBAction func deleteBackward(sender: AnyObject?) {
        deleteSelectedSong()
    }
    
    @IBAction func volumeDown(sender: AnyObject?) {
        reduceVolume()
    }
    
    @IBAction func volumeUp(sender: AnyObject?) {
        increaseVolume()
    }

    // MARK: - AVAudioPlayer
    
    private func startPlayer() {
        if nil == player && songs.count > 0 {
            
            // We ensure that we start with a song we can play.
            var index = songIndex
            while player == nil && index < songs.count {
                player = avPlayerForSongIndex(index: songIndex)
                index += 1
            }
            
            if index - 1 != songIndex {
                songIndex = index - 1
            }
            
            if position > 0 {
                player?.currentTime = position
            }
            
            player?.play()
            updatePlayPause()

            if songs.count > index {
                nextPlayer = avPlayerForSongIndex(index: index)
            }
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
            position = player.currentTime
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
    
    private func reduceVolume() {
        
        if volume == 0 { return }
        
        var value = Int(volume * 100.0)
        
        // Yes, I am a bit nuts
        
        if value > 90 {
            value -= 1
        }
        else if value > 11 {
            value -= 10
        }
        else if value > 1 {
            value -= 1
        }
        
        volume = Float(value) / 100
    }
    
    private func increaseVolume() {
        
        if volume == 1 { return }
        
        var value = Int(volume * 100.0)

        // still crazy
        if value < 10 {
            value += 1
        }
        else if value < 90 {
            value += 10
        }
        else if value < 100 {
            value += 1
        }
        
        volume = Float(value) / 100
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
