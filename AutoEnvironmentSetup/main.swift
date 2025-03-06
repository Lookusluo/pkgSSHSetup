//
//  main.swift
//  AutoEnvironmentSetup
//
//  Created by LukeLuo on 3/5/25.
//

import Foundation

// 定义所需的路径和命令
let sshKeyPath = "\(NSHomeDirectory())/.ssh/id_ed25519.pub"
let repoPath = "\(NSHomeDirectory())/BVVConfigs"
let repoURL = "git@hwtegit.apple.com:BVV/BVVConfigs.git"
let domainURL = "hwtegit.apple.com"
// 获取当前程序的包路径
let bundlePath = Bundle.main.bundlePath
let resourcePath = (bundlePath as NSString).appendingPathComponent("Contents/Resources")

// 检查必要的包是否已安装
func checkEnvironment() -> Bool {
    // 检查 GoatCLI 是否已安装
    let goatCliPath = "/usr/local/bin/goat"
    // 检查 Mink 是否已安装
    let minkPath = "/usr/local/bin/mink"
    // 检查 GitHub CLI 是否已安装
    let ghCliPath = "/usr/local/bin/gh"
    
    let fileManager = FileManager.default
    let toolsInstalled = fileManager.fileExists(atPath: goatCliPath) && 
                        fileManager.fileExists(atPath: minkPath) &&
                        fileManager.fileExists(atPath: ghCliPath)

    return toolsInstalled
}

// 安装必要的包
func installPackages() {
    print("开始安装必要的包...")
    print("请输入管理员密码：")
    
    // 读取密码
    // 使用 termios 结构体来控制终端输入模式
    var term = termios()
    tcgetattr(STDIN_FILENO, &term)
    var oldTerm = term
    term.c_lflag &= ~UInt(ECHO)  // 禁用回显
    tcsetattr(STDIN_FILENO, TCSANOW, &term)
    
    guard let password = String(data: FileHandle.standardInput.availableData, encoding: .utf8)?.trimmingCharacters(in: .newlines) else {
        // 恢复终端设置
        tcsetattr(STDIN_FILENO, TCSANOW, &oldTerm)
        print("无法读取密码")
        exit(1)
    }
    
    // 恢复终端设置
    tcsetattr(STDIN_FILENO, TCSANOW, &oldTerm)
    print("")  // 换行
    
    let packages = [
        "\(bundlePath)/GoatCLI-1.2.3-Release.pkg",
        "\(bundlePath)/Mink-2.5.7-Release.pkg",
        "\(bundlePath)/gitCLI_2.67.0_macOS_universal.pkg"
    ]
    
    for package in packages {
        print("正在安装 \(package.components(separatedBy: "/").last ?? "")...")
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
                print("安装包过程出错：\n\(output)")
                exit(1)
            }
            print("✅ 安装成功")
        } catch {
            print("安装包过程出错：\n\(error.localizedDescription)")
            exit(1)
        }
    }
}

func setupSSHKey() {
    let fileManager = FileManager.default
    
    if !fileManager.fileExists(atPath: sshKeyPath) {
        print("generating SSH key...")
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

// 配置 GitHub CLI 认证
func configureGitHubCLI() {
    print("配置 GitHub CLI...")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/local/bin/gh")
    process.arguments = ["auth", "login", "-h", domainURL, "-p", "ssh"]
    
    // Set up proper terminal handling for interactive input
    let pipe = Pipe()
    process.standardError = pipe
    process.standardInput = FileHandle.standardInput
    process.standardOutput = FileHandle.standardOutput
    
    do {
        try process.run()
        process.waitUntilExit()
        
        let errorData = pipe.fileHandleForReading.readDataToEndOfFile()
        if let errorOutput = String(data: errorData, encoding: .utf8), !errorOutput.isEmpty {
            print("GitHub CLI 配置出错：\n\(errorOutput)")
            exit(1)
        }
    } catch {
        print("GitHub CLI 配置出错：\(error.localizedDescription)")
        exit(1)
    }
}

// 克隆仓库
func cloneRepository() {
    print("克隆仓库...")
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
    process.arguments = ["clone", repoURL, repoPath]
    
    try? process.run()
    process.waitUntilExit()
}
// 主程序流程
func main() {
    print("开始环境检查...")
    
    if checkEnvironment() {
        print("环境已经设置完成，无需进行安装。")
    } else {
        installPackages()
    }

    let fileManager = FileManager.default
    if !fileManager.fileExists(atPath: repoPath) {
        cloneRepository()
        print("环境设置完成！")
    } else {
        print("仓库未找到，请重新配置 GitHub CLI后重启")
        setupSSHKey()
        configureGitHubCLI()
    }
    
}

// 运行主程序
main()

