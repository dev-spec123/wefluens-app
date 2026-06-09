//
//  SupabaseService.swift
//  WeConnect
//
//  Singleton Supabase client — native Supabase Auth (email/password).
//  The SDK manages sessions internally; no accessToken callback needed.
//

import Foundation
import Supabase

let supabase: SupabaseClient = {
    guard let url = URL(string: Config.EXPO_PUBLIC_SUPABASE_URL),
          !Config.EXPO_PUBLIC_SUPABASE_URL.isEmpty else {
        return SupabaseClient(
            supabaseURL: URL(string: "https://placeholder.supabase.co")!,
            supabaseKey: "placeholder"
        )
    }
    return SupabaseClient(
        supabaseURL: url,
        supabaseKey: Config.EXPO_PUBLIC_SUPABASE_ANON_KEY
    )
}()
