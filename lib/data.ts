import { supabase } from "@/lib/supabase";
import type {
  Application,
  ApplicationStatus,
  BusinessVerification,
  Job,
  Notification,
  PaymentPreferenceRecord,
  PaymentPreference,
  ProofUpload,
  Report,
  SafetyPing,
  SupportTicket,
  UserRole
} from "@/types/domain";

export async function completeOnboarding(input: {
  userId: string;
  role: Exclude<UserRole, "admin">;
  displayName: string;
  dob: string;
  city: string;
  state: string;
}) {
  const { error } = await supabase.from("profiles").upsert({
    id: input.userId,
    role: input.role,
    display_name: input.displayName.trim(),
    dob: input.dob,
    city: input.city.trim(),
    state: input.state.trim().toUpperCase(),
    onboarding_completed: true
  });

  if (error) {
    throw error;
  }

  if (input.role === "teen") {
    const { error: teenError } = await supabase.from("teen_profiles").upsert({
      user_id: input.userId,
      guardian_approval_required: true,
      skills: []
    });
    if (teenError) throw teenError;
  }

  if (input.role === "adult") {
    const { error: adultError } = await supabase.from("adult_profiles").upsert({
      user_id: input.userId
    });
    if (adultError) throw adultError;
  }

  if (input.role === "guardian") {
    const { error: guardianError } = await supabase.from("guardian_profiles").upsert({
      user_id: input.userId
    });
    if (guardianError) throw guardianError;
  }
}

export async function listOpenJobs() {
  const { data, error } = await supabase
    .from("jobs")
    .select("*")
    .eq("status", "open")
    .order("created_at", { ascending: false });

  if (error) throw error;
  return data ?? [];
}

export async function listJobsForPoster(posterId: string) {
  const { data, error } = await supabase
    .from("jobs")
    .select("*")
    .eq("poster_id", posterId)
    .order("created_at", { ascending: false });

  if (error) throw error;
  return data ?? [];
}

export async function listAdminJobs() {
  const { data, error } = await supabase.from("jobs").select("*").order("created_at", { ascending: false });
  if (error) throw error;
  return data ?? [];
}

export async function updateJobStatus(jobId: string, status: Job["status"]) {
  const { data, error } = await supabase.from("jobs").update({ status }).eq("id", jobId).select().single();
  if (error) throw error;
  return data;
}

export async function getJob(jobId: string) {
  const { data, error } = await supabase.from("jobs").select("*").eq("id", jobId).single();
  if (error) throw error;
  return data;
}

export async function getApplication(applicationId: string) {
  const { data, error } = await supabase
    .from("applications")
    .select("*, jobs(id,title,location_text,pay_label,poster_id), profiles:teen_id(id,display_name)")
    .eq("id", applicationId)
    .single();

  if (error) throw error;
  return data as Application;
}

export async function createJob(input: {
  posterId: string;
  title: string;
  description: string;
  category: string;
  locationText: string;
  city: string;
  state: string;
  payLabel: string;
  teenMinAge: number;
  teenMaxAge: number;
  requiresGuardianApproval: boolean;
}) {
  const { data, error } = await supabase
    .from("jobs")
    .insert({
      poster_id: input.posterId,
      title: input.title.trim(),
      description: input.description.trim(),
      category: input.category.trim(),
      location_text: input.locationText.trim(),
      city: input.city.trim(),
      state: input.state.trim().toUpperCase(),
      pay_label: input.payLabel.trim(),
      teen_min_age: input.teenMinAge,
      teen_max_age: input.teenMaxAge,
      requires_guardian_approval: input.requiresGuardianApproval,
      status: "open"
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function applyToJob(input: {
  job: Job;
  teenId: string;
  note: string;
  guardianId?: string | null;
  guardianRequired: boolean;
}) {
  const status: ApplicationStatus = input.guardianRequired ? "guardian_pending" : "adult_review";
  const { data, error } = await supabase
    .from("applications")
    .insert({
      job_id: input.job.id,
      teen_id: input.teenId,
      note: input.note.trim(),
      status,
      guardian_id: input.guardianId ?? null
    })
    .select()
    .single();

  if (error) throw error;
  await ensureThreadForApplication(data.id, input.job.id, input.teenId, input.job.poster_id, input.guardianId ?? null);
  return data;
}

export async function ensureThreadForApplication(
  applicationId: string,
  jobId: string,
  teenId: string,
  adultId: string,
  guardianId: string | null
) {
  const { data: existing } = await supabase
    .from("message_threads")
    .select("*")
    .eq("application_id", applicationId)
    .maybeSingle();

  if (existing) return existing;

  const { data, error } = await supabase
    .from("message_threads")
    .insert({
      application_id: applicationId,
      job_id: jobId,
      teen_id: teenId,
      adult_id: adultId,
      guardian_id: guardianId
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function listMyApplications(userId: string, role: UserRole) {
  let query = supabase
    .from("applications")
    .select("*, jobs(id,title,location_text,pay_label,poster_id), profiles:teen_id(id,display_name)")
    .order("created_at", { ascending: false });

  if (role === "teen") {
    query = query.eq("teen_id", userId);
  } else if (role === "guardian") {
    query = query.eq("guardian_id", userId);
  } else if (role === "adult") {
    query = query.eq("jobs.poster_id", userId);
  }

  const { data, error } = await query;
  if (error) throw error;
  return (data ?? []) as Application[];
}

export async function listApplicationsForPoster(posterId: string) {
  const { data: jobs, error: jobError } = await supabase.from("jobs").select("id").eq("poster_id", posterId);
  if (jobError) throw jobError;

  const jobIds = (jobs ?? []).map((job) => job.id);
  if (jobIds.length === 0) return [];

  const { data, error } = await supabase
    .from("applications")
    .select("*, jobs(id,title,location_text,pay_label,poster_id), profiles:teen_id(id,display_name)")
    .in("job_id", jobIds)
    .order("created_at", { ascending: false });

  if (error) throw error;
  return (data ?? []) as Application[];
}

export async function updateApplicationStatus(applicationId: string, status: ApplicationStatus) {
  const { data, error } = await supabase
    .from("applications")
    .update({ status })
    .eq("id", applicationId)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function setTeenPause(teenId: string, paused: boolean, reason: string) {
  const { data, error } = await supabase.rpc("set_teen_pause", {
    p_teen_id: teenId,
    p_paused: paused,
    p_reason: reason
  });

  if (error) throw error;
  return data;
}

export async function listThreadsForUser(userId: string, role: UserRole) {
  let column = "teen_id";
  if (role === "adult") column = "adult_id";
  if (role === "guardian") column = "guardian_id";

  const { data, error } = await supabase
    .from("message_threads")
    .select("*")
    .eq(column, userId)
    .order("created_at", { ascending: false });

  if (error) throw error;
  return data ?? [];
}

export async function getThread(threadId: string) {
  const { data, error } = await supabase.from("message_threads").select("*").eq("id", threadId).single();
  if (error) throw error;
  return data;
}

export async function listMessages(threadId: string) {
  const { data, error } = await supabase
    .from("messages")
    .select("*")
    .eq("thread_id", threadId)
    .order("created_at", { ascending: true });

  if (error) throw error;
  return data ?? [];
}

export async function sendMessage(threadId: string, body: string) {
  const { data, error } = await supabase.rpc("send_safe_message", {
    p_thread_id: threadId,
    p_body: body
  });

  if (error) throw error;
  return data;
}

export async function createReport(input: {
  reporterId: string;
  targetUserId?: string | null;
  targetJobId?: string | null;
  targetMessageId?: string | null;
  reason: string;
  details: string;
}) {
  const { data, error } = await supabase
    .from("reports")
    .insert({
      reporter_id: input.reporterId,
      target_user_id: input.targetUserId ?? null,
      target_job_id: input.targetJobId ?? null,
      target_message_id: input.targetMessageId ?? null,
      reason: input.reason.trim(),
      details: input.details.trim(),
      status: "open"
    })
    .select()
    .single();

  if (error) throw error;
  return data as Report;
}

export async function blockUser(blockerId: string, blockedId: string) {
  const { error } = await supabase.from("blocks").insert({
    blocker_id: blockerId,
    blocked_id: blockedId
  });
  if (error) throw error;
}

export async function listGuardianConnections(userId: string, role: "teen" | "guardian") {
  const column = role === "teen" ? "teen_id" : "guardian_id";
  const { data, error } = await supabase
    .from("guardian_connections")
    .select("*")
    .eq(column, userId)
    .order("created_at", { ascending: false });

  if (error) throw error;
  const connections = data ?? [];
  if (role !== "guardian" || connections.length === 0) return connections;

  const teenIds = connections.map((connection) => connection.teen_id);
  const { data: teenProfiles, error: teenProfileError } = await supabase
    .from("teen_profiles")
    .select("user_id,paused_by_guardian,pause_reason")
    .in("user_id", teenIds);

  if (teenProfileError) throw teenProfileError;

  return connections.map((connection) => ({
    ...connection,
    teen_profiles: teenProfiles?.find((teenProfile) => teenProfile.user_id === connection.teen_id) ?? null
  }));
}

export async function getActiveGuardianForTeen(teenId: string) {
  const { data, error } = await supabase
    .from("guardian_connections")
    .select("*")
    .eq("teen_id", teenId)
    .eq("status", "active")
    .limit(1)
    .maybeSingle();

  if (error) throw error;
  return data;
}

export async function submitBusinessVerification(input: {
  adultId: string;
  businessName: string;
  businessType: string;
  documentStoragePath?: string | null;
  notes: string;
}) {
  const { data, error } = await supabase
    .from("business_verifications")
    .insert({
      adult_id: input.adultId,
      business_name: input.businessName.trim(),
      business_type: input.businessType.trim(),
      document_storage_path: input.documentStoragePath ?? null,
      notes: input.notes.trim(),
      status: "pending"
    })
    .select()
    .single();

  if (error) throw error;
  return data as BusinessVerification;
}

export async function addProofUpload(input: {
  applicationId: string;
  uploadedBy: string;
  storagePath: string;
  note: string;
}) {
  const { data, error } = await supabase
    .from("proof_uploads")
    .insert({
      application_id: input.applicationId,
      uploaded_by: input.uploadedBy,
      storage_path: input.storagePath,
      note: input.note.trim()
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function listProofUploads(applicationId: string) {
  const { data, error } = await supabase
    .from("proof_uploads")
    .select("*")
    .eq("application_id", applicationId)
    .order("created_at", { ascending: false });

  if (error) throw error;
  return (data ?? []) as ProofUpload[];
}

export async function updatePaymentPreference(userId: string, paymentPreference: PaymentPreference) {
  return savePaymentPreference(userId, { preference: paymentPreference });
}

export type PaymentPreferenceInput = {
  preference: PaymentPreference;
  cashAppTag?: string | null;
  squareUrl?: string | null;
  note?: string | null;
};

export async function getPaymentPreference(userId: string) {
  const { data, error } = await supabase.from("payment_preferences").select("*").eq("user_id", userId).maybeSingle();
  if (error) throw error;
  return data as PaymentPreferenceRecord | null;
}

export async function savePaymentPreference(userId: string, input: PaymentPreferenceInput) {
  const cleaned = validatePaymentPreference(input);
  const { error } = await supabase
    .from("profiles")
    .update({ payment_preference: cleaned.preference })
    .eq("id", userId);

  if (error) throw error;

  const { error: preferenceError } = await supabase.from("payment_preferences").upsert({
    user_id: userId,
    preference: cleaned.preference,
    cash_app_tag: cleaned.cashAppTag,
    square_url: cleaned.squareUrl,
    note: cleaned.note
  });
  if (preferenceError) throw preferenceError;
}

function validatePaymentPreference(input: PaymentPreferenceInput) {
  const preference = input.preference;
  const cashAppTag = input.cashAppTag?.trim() || null;
  const squareUrl = input.squareUrl?.trim() || null;
  const note = input.note?.trim() || null;

  if (cashAppTag && !/^\$?[A-Za-z][A-Za-z0-9_]{1,20}$/.test(cashAppTag)) {
    throw new Error("Cash App tag must look like $MortUser or MortUser.");
  }

  if (squareUrl) {
    try {
      const parsed = new URL(squareUrl);
      if (!["http:", "https:"].includes(parsed.protocol)) {
        throw new Error("Square link must be an http or https URL.");
      }
    } catch {
      throw new Error("Square invoice/payment link must be a valid URL.");
    }
  }

  if (note && note.length > 240) {
    throw new Error("Payment note must be 240 characters or fewer.");
  }

  return {
    preference,
    cashAppTag: preference === "cash_app" ? cashAppTag : null,
    squareUrl: preference === "square_link" ? squareUrl : null,
    note
  };
}

export async function listNotifications(userId: string) {
  const { data, error } = await supabase
    .from("notifications")
    .select("*")
    .eq("recipient_id", userId)
    .order("created_at", { ascending: false })
    .limit(50);

  if (error) throw error;
  return (data ?? []) as Notification[];
}

export async function markNotificationRead(notificationId: string) {
  const { data, error } = await supabase
    .from("notifications")
    .update({ read_at: new Date().toISOString() })
    .eq("id", notificationId)
    .select()
    .single();

  if (error) throw error;
  return data as Notification;
}

export async function createSafetyPing(input: {
  teenId: string;
  guardianId?: string | null;
  status: SafetyPing["status"];
  note: string;
}) {
  const { data, error } = await supabase
    .from("safety_pings")
    .insert({
      teen_id: input.teenId,
      guardian_id: input.guardianId ?? null,
      status: input.status,
      note: input.note.trim()
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function listSafetyPings(userId: string, role: "teen" | "guardian") {
  const column = role === "teen" ? "teen_id" : "guardian_id";
  const { data, error } = await supabase
    .from("safety_pings")
    .select("*")
    .eq(column, userId)
    .order("created_at", { ascending: false })
    .limit(25);

  if (error) throw error;
  return data ?? [];
}

export async function createSupportTicket(input: { requesterId: string; subject: string; body: string }) {
  const { data, error } = await supabase
    .from("support_tickets")
    .insert({
      requester_id: input.requesterId,
      subject: input.subject.trim(),
      status: "open"
    })
    .select()
    .single();

  if (error) throw error;

  const ticket = data as SupportTicket;
  const { error: messageError } = await supabase.from("support_ticket_messages").insert({
    ticket_id: ticket.id,
    sender_id: input.requesterId,
    body: input.body.trim()
  });

  if (messageError) throw messageError;
  return ticket;
}

export async function listMySupportTickets(userId: string) {
  const { data, error } = await supabase
    .from("support_tickets")
    .select("*")
    .eq("requester_id", userId)
    .order("created_at", { ascending: false });

  if (error) throw error;
  return (data ?? []) as SupportTicket[];
}

export async function listAdminSupportTickets() {
  const { data, error } = await supabase.from("support_tickets").select("*").order("created_at", { ascending: false });
  if (error) throw error;
  return (data ?? []) as SupportTicket[];
}

export async function updateSupportTicketStatus(ticketId: string, status: SupportTicket["status"]) {
  const { data, error } = await supabase.from("support_tickets").update({ status }).eq("id", ticketId).select().single();
  if (error) throw error;
  return data as SupportTicket;
}

export async function createGuardianInvite() {
  const { data, error } = await supabase.rpc("create_guardian_invite");
  if (error) throw error;
  return data;
}

export async function acceptGuardianInvite(inviteCode: string) {
  const { data, error } = await supabase.rpc("accept_guardian_invite", {
    p_invite_code: inviteCode.trim().toUpperCase()
  });
  if (error) throw error;
  return data;
}

export async function listAdminReports() {
  const { data, error } = await supabase.from("reports").select("*").order("created_at", { ascending: false });
  if (error) throw error;
  return data ?? [];
}

export async function updateReportStatus(reportId: string, status: Report["status"]) {
  const { data, error } = await supabase.from("reports").update({ status }).eq("id", reportId).select().single();
  if (error) throw error;
  return data;
}

export async function listAdminVerifications() {
  const { data, error } = await supabase
    .from("business_verifications")
    .select("*")
    .order("created_at", { ascending: false });
  if (error) throw error;
  return data ?? [];
}

export async function reviewVerification(verificationId: string, status: "approved" | "rejected") {
  const { data: authData } = await supabase.auth.getUser();
  const { data, error } = await supabase
    .from("business_verifications")
    .update({ status, reviewed_by: authData.user?.id ?? null })
    .eq("id", verificationId)
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function listAdminProfiles() {
  const { data, error } = await supabase.rpc("admin_list_profiles", { p_limit: 100 });
  if (error) throw error;
  return data ?? [];
}

export async function getUserAdPreferences(userId: string) {
  const { data, error } = await supabase.from("user_ad_preferences").select("*").eq("user_id", userId).maybeSingle();
  if (error) throw error;
  return data;
}

export async function saveUserAdPreferences(input: {
  userId: string;
  personalizedAdsAllowed: boolean;
  adsConsentReady: boolean;
  ageRestrictedAds: boolean;
}) {
  const { data, error } = await supabase
    .from("user_ad_preferences")
    .upsert({
      user_id: input.userId,
      personalized_ads_allowed: input.personalizedAdsAllowed,
      ads_consent_ready: input.adsConsentReady,
      age_restricted_ads: input.ageRestrictedAds,
      last_prompted_at: new Date().toISOString()
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function recordPaywallEvent(input: {
  eventType:
    | "viewed"
    | "package_selected"
    | "purchase_started"
    | "purchase_cancelled"
    | "purchase_failed"
    | "purchase_completed"
    | "restore_started"
    | "restore_completed";
  placement: string;
  offeringId?: string | null;
  packageId?: string | null;
  productId?: string | null;
  errorMessage?: string | null;
}) {
  const { data, error } = await supabase.rpc("record_paywall_event", {
    p_event_type: input.eventType,
    p_placement: input.placement,
    p_offering_id: input.offeringId ?? null,
    p_package_id: input.packageId ?? null,
    p_product_id: input.productId ?? null,
    p_error_message: input.errorMessage ?? null
  });

  if (error) throw error;
  return data;
}

export async function recordAdImpression(input: {
  placement: string;
  adFormat: "banner" | "interstitial" | "rewarded" | "native" | "app_open";
  adUnitId?: string | null;
  requestNonPersonalized: boolean;
}) {
  const { data, error } = await supabase.rpc("record_ad_impression", {
    p_placement: input.placement,
    p_ad_format: input.adFormat,
    p_ad_unit_id: input.adUnitId ?? null,
    p_request_non_personalized: input.requestNonPersonalized
  });

  if (error) throw error;
  return data;
}

export type UsernameChangeStatus = {
  current_username: string | null;
  free_changes_used: number;
  free_changes_remaining: number;
  token_credits: number;
  admin_credits: number;
  plus_allowance_available: boolean;
  plus_changes_used: number;
  plus_period_start: string | null;
};

export type UsernameChangeResult = {
  username: string;
  source: "free" | "plus_allowance" | "token" | "admin_credit" | "admin_override";
  free_changes_remaining: number;
  token_credits: number;
  admin_credits: number;
};

export async function getUsernameChangeStatus() {
  const { data, error } = await supabase.rpc("get_username_change_status");
  if (error) throw error;
  return (data?.[0] ?? null) as UsernameChangeStatus | null;
}

export async function requestUsernameChange(newUsername: string) {
  const { data, error } = await supabase.rpc("request_username_change", {
    p_new_username: newUsername
  });
  if (error) throw error;
  return (data?.[0] ?? null) as UsernameChangeResult | null;
}

export async function listUsernameChangeEvents() {
  const { data, error } = await supabase
    .from("username_change_events")
    .select("*")
    .order("created_at", { ascending: false })
    .limit(25);

  if (error) throw error;
  return data ?? [];
}

export async function recordFeatureUsage(input: {
  featureKey: string;
  entitlementRequired?: string | null;
  allowed: boolean;
}) {
  const { data, error } = await supabase.rpc("record_feature_usage", {
    p_feature_key: input.featureKey,
    p_entitlement_required: input.entitlementRequired ?? null,
    p_allowed: input.allowed
  });

  if (error) throw error;
  return data;
}

export async function getProfileThemeSettings(userId: string) {
  const { data, error } = await supabase.from("user_profile_theme_settings").select("*").eq("user_id", userId).maybeSingle();
  if (error) throw error;
  return data;
}

export async function saveProfileThemeSettings(input: {
  userId: string;
  themeKey?: string | null;
  borderStyle?: string | null;
  accentColor?: string | null;
  backgroundPattern?: string | null;
}) {
  const { data, error } = await supabase
    .from("user_profile_theme_settings")
    .upsert({
      user_id: input.userId,
      theme_key: input.themeKey ?? null,
      border_style: input.borderStyle ?? null,
      accent_color: input.accentColor ?? null,
      background_pattern: input.backgroundPattern ?? null
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function listSavedJobFolders() {
  const { data, error } = await supabase
    .from("user_saved_job_folders")
    .select("*, saved_job_folder_items(job_id, created_at)")
    .order("created_at", { ascending: false });

  if (error) throw error;
  return data ?? [];
}

export async function createSavedJobFolder(input: { userId: string; name: string; color?: string | null }) {
  const { data, error } = await supabase
    .from("user_saved_job_folders")
    .insert({
      user_id: input.userId,
      name: input.name.trim(),
      color: input.color ?? null
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function addJobToSavedFolder(input: { folderId: string; jobId: string; userId: string }) {
  const { data, error } = await supabase
    .from("saved_job_folder_items")
    .upsert({
      folder_id: input.folderId,
      job_id: input.jobId,
      user_id: input.userId
    })
    .select()
    .single();

  if (error) throw error;
  return data;
}

export async function removeJobFromSavedFolder(input: { folderId: string; jobId: string }) {
  const { error } = await supabase
    .from("saved_job_folder_items")
    .delete()
    .eq("folder_id", input.folderId)
    .eq("job_id", input.jobId);

  if (error) throw error;
}
