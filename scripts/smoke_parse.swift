#!/usr/bin/env swift
import Foundation

func remainingPercent(used: Double) -> Double {
    let usedPercent = used <= 1.0 ? used * 100.0 : used
    return max(0, min(100, 100.0 - usedPercent))
}

struct ClaudeWindow: Decodable { var utilization: Double; var resets_at: String }
struct ClaudePayload: Decodable { var five_hour: ClaudeWindow?; var seven_day: ClaudeWindow? }
struct CodexWindow: Decodable { var used_percent: Double; var reset_at: Int? }
struct CodexRate: Decodable { var primary_window: CodexWindow?; var secondary_window: CodexWindow? }
struct CodexPayload: Decodable { var plan_type: String?; var rate_limit: CodexRate? }

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let claudeData = try Data(contentsOf: root.appendingPathComponent("LimitMeterTests/Fixtures/claude_usage.json"))
let codexData = try Data(contentsOf: root.appendingPathComponent("LimitMeterTests/Fixtures/codex_usage.json"))
let claude = try JSONDecoder().decode(ClaudePayload.self, from: claudeData)
let codex = try JSONDecoder().decode(CodexPayload.self, from: codexData)

assert(abs(remainingPercent(used: claude.five_hour!.utilization) - 62) < 0.01)
assert(abs(remainingPercent(used: claude.seven_day!.utilization) - 81) < 0.01)
assert(abs(remainingPercent(used: codex.rate_limit!.primary_window!.used_percent) - 41) < 0.01)
assert(abs(remainingPercent(used: codex.rate_limit!.secondary_window!.used_percent) - 74) < 0.01)
print("parser smoke OK")
