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
        case "FIRFirestoreErrorDomain":
            switch nsError.code {
            case 7: // permission-denied
                return .permissionDenied
            case 5: // not-found
                return .notFound("Dokument")
            default:
                return .unknown(nsError.localizedDescription)
            }
        case NSURLErrorDomain:
            return .network
        default:
            return .unknown(nsError.localizedDescription)
        }
    }
}
