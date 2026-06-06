import Foundation

/// Connection details for the personal ChoreQuest Supabase project.
///
/// Both values are **publishable** — the URL and the `sb_publishable_…` key are
/// designed to ship in clients (access is gated by Row-Level Security). The
/// database password and `service_role` key are NOT here and must never ship.
enum SupabaseConfig {
    static let url = URL(string: "https://zgmkkqyxhxsiwjfbasca.supabase.co")!
    static let publishableKey = "sb_publishable_cLE86MSdRy0FZeLEIPdLeQ_7yhdW4bW"

    static var restURL: URL { url.appendingPathComponent("rest/v1") }
    static var authURL: URL { url.appendingPathComponent("auth/v1") }
}
