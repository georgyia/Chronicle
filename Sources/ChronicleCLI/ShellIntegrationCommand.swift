import ArgumentParser
import Foundation

/// `chronicle shell-integration` — install or remove the zsh command hook.
struct ShellIntegrationCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "shell-integration",
        abstract: "Install or remove the zsh hook for the terminal module.",
        subcommands: [ShellIntegrationInstall.self, ShellIntegrationUninstall.self]
    )

    static let beginMarker = "# >>> chronicle shell-integration >>>"
    static let endMarker = "# <<< chronicle shell-integration <<<"

    static func snippet(fifoPath: String) -> String {
        """
        \(beginMarker)
        _chronicle_preexec() {
          local fifo="\(fifoPath)"
          [ -p "$fifo" ] || return
          printf '{"command":"%s","cwd":"%s"}\\n' "${1//\\"/\\\\\\"}" "$PWD" > "$fifo" 2>/dev/null &!
        }
        autoload -Uz add-zsh-hook 2>/dev/null && add-zsh-hook preexec _chronicle_preexec
        \(endMarker)
        """
    }
}

struct ShellIntegrationInstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(commandName: "install", abstract: "Add the zsh hook to ~/.zshrc.")
    @OptionGroup var options: GlobalOptions
    func run() async throws {
        let context = try CLIContext.make(options)
        let fifo = context.paths.dataDirectory.appendingPathComponent("terminal.fifo").path
        let zshrc = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".zshrc")

        var contents = (try? String(contentsOf: zshrc, encoding: .utf8)) ?? ""
        guard !contents.contains(ShellIntegrationCommand.beginMarker) else {
            print("Shell integration already installed.")
            return
        }
        if !contents.isEmpty, !contents.hasSuffix("\n") { contents += "\n" }
        contents += "\n" + ShellIntegrationCommand.snippet(fifoPath: fifo) + "\n"
        try contents.write(to: zshrc, atomically: true, encoding: .utf8)
        print("Installed. Restart your shell, then enable the module: chronicle module enable terminal")
    }
}

struct ShellIntegrationUninstall: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "uninstall",
        abstract: "Remove the zsh hook from ~/.zshrc."
    )
    @OptionGroup var options: GlobalOptions
    func run() async throws {
        let zshrc = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent(".zshrc")
        guard let contents = try? String(contentsOf: zshrc, encoding: .utf8),
              let start = contents.range(of: ShellIntegrationCommand.beginMarker),
              let end = contents.range(of: ShellIntegrationCommand.endMarker)
        else {
            print("Shell integration not found.")
            return
        }
        var updated = contents
        updated.removeSubrange(start.lowerBound..<end.upperBound)
        try updated.write(to: zshrc, atomically: true, encoding: .utf8)
        print("Removed shell integration.")
    }
}
