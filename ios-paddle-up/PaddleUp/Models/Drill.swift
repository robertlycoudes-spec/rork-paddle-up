//
//  Drill.swift
//  PaddleUp
//
//  Drill library. Content lives here, outside screen logic, so drills can be
//  extended or served remotely later.
//

import Foundation

nonisolated struct Drill: Codable, Sendable, Identifiable, Equatable {
    let id: String
    let name: String
    let shot: ShotType
    /// The mechanic this drill is designed to move.
    let targetMechanic: MechanicID
    let minimumLevel: SkillLevel
    let goal: String
    let instructions: [String]
    let sets: Int
    let repsPerSet: Int
    let estimatedMinutes: Int
    let successCriteria: String
    /// The cue repeated to the player during the drill.
    let focusCue: String

    var prescription: String { "\(sets) sets × \(repsPerSet) reps" }
    var targetReps: Int { sets * repsPerSet }
}

nonisolated enum DrillLibrary {
    static let all: [Drill] = [
        Drill(
            id: "dink_contact_point",
            name: "Contact Point Dink Drill",
            shot: .forehandDink,
            targetMechanic: .contactPosition,
            minimumLevel: .beginner,
            goal: "Improve contact distance so you meet the ball out in front.",
            instructions: [
                "Stand a full step behind the kitchen line.",
                "Set a target (a towel or cone) one paddle-length in front of your lead foot.",
                "Dink cross-court, striking every ball above that target.",
                "If the ball gets behind the target, let it go and reset."
            ],
            sets: 3,
            repsPerSet: 20,
            estimatedMinutes: 10,
            successCriteria: "Contact Position score of 80+ across a full set.",
            focusCue: "Meet the ball farther in front"
        ),
        Drill(
            id: "dink_low_base",
            name: "Low Base Dink Ladder",
            shot: .forehandDink,
            targetMechanic: .kneeBend,
            minimumLevel: .beginner,
            goal: "Hold a bent-knee athletic base for a whole exchange.",
            instructions: [
                "Start in a squat with your thighs loaded and paddle up.",
                "Dink 10 balls without letting your hips rise.",
                "Rest 20 seconds, then repeat one inch lower.",
                "Bend from the knees, not the waist."
            ],
            sets: 3,
            repsPerSet: 20,
            estimatedMinutes: 12,
            successCriteria: "Knee Bend score of 85+ with no drop-off in the final set.",
            focusCue: "Stay low the whole rally"
        ),
        Drill(
            id: "dink_quiet_head",
            name: "Quiet Head Dink",
            shot: .forehandDink,
            targetMechanic: .headStability,
            minimumLevel: .intermediate,
            goal: "Stop the head from lifting before contact.",
            instructions: [
                "Pick a spot on the court two feet in front of you.",
                "Keep your eyes down through contact — see the paddle meet the ball.",
                "Only lift your head after the ball has left the paddle.",
                "Slow the exchange down until the head stays still."
            ],
            sets: 3,
            repsPerSet: 15,
            estimatedMinutes: 8,
            successCriteria: "Head Stability score of 88+ for two consecutive sets.",
            focusCue: "Keep your head still through contact"
        ),
        Drill(
            id: "dink_arm_shape",
            name: "Locked Triangle Dink",
            shot: .forehandDink,
            targetMechanic: .armStructure,
            minimumLevel: .intermediate,
            goal: "Keep a stable elbow shape instead of flicking with the wrist.",
            instructions: [
                "Set your elbow slightly bent and away from your ribs.",
                "Move the whole arm from the shoulder — no wrist flick.",
                "Hold the triangle between forearm, upper arm and chest.",
                "Dink 20 balls keeping that shape identical."
            ],
            sets: 3,
            repsPerSet: 20,
            estimatedMinutes: 10,
            successCriteria: "Arm Structure score of 82+ with consistent elbow angle.",
            focusCue: "Hold your arm shape"
        ),
        Drill(
            id: "dink_follow_through",
            name: "Lift & Finish Dink",
            shot: .forehandDink,
            targetMechanic: .followThrough,
            minimumLevel: .beginner,
            goal: "Finish the stroke instead of stopping at the ball.",
            instructions: [
                "Start the paddle low, below the ball.",
                "Push through contact and finish with the paddle out toward your target.",
                "Freeze the finish for a beat on each rep.",
                "No jabbing or poking at the ball."
            ],
            sets: 3,
            repsPerSet: 20,
            estimatedMinutes: 9,
            successCriteria: "Follow-Through score of 80+ across a full set.",
            focusCue: "Finish toward your target"
        ),
        Drill(
            id: "dink_backhand_consistency",
            name: "Backhand Dink Wall",
            shot: .backhandDink,
            targetMechanic: .contactPosition,
            minimumLevel: .beginner,
            goal: "Build a repeatable backhand dink contact point.",
            instructions: [
                "Play every ball with the backhand, even ones you could run around.",
                "Meet the ball in front of your lead hip.",
                "Keep the paddle face open and quiet.",
                "Work in blocks of 20 without losing the contact point."
            ],
            sets: 3,
            repsPerSet: 20,
            estimatedMinutes: 10,
            successCriteria: "Backhand contact position within a paddle-length in front.",
            focusCue: "Contact in front of your lead hip"
        ),
        Drill(
            id: "reset_soft_hands",
            name: "Soft Hands Reset Block",
            shot: .reset,
            targetMechanic: .softHands,
            minimumLevel: .intermediate,
            goal: "Absorb pace so the ball dies in the kitchen.",
            instructions: [
                "Have a partner drive at you from mid-court.",
                "Loosen your grip pressure to about 3 out of 10.",
                "Let the paddle give slightly at contact — do not swing.",
                "Target the kitchen, not depth."
            ],
            sets: 3,
            repsPerSet: 15,
            estimatedMinutes: 12,
            successCriteria: "Soft Hands score of 80+ with balance held.",
            focusCue: "Soft hands, no swing"
        ),
        Drill(
            id: "drop_weight_transfer",
            name: "Step-Through Third-Shot Drop",
            shot: .thirdShotDrop,
            targetMechanic: .weightTransfer,
            minimumLevel: .intermediate,
            goal: "Move forward through the drop rather than standing still.",
            instructions: [
                "Start two steps behind the baseline.",
                "Lift the ball with your legs and step through contact.",
                "Follow the drop forward toward the kitchen.",
                "Reset and repeat without rushing."
            ],
            sets: 3,
            repsPerSet: 15,
            estimatedMinutes: 12,
            successCriteria: "Weight Transfer score of 78+ with forward hip travel every rep.",
            focusCue: "Step through the drop"
        ),
        Drill(
            id: "serve_base",
            name: "Repeatable Serve Base",
            shot: .serve,
            targetMechanic: .stanceWidth,
            minimumLevel: .beginner,
            goal: "Build an identical serve setup every time.",
            instructions: [
                "Set your feet just wider than shoulder width.",
                "Same ball drop, same starting paddle position, every serve.",
                "Transfer weight from back foot to front through contact.",
                "Finish balanced and ready to move."
            ],
            sets: 3,
            repsPerSet: 20,
            estimatedMinutes: 10,
            successCriteria: "Stance and contact point repeat within a narrow band.",
            focusCue: "Same setup every serve"
        )
    ]

    static func drill(id: String) -> Drill? { all.first { $0.id == id } }

    static func drills(for shot: ShotType) -> [Drill] {
        let matching = all.filter { $0.shot == shot }
        if !matching.isEmpty { return matching }
        // Fall back to same-group drills so every practiceable shot has content.
        return all.filter { $0.shot.group == shot.group }
    }

    /// Best drill for a given weakness, preferring exact shot match.
    static func drill(for mechanic: MechanicID, shot: ShotType) -> Drill? {
        all.first { $0.targetMechanic == mechanic && $0.shot == shot }
            ?? all.first { $0.targetMechanic == mechanic && $0.shot.group == shot.group }
            ?? all.first { $0.targetMechanic == mechanic }
            ?? drills(for: shot).first
    }
}
