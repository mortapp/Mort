export type UserRole = "teen" | "adult" | "guardian" | "admin";

export type JobStatus = "draft" | "open" | "paused" | "filled" | "closed" | "removed";

export type ApplicationStatus =
  | "submitted"
  | "guardian_pending"
  | "guardian_rejected"
  | "adult_review"
  | "accepted"
  | "rejected"
  | "completed"
  | "disputed";

export type VerificationStatus = "not_started" | "pending" | "approved" | "rejected";

export type GuardianConnectionStatus = "invited" | "active" | "revoked";

export type ReportStatus = "open" | "reviewing" | "resolved" | "dismissed";

export type PaymentPreference = "cash" | "cash_app" | "square_link" | "flexible" | "none";

export type AccountStatus = "active" | "suspended" | "banned";

export type Profile = {
  id: string;
  role: UserRole | null;
  display_name: string | null;
  username: string | null;
  dob: string | null;
  city: string | null;
  state: string | null;
  onboarding_completed: boolean;
  account_status: AccountStatus;
  verification_status: VerificationStatus;
  payment_preference: PaymentPreference;
  expo_push_token: string | null;
  blocked_until: string | null;
  created_at: string;
  updated_at: string;
};

export type TeenProfile = {
  user_id: string;
  guardian_approval_required: boolean;
  paused_by_guardian: boolean;
  pause_reason: string | null;
  bio: string | null;
  skills: string[];
  school_year: string | null;
};

export type AdultProfile = {
  user_id: string;
  business_name: string | null;
  business_type: string | null;
  verification_notes: string | null;
};

export type GuardianProfile = {
  user_id: string;
  emergency_contact_name: string | null;
  emergency_contact_phone: string | null;
};

export type GuardianConnection = {
  id: string;
  teen_id: string;
  guardian_id: string | null;
  status: GuardianConnectionStatus;
  invite_code: string;
  created_at: string;
  teen_profiles?: Pick<TeenProfile, "user_id" | "paused_by_guardian" | "pause_reason"> | null;
};

export type Job = {
  id: string;
  poster_id: string;
  title: string;
  description: string;
  category: string;
  location_text: string;
  city: string;
  state: string;
  pay_amount_cents: number | null;
  pay_label: string | null;
  teen_min_age: number;
  teen_max_age: number;
  requires_guardian_approval: boolean;
  status: JobStatus;
  starts_at: string | null;
  created_at: string;
};

export type Application = {
  id: string;
  job_id: string;
  teen_id: string;
  status: ApplicationStatus;
  note: string | null;
  guardian_id: string | null;
  created_at: string;
  updated_at: string;
  jobs?: Pick<Job, "id" | "title" | "location_text" | "pay_label" | "poster_id"> | null;
  profiles?: Pick<Profile, "id" | "display_name"> | null;
};

export type MessageThread = {
  id: string;
  job_id: string | null;
  application_id: string | null;
  teen_id: string | null;
  adult_id: string | null;
  guardian_id: string | null;
  created_at: string;
};

export type Notification = {
  id: string;
  recipient_id: string;
  title: string;
  body: string;
  data: Record<string, unknown>;
  read_at: string | null;
  created_at: string;
};

export type PushToken = {
  id: string;
  user_id: string;
  expo_push_token: string;
  platform: "ios" | "android" | "web" | "unknown";
  is_active: boolean;
  last_error: string | null;
  created_at: string;
  updated_at: string;
};

export type PaymentPreferenceRecord = {
  user_id: string;
  preference: PaymentPreference;
  cash_app_tag: string | null;
  square_url: string | null;
  note: string | null;
  created_at: string;
  updated_at: string;
};

export type Message = {
  id: string;
  thread_id: string;
  sender_id: string;
  body: string;
  scanner_status: "clean" | "flagged" | "blocked";
  scanner_reason: string | null;
  created_at: string;
};

export type Report = {
  id: string;
  reporter_id: string;
  target_user_id: string | null;
  target_job_id: string | null;
  target_message_id: string | null;
  reason: string;
  details: string | null;
  status: ReportStatus;
  created_at: string;
};

export type ProofUpload = {
  id: string;
  application_id: string;
  uploaded_by: string;
  storage_path: string;
  note: string | null;
  created_at: string;
};

export type BusinessVerification = {
  id: string;
  adult_id: string;
  business_name: string;
  business_type: string;
  document_storage_path: string | null;
  notes: string | null;
  status: VerificationStatus;
  reviewed_by: string | null;
  created_at: string;
  updated_at: string;
};

export type SafetyPing = {
  id: string;
  teen_id: string;
  guardian_id: string | null;
  status: "ok" | "needs_help" | "missed";
  note: string | null;
  created_at: string;
};

export type SupportTicket = {
  id: string;
  requester_id: string;
  subject: string;
  status: "open" | "waiting" | "resolved" | "closed";
  created_at: string;
  updated_at: string;
};

export type SupportTicketMessage = {
  id: string;
  ticket_id: string;
  sender_id: string;
  body: string;
  created_at: string;
};
