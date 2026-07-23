// Scaffolding for ai-risk-score
Deno.serve(async (req) => {
  return new Response(JSON.stringify({ 
    ok: true, 
    score: 0.1,
    factors: { "baseline": 0.1 },
    message: "ai-risk-score scaffolded using fallback baseline." 
  }), { headers: { "Content-Type": "application/json" } });
});
