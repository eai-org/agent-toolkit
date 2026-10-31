# Orders

In-memory order service used by the checkout demo.

- An order holds line items priced in cents.
- Coupon codes take a percent off the subtotal and may expire; unknown or expired codes are
  rejected at placement.
- Orders can be cancelled within 30 minutes of placement while `PENDING`.
