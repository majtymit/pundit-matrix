# Changelog

## 1.0.0 - 2026-11-26

First stable release. The public API is what the README describes; breaking it from now on means a major version.

- In ActiveAdmin the actor is `current_active_admin_user`, even when `ApplicationController` does not include
  `Pundit::Authorization`; before, the admin could run with no actor and restrict nothing
- In a request with nobody signed in, no role and no superadmin flag can change; with no actor at all (console, seeds,
  jobs) nothing is restricted as before
- Deleting a subject destroys its role assignments through their callbacks, so an audit of them sees it
- `matrix_subject` preloads the roles of the listed subjects
- After a save that takes away the actor's own access to the record, such as a superadmin dropping their own flag,
  ActiveAdmin goes to the list instead of the detail, or to the dashboard when the list is refused as well
- `pundit_matrix_access_denied` sends someone refused by the page they came from to the dashboard instead of back
  to that page, which redirected to itself forever
- The last superadmin error of a save that drops the flag is on `superadmin`, so the form shows it at the flag;
  a deactivation or delete keeps it on `base`
- The header of the form's matrix is sticky; `--pundit-matrix-header-offset` and
  `--pundit-matrix-header-background` set where it stops and its background
