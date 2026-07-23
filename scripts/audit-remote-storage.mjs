import { withDatabase } from "./feature-qa-helpers.mjs";

const identityBuckets = new Set([
  "verification-uploads",
  "identity-evidence",
  "mort-document-vault",
]);

await withDatabase(async (database) => {
  const bucketResult = await database.query(`
    select
      bucket.id,
      bucket.public,
      bucket.file_size_limit,
      count(object.id)::integer as object_count
    from storage.buckets bucket
    left join storage.objects object on object.bucket_id = bucket.id
    group by bucket.id, bucket.public, bucket.file_size_limit
    order by bucket.id
  `);
  const policyResult = await database.query(`
    select count(*)::integer as count
    from pg_policies
    where schemaname = 'storage' and tablename = 'objects'
  `);

  const publicBuckets = bucketResult.rows.filter((bucket) => bucket.public);
  if (publicBuckets.length > 0) {
    throw new Error(`Public Storage buckets detected: ${publicBuckets.map((bucket) => bucket.id).join(", ")}`);
  }

  const identityObjectCount = bucketResult.rows
    .filter((bucket) => identityBuckets.has(bucket.id))
    .reduce((total, bucket) => total + bucket.object_count, 0);

  console.log(JSON.stringify({
    status: "PASS",
    buckets: bucketResult.rows,
    storage_object_policy_count: policyResult.rows[0].count,
    identity_bucket_object_count: identityObjectCount,
    object_names_or_paths_read: false,
    object_contents_read: false,
  }));
});
