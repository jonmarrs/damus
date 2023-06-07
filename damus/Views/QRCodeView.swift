//
//  QRCodeView.swift
//  damus
//
//  Created by eric on 1/27/23.
//

import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let damus_state: DamusState
    @State var pubkey: String
    
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedTab = 0
    
    @State var scanResult: Search? = nil
    
    @State var showProfileView: Bool = false
    @State var profile: Profile? = nil
    
    @State private var scannedCode = ""
    
    @State private var outerTrimEnd: CGFloat = 0
    var animationDuration: Double = 0.5
    
    let generator = UIImpactFeedbackGenerator(style: .light)

    var maybe_key: String? {
        guard let key = bech32_pubkey(pubkey) else {
            return nil
        }

        return key
    }
    
    @ViewBuilder
    func navImage(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .frame(width: 33, height: 33)
            .background(Color.black.opacity(0.6))
            .clipShape(Circle())
    }
    
    var navBackButton: some View {
        Button {
            presentationMode.wrappedValue.dismiss()
        } label: {
            navImage(systemImage: "chevron.left")
        }
    }
    
    var customNavbar: some View {
        HStack {
            navBackButton
            Spacer()
        }
        .padding(.top, 5)
        .padding(.horizontal)
        .accentColor(DamusColors.white)
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .center) {
                ZStack(alignment: .topLeading) {
                    DamusGradient()
                }
                TabView(selection: $selectedTab) {
                    QRView
                        .tag(0)
                    if pubkey == damus_state.pubkey {
                        QRCameraView()
                            .tag(1)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .onAppear {
                    UIScrollView.appearance().isScrollEnabled = false
                }
                .gesture(
                    DragGesture()
                        .onChanged { _ in }
                )
            }
        }
        .navigationTitle("")
        .navigationBarHidden(true)
        .overlay(customNavbar, alignment: .top)
    }
    
    var QRView: some View {
        VStack(alignment: .center) {
            let profile = damus_state.profiles.lookup(id: pubkey)
            
            if (damus_state.profiles.lookup(id: damus_state.pubkey)?.picture) != nil {
                ProfilePicView(pubkey: pubkey, size: 90.0, highlight: .custom(DamusColors.white, 3.0), profiles: damus_state.profiles, disable_animation: damus_state.settings.disable_animation)
                    .padding(.top, 50)
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 60))
                    .padding(.top, 50)
            }
            
            if let display_name = profile?.display_name {
                Text(display_name)
                    .font(.system(size: 24, weight: .heavy))
            }
            if let name = profile?.name {
                Text("@" + name)
                    .font(.body)
            }
            
            Spacer()
            
            if let key = maybe_key {
                Image(uiImage: generateQRCode(pubkey: "nostr:" + key))
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 300, height: 300)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10)
                        .stroke(DamusColors.white, lineWidth: 5.0))
                    .shadow(radius: 10)
            }
            
            Spacer()
            
            Text("Follow me on nostr", comment: "Text on QR code view to prompt viewer looking at screen to follow the user.")
                .font(.system(size: 24, weight: .heavy))
                .padding(.top)
            
            Text("Scan the code", comment: "Text on QR code view to prompt viewer to scan the QR code on screen with their device camera.")
                .font(.system(size: 18, weight: .ultraLight))
            
            Spacer()
            
            Button(action: {
                selectedTab = 1
            }) {
                HStack {
                    Text("Scan Code", comment: "Button to switch to scan QR Code page.")
                        .fontWeight(.semibold)
                }
                .frame(minWidth: 300, maxWidth: .infinity, maxHeight: 12, alignment: .center)
            }
            .buttonStyle(GradientButtonStyle())
            .padding(50)
        }
    }
    
    func search_changed(_ new: String) {
        var str = new
        guard str.count != 0 else {
            return
        }
        
        if str.hasPrefix("nostr:") {
            str.removeFirst("nostr:".count)
        }
        
        if let _ = hex_decode(str), str.count == 64 {
            self.scanResult = .hex(str)
            return
        }
        
        if str.starts(with: "npub") {
            if let _ = try? bech32_decode(str) {
                self.scanResult = .profile(str)
                return
            }
        }
    }
    
    func QRCameraView() -> some View {
        return VStack(alignment: .center) {
            Text("Scan a user's pubkey")
                .padding(.top, 50)
                .font(.system(size: 24, weight: .heavy))
            
            Spacer()

            CodeScannerView(codeTypes: [.qr], scanMode: .continuous, simulatedData: "npub1k92qsr95jcumkpu6dffurkvwwycwa2euvx4fthv78ru7gqqz0nrs2ngfwd", shouldVibrateOnSuccess: false) { result in
                switch result {
                case .success(let result):
                    search_changed(result.string)
                    switch scanResult {
                    case .profile(let prof):
                        handleProfileScan(prof)
                    default:
                        print("Not a profile")
                    }
                case .failure(let error):
                    print(error.localizedDescription)
                }
            }
            .scaledToFit()
            .frame(width: 300, height: 300)
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(DamusColors.white, lineWidth: 5.0))
            .overlay(RoundedRectangle(cornerRadius: 10).trim(from: 0.0, to: outerTrimEnd).stroke(DamusColors.black, lineWidth: 5.5)
            .rotationEffect(.degrees(-90)))
            .shadow(radius: 10)
            
            Spacer()
            
            if showProfileView {
                let decoded = try? bech32_decode(scannedCode)
                let hex = hex_encode(decoded!.data)
                
                NavigationLink(
                    destination: ProfileView(damus_state: damus_state, pubkey: hex),
                    isActive: $showProfileView,
                    label: {
                        EmptyView()
                    }
                )
            }
            
            Spacer()
            
            Button(action: {
                selectedTab = 0
            }) {
                HStack {
                    Text("View QR Code", comment: "Button to switch to view users QR Code")
                        .fontWeight(.semibold)
                }
                .frame( maxWidth: .infinity, maxHeight: 12, alignment: .center)
            }
            .buttonStyle(GradientButtonStyle())
            .padding(50)
        }
    }

    func profile(for code: String) -> Profile? {
        let decoded = try? bech32_decode(code)
        let hex = hex_encode(decoded!.data)
        return damus_state.profiles.lookup(id: hex)
    }
    
    func handleProfileScan(_ prof: String) {
        guard scannedCode != prof else {
            return
        }
        
        generator.impactOccurred()
        cameraAnimate {
            scannedCode = prof
            
            if profile(for: scannedCode) != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + animationDuration) {
                    showProfileView = true
                }
            } else {
                print("Profile not found")
            }
        }
    }

    func cameraAnimate(completion: @escaping () -> Void) {
        outerTrimEnd = 0.0
        withAnimation(.easeInOut(duration: animationDuration)) {
            outerTrimEnd = 1.05 // Set to 1.05 instead of 1.0 since sometimes `completion()` runs before the value reaches 1.0. This ensures the animation is done.
        }
        completion()
    }
    
    func generateQRCode(pubkey: String) -> UIImage {
        let data = pubkey.data(using: String.Encoding.ascii)
        let qrFilter = CIFilter(name: "CIQRCodeGenerator")
        qrFilter?.setValue(data, forKey: "inputMessage")
        let qrImage = qrFilter?.outputImage
        
        let colorInvertFilter = CIFilter(name: "CIColorInvert")
        colorInvertFilter?.setValue(qrImage, forKey: "inputImage")
        let outputInvertedImage = colorInvertFilter?.outputImage
        
        let maskToAlphaFilter = CIFilter(name: "CIMaskToAlpha")
        maskToAlphaFilter?.setValue(outputInvertedImage, forKey: "inputImage")
        let outputCIImage = maskToAlphaFilter?.outputImage

        let context = CIContext()
        let cgImage = context.createCGImage(outputCIImage!, from: outputCIImage!.extent)!
        return UIImage(cgImage: cgImage)
    }
}

struct QRCodeView_Previews: PreviewProvider {
    static var previews: some View {
        QRCodeView(damus_state: test_damus_state(), pubkey: test_event.pubkey)
    }
}
