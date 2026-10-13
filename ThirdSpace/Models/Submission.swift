import Foundation
enum SubmissionKind: String, Codable, Sendable { case newPlace, fieldNote, question, update, accessNote, event }
enum SubmissionState: String, Codable, Sendable { case localDraft, submittedPending, inReview, needsChanges, approved, rejected, withdrawn }
struct Submission: Identifiable, Codable, Hashable, Sendable {
    let id: UUID // client idempotency key; do not regenerate on retry
    let kind: SubmissionKind
    let originalLanguage: String
    let body: String
    let state: SubmissionState
}
