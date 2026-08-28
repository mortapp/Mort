import type {
  Application,
  BusinessVerification,
  GuardianConnection,
  Job,
  Message,
  MessageThread,
  Notification,
  PaymentPreferenceRecord,
  Profile,
  ProofUpload,
  PushToken,
  Report,
  SafetyPing,
  SupportTicket,
  SupportTicketMessage,
  TeenProfile,
  AdultProfile,
  GuardianProfile
} from "@/types/domain";

type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[];

type Row<T> = T;
type Insert<T> = Partial<T>;
type Update<T> = Partial<T>;

export type Database = {
  public: {
    Tables: {
      profiles: {
        Row: Row<Profile>;
        Insert: Insert<Profile>;
        Update: Update<Profile>;
      };
      teen_profiles: {
        Row: Row<TeenProfile>;
        Insert: Insert<TeenProfile>;
        Update: Update<TeenProfile>;
      };
      adult_profiles: {
        Row: Row<AdultProfile>;
        Insert: Insert<AdultProfile>;
        Update: Update<AdultProfile>;
      };
      guardian_profiles: {
        Row: Row<GuardianProfile>;
        Insert: Insert<GuardianProfile>;
        Update: Update<GuardianProfile>;
      };
      guardian_connections: {
        Row: Row<GuardianConnection>;
        Insert: Insert<GuardianConnection>;
        Update: Update<GuardianConnection>;
      };
      jobs: {
        Row: Row<Job>;
        Insert: Insert<Job>;
        Update: Update<Job>;
      };
      applications: {
        Row: Row<Application>;
        Insert: Insert<Application>;
        Update: Update<Application>;
      };
      message_threads: {
        Row: Row<MessageThread>;
        Insert: Insert<MessageThread>;
        Update: Update<MessageThread>;
      };
      messages: {
        Row: Row<Message>;
        Insert: Insert<Message>;
        Update: Update<Message>;
      };
      reports: {
        Row: Row<Report>;
        Insert: Insert<Report>;
        Update: Update<Report>;
      };
      proof_uploads: {
        Row: Row<ProofUpload>;
        Insert: Insert<ProofUpload>;
        Update: Update<ProofUpload>;
      };
      business_verifications: {
        Row: Row<BusinessVerification>;
        Insert: Insert<BusinessVerification>;
        Update: Update<BusinessVerification>;
      };
      safety_pings: {
        Row: Row<SafetyPing>;
        Insert: Insert<SafetyPing>;
        Update: Update<SafetyPing>;
      };
      payment_preferences: {
        Row: Row<PaymentPreferenceRecord>;
        Insert: Insert<PaymentPreferenceRecord>;
        Update: Update<PaymentPreferenceRecord>;
      };
      push_tokens: {
        Row: Row<PushToken>;
        Insert: Insert<PushToken>;
        Update: Update<PushToken>;
      };
      notifications: {
        Row: Row<Notification>;
        Insert: Insert<Notification>;
        Update: Update<Notification>;
      };
      support_tickets: {
        Row: Row<SupportTicket>;
        Insert: Insert<SupportTicket>;
        Update: Update<SupportTicket>;
      };
      support_ticket_messages: {
        Row: Row<SupportTicketMessage>;
        Insert: Insert<SupportTicketMessage>;
        Update: Update<SupportTicketMessage>;
      };
      blocks: {
        Row: {
          id: string;
          blocker_id: string;
          blocked_id: string;
          created_at: string;
        };
        Insert: {
          blocker_id: string;
          blocked_id: string;
        };
        Update: never;
      };
    };
    Views: Record<string, never>;
    Functions: {
      send_safe_message: {
        Args: {
          p_thread_id: string;
          p_body: string;
        };
        Returns: Message;
      };
      create_guardian_invite: {
        Args: Record<string, never>;
        Returns: string;
      };
      accept_guardian_invite: {
        Args: {
          p_invite_code: string;
        };
        Returns: string;
      };
      set_teen_pause: {
        Args: {
          p_teen_id: string;
          p_paused: boolean;
          p_reason: string | null;
        };
        Returns: TeenProfile;
      };
    };
    Enums: Record<string, string>;
    CompositeTypes: Record<string, Json>;
  };
};
