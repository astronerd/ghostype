//
//  AccountPage.swift
//  AIInputMethod
//
//  账号页面 - 登录/注册 + 用户信息 + 额度 + 订阅状态
//

import SwiftUI

// MARK: - AccountPage

struct AccountPage: View {
    
    @ObservedObject private var authManager = AuthManager.shared
    private var quotaManager = QuotaManager.shared
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                Text(L.Account.title)
                    .font(DS.Typography.largeTitle)
                    .foregroundColor(DS.Colors.text1)
                    .padding(.bottom, DS.Spacing.sm)
                
                if authManager.isLoggedIn {
                    loggedInView
                } else {
                    loggedOutView
                }
                
                Spacer(minLength: DS.Spacing.xl)
            }
            .padding(.top, 21)
            .padding(.horizontal, DS.Spacing.xl)
            .padding(.bottom, DS.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(DS.Colors.bg1)
        .onAppear {
            if authManager.isLoggedIn {
                Task { await quotaManager.refresh() }
            }
        }
    }
    
    // MARK: - Logged Out View
    
    private var loggedOutView: some View {
        VStack(spacing: DS.Spacing.xl) {
            VStack(spacing: DS.Spacing.lg) {
                Image(systemName: "person.circle")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundColor(DS.Colors.text2)
                
                Text(L.Account.welcomeTitle)
                    .font(DS.Typography.title)
                    .foregroundColor(DS.Colors.text1)
                
                Text(L.Account.welcomeDesc)
                    .font(DS.Typography.body)
                    .foregroundColor(DS.Colors.text2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.xxl)
            
            VStack(spacing: DS.Spacing.md) {
                Button(action: { authManager.openLogin() }) {
                    Text(L.Account.login)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.bg1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(DS.Colors.text1)
                        .cornerRadius(DS.Layout.cornerRadius)
                }
                .buttonStyle(.plain)
                
                Button(action: { authManager.openSignUp() }) {
                    Text(L.Account.signUp)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                        .frame(maxWidth: .infinity)
                        .frame(height: 40)
                        .background(DS.Colors.bg2)
                        .overlay(
                            RoundedRectangle(cornerRadius: DS.Layout.cornerRadius)
                                .stroke(DS.Colors.border, lineWidth: DS.Layout.borderWidth)
                        )
                        .cornerRadius(DS.Layout.cornerRadius)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: 280)
            .frame(maxWidth: .infinity)
            
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundColor(DS.Colors.text3)
                Text(L.Account.deviceIdHint)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text3)
            }
        }
    }

    // MARK: - Logged In View
    
    private var loggedInView: some View {
        VStack(spacing: DS.Spacing.xl) {
            // 用户信息卡片
            MinimalSettingsSection(title: L.Account.profile, icon: "person.circle") {
                VStack(spacing: 0) {
                    HStack(spacing: DS.Spacing.md) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(DS.Colors.text2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: DS.Spacing.sm) {
                                Text(L.Account.loggedIn)
                                    .font(DS.Typography.body)
                                    .foregroundColor(DS.Colors.text1)
                                
                                UserTierBadge(tier: quotaManager.userTier)
                            }
                            
                            HStack(spacing: DS.Spacing.xs) {
                                Image(systemName: "desktopcomputer")
                                    .font(.system(size: 10))
                                    .foregroundColor(DS.Colors.text3)
                                Text(DeviceIdManager.shared.truncatedId())
                                    .font(DS.Typography.mono(10, weight: .regular))
                                    .foregroundColor(DS.Colors.text3)
                            }
                        }
                        
                        Spacer()
                        
                        Button(action: { authManager.logout() }) {
                            Text(L.Account.logout)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text2)
                                .padding(.horizontal, DS.Spacing.md)
                                .padding(.vertical, DS.Spacing.xs)
                                .background(DS.Colors.highlight)
                                .cornerRadius(DS.Layout.cornerRadius)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(DS.Spacing.lg)
                }
            }
            
            // 订阅信息卡片
            MinimalSettingsSection(title: L.Account.subscription, icon: "creditcard") {
                subscriptionInfoView
            }
            
            // 额度信息卡片
            MinimalSettingsSection(title: L.Account.quota, icon: "chart.bar") {
                quotaInfoView
            }
        }
    }

    // MARK: - Subscription Info
    
    private var subscriptionInfoView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                switch quotaManager.userTier {
                case .lifetimeVip:
                    Text(L.Account.lifetimeVipPlan)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                    Text(L.Account.permanent)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                case .pro:
                    Text(L.Account.proPlan)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                    if let endDate = quotaManager.currentPeriodEnd {
                        Text("\(L.Account.expiresAt) \(formatDate(endDate))")
                            .font(DS.Typography.caption)
                            .foregroundColor(DS.Colors.text2)
                    }
                case .free:
                    Text(L.Account.freePlan)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                }
            }
            
            Spacer()
            
            switch quotaManager.userTier {
            case .lifetimeVip:
                Text(L.Account.activated)
                    .font(DS.Typography.caption)
                    .foregroundColor(DS.Colors.text3)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.xs)
                    .background(DS.Colors.highlight)
                    .cornerRadius(DS.Layout.cornerRadius)
            case .pro:
                Button(action: { openManageSubscription() }) {
                    Text(L.Account.manageSubscription)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text1)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(DS.Colors.highlight)
                        .cornerRadius(DS.Layout.cornerRadius)
                }
                .buttonStyle(.plain)
            case .free:
                Button(action: { openUpgrade() }) {
                    Text(L.Account.upgradePro)
                        .font(DS.Typography.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.xs)
                        .background(Color.purple.opacity(0.8))
                        .cornerRadius(DS.Layout.cornerRadius)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(DS.Spacing.lg)
    }
    
    // MARK: - Quota Info
    
    private var quotaInfoView: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.Account.plan)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                    Text(planDisplayName)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(L.Account.used)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text2)
                    Text(quotaManager.formattedUsed)
                        .font(DS.Typography.body)
                        .foregroundColor(DS.Colors.text1)
                }
            }
            
            if !quotaManager.isUnlimited {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(DS.Colors.border)
                            .frame(height: 4)
                            .cornerRadius(2)
                        
                        Rectangle()
                            .fill(quotaManager.usedPercentage > 0.9 ? DS.Colors.statusWarning : DS.Colors.text1)
                            .frame(width: geo.size.width * min(quotaManager.usedPercentage, 1.0), height: 4)
                            .cornerRadius(2)
                    }
                }
                .frame(height: 4)
            }
            
            if !quotaManager.formattedResetTime.isEmpty {
                HStack {
                    Spacer()
                    Text(quotaManager.formattedResetTime)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.text3)
                }
            }
        }
        .padding(DS.Spacing.lg)
    }
    
    // MARK: - Helpers
    
    private var planDisplayName: String {
        switch quotaManager.userTier {
        case .lifetimeVip: return L.Account.lifetimeVipPlan
        case .pro: return L.Account.proPlan
        case .free: return L.Account.freePlan
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
    
    private func openManageSubscription() {
        #if DEBUG
        let url = URL(string: "http://localhost:3000/pricing")!
        #else
        let url = URL(string: "https://ghostype.com/pricing")!
        #endif
        NSWorkspace.shared.open(url)
    }
    
    private func openUpgrade() {
        #if DEBUG
        let url = URL(string: "http://localhost:3000/pricing")!
        #else
        let url = URL(string: "https://ghostype.com/pricing")!
        #endif
        NSWorkspace.shared.open(url)
    }
}

// MARK: - User Tier Badge

struct UserTierBadge: View {
    let tier: QuotaManager.UserTier
    @State private var animationPhase: CGFloat = 0
    
    var body: some View {
        switch tier {
        case .free:
            EmptyView()
        case .pro:
            Text("PRO")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.purple)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.purple.opacity(0.15))
                .cornerRadius(10)
        case .lifetimeVip:
            Text(L.Account.lifetimeVipBadge)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(
                    LinearGradient(
                        colors: [
                            Color(hex: "#f472b6"),
                            Color(hex: "#a78bfa"),
                            Color(hex: "#60a5fa"),
                            Color(hex: "#a78bfa"),
                            Color(hex: "#f472b6")
                        ],
                        startPoint: UnitPoint(x: animationPhase - 1, y: 0.5),
                        endPoint: UnitPoint(x: animationPhase + 1, y: 0.5)
                    )
                )
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(hex: "#a78bfa").opacity(0.4), lineWidth: 0.5)
                )
                .shadow(color: Color(hex: "#a78bfa").opacity(0.5), radius: 4, x: 0, y: 0)
                .onAppear {
                    withAnimation(.linear(duration: 4).repeatForever(autoreverses: false)) {
                        animationPhase = 2
                    }
                }
        }
    }
}

// MARK: - Preview

#if DEBUG
struct AccountPage_Previews: PreviewProvider {
    static var previews: some View {
        AccountPage()
            .frame(width: 600, height: 500)
    }
}
#endif
