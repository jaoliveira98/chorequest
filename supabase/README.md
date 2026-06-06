# ChoreQuest cloud sync — Supabase setup

Cross-phone sync (you + your wife seeing each other's data) uses a **personal, free
Supabase project**. This is unrelated to any other database.

## One-time setup (you)

1. **Create a free project** at [supabase.com](https://supabase.com) (Free plan).
2. **Run the schema:** Dashboard → **SQL Editor** → *New query* → paste all of
   [`schema.sql`](schema.sql) → **Run**. It creates the tables, row-level security,
   and the `create_household` / `join_household` functions.
3. **Enable anonymous accounts:** Dashboard → **Authentication → Sign In / Providers**
   → turn **Anonymous sign-ins** **ON**. (Each phone gets an invisible account; no
   email/password.)
4. **Give the app two values** (both safe to embed in the app):
   - **Project URL** — Dashboard → Project Settings → Data API → *Project URL*.
   - **Publishable (anon) key** — Project Settings → API Keys → the `sb_publishable_…`
     (a.k.a. anon) key.

## Security notes
- The **publishable/anon key** is meant to be shipped in clients — safe to embed/commit.
- **Never** put the **database password** or the **service_role key** in the app or repo.
  If a password is ever exposed, reset it: Project Settings → Database → *Reset database password*.
- All access is gated by Row Level Security: a row is only visible to members of its
  household, so the data is private to the people you share the household code with.

## How sharing works
- One phone taps **Create household** → gets a short **code**.
- The other phone taps **Join household** → enters the code.
- From then on, both phones read/write the same household's people, chores, and history.
  The app keeps working offline and syncs on foreground / pull-to-refresh / after changes.
