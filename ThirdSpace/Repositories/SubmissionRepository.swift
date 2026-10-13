import Foundation
protocol SubmissionRepository: Sendable {
    func submit(_ submission: Submission) async throws -> Submission
    func findDuplicates(name: String, regionID: String) async throws -> [Place]
}
