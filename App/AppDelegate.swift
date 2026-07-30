//
//  AppDelegate.swift
//  BeerStats
//
//  Klassischer UIApplicationDelegate, ausschließlich für Aufgaben, die es
//  (noch) nicht als sauberes SwiftUI-Äquivalent gibt: Firebase-Konfiguration
//  und Push-Notification-Registrierung.
//
//  Bewusst schlank gehalten: Der AppDelegate enthält keine Business-Logik,
//  sondern delegiert sofort an die zuständigen Services.
//

import UIKit
import FirebaseCore
import FirebaseMessaging
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate {

func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Bereits in BeerStatsApp.init() konfiguriert (siehe dortiger Kommentar
        // zur Startreihenfolge) – hier nur zur Absicherung, falls dieser
        // AppDelegate-Callback doch vor dem App-Init ausgeführt wird.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            AppLogger.app.info("Firebase erfolgreich initialisiert")
        }

        configurePushNotifications(application)

        return true
    }
    // MARK: - Push Notifications

    private func configurePushNotifications(_ application: UIApplication) {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        Task {
            do {
                let granted = try await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .badge, .sound])
                AppLogger.app.info("Push-Berechtigung erteilt: \(granted)")
                if granted {
                    await MainActor.run {
                        application.registerForRemoteNotifications()
                    }
                }
            } catch {
                AppLogger.app.error("Push-Berechtigung fehlgeschlagen: \(error.localizedDescription)")
            }
        }
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }
}

// MARK: - MessagingDelegate

extension AppDelegate: MessagingDelegate {

    /// Wird aufgerufen, sobald Firebase Cloud Messaging ein (neues) Token vergibt.
    /// Das Token wird an den PushNotificationService weitergereicht, der es
    /// im User-Dokument persistiert – nicht hier direkt, um die Trennung
    /// von UIKit-Lifecycle und Firestore-Zugriff zu wahren.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        AppLogger.app.debug("FCM-Token erhalten")
        NotificationCenter.default.post(
            name: .fcmTokenReceived,
            object: nil,
            userInfo: ["token": fcmToken]
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {

    /// Zeigt Push-Benachrichtigungen auch dann an, wenn die App im Vordergrund ist
    /// (z. B. "Dein Freund hat dich zu einem Spiel eingeladen").
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .badge, .sound]
    }
}

extension Notification.Name {
    static let fcmTokenReceived = Notification.Name("fcmTokenReceived")
}
