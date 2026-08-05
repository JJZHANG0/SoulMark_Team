import SwiftUI

struct SoulLaunchView: View {
    @State private var signalVisible = false

    var body: some View {
        ZStack {
            SoulBackground()

            VStack(spacing: 18) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(SoulTheme.energy.opacity(signalVisible ? 0.08 : 0.34), lineWidth: 1)
                        .frame(width: signalVisible ? 250 : 180, height: signalVisible ? 250 : 180)

                    Circle()
                        .fill(SoulTheme.visorSurface)
                        .frame(width: 156, height: 156)
                        .overlay(Circle().stroke(Color.white.opacity(0.1), lineWidth: 1))

                    SoulMascotFigure(height: 188, haloIntensity: 1.4)
                        .offset(y: 28)
                }
                .frame(height: 230)

                VStack(spacing: 6) {
                    Text("SOULMARK")
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(SoulTheme.primaryText)

                    Text("IDENTITY SIGNAL / ONLINE")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(SoulTheme.energy)
                }

                Spacer()

                HStack(spacing: 7) {
                    ForEach(0..<3, id: \.self) { index in
                        Capsule()
                            .fill(index == 0 ? SoulTheme.energy : SoulTheme.primaryText.opacity(0.18))
                            .frame(width: index == 0 ? 34 : 8, height: 3)
                    }
                }
                .padding(.bottom, 48)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.5).repeatForever(autoreverses: false)) {
                signalVisible = true
            }
        }
    }
}

struct AuthenticationView: View {
    @EnvironmentObject private var session: AppSession
    @State private var mode: AuthenticationMode = .email
    @State private var displayName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var passwordConfirmation = ""
    @State private var phoneNumber = ""
    @State private var verificationCode = ""
    @State private var phoneCodeSent = false
    @FocusState private var focusedField: Field?

    private enum AuthenticationMode: Hashable {
        case email, phone, register
    }

    private enum Field {
        case name, email, password, confirmation, phone, code
    }

    private var canSubmit: Bool {
        let validEmail = email.contains("@") && email.contains(".")
        let validPassword = password.count >= 8
        if mode == .register {
            return !displayName.trimmingCharacters(in: .whitespaces).isEmpty
                && validEmail && validPassword && password == passwordConfirmation
        }
        if mode == .phone {
            return phoneNumber.count == 11 && verificationCode.count == 6 && phoneCodeSent
        }
        return validEmail && validPassword
    }

    var body: some View {
        ZStack {
            SoulBackground()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    brandHeader
                    modeControl
                    form
                }
                .padding(.horizontal, 22)
                .padding(.top, 26)
                .padding(.bottom, 36)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .alert(
            localizedText("连接没有完成", "Connection incomplete"),
            isPresented: Binding(
                get: { session.errorMessage != nil },
                set: { if !$0 { session.errorMessage = nil } }
            )
        ) {
            Button(localizedText("知道了", "OK")) { session.errorMessage = nil }
        } message: {
            Text(session.errorMessage ?? "")
        }
        .onChange(of: phoneNumber) {
            phoneNumber = String(phoneNumber.filter(\.isNumber).prefix(11))
            phoneCodeSent = false
            verificationCode = ""
        }
        .onChange(of: verificationCode) {
            verificationCode = String(verificationCode.filter(\.isNumber).prefix(6))
        }
    }

    private var brandHeader: some View {
        HStack(alignment: .bottom, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    Capsule().fill(SoulTheme.energy).frame(width: 32, height: 3)
                    Text("SOUL ID / ACCESS")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(SoulTheme.energy)
                }

                Text("SoulMark")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .foregroundStyle(SoulTheme.primaryText)

                Text(localizedText("回来，继续理解每一次连接。", "Return to every connection with more clarity."))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(SoulTheme.secondaryText)
            }

            Spacer(minLength: 0)
            SoulMascotFigure(height: 138, haloIntensity: 1.2)
                .offset(y: 12)
        }
        .frame(minHeight: 170)
    }

    private var modeControl: some View {
        Picker("", selection: $mode) {
            Text(localizedText("邮箱登录", "Email")).tag(AuthenticationMode.email)
            Text(localizedText("手机登录", "Phone")).tag(AuthenticationMode.phone)
            Text(localizedText("创建身份", "Create")).tag(AuthenticationMode.register)
        }
        .pickerStyle(.segmented)
        .onChange(of: mode) {
            session.errorMessage = nil
            focusedField = switch mode {
            case .email: .email
            case .phone: .phone
            case .register: .name
            }
        }
    }

    private var form: some View {
        VStack(spacing: 14) {
            if mode == .phone {
                phoneForm
            } else {
                emailForm
            }

            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                Text(localizedText("登录状态会在此设备安全保留 30 天", "Your session stays secured on this device for 30 days"))
            }
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(SoulTheme.tertiaryText)
            .frame(maxWidth: .infinity)
            .padding(.top, 4)
        }
        .animation(.spring(response: 0.32, dampingFraction: 0.9), value: mode)
    }

    @ViewBuilder
    private var emailForm: some View {
        if mode == .register {
            AuthField(
                title: localizedText("你的名字", "Your name"),
                systemImage: "person.fill",
                text: $displayName,
                contentType: .name
            )
            .focused($focusedField, equals: .name)
            .transition(.move(edge: .top).combined(with: .opacity))
        }

        AuthField(
            title: localizedText("邮箱", "Email"),
            systemImage: "at",
            text: $email,
            contentType: .emailAddress,
            keyboardType: .emailAddress
        )
        .focused($focusedField, equals: .email)

        AuthSecureField(
            title: localizedText("密码 · 至少 8 位", "Password · 8+ characters"),
            text: $password,
            contentType: mode == .register ? .newPassword : .password
        )
        .focused($focusedField, equals: .password)

        if mode == .register {
            AuthSecureField(
                title: localizedText("再次输入密码", "Confirm password"),
                text: $passwordConfirmation,
                contentType: .newPassword
            )
            .focused($focusedField, equals: .confirmation)
            .transition(.move(edge: .top).combined(with: .opacity))
        }

        Button {
            focusedField = nil
            Task {
                if mode == .register {
                    await session.register(
                        displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                        password: password
                    )
                } else {
                    await session.login(
                        email: email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                        password: password
                    )
                }
            }
        } label: {
            HStack(spacing: 10) {
                if session.isWorking {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: mode == .register ? "person.badge.plus" : "arrow.right")
                }
                Text(mode == .register
                    ? localizedText("创建 Soul 身份", "Create Soul ID")
                    : localizedText("进入 SoulMark", "Enter SoulMark"))
            }
            .font(.system(size: 16, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(canSubmit ? SoulTheme.accent : SoulTheme.secondaryText.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
            .shadow(color: canSubmit ? SoulTheme.accent.opacity(0.28) : .clear, radius: 16, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit || session.isWorking)
    }

    @ViewBuilder
    private var phoneForm: some View {
        AuthField(
            title: localizedText("11 位手机号", "11-digit phone number"),
            systemImage: "phone.fill",
            text: $phoneNumber,
            contentType: .telephoneNumber,
            keyboardType: .phonePad
        )
        .focused($focusedField, equals: .phone)

        HStack(spacing: 10) {
            AuthField(
                title: localizedText("6 位验证码", "6-digit code"),
                systemImage: "number",
                text: $verificationCode,
                contentType: .oneTimeCode,
                keyboardType: .numberPad
            )
            .focused($focusedField, equals: .code)

            Button {
                focusedField = nil
                Task {
                    if await session.sendPhoneCode(phoneNumber) {
                        phoneCodeSent = true
                        focusedField = .code
                    }
                }
            } label: {
                Text(phoneCodeSent
                    ? localizedText("重新发送", "Resend")
                    : localizedText("获取验证码", "Send code"))
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                    .foregroundStyle(SoulTheme.accent)
                    .frame(width: 86, height: 54)
                    .background(SoulTheme.accentSoft, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(phoneNumber.count != 11 || session.isWorking)
        }

        Button {
            focusedField = nil
            Task {
                await session.login(phoneNumber: phoneNumber, code: verificationCode)
            }
        } label: {
            HStack(spacing: 10) {
                if session.isWorking {
                    ProgressView().tint(.white)
                } else {
                    Image(systemName: "checkmark.shield.fill")
                }
                Text(localizedText("验证并登录", "Verify and sign in"))
            }
            .font(.system(size: 16, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(canSubmit ? SoulTheme.accent : SoulTheme.secondaryText.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!canSubmit || session.isWorking)

        HStack(spacing: 12) {
            Rectangle().fill(SoulTheme.cardStroke).frame(height: 1)
            Text(localizedText("其他方式", "OR"))
                .font(.system(size: 9, weight: .heavy, design: .monospaced))
                .foregroundStyle(SoulTheme.tertiaryText)
            Rectangle().fill(SoulTheme.cardStroke).frame(height: 1)
        }

        Button {
            session.reportWeChatSDKNotConfigured()
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "message.fill")
                Text(localizedText("使用微信登录", "Continue with WeChat"))
            }
            .font(.system(size: 15, weight: .heavy, design: .rounded))
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(Color(red: 0.10, green: 0.66, blue: 0.34), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct AuthField: View {
    let title: String
    let systemImage: String
    @Binding var text: String
    var contentType: UITextContentType?
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(SoulTheme.accent)
                .frame(width: 22)
            TextField(title, text: $text)
                .textContentType(contentType)
                .keyboardType(keyboardType)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(.system(size: 15, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 15)
        .frame(height: 54)
        .background(SoulTheme.cardFill, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(SoulTheme.cardStroke, lineWidth: 1))
    }
}

private struct AuthSecureField: View {
    let title: String
    @Binding var text: String
    var contentType: UITextContentType?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "key.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(SoulTheme.accent)
                .frame(width: 22)
            SecureField(title, text: $text)
                .textContentType(contentType)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 15)
        .frame(height: 54)
        .background(SoulTheme.cardFill, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(SoulTheme.cardStroke, lineWidth: 1))
    }
}

struct SoulOnboardingView: View {
    @EnvironmentObject private var session: AppSession
    @State private var step = 0
    @State private var displayName = ""
    @State private var language = "zh"
    @State private var gender = "male"
    @State private var appearance = "auto"
    @State private var goal = "difficult-talks"

    var body: some View {
        ZStack {
            SoulBackground()

            VStack(spacing: 0) {
                onboardingHeader

                TabView(selection: $step) {
                    identityStep.tag(0)
                    styleStep.tag(1)
                    goalStep.tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.spring(response: 0.42, dampingFraction: 0.88), value: step)

                onboardingActions
            }
        }
        .onAppear {
            displayName = session.user?.displayName ?? ""
            language = session.user?.preferredLanguage ?? "zh"
        }
        .alert(
            localizedText("设置没有保存", "Setup not saved"),
            isPresented: Binding(
                get: { session.errorMessage != nil },
                set: { if !$0 { session.errorMessage = nil } }
            )
        ) {
            Button(localizedText("知道了", "OK")) { session.errorMessage = nil }
        } message: {
            Text(session.errorMessage ?? "")
        }
    }

    private var onboardingHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 5) {
                Text("SOUL CALIBRATION / 0\(step + 1)")
                    .font(.system(size: 10, weight: .heavy, design: .monospaced))
                    .foregroundStyle(SoulTheme.energy)
                Text(localizedText("建立你的数字身份", "Calibrate your identity"))
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(SoulTheme.primaryText)
            }
            Spacer()
            Text("\(step + 1)/3")
                .font(.system(size: 13, weight: .heavy, design: .monospaced))
                .foregroundStyle(SoulTheme.secondaryText)
        }
        .padding(.horizontal, 22)
        .padding(.top, 20)
    }

    private var identityStep: some View {
        OnboardingPage(
            title: localizedText("Soul 怎么称呼你？", "What should Soul call you?"),
            subtitle: localizedText("这个名字会出现在你的身份面板。", "This name appears on your identity panel.")
        ) {
            SoulMascotFigure(height: 218, haloIntensity: 1.3)
                .frame(maxWidth: .infinity)

            AuthField(
                title: localizedText("你的名字", "Your name"),
                systemImage: "person.fill",
                text: $displayName,
                contentType: .name
            )

            Picker("", selection: $language) {
                Text("中文").tag("zh")
                Text("English").tag("en")
            }
            .pickerStyle(.segmented)
        }
    }

    private var styleStep: some View {
        OnboardingPage(
            title: localizedText("选择你的信号色", "Choose your signal"),
            subtitle: localizedText("随时可以在“我的”里切换。", "You can change it later in Profile.")
        ) {
            HStack(spacing: 12) {
                OnboardingChoice(
                    title: localizedText("深空蓝", "Orbit Blue"),
                    subtitle: localizedText("冷静 · 锐利", "Calm · Sharp"),
                    systemImage: "circle.hexagongrid.fill",
                    tint: Color(red: 0.04, green: 0.50, blue: 0.90),
                    isSelected: gender == "male"
                ) { gender = "male" }
                OnboardingChoice(
                    title: localizedText("樱花粉", "Sakura Pink"),
                    subtitle: localizedText("温柔 · 有力", "Warm · Bold"),
                    systemImage: "sparkles",
                    tint: Color(red: 0.94, green: 0.30, blue: 0.56),
                    isSelected: gender == "female"
                ) { gender = "female" }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text(localizedText("显示模式", "Appearance"))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundStyle(SoulTheme.primaryText)
                Picker("", selection: $appearance) {
                    Text(localizedText("自动", "Auto")).tag("auto")
                    Text(localizedText("日间", "Day")).tag("light")
                    Text(localizedText("夜间", "Night")).tag("dark")
                }
                .pickerStyle(.segmented)
            }
            .padding(16)
            .background(SoulTheme.cardFill, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var goalStep: some View {
        OnboardingPage(
            title: localizedText("先从哪里开始？", "Where do you want to begin?"),
            subtitle: localizedText("Soul 会据此调整首页与练习重点。", "Soul will tune your home and practice focus.")
        ) {
            VStack(spacing: 10) {
                GoalChoice(id: "difficult-talks", title: localizedText("练习难开口的话", "Practice difficult talks"), icon: "waveform.and.mic", selection: $goal)
                GoalChoice(id: "relationships", title: localizedText("看清关系距离", "Understand relationship distance"), icon: "point.3.connected.trianglepath.dotted", selection: $goal)
                GoalChoice(id: "reflection", title: localizedText("复盘表达影响", "Reflect on communication"), icon: "text.quote", selection: $goal)
            }

            ZStack(alignment: .bottomTrailing) {
                SoulVisorPanelBackground()
                VStack(alignment: .leading, spacing: 7) {
                    Text("SOULMARK / READY")
                        .font(.system(size: 10, weight: .heavy, design: .monospaced))
                        .foregroundStyle(SoulTheme.energy)
                    Spacer()
                    Text(localizedText("你的信号已准备好", "Your signal is ready"))
                        .font(.system(size: 20, weight: .black, design: .rounded))
                        .foregroundStyle(Color.white)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .padding(17)
                SoulMascotFigure(height: 138).offset(x: 8, y: 15)
            }
            .frame(height: 150)
            .clipped()
        }
    }

    private var onboardingActions: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button { step -= 1 } label: {
                    Image(systemName: "arrow.left")
                        .font(.system(size: 17, weight: .heavy))
                        .foregroundStyle(SoulTheme.primaryText)
                        .frame(width: 52, height: 52)
                        .background(SoulTheme.cardFill, in: Circle())
                        .overlay(Circle().stroke(SoulTheme.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }

            Button {
                if step < 2 {
                    step += 1
                } else {
                    Task {
                        await session.finishOnboarding(
                            displayName: displayName.trimmingCharacters(in: .whitespacesAndNewlines),
                            language: language,
                            gender: gender,
                            appearance: appearance,
                            goal: goal
                        )
                    }
                }
            } label: {
                HStack(spacing: 9) {
                    if session.isWorking {
                        ProgressView().tint(.white)
                    } else {
                        Text(step == 2 ? localizedText("进入 SoulMark", "Enter SoulMark") : localizedText("继续", "Continue"))
                        Image(systemName: step == 2 ? "checkmark" : "arrow.right")
                    }
                }
                .font(.system(size: 16, weight: .heavy, design: .rounded))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(SoulTheme.accent, in: RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
            .disabled(displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || session.isWorking)
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 24)
    }
}

private struct OnboardingPage<Content: View>: View {
    let title: String
    let subtitle: String
    let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(title)
                        .font(.system(size: 30, weight: .black, design: .rounded))
                        .foregroundStyle(SoulTheme.primaryText)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(SoulTheme.secondaryText)
                }
                content
            }
            .padding(.horizontal, 22)
            .padding(.top, 28)
            .padding(.bottom, 20)
        }
    }
}

private struct OnboardingChoice: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let tint: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 14) {
                Image(systemName: systemImage)
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(tint)
                Spacer()
                Text(title)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(SoulTheme.primaryText)
                Text(subtitle)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(SoulTheme.secondaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 130, alignment: .leading)
            .padding(16)
            .background(isSelected ? tint.opacity(0.14) : SoulTheme.cardFill, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(isSelected ? tint : SoulTheme.cardStroke, lineWidth: isSelected ? 2 : 1))
        }
        .buttonStyle(.plain)
    }
}

private struct GoalChoice: View {
    let id: String
    let title: String
    let icon: String
    @Binding var selection: String

    var body: some View {
        Button { selection = id } label: {
            HStack(spacing: 13) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(selection == id ? Color.white : SoulTheme.accent)
                    .frame(width: 40, height: 40)
                    .background(selection == id ? SoulTheme.accent : SoulTheme.accentSoft, in: RoundedRectangle(cornerRadius: 8))
                Text(title)
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                    .foregroundStyle(SoulTheme.primaryText)
                Spacer()
                Image(systemName: selection == id ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selection == id ? SoulTheme.energy : SoulTheme.tertiaryText)
            }
            .padding(13)
            .background(SoulTheme.cardFill, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selection == id ? SoulTheme.accent.opacity(0.7) : SoulTheme.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
