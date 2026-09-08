import Foundation

@main enum ArenaLobbyFixtureCases {
    struct Envelope: Decodable { let match: ServerAPI.GoatArenaParticipantMatch }
    static func main() throws {
        let now = Date(timeIntervalSince1970: 1_788_840_000)
        for role in ["DEFENDER", "CHALLENGER"] {
            let json = DemoTemplate.resolve(DemoArenaFixtures.matchDetail(matchId: "match-01", role: role), now: now)
            let value = try JSONDecoder().decode(Envelope.self, from: Data(json.utf8)).match
            precondition(value.id == "match-01" && value.role == role)
            precondition(value.status == "MATCHED" && value.timeLimitSeconds == 1500)
            precondition(value.capabilities?.availableActions == ["START"])
            precondition(value.preStartContract != nil)
            precondition(ArenaMatchEntryPolicy.permitsStart(actions: value.capabilities?.availableActions,
                                                           hasContract: value.preStartContract != nil))
            let startJSON = DemoArenaFixtures.matchStart(matchId: "match-01", slot: 1, role: role, now: now)
            let nextJSON = DemoArenaFixtures.matchStart(matchId: "match-01", slot: 2, role: role, now: now.addingTimeInterval(30))
            let first = (try JSONSerialization.jsonObject(with: Data(startJSON.utf8)) as! [String: Any])["attempt"] as! [String: Any]
            let next = (try JSONSerialization.jsonObject(with: Data(nextJSON.utf8)) as! [String: Any])["attempt"] as! [String: Any]
            precondition(first["participantRole"] as? String == role)
            for raw in [startJSON, nextJSON, DemoArenaFixtures.questionPack(matchId: "match-01", slot: 1, role: role)] {
                let envelope = try JSONSerialization.jsonObject(with: Data(raw.utf8)) as! [String: Any]
                let pack = envelope["questionPack"] as! [String: Any]
                precondition(pack["participantRole"] as? String == role)
                precondition(pack["matchId"] as? String == "match-01")
                precondition(pack["questionPackId"] as? String == first["questionPackId"] as? String)
            }
            precondition(first["startedAt"] as? String == next["startedAt"] as? String)
            precondition(first["endsAt"] as? String == next["endsAt"] as? String, "advance never resets the timer")
            precondition(first["recognizedHeartbeatActiveMs"] as? Int == 0)
            precondition(next["recognizedHeartbeatActiveMs"] as? Int == 30000)
        }
        print("Actual participant-match DTO + actual demo GET lobby templates decode for attack and defense PASS")
    }
}
