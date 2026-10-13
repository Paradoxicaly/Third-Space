import Foundation

// Presentation labels are separate from stable Codable wire values.
extension FactValue {
    var displayName: String {
        switch self {
        case .yes: String(localized: "Yes (observed)")
        case .no: String(localized: "No (observed)")
        case .unknown: String(localized: "Unknown")
        case .free: String(localized: "Free")
        case .purchaseExpected: String(localized: "Purchase expected")
        case .paid: String(localized: "Paid")
        case .quiet: String(localized: "Quiet")
        case .moderate: String(localized: "Moderate")
        case .lively: String(localized: "Lively")
        }
    }
}

extension SubmissionKind {
    var displayName: String {
        switch self {
        case .newPlace: String(localized: "New place")
        case .fieldNote: String(localized: "Field note")
        case .question: String(localized: "Question")
        case .update: String(localized: "Update")
        case .accessNote: String(localized: "Access note")
        case .event: String(localized: "Event")
        }
    }
}
