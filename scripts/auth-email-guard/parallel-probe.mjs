export async function completeParallelRequests(requests){
  const results=await Promise.allSettled(requests);
  if(results.some(result=>result.status!=='fulfilled'))throw new Error('Parallel fixture probe failed; private values redacted');
  return results.map(result=>result.value);
}
