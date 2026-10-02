import { createClient } from '@supabase/supabase-js'

const url = import.meta.env.VITE_SUPABASE_URL as string | undefined
const anonKey = import.meta.env.VITE_SUPABASE_ANON_KEY as string | undefined

/** Supabase の設定が .env に入っているか */
export const isSupabaseConfigured = Boolean(url && anonKey)

/**
 * 画面側で使うクライアント。anon key（公開してよい鍵）だけを使う。
 * service role key は絶対にここに入れない（CLAUDE.md の禁止事項）。
 */
export const supabase = isSupabaseConfigured ? createClient(url!, anonKey!) : null
