# Design

Roles, a permission matrix and a UI to manage them, on top of Pundit. Pundit stays the place where authorization
is checked; the gem owns roles and their assignments, decides what a subject is allowed to do and gives the host
app the answers.

- Name `pundit-matrix`, MIT licence, the author's own repo on GitHub.
- Ruby >= 3.2, Rails >= 7.2. CI runs against every supported Rails minor version.
- Independent of any admin framework. The UI is a Rails engine rendered in the host app's layout.

## Terms

- **Subject** - whatever the host app authorizes, the object Pundit receives as `user`. Usually `User`, but the gem
  must not assume it. Any model becomes a subject by calling `has_roles`.
- **Screen** - one area of the host app, for example branches, reservations or settings. One screen is one permission.
- **Level** - how much access a role has to a screen: `none`, `read` or `write`. `write` includes `read`.
- **Role** - a named set of screen levels. Roles can share part of their permissions.
- **Position** - a unique number on each role that orders all roles. Used to decide who can manage whom.

## Screens

- The host app declares its screens in code: key, label (i18n), group in the menu, and whether the screen is
  read-only. The matrix stores levels in the database by screen key.
- A read-only screen (history of changes, API request log) offers only `none` and `read` in the matrix.
- A screen with no level set for a role means `none`. A new screen is therefore closed for every ordinary role
  until someone opens it in the matrix.
- The levels are fixed. A project cannot add its own.
- Rows for a key the host app no longer declares are ignored and can be removed by a rake task.
- Renaming a screen key needs a data migration, otherwise every ordinary role loses access to it. The gem gives a
  helper for that migration.

## Three kinds of access

| | Where it lives | Permissions | Can manage |
|---|---|---|---|
| **Superadmin** | the host's subject, read by the gem | everything | everyone, including itself and other superadmins |
| **Admin** | `admin` flag on a role | everything, including screens added later | roles, the matrix, and subjects without an admin role |
| **Ordinary role** | rows in the matrix | what the matrix says | subjects whose role is lower, if it has write on the subjects screen |

### Superadmin

- Not a role. The host app owns it: the subject answers `superadmin?`, and `has_roles active_superadmins: -> { ... }`
  gives a scope of active superadmins (by default every subject with a `superadmin` flag). The gem only reads it. It never shows up in role
  lists, the matrix or role selects.
- Typically a superadmin also holds an admin role. Removing superadmin leaves an ordinary admin.
- A superadmin can change anything and anyone, including itself and other superadmins. Superadmins are trusted
  by definition.
- Only a superadmin can make someone a superadmin or take it away.
- At least one active superadmin must always exist. The gem's subject concern refuses to save or delete the last
  one, but only once a superadmin exists, so a project can start without one.
- The install generator refuses to run when the subject does not answer the superadmin question, and says what to
  add. Whether a superadmin record actually exists cannot be checked there (the developer's database is not
  production, and a fresh project has no subjects yet), so the roles screen shows a warning while none exists.
  The app keeps working, so deploys and tests do not break.

### Admin

- A role with the `admin` flag.
- Only a superadmin can create a role with the flag, remove the flag, or assign an admin role.
- Gets every permission automatically, including screens added later. It has no row in the matrix.
- Is the only kind of role (besides superadmin) that can open the roles screen and the matrix. The roles screen is
  not part of the matrix, so it cannot be granted to an ordinary role by mistake.
- Admin roles are positioned above every ordinary role.
- Cannot touch superadmins or subjects with an admin role, whatever the positions.
- Cannot change its own roles.

### Ordinary role

- Permissions come only from the matrix.
- Positioned below every admin role.

## Roles and their assignments

- Roles, their permissions and their assignments to subjects live in the gem's tables. A project that uses the gem
  has no roles of its own.
- The tables have neutral names: `roles` (name, position, admin flag), `permissions` (role, screen key, level) and
  `role_assignments` (role, subject).
- When one of them already exists, the install generator stops and offers `--table-prefix`. The prefix goes to
  the gem's configuration and its models read it. Names of individual tables are not configurable.
- The project names each role, sets its permissions and its position. Positions are unique, so it is always clear
  which of two roles is higher. Position 1 is the highest.
- A role that is held by any subject cannot be deleted.
- Changing a role's name, position or permissions is done on the roles screen (admins only).
- The host app includes the gem's concern in its subject model. That gives the subject its roles and the
  validations above.
- The assignment table allows several roles per subject from the start. With more than one, all permissions from
  all roles apply: for each screen the highest level from any of them, and the subject's position is that of its
  highest role. Allowing a second role in the UI is a later step (see nice-to-have); the first version assigns one.
- A subject with no role is allowed and sees nothing.

## Who can manage whom

Subjects are compared by the position of their role, not by their permissions. Permissions can be combined in any
way, positions are explicit.

- You can manage a subject (show, edit, deactivate, change roles) only if its role is strictly lower than yours.
  Two subjects with the same role cannot manage each other, so colleagues cannot demote each other.
- You can assign only a role strictly lower than yours. You never create something you then could not manage.
- Nobody except a superadmin changes their own roles.
- Superadmin is the exception to all of the above and manages everyone.
- Subjects you cannot manage are still listed on the index, but only with safe, non-sensitive columns, without a
  detail page and without any action. This applies to admins looking at superadmins too.

Positions and permissions are independent, so a lower role can have a permission a higher one lacks. Keeping the
matrix consistent with the positions is the job of whoever edits it, and only admins edit it.

## Installing into an existing project

- The gem is written for any project. Nothing in it may assume a particular
  admin framework, subject model or existing data.
- The install generator only creates files (initializer, migrations, routes). It never runs migrations and
  never touches the database.
- There is no uninstall. Removing the gem is the project's own job.

## Caching

- A subject's resolved permissions are loaded once per request, in one query, and reused for every check in that
  request.
- Nothing is cached across requests. A change in the matrix or in a subject's roles applies on the next request.

## Translations

- The gem ships only `en.yml`. Every text in the UI is an I18n key under the gem's namespace.
- A project translates into any language by defining the same keys in its own locale files.
- A key missing in the current locale falls back to the gem's English, whether or not the host app has I18n
  fallbacks enabled.
- Screen labels are the host app's keys, the gem only looks them up.

## What the gem does and what the host app does

The gem:

- tables for roles, role permissions and role assignments, migration generators
- the subject concern: roles of a subject, validations
- resolving a subject's level for a screen
- Pundit integration: the base policy calls `extend Pundit::Matrix::Policy`, each policy declares its screen with
  `screen :branches`; `index?` and `show?` need `read`, everything else needs `write`, and custom actions (run a job,
  unblock, import) are written as `def import? = write?`
- the roles and matrix UI as an engine
- helpers for the host's subject screen: may A manage subject B, which roles may A assign

The host app:

- the subject model with its superadmin and active state, and the subject screens, including the role field in
  the subject form (using the gem's helpers) and which index columns are safe
- hiding menu items (through the policy)
- record-level scoping, for example limiting data to the subject's branches in a policy `Scope`
- applying the same "you cannot give what you do not have" rule to its own data, for example branches
- audit of changes (paper_trail or anything else on the gem's models)
