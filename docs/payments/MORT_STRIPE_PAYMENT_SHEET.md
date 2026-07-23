# Stripe PaymentSheet

Flutter's native PaymentSheet is optional and unavailable on web preview. `stripe-create-job-payment-intent` authenticates the adult, loads the accepted immutable contract, computes cents/currency/fee server-side, and returns short-lived PaymentSheet configuration. The client cannot submit an amount, teen payout destination, fee, environment, or provider customer ID as authority.

The app must show server-returned amount and currency, explain that payment funds the job obligation, handle cancellation/pending/authentication/failure, and avoid claiming success from PaymentSheet alone. Final funded state comes from a signed webhook and server refresh. No card data passes through MORT servers or Supabase tables.
