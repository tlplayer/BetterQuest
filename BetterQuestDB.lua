
-- Persistent Database through game sessions to save missing dialogue and maybe settings?
BetterQuestDB = {
    missingNPCs = {
        ["npc_name"] = {
            originalName = "Original NPC Name",
            dialogs = {
                ["normalized_text_hash"] = {
                    dialog_text = "Full dialog text",
                    dialogType = "gossip",
                    count = number_of_times_seen
                }
            }
        }
    },
}