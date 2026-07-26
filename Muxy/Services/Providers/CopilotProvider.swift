import Foundation

struct CopilotProvider: AIProviderIntegration, AIAgentLaunchProvider {
    let id = "copilot"
    let displayName = "GitHub Copilot"
    let socketTypeKey = "copilot_hook"
    let iconName = "copilot"
    let executableNames = ["copilot"]
    let hookScriptName = "muxy-copilot-hook"

    var agentLaunchConfiguration: AIAgentLaunchConfiguration {
        AIAgentLaunchConfiguration(
            executable: "copilot",
            headlessArguments: ["-p"]
        )
    }

    private static let muxyMarker = "muxy-notification-hook"
    private static let hookFileName = "muxy-notify.json"
    private static let hookTimeoutSeconds = 10

    static let bindings: [(settingsKey: String, argument: String)] = [
        ("userPromptSubmitted", "user-prompt-submit"),
        ("preToolUse", "pre-tool-use"),
        ("permissionRequest", "permission-request"),
        ("notification", "notification"),
        ("agentStop", "stop"),
        ("sessionEnd", "session-end"),
        ("errorOccurred", "stop-failure"),
    ]

    private static let managedEvents = bindings.map(\.settingsKey)

    private let homeDirectory: String
    private let pathEnvironment: @Sendable () -> String
    private let copilotHomeOverride: String?

    init(
        homeDirectory: String = NSHomeDirectory(),
        pathEnvironment: @escaping @Sendable () -> String = { LoginShellPath.current },
        copilotHome: String? = nil
    ) {
        self.homeDirectory = homeDirectory
        self.pathEnvironment = pathEnvironment
        self.copilotHomeOverride = copilotHome
    }

    init(
        homeDirectory: String = NSHomeDirectory(),
        pathEnvironment: String,
        copilotHome: String? = nil
    ) {
        self.init(
            homeDirectory: homeDirectory,
            pathEnvironment: { pathEnvironment },
            copilotHome: copilotHome
        )
    }

    private var copilotHome: String {
        if let copilotHomeOverride, !copilotHomeOverride.isEmpty {
            return copilotHomeOverride
        }
        if let envHome = ProcessInfo.processInfo.environment["COPILOT_HOME"], !envHome.isEmpty {
            return envHome
        }
        return homeDirectory + "/.copilot"
    }

    private var hooksDir: String { copilotHome + "/hooks" }
    private var hookFilePath: String { hooksDir + "/" + Self.hookFileName }

    func isToolInstalled() -> Bool {
        agentCLIExecutablePath() != nil
    }

    func agentCLIExecutablePath() -> String? {
        ProviderExecutableLocator.executablePath(
            names: [agentLaunchConfiguration.executable],
            homeDirectory: homeDirectory,
            pathEnvironment: pathEnvironment(),
            includeSystemWide: homeDirectory == NSHomeDirectory(),
            homeRelativeBins: [".local/bin", ".npm-global/bin"]
        )
    }

    func isHookInstalled() -> Bool {
        ClaudeCodeProvider.fileContainsMuxyMarker(at: hookFilePath)
    }

    var configPaths: [String] { [hookFilePath] }

    func verify(hookScriptPath: String) -> HookVerification {
        guard ClaudeCodeProvider.fileContainsMuxyMarker(at: hookFilePath) else { return .needsRepair }
        guard let settings = try? ClaudeCodeProvider.readJSON(at: hookFilePath),
              let hooks = settings["hooks"] as? [String: Any]
        else { return .needsRepair }

        for binding in Self.bindings {
            let expected = Self.hookCommand(hookScript: hookScriptPath, argument: binding.argument)
            let entries = hooks[binding.settingsKey] as? [[String: Any]]
            guard Self.hasSingleMuxyHook(entries: entries, expectedBash: expected) else {
                return .needsRepair
            }
        }
        return .satisfied
    }

    func install(hookScriptPath: String) throws {
        var settings = try Self.readSettings(at: hookFilePath)
        settings["version"] = settings["version"] ?? 1
        var hooks = settings["hooks"] as? [String: Any] ?? [:]

        var changed = false
        for binding in Self.bindings {
            let bash = Self.hookCommand(hookScript: hookScriptPath, argument: binding.argument)
            let existing = hooks[binding.settingsKey] as? [[String: Any]]
            if Self.hasSingleMuxyHook(entries: existing, expectedBash: bash) {
                continue
            }
            hooks[binding.settingsKey] = Self.mergeHookArray(existing: existing, bash: bash)
            changed = true
        }

        guard changed else { return }
        settings["hooks"] = hooks
        try Self.writeSettings(settings, at: hookFilePath)
    }

    func uninstall() throws {
        guard FileManager.default.fileExists(atPath: hookFilePath) else { return }
        guard isHookInstalled() else { return }
        var settings = try Self.readSettings(at: hookFilePath)
        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        for event in Self.managedEvents {
            guard var entries = hooks[event] as? [[String: Any]] else { continue }
            entries.removeAll { Self.isMuxyHookEntry($0) }
            if entries.isEmpty {
                hooks.removeValue(forKey: event)
            } else {
                hooks[event] = entries
            }
        }

        settings["hooks"] = hooks
        try Self.writeSettings(settings, at: hookFilePath)
    }

    static func hookCommand(hookScript: String, argument: String) -> String {
        "\(ShellEscaper.quote(hookScript)) \(argument) # \(muxyMarker)"
    }

    static func hasSingleMuxyHook(entries: [[String: Any]]?, expectedBash: String) -> Bool {
        let muxyCommands = entries?.compactMap { entry -> String? in
            guard let bash = entry["bash"] as? String, bash.contains(muxyMarker) else { return nil }
            return bash
        } ?? []
        return muxyCommands == [expectedBash]
    }

    private static func mergeHookArray(existing: [[String: Any]]?, bash: String) -> [[String: Any]] {
        var entries = existing ?? []
        entries.removeAll { isMuxyHookEntry($0) }
        entries.append(buildHookEntry(bash: bash))
        return entries
    }

    private static func buildHookEntry(bash: String) -> [String: Any] {
        [
            "type": "command",
            "bash": bash,
            "timeoutSec": hookTimeoutSeconds,
        ]
    }

    private static func isMuxyHookEntry(_ entry: [String: Any]) -> Bool {
        guard let bash = entry["bash"] as? String else { return false }
        return bash.contains(muxyMarker)
    }

    private static func readSettings(at path: String) throws -> [String: Any] {
        guard FileManager.default.fileExists(atPath: path) else { return [:] }
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        guard !data.isEmpty else { return [:] }
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return json
    }

    private static func writeSettings(_ settings: [String: Any], at path: String) throws {
        try HookConfigWriter.write(settings, to: path)
    }
}
