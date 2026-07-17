//
//  SignIn.swift
//  Task Pilot
//
//  Created by Raghul S on 19/09/25.
//
import SwiftUI
import AuthenticationServices
internal import Combine
import Network
import AVFoundation
import _AVKit_SwiftUI

public func secureString() -> String {
    
    let data: [(UInt32, UInt32)] = [
        (108,2),(106,2),(87,2),(73,2),   // j h U G
        (124,3),(105,3),(103,3),(105,3), // y f d f
        (72,1),(87,1),(75,1),(73,1),(122,1),(72,1), // G V J H y G
        (59,4),(57,4),(46,4),(58,4),(57,4),(42,4),(98,4), // 7 5 * 6 5 & ^
        (123,2),(106,2),(102,2),(117,2),(119,2),(96,2),(39,2),(57,2),(53,2),(123,2),(72,2),(101,2),(107,2) // rest
    ]
    
    let result = data.map { (val, shift) -> Character in
        Character(UnicodeScalar(val - shift)!)
    }
    
    return String(result)
}
public func sendToSchoolServer(noSignal: Binding<Bool>, accessDenied: Binding<Bool>){
    guard let url = URL(string: "https://www.rd.school/server-down/apple/project-pilot.php") else {
        print("Invalid URL")
        return
    }

    URLSession.shared.dataTask(with: url) { data, response, error in
        if let error = error {
            print("Error:", error)
            noSignal.wrappedValue = true
            return
        }

        guard let data = data else {
            print("No data received")
            return
        }
        
        if let rawString = String(data: data, encoding: .utf8) {
            accessDenied.wrappedValue = true
        } else {
            print("Unable to decode response as UTF-8 string")
            accessDenied.wrappedValue = true
        }
    }.resume()
}
public func sendToServer(userID: String, email: String?, fullName: String?, noSignal: Binding<Bool>, accessDenied: Binding<Bool>, title: Binding<String>, msg: Binding<String>, otpNum: Binding<String>, loadOtp: Binding<Bool>, isAuthenticated: Binding<Bool>) {
    var nextAuthenticated = false
    guard let url = URL(string: "\(AppConfig.site)synchronization/apple-api-interface/login-with-apple-db-sync.php") else {
        print("Invalid URL")
        return
    }

    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    // Create JSON body
    let jsonBody: [String: Any] = [
        "loop-speed-test-result": secureString(),
        "pid": "Apple/TaskPilot/SignIn",
        "apple-json-data": [
            "userId": userID,
            "email": email ?? "",
            "fullName": fullName ?? ""
        ],
        "old-table-data": DF.executeQuery("Select * from login_with_apple_data_from_apple where todat = '0000-00-00' and ftodat = '0000-00-00'").1 == nil ? [] : DF.executeQuery("Select * from login_with_apple_data_from_apple where todat = '0000-00-00' and ftodat = '0000-00-00'").1!,
        "tablesinproject": DatabaseStructure.NeuralMemoryTables.map { $0.name }, //,
        "app-update" : "2026-02-30"
    ]
//    print("__________")
//    print(jsonBody)
//    print("__________")
    do {
        request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody, options: [])
    } catch {
        print("Error creating JSON:", error)
        return
    }

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let error = error {
            print("Error:", error)
            noSignal.wrappedValue = true
            return
        }

        guard let data = data else {
            el("No data received from server")
            return
        }
        if let responseString = String(data: data, encoding: .utf8) {
            if responseString.contains("Error Code : 253") {
                accessDenied.wrappedValue = true
            } else if responseString.contains("App Update Required") {
                accessDenied.wrappedValue = true
                title.wrappedValue = "App Update Required"
                msg.wrappedValue = "The app you are currently using is an outdated version, which may pose security risks. Please update the app from the Google Play Store to ensure safety and proper functionality."
            } else if responseString.contains("App Expired") {
                accessDenied.wrappedValue = true
                title.wrappedValue = "App Expired"
                msg.wrappedValue = responseString
            } else if responseString.contains("tabledata") {
                nextAuthenticated = true
            } else {
                if otpNum.wrappedValue == "" {
                    sendToSchoolServer(noSignal: noSignal, accessDenied: accessDenied)
                    el(responseString, type: "Send to server")
                }
            }
                print("raw Data", responseString)
        }
        if nextAuthenticated {
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    
                    let userdata = json["userdata"] as? [String: Any] ?? [:]
                    let downsync = json["downsync"] as? [[String: Any]] ?? []
                    user.setUserInfo(name: downsync[0]["fullname"] as? String ?? "", id: userdata["unique_member_id"] as? String ?? "", area: userdata["area"] as? String ?? "", ownComCode:  downsync[0]["owncomcode"] as? String ?? "")
                    if userdata["status"] as! String == "connected" {
                        // ✅ Access values
                        if downsync.count > 0 {
                            _ = DF.insert("login_with_apple_data_from_apple", buildInsertQuery(data: downsync[0]))
                            _ = DF.executeQuery("UPDATE login_with_apple_data_from_apple SET area = '\(userdata["area"]!)', unique_member_id = '\(userdata["unique_member_id"]!)', doe = '\(getDate())', toe = '\(getTime())' WHERE userid = '\(downsync[0]["userid"]!)' AND todat = '0000-00-00' AND ftodat = '0000-00-00'")
                        }
                        let tabledata = json["tabledata"] as? [String: Any] ?? [:]
                        var a = 0
                        let allTables = DatabaseStructure.NeuralMemoryTables.map { $0.name }
                        while a < allTables.count {
                            var b = 0
                            if let comp = tabledata[allTables[a]] as? [[String: Any]] {
                                while b < comp.count {
                                    _ = sql.executeQuery(buildInsertQuery(table: allTables[a], data: comp[b]))
                                    b += 1
                                }
                            }
                            a += 1
                        }
                        isAuthenticated.wrappedValue = true
                    } else {
                        //code to redrict FPAGE
                        if DF.executeQuery("Select * from login_with_apple_data_from_apple where todat = '0000-00-00' and ftodat = '0000-00-00'").1 == nil {
                            if downsync.count > 0 {
                                _ = DF.executeQuery(buildInsertQuery(table: "login_with_apple_data_from_apple", data: downsync[0]))
                                _ = DF.executeQuery("UPDATE login_with_apple_data_from_apple SET doe = '\(getDate())', toe = '\(getTime())' WHERE userid = '\(downsync[0]["userid"]!)' AND todat = '0000-00-00' AND ftodat = '0000-00-00'")
                            }
                        }
                        otpNum.wrappedValue = userdata["otp"] as! String
                        loadOtp.wrappedValue = true
                    }
                }
            } catch {
                el(error, type: "JSON Error after receiving from server")
            }
        }
    }.resume()
}
public func buildInsertQuery(table: String, data: [String: Any]) -> String {
    
    var columns: [String] = []
    var values: [String] = []
    
    for (key, value) in data {
        
        columns.append(key)
        
        if value is NSNull {
            values.append("NULL")
        } else {
            let val = "\(value)"
                .replacingOccurrences(of: "'", with: "''") // escape '
            values.append("'\(val)'")
        }
    }
    
    let columnString = columns.joined(separator: ", ")
    var valueString = values.joined(separator: ", ")
    valueString.replace("NULL", with: "''")
    let query = "INSERT INTO \(table) (\(columnString)) VALUES (\(valueString));"
    
    return query
}

public func buildInsertQuery(data: [String: Any]) -> [String: String] {
    var result: [String: String] = [:]
    for (key, value) in data {
        if value is NSNull {
            result[key] = ""
        } else {
            let val = "\(value)"
                .replacingOccurrences(of: "'", with: "''")
            result[key] = val
        }
    }
    return result
}

// Custom full-screen video player using AVPlayerLayer with .resizeAspectFill
//public struct FullScreenVideoPlayer: UIViewRepresentable {
//    let player: AVPlayer
//    
//    func makeUIView(context: Context) -> PlayerUIView {
//        let view = PlayerUIView()
//        view.playerLayer.player = player
//        view.playerLayer.videoGravity = .resizeAspectFill
//        view.backgroundColor = .black
//        return view
//    }
//    
//    func updateUIView(_ uiView: PlayerUIView, context: Context) {
//        uiView.playerLayer.player = player
//    }
//    
//    class PlayerUIView: UIView {
//        override static var layerClass: AnyClass { AVPlayerLayer.self }
//        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
//    }
//}
public struct FullScreenVideoPlayer: UIViewRepresentable {
    let player: AVPlayer
    
    public func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspectFill
        view.backgroundColor = .black
        return view
    }
    
    public func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
    
    public class PlayerUIView: UIView {
        public override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
public struct Signin<Content: View>: View {
    let homeView: Content
    public init(
        homeView: Content
    ) {
        self.homeView = homeView
    }
    @State private var isAuthenticated = false
    @State private var nextAuthenticated = false
    @State private var accessDenied = false
    @State private var noSignal = false
    @State private var isAlert = false
    @State private var loadOtp = false
    @State private var reLoad = false
    @State private var showAppleSignIn = false
    @State private var showSplash = true
    @State private var appleCheckCompleted = false
    @State private var userID = ""
    @State private var userID2 = ""
    @State private var title = ""
    @State private var msg = ""
    @State private var password = ""
    @State private var otpNum = ""
    @State private var fullName: String? = nil
    @State private var email: String? = nil
    @State private var player = AVPlayer()
    @State private var splashPlayer = AVPlayer()
    public func sendToServerByPas() {
        guard let url = URL(string: "\(AppConfig.site)synchronization/apple-api-interface/direct-login.php") else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Create JSON body
        let jsonBody: [String: Any] = [
            "username": userID2,
            "password": password
        ]
        print("__________")
        print(jsonBody)
        print("__________")
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody, options: [])
        } catch {
            print("Error creating JSON:", error)
            return
        }

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error:", error)
                noSignal = true
                return
            }

            guard let data = data else {
                print("No data received")
                return
            }
            if let responseString = String(data: data, encoding: .utf8) {
                if responseString.contains("Invalid") {
                    isAlert = true
                    userID2 = ""
                    password = ""
                    reLoad = false
                } else if responseString.contains("email") {
                    do {
                        if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                            userID = json["parkingHost"] as? String ?? ""
                            email = json["parkingHost"] as? String ?? ""
                            fullName = json["fullname"] as? String ?? ""
                            sendToServer(userID: userID, email: email, fullName: fullName, noSignal: $noSignal, accessDenied: $accessDenied, title: $title, msg: $msg, otpNum: $otpNum, loadOtp: $loadOtp, isAuthenticated: $isAuthenticated)
                            print(responseString)
                        }
                    } catch {
                        if fastAccess(userId: userID2, pass: password) {
                            isAuthenticated = true
                        } else {
                            isAlert = true
                            userID2 = ""
                            password = ""
                            reLoad = false
                        }
                    }
                } else {
                    if fastAccess(userId: userID2, pass: password) {
                        isAuthenticated = true
                    } else {
                        isAlert = true
                        userID2 = ""
                        password = ""
                        reLoad = false
                    }
                }
                print("-------", responseString, "---------")
            }
            
        }.resume()
    }
    
    // Checks the school server to decide whether to show the Sign in with Apple button
    private func checkAppleSignInAvailability() {
        guard let url = URL(string: "https://www.rd.school/apple/is-sign-in-with-apple-ready.php") else {
            DispatchQueue.main.async {
                appleCheckCompleted = true
            }
            return
        }
        URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                el(error, type: "Apple sign-in")
                DispatchQueue.main.async {
                    appleCheckCompleted = true
                }
                return
            }
            guard let data = data,
                  let responseString = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    appleCheckCompleted = true
                }
                return
            }
            let trimmed = responseString
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            DispatchQueue.main.async {
                showAppleSignIn = trimmed.contains("yes")
                appleCheckCompleted = true
            }
        }.resume()
    }
    
    // Plays the splash screen video once and dismisses when complete (or after server check, whichever is later)
    private func playSplashVideo() {
        guard let url = Bundle.main.url(forResource: "splashscreen", withExtension: "mp4") else {
            print("splashscreen.mov NOT FOUND in bundle")
            showSplash = false
            return
        }
//        print("Splash URL found:", url)
        
        let item = AVPlayerItem(url: url)
        splashPlayer.replaceCurrentItem(with: item)
        splashPlayer.actionAtItemEnd = .pause
        
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
//            print("Splash video ended")
            if appleCheckCompleted {
                withAnimation {
                    showSplash = false
                }
            } else {
                splashWaitForCheck()
            }
        }
        
        // Seek to start and play with a tiny delay to ensure player is ready
        splashPlayer.seek(to: .zero)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            splashPlayer.play()
//            print("Splash player.play() called, rate:", splashPlayer.rate)
        }
    }
    
    // Polls until appleCheckCompleted, then dismisses splash
    private func splashWaitForCheck() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if appleCheckCompleted {
                withAnimation {
                    showSplash = false
                }
            } else {
                splashWaitForCheck()
            }
        }
    }
    
    // Starts the Sign in with Apple flow using ASAuthorizationController so we can trigger it from a custom button
    private func startSignInWithApple() {
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        let coordinator = AppleSignInCoordinator(
            onSuccess: { credential in
                self.userID = credential.user
                if let name = credential.fullName?.formatted(.name(style: .medium)), !name.isEmpty {
                    self.fullName = name
                }
                if let mail = credential.email, !mail.isEmpty {
                    self.email = mail
                }
                sendToServer(userID: userID, email: email, fullName: fullName, noSignal: $noSignal, accessDenied: $accessDenied, title: $title, msg: $msg, otpNum: $otpNum, loadOtp: $loadOtp, isAuthenticated: $isAuthenticated)
                print(self.userID)
            },
            onFailure: { error in
                el("\(error.localizedDescription)", type: "Sign In failed")
            }
        )
        controller.delegate = coordinator
        controller.presentationContextProvider = coordinator
        coordinator.retainSelf = coordinator // keep alive during request
        controller.performRequests()
    }

    // Coordinator to bridge ASAuthorizationController delegate callbacks
    private final class AppleSignInCoordinator: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
        let onSuccess: (ASAuthorizationAppleIDCredential) -> Void
        let onFailure: (Error) -> Void
        // Keep a strong reference while the controller is active
        var retainSelf: AppleSignInCoordinator?

        init(onSuccess: @escaping (ASAuthorizationAppleIDCredential) -> Void, onFailure: @escaping (Error) -> Void) {
            self.onSuccess = onSuccess
            self.onFailure = onFailure
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
            if let credential = authorization.credential as? ASAuthorizationAppleIDCredential {
                onSuccess(credential)
            }
            retainSelf = nil
        }

        func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
            onFailure(error)
            retainSelf = nil
        }

        func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
            // Provide a window for presentation; best-effort fallback if keyWindow not available
            return UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow } ?? ASPresentationAnchor()
        }
    }
    func playVideo(_ video: String) {
        guard let url = Bundle.main.url(forResource: video, withExtension: "mov") else {
            return
        }
        
        let item = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: item)
        
        // Remove old observers (important to avoid duplicates)
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        
        // Loop video
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        
        player.play()
    }
    public var body: some View {
        NavigationStack {
            ZStack {
                Background()
                SmartAlert(title: "Looks like you forgot your userid or password", showAlert: $isAlert, Duration: 5)
                
                if reLoad {
                    VStack {
                        FullScreenVideoPlayer(player: player)
                            .ignoresSafeArea()
                            .onAppear {
                                playVideo("reLoading")
                            }
                    }
                } else {
                    VStack {
                        if !showAppleSignIn {
                            Image("Bee")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 120)
                                .padding(.leading, -30)
                                .padding(.top, 10)
                            Spacer()
                        } else{
                            Image("Bee")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 150, height: 120)
                                .padding(.leading, -30)
                                .padding(.bottom, 250)
                        }
                    }
                    VStack {
                        if !showAppleSignIn {
                            Image("skynetlogo1-removebg-preview")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 500, height: 200)
                            Spacer()
                        } else {
                            Image("skynetlogo1-removebg-preview")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 500, height: 200)
                                .padding(.bottom, 100)
                        }
                    }
                    .padding(.top, UIScreen.main.bounds.height/10)
                    
                    VStack(spacing: 5) {
                        if showAppleSignIn {
                            Button(action: {
                                startSignInWithApple()
                            }) {
                                HStack(spacing: 12) {
                                    Image(systemName: "applelogo")
                                        .font(.title2)
                                    Text("Sign in with Apple")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(width: 280, height: 60)
                            .glassEffect(.clear, in: .rect(cornerRadius: 20))
                            .padding(.top, UIScreen.main.bounds.height/4.5 - 100)
                        } else {
                            VStack(spacing: 20) {
                                RIBT(placeholder: "SkynetCipher", value: $userID2)
                                RIBP(placeholder: "Password", value: $password)
                                Button(action: {
                                    if !userID2.isEmpty && !password.isEmpty {
                                        sendToServerByPas()
                                        reLoad = true
                                    } else {
                                        isAlert = true
                                        userID2 = ""
                                        password = ""
                                    }
                                }) {
                                    Text("Sign in ")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                                .padding()
                                .foregroundStyle(.white)
                                .glassEffect(.clear, in: .rect(cornerRadius: 20))
                                Spacer()
                            }
                            .padding(.top, UIScreen.main.bounds.height/3.5)
                            .preferredColorScheme(ColorScheme.dark)
                        }
                    }
                    
                }
                if showSplash {
                    ZStack {
                        Color.black
                            .ignoresSafeArea()
                        FullScreenVideoPlayer(player: splashPlayer)
                            .ignoresSafeArea()
                    }
                    .transition(.opacity)
                    .zIndex(999)
                }
                if accessDenied && !title.isEmpty {
                    NavigationLink(destination: Accessdenied(title: title, message: msg), isActive: $accessDenied){
                        EmptyView()
                    }
                } else if accessDenied {
                    NavigationLink(destination: Accessdenied(), isActive: $accessDenied){
                        EmptyView()
                    }
                }
                if loadOtp {
                    NavigationLink(destination: OtpPage(otp: $otpNum, homeView: homeView), isActive: $loadOtp){
                        EmptyView()
                    }
                }
                if noSignal {
                    NavigationLink(destination: SignalLost(homeView: homeView), isActive: $noSignal){
                        EmptyView()
                    }
                }
                if isAuthenticated {
                    Text("")
                        .onAppear(){
                            if DF.executeQuery("Select * from login_with_apple_data_from_apple where unique_member_id != '' and todat == '0000-00-00' and ftodat == '0000-00-00'").1 != nil {
                                if DF.executeQuery("Select date from last_sync_details").1 == nil {
                                    _ = DF.executeQuery("insert into last_sync_details ('date', 'time', 'completionstatus') values ('\(getDate())', '\(getTime())', 'insertup')")
                                    _ = DF.executeQuery("insert into last_sync_details ('date', 'time', 'completionstatus') values ('\(getDate())', '\(getTime())', 'endup')")
                                    _ = DF.executeQuery("insert into last_sync_details ('date', 'time', 'completionstatus') values ('\(getDate())', '\(getTime())', 'deleteup')")
                                    _ = DF.executeQuery("insert into last_sync_details ('date', 'time', 'completionstatus') values ('\(getDate())', '\(getTime())', 'insertdown')")
                                    _ = DF.executeQuery("insert into last_sync_details ('date', 'time', 'completionstatus') values ('\(getDate())', '\(getTime())', 'enddown')")
                                    _ = DF.executeQuery("insert into last_sync_details ('date', 'time', 'completionstatus') values ('\(getDate())', '\(getTime())', 'deletedown')")
                                }
                            }
                        }
                    NavigationLink(destination: homeView, isActive: $isAuthenticated){
                        EmptyView()
                    }
                }
            }
            .onAppear {
                playSplashVideo()
                checkAppleSignInAvailability()
            }
            .ignoresSafeArea(.keyboard)
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .environment(\.colorScheme, .dark)
        }
        .navigationBarBackButtonHidden()
    }
}

