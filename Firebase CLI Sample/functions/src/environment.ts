export const adminPassword = process.env.ADMIN_PASSWORD ?? "p^s$word";
export const firebase_dynamic_links_key = process.env.FB_DYNAMIC_LINKS_KEY!;
export const projectId = process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT;
export const packageName =
  process.env.PACKAGE_NAME ?? "com.AndroidQuartz.meetinghelper";
export const firebase_dynamic_links_prefix =
  process.env.FB_DYNAMIC_LINKS_PREFIX!;
