export const adminPassword = process.env.AdminPassword;
export const firebase_dynamic_links_key = process.env.FirebaseDynamicLinksKey!;
export const projectId = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT;
export const packageName =
  process.env.packageName ?? "com.AndroidQuartz.meetinghelper";
export const firebase_dynamic_links_prefix =
  process.env.FirebaseDynamicLinksPrefix!;
