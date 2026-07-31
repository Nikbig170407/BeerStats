//
//  AppError.swift
//  BeerStats
//
//  Einheitliches Fehlermodell für die gesamte App. Ziel: ViewModels und Views
//  arbeiten nie direkt mit Firebase-spezifischen NSError-Objekten, sondern
//  immer mit diesem domänenspezifischen, benutzerfreundlichen Fehlertyp.
//  Das hält Firebase-Details aus der UI-Schicht heraus und macht Fehler-UI
//  konsistent und lokalisierbar.
//

import Foundation

enum AppError: LocalizedError, Equatable {

    case network
    case notAuthenticated
    case permissionDenied
    case notFound(String)
    case validation(String)
    /// Das Firebase-Projekt ist nicht vollständig eingerichtet – ein Fehler,
    /// den der Nutzer nur in der Konsole beheben kann, nicht in der App.
    case configuration(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .network:
            return "Keine Internetverbindung. Bitte überprüfe dein Netzwerk."
        case .notAuthenticated:
            return "Du bist nicht angemeldet. Bitte melde dich erneut an."
        case .permissionDenied:
            return "Du hast keine Berechtigung für diese Aktion."
        case .notFound(let entity):
            return "\(entity) wurde nicht gefunden."
        case .validation(let message):
            return message
        case .configuration(let message):
            return message
        case .unknown(let message):
            return "Etwas ist schiefgelaufen: \(message)"
        }
    }

    /// Wandelt beliebige Fehler (z. B. von Firebase) in ein AppError um.
    /// Zentrale Stelle, an der wir Firebase-spezifische Fehlercodes auf
    /// unser eigenes, UI-taugliches Fehlermodell mappen.
    static func from(_ error: Error) -> AppError {
        let nsError = error as NSError

        switch nsError.domain {
        case "FIRAuthErrorDomain":
            return fromAuth(nsError)
        case "FIRFirestoreErrorDomain":
            switch nsError.code {
            case 7: // permission-denied
                return .permissionDenied
            case 5: // not-found
                return .notFound("Dokument")
            case 14: // unavailable
                return .network
            default:
                return .unknown(nsError.localizedDescription)
            }
        case NSURLErrorDomain:
            return .network
        default:
            return .unknown(nsError.localizedDescription)
        }
    }

    // MARK: - Firebase Authentication

    /// Firebase Auth meldet Einrichtungsprobleme als generischen
    /// „internal error" und versteckt die eigentliche Ursache in einem
    /// verschachtelten Fehler. Ohne dieses Auspacken bleibt für den Nutzer
    /// nur der nutzlose Satz „print and inspect the error details".
    private static func fromAuth(_ nsError: NSError) -> AppError {
        let detail = underlyingDetail(nsError)

        // Kommt, wenn Authentication im Firebase-Projekt nie aktiviert wurde.
        if let detail, detail.contains("CONFIGURATION_NOT_FOUND") {
            return .configuration(
                "Anmeldung ist im Firebase-Projekt noch nicht eingerichtet. "
                + "In der Firebase Console unter Authentication einmal „Get started" "
                + "ausführen und E-Mail/Passwort aktivieren."
            )
        }

        switch nsError.code {
        case 17020: // networkError
            return .network
        case 17006: // operationNotAllowed
            return .configuration(
                "E-Mail/Passwort ist als Anmeldemethode nicht aktiviert. "
                + "Firebase Console → Authentication → Sign-in method → E-Mail/Passwort aktivieren."
            )
        case 17007: // emailAlreadyInUse
            return .validation("Diese E-Mail-Adresse wird bereits verwendet.")
        case 17008: // invalidEmail
            return .validation("Diese E-Mail-Adresse ist ungültig.")
        case 17026: // weakPassword
            return .validation("Das Passwort ist zu schwach. Mindestens 6 Zeichen.")
        case 17009, 17011: // wrongPassword, userNotFound
            return .validation("E-Mail-Adresse oder Passwort stimmen nicht.")
        case 17010: // tooManyRequests
            return .validation("Zu viele Versuche. Bitte kurz warten und erneut probieren.")
        case 17999: // internalError
            return .configuration(
                "Firebase meldet einen internen Fehler. Details: \(detail ?? "keine weiteren Angaben")"
            )
        default:
            return .unknown(detail ?? nsError.localizedDescription)
        }
    }

    /// Gräbt die eigentliche Serverantwort aus den verschachtelten
    /// Fehlerinformationen aus.
    private static func underlyingDetail(_ nsError: NSError) -> String? {
        let responseKey = "FIRAuthErrorUserInfoDeserializedResponseKey"

        if let response = nsError.userInfo[responseKey] {
            return String(describing: response)
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError {
            if let response = underlying.userInfo[responseKey] {
                return String(describing: response)
            }
            return underlying.localizedDescription
        }
        return nil
    }
}
