//
//  main.swift
//  AutoEnvironmentSetup
//
//  Created by LukeLuo on 3/5/25.
//

import Foundation

// Define the required paths and commands
let sshKeyPath = "\(NSHomeDirectory())/.ssh/id_ed25519.pub"
let repoPath = "\(NSHomeDirectory())/BVVConfigs"
let repoURL = "git@hwtegit.apple.com:BVV/BVVConfigs.git"
let domainURL = "hwtegit.apple.com"
// Get the bundle path of the current program
let bundlePath = Bundle.main.bundlePath
let resourcePath = (bundlePath as NSString).appendingPathComponent("Contents/Resources")

// Check if the necessary packages are installed
func checkEnvironment() -> Bool {
    // Check if GoatCLI is installed
    let goatCliPath = "/usr/local/bin/goat"
    // Check if Mink is installed
    let minkPath = "/usr/local/bin/mink"
    // Check if GitHub CLI is installed
    let ghCliPath = "/usr/local/bin/gh"
    
    let fileManager = FileManager.default
    let toolsInstalled = fileManager.fileExists(atPath: goatCliPath) && 
                        fileManager.fileExists(atPath: minkPath) &&
                        fileManager.fileExists(atPath: ghCliPath)

    return toolsInstalled
}

// Install the necessary packages
func installPackages() {
    print("Starting to install necessary packages...")
    print("Please enter your administrator password:")
    
    // Read the password
    // Use the termios structure to control the terminal input mode
    var term = termios()
    tcgetattr(STDIN_FILENO, &term)
    var oldTerm = term
    term.c_lflag &= ~UInt(ECHO)  // Disable echo
    tcsetattr(STDIN_FILENO, TCSANOW, &term)
    
    guard let password = String(data: FileHandle.standardInput.availableData, encoding: .utf8)?.trimmingCharacters(in: .newlines) else {
        // Restore the terminal settings
        tcsetattr(STDIN_FILENO, TCSANOW, &oldTerm)
        print("Failed to read the password")
        exit(1)
    }
    
    // Restore the terminal settings
    tcsetattr(STDIN_FILENO, TCSANOW, &oldTerm)
    print("")  // New line
    
    let packages = [
        "\(bundlePath)/GoatCLI-1.2.3-Release.pkg",
        "\(bundlePath)/Mink-2.5.7-Release.pkg",
        "\(bundlePath)/gitCLI_2.67.0_macOS_universal.pkg"
    ]
    
    for package in packages {
        print("Installing \(package.components(separatedBy: "/").last ?? "")...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        let command = "echo '\(password)' | sudo -S installer -pkg \"\(package)\" -target /"
        process.arguments = ["-c", command]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            if process.terminationStatus != 0 {
                print("Error occurred during package installation:\n\(output)")
                exit(1)
            }
            print("✅ Installation successful")
        } catch {
            print("Error occurred during package installation:\n\(error.localizedDescription)")
            exit(1)
        }
    }
}

func setupSSHKey() {
    let fileManager = FileManager.default
    
    if !fileManager.fileExists(atPath: sshKeyPath) {
        print("Generating SSH key...")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-keygen")
        process.arguments = ["-t", "ed25519", "-f", sshKeyPath, "-N", ""]
        
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError
        
        try? process.run()
        process.waitUntilExit()
        
        let sshAddProcess = Process()
        sshAddProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ssh-add")
        sshAddProcess.arguments = [sshKeyPath.replacingOccurrences(of: ".pub", with: "")]
        try? process.run()
        process.waitUntilExit()
    }
}

// Configure GitHub CLI authentication
func configureGitHubCLI() {
    print("Configuring GitHub CLI...")
    print("Please complete authentication in the new terminal window...")
    
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    let command = """
    osascript -e 'tell application "Terminal" to do script "gh auth login -h \(domainURL) -p https"'
    """
    process.arguments = ["-c", command]
    
    try? process.run()
    process.waitUntilExit()
}

func cloneRepository() {
    print("Cloning repository...")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/local/bin/gh")
    process.arguments = ["repo", "clone", repoURL, repoPath]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        
        if process.terminationStatus != 0 {
            print("Repository clone failed:\n\(output)")
            exit(1)
        }
    } catch {
        print("Repository clone error:\n\(error.localizedDescription)")
        exit(1)
    }
}

// Main program flow
func main() {
    print("Starting environment check...")
    
    if checkEnvironment() {
        print("✅ The environment is already set up. No installation is required.")
    } else {
        installPackages()
    }

    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: repoPath) {
        cloneRepository()
        print("✅ Environment setup completed!")
    } else {
        print("⚠️  Repository not found. Please reconfigure GitHub CLI and restart this program.")
        setupSSHKey()
        configureGitHubCLI()
    }
    
}

// Run the main program
main()

