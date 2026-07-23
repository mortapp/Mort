create index if not exists proof_uploads_reviewed_by_idx
  on public.proof_uploads (reviewed_by);
