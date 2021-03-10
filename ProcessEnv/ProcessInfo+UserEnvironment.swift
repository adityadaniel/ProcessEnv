//
//  ProcessInfo+UserEnvironment.swift
//  ProcessEnv
//
//  Created by Matthew Massicotte on 2019-02-12.
//

import Foundation

public extension ProcessInfo {
    var shellExecutablePath: String {
        if let value = environment["SHELL"], !value.isEmpty {
            return value
        }

        if let value = pwShell, !value.isEmpty {
            return value
        }

        // this is a terrible fallback, but we need something
        return "/bin/bash"
    }

    var pwShell: String? {
        guard let passwd = getpwuid(getuid()) else {
            return nil
        }

        guard let cString = passwd.pointee.pw_shell else {
            return nil
        }

        return String(cString: cString)
    }

    var pwUserName: String? {
        guard let passwd = getpwuid(getuid()) else {
            return nil
        }

        guard let cString = passwd.pointee.pw_name else {
            return nil
        }

        return String(cString: cString)
    }

    var pwDir: String? {
        guard let passwd = getpwuid(getuid()) else {
            return nil
        }

        guard let cString = passwd.pointee.pw_dir else {
            return nil
        }

        return String(cString: cString)
    }

    var path: String {
        return environment["PATH"] ?? "/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    }

    var homePath: String {
        if let path = environment["HOME"] {
            return path
        }

        if let path = pwDir {
            return path
        }

        if #available(macOS 12.0, *) {
            return "/Users/\(userName)"
        }

        if let name = pwUserName {
            return "/Users/\(name)"
        }

        // I'm not sure there is a reasonable fallback in this situation
        return ""
    }

    var userEnvironment: [String : String] {
        let args = ["-lc", "/usr/bin/env"]
        let defaultEnv = ["TERM": "xterm-256color",
                          "HOME": homePath,
                          "PATH": path]
        let env = environment.merging(defaultEnv, uniquingKeysWith: { (a, _) in a })

        guard let data = Process.readOutput(from: shellExecutablePath, arguments: args, environment: env) else {
            return env
        }

        return parseEnvOutput(data)
    }

    private func parseEnvOutput(_ data: Data) -> [String : String] {
        guard let string = String(data: data, encoding: .utf8) else {
            return [:]
        }

        var env: [String: String] = [:]
        let charSet = CharacterSet.whitespaces

        string.enumerateLines { (line, _) in
            let components = line.split(separator: "=")

            guard components.count == 2 else {
                return
            }

            let key = String(components[0].trimmingCharacters(in: charSet))
            let value = String(components[1].trimmingCharacters(in: charSet))

            env[key] = value
        }

        return env
    }
}
