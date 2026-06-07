import Foundation
import UserNotifications

class LocalNotificationManager {
    static let shared = LocalNotificationManager()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
    }
    
    func showDestinationReached(message: String, customSoundName: String? = nil) {
        guard DestinationStore.shared.isArrivalNotificationEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification_title", comment: "")
        content.body = message
        content.sound = customSoundName.map { UNNotificationSound(named: UNNotificationSoundName($0)) } ?? .default
        
        let request = UNNotificationRequest(
            identifier: "arrival_notification",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func showApproachProgress(remainingMeters: Double, progressPercent: Int) {
        guard DestinationStore.shared.isLiveUpdateEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = NSLocalizedString("notification_live_title", comment: "")
        
        let distanceStr = GeoUtils.shared.formatDistance(remainingMeters)
        content.body = String(format: NSLocalizedString("notification_live_body", comment: ""), distanceStr)
        content.subtitle = String(format: NSLocalizedString("notification_live_summary", comment: ""), progressPercent)
        content.sound = nil
        
        let request = UNNotificationRequest(
            identifier: "approach_progress",
            content: content,
            trigger: nil
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func cancelApproachProgress() {
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: ["approach_progress"])
    }
}
