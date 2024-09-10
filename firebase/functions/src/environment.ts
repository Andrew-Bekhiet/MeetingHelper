import { SupabaseClient } from "@supabase/supabase-js";

export const projectId =
  process.env.GCP_PROJECT ||
  process.env.GCLOUD_PROJECT ||
  process.env["PROJECT_ID"];

export const firebaseDynamicLinksAPIKey =
  process.env["FB_DYNAMIC_LINKS_API_KEY"];

export const firebaseDynamicLinksPrefix =
  process.env["FB_DYNAMIC_LINKS_PREFIX"];

export const packageName = process.env["PACKAGE_NAME"];

// Supabase

export const supabaseAdminSecret = process.env["SUPABASE_ADMIN_SECRET"] || null;

export const supabaseUrl = process.env["SUPABASE_URL"] || null;

export const supabaseJWTSecret = process.env["SUPABASE_JWT_SECRET"] || null;

export const supabaseClient =
  supabaseUrl && supabaseAdminSecret && supabaseJWTSecret
    ? new SupabaseClient(supabaseUrl, supabaseAdminSecret)
    : null;
