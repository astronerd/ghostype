//
//  AccountPage.swift
//  AIInputMethod
//
//  账号页面 - 登录/注册 + 用户信息 + 额度
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
            // 欢迎卡片
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
            
            // 登录/注册按钮
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
            
            // 设备 ID 提示
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
                            Text(L.Account.loggedIn)
                                .font(DS.Typography.body)
                                .foregroundColor(DS.Colors.text1)
                            
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
            
            // 额度信息卡片
            MinimalSettingsSection(title: L.Account.quota, icon: "chart.bar") {
                VStack(spacing: DS.Spacing.md) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.Account.plan)
                                .font(DS.Typography.caption)
                                .foregroundColor(DS.Colors.text2)
                            Text(quotaManager.plan.isEmpty ? "Free" : quotaManager.plan)
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
                    
                    // 进度条
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
