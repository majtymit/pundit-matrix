# Nice to have

Ideas we want to keep but are not building now.

- **Several roles per subject with expiry.** A subject gets a second role, for example for a week of holiday
  cover, with an end date after which it stops granting permissions, so nobody has to remove it by hand. The
  assignment table already allows several roles; this adds the UI and an expiry date on the assignment. The date
  is inclusive, an expired role stops applying on the next request without a background job, and admin roles
  cannot expire.
