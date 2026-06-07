import Foundation
import AVFoundation

class AudioPlayer: NSObject, AVAudioPlayerDelegate {
    static let shared = AudioPlayer()
    private var player: AVAudioPlayer?
    private var currentPriority: Int = 0
    
    private override init() {
        super.init()
    }
    
    func playSound(resource: String, priority: Int) {
        let filename = (resource as NSString).deletingPathExtension
        let ext = (resource as NSString).pathExtension
        
        guard let url = Bundle.main.url(forResource: filename, withExtension: ext) else {
            print("Sound file \(resource) not found in bundle resources.")
            return
        }
        
        if player?.isPlaying == true && priority <= currentPriority {
            return
        }
        
        stop()
        
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.duckOthers])
            try AVAudioSession.sharedInstance().setActive(true)
            
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            currentPriority = priority
            player?.play()
            print("Playing sound: \(resource) with priority \(priority)")
        } catch {
            print("Failed to play sound: \(error.localizedDescription)")
        }
    }
    
    func stop() {
        player?.stop()
        player = nil
        currentPriority = 0
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        self.player = nil
        self.currentPriority = 0
    }
}
