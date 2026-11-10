# Design

Roles, a permission matrix and a UI to manage them, on top of Pundit. Pundit stays the place where authorization
is checked; the gem owns roles and their assignments, decides what a subject is allowed to do, enforces who may
change whose roles and gives the host app the answers.

- Name `pundit-matrix`, MIT licence, the author's own repo on GitHub.
- Ruby >= 3.2, Rails >= 7.2. CI runs against every supported Rails minor version.
- Independent of any admin framework. The gem has no pages of its own, see [UI](#ui).

## Terms

- **Subject** - whatever the host app authorizes, the object Pundit receives as `user`. Usually `User`, but the gem
  must not assume it. Any model becomes a subject by calling `has_roles`.
- **Screen** - one area of the host app, for example orders, invoices or reports. One screen is one permission.
- **Level** - how much access a role has to a screen: `none`, `read` or `write`. `write` includes `read`.
- **Role** - a named set of screen levels. Roles can share part of their permissions.
- **Position** - a unique number on each role that orders all roles. Used to decide who can manage whom. The gem
  assigns it; nobody types it.

## Screens

- The host app declares its screens in code: key, label (i18n), group, and whether the screen is read-only. The
  matrix stores levels in the database by screen key.
- With ActiveAdmin, the group, the order and the labels come from the admin menu, where the app declares them
  anyway, so the two never drift apart; the initializer keeps the keys and `read_only:`, and what it or the
  translations declare explicitly still wins. The menu is read only when the matrix renders inside the admin, so
  roles, levels and policies never wait for the admin to load.
- Read-only is declared, never inferred from the actions, because a new action would quietly open a write level.
  The screens spec checks instead that a read-only screen offers no action needing write and a writable one has
  one.
- A read-only screen (history of changes, API request log) offers only `none` and `read` in the matrix.
- A screen with no level set for a role means `none`. A new screen is therefore closed for every ordinary role
  until someone opens it in the matrix.
- The levels are fixed. A project cannot add its own.
- Rows for a key the host app no longer declares are ignored. Removing them is up to the project.
- Renaming a screen key needs a data migration in the project, otherwise every ordinary role loses access to it.
  The README shows how.
- A screen too powerful for the matrix (an audit log of every record) is declared with `admin_screen`: admins and
  superadmins read it, nobody writes it, and it never appears in the matrix, so it cannot be granted by mistake.
- Who may see the history of a record is the policy's `history?`, `write?` by default. The gem knows nothing about
  auditing and adds no level for it.
- An action that belongs to another screen is declared with `actions_of_screen` and needs write on that screen, so
  both the policy and the screens spec know where it belongs.

## Three kinds of access

| | Where it lives | Permissions | Can manage |
|---|---|---|---|
| **Superadmin** | the host's subject, read by the gem | everything | everyone, including itself and other superadmins |
| **Admin** | the one admin role, at position 1 | everything, including screens added later | roles, the matrix, and subjects without the admin role |
| **Ordinary role** | rows in the matrix | what the matrix says | subjects whose role is lower, if it has write on the subjects screen |

### Superadmin

- Not a role. The host app owns it: the subject answers `superadmin?`, and `has_roles active_superadmins: -> { ... }`
  gives a scope of active superadmins (by default every subject with a `superadmin` flag). The gem only reads it.
  It never shows up in role lists, the matrix or role selects.
- Only a subject holding the admin role can be a superadmin. The subject concern refuses the flag without the role
  and refuses taking the role from a superadmin; both change together in one save. Removing superadmin leaves an
  ordinary admin.
- A superadmin can change anything and anyone, including itself and other superadmins. Superadmins are trusted
  by definition.
- Only a superadmin can make someone a superadmin or take it away.
- At least one active superadmin must always exist. The gem's subject concern refuses to save or delete the last
  one, but only once a superadmin exists, so a project can start without one.
- When the subject does not answer the superadmin question, the install generator adds a migration with a boolean
  `superadmin` column; a host with its own answer (a column or a method) keeps it. Whether a superadmin record
  actually exists cannot be checked there (the developer's database is not production, and a fresh project has no
  subjects yet), so the gem gives a warning widget for the roles screen that shows while none exists.
  The app keeps working, so deploys and tests do not break.
- The first superadmin is made by `bin/rails pundit_matrix:superadmin EMAIL=...`, or by
  `Pundit::Matrix.setup_superadmin!(subject)` from seeds, a console or a deploy script. Not seeds, because many apps
  never run them and an app that adds the gem after its first deploy cannot. Both are idempotent and run with no
  actor.

### Admin

- Exactly one role, a fixed part of the gem: the role at position 1. There is no flag, so nobody can make another
  role an admin role or stop this one being it. Position 1 is never given to a new role and never changes, so a
  second admin role cannot exist.
- Created by the install migration, so the roles screen has it right after migrating. A database loaded from the
  schema has none, so the superadmin task and `make_admin` create it when it is missing.
- Cannot be deleted by anyone, superadmins included, and never moves.
- Nobody edits it, superadmins included: its name comes from the install, its position is fixed and it has every
  permission. Only a superadmin assigns it.
- Gets every permission automatically, including screens added later. It has no rows in the matrix; its detail shows
  the highest level of every screen, so it reads like any other role.
- Is the only role (besides superadmin) that can manage roles and the matrix. Roles are not a screen in the matrix,
  so managing them cannot be granted to an ordinary role by mistake.
- Cannot touch superadmins or subjects with the admin role, whatever the positions.
- Cannot change its own roles.

### Ordinary role

- Permissions come only from the matrix.
- Positioned below the admin role, from 2 on.

## Roles and their assignments

- Roles, their permissions and their assignments to subjects live in the gem's tables. A project that uses the gem
  has no roles of its own.
- The tables have neutral names: `roles` (name, position), `permissions` (role, screen key, level) and
  `role_assignments` (role, subject).
- When one of them already exists, the install generator stops and offers `--table-prefix`. The prefix goes to
  the gem's configuration and its models read it. Names of individual tables are not configurable.
- The project names each role and sets its permissions. Positions are unique, so it is always clear which of two
  roles is higher. Position 1 is the highest.
- Positions are never typed. A new role gets the next free one, and the order changes only by moving a role one
  step up or down. A move renumbers the ordinary roles gapless in one transaction, first past every position and
  then to the final one, so the unique index never sees two roles on one position; deleting a role closes its gap
  the same way. Each role is saved, with its callbacks, so an audit sees two position changes per role and move.
  The move is a model API, so an app without ActiveAdmin wires its own buttons.
- Move arrows show only on an unfiltered list ordered by position, because elsewhere a move would pass neighbours
  nobody sees.
- A role that is held by any subject cannot be deleted.
- Changing a role's name, order or permissions is done on the roles screen (admins only).
- The host app calls `has_roles` in its subject model. That gives the subject its roles and the validations above.
- The assignment table allows several roles per subject from the start. With more than one, all permissions from
  all roles apply: for each screen the highest level from any of them, and the subject's position is that of its
  highest role. The host's subject form assigns any number of them.
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

### Who enforces what

- The gem enforces the rules on roles in the subject model, so they hold whichever controller, API or form saves
  them. While an actor is known, `role_ids=`, `roles=` and `update(role_ids:)` refuse a subject the actor does not
  manage and the actor's own roles (unless it is a superadmin), and refuse a role the actor cannot assign with a
  validation error on the subject. Roles the actor cannot assign stay as they are when the submitted ids leave them
  out, because the form shows them disabled and does not send them. Only a superadmin changes the `superadmin`
  flag.
- The rules apply only to changes of roles and of the flag. Other changes of a subject (its name, deactivation, a
  password reset) are the host policy's job, so signing in or Devise's own updates of the signed in subject are
  never refused.
- The actor is `pundit_user` of the current request, taken in every controller that includes
  `Pundit::Authorization` and resolved on first use, after the host's authentication. Outside a request the host
  sets it for a block (`Pundit::Matrix::Current.set(actor:)`). With no actor (console, seeds, jobs) nothing is
  restricted, so data fixes and imports keep working.
- An actor that changes itself is judged by what is stored, not by the change it is saving, so nobody grants
  themselves the flag or a role through their own record.
- Who holds which role is visible to those who manage roles: admins and superadmins. While anyone else acts, Ransack
  allows no column of a role or of an assignment, so a subject list cannot be searched by role (by its id, name,
  position). A host shows its role filter only when `access.everything?`, because ActiveAdmin cannot
  render a filter Ransack refuses. With no actor nothing is restricted.
- The subject policy (`subject_screen`) adds `manage?` on the record to the screen levels: `show?` needs read,
  `update?` and `destroy?` need write. It gives the form `role_ids` for anyone who may edit and `superadmin` for a
  superadmin. Custom actions (deactivate, reset password) use its public `manage?`.

Positions and permissions are independent, so a lower role can have a permission a higher one lacks. Keeping the
matrix consistent with the positions is the job of whoever edits it, and only admins edit it.

## Installing into an existing project

- The gem is written for any project. Nothing in it may assume a particular admin framework, subject model, domain or
  existing data, and no example names one project's data.
- `rails generate pundit:matrix:install User` creates the migrations and the initializer, adds `has_roles` to the
  model, `extend Pundit::Matrix::Policy` to an existing base policy and `subject_screen` to an existing subject
  policy, and lists what it cannot find in one list of next steps. The role policy outside a namespace is created only
  without ActiveAdmin, where nothing else would find roles. It reads the schema to check the model and the existing tables, but never runs migrations
  or changes the database.
- When the app has ActiveAdmin, the install generator also runs `rails generate pundit:matrix:active_admin User`. It
  stays available on its own for an app that adds ActiveAdmin later. It writes the roles screen and the role and page
  policies, wires the refusal handler, opens the dashboard, adds `matrix_subject` to the subject resource and writes
  a screens spec, and lists whatever it could not do. ActiveAdmin is not a dependency of the gem.
- Neither generator touches `db/seeds.rb`.
- There is no uninstall. Removing the gem is the project's own job.

## UI

- The gem has no pages, controllers or routes of its own. Roles are an ordinary model, so the host manages them as a
  resource in its own admin (`ActiveAdmin.register Pundit::Matrix::Role` or a plain controller), and lists, forms and
  styling stay native to that admin.
- The gem never asks who is signed in. Its policies get the subject from Pundit, and the rules on saving take it from
  `pundit_user`, so whatever the host passes there (`current_user`, `current_admin_user`) works without
  configuration.
- The host's role policy inherits from `Pundit::Matrix::RolePolicy`: only admins and superadmins manage and move
  ordinary roles, nobody edits or deletes the admin role, and no one is permitted a position. The role answers `policy_class` with `RolePolicy`, because Pundit would otherwise
  look for `Admin::Pundit::Matrix::RolePolicy` in a namespace, and a module `Admin::Pundit` would hide `::Pundit`
  inside the host's admin code.
- The matrix is a widget: `render 'pundit/matrix/levels_fields', role:` in the role form and
  `render 'pundit/matrix/levels', role:` on the role detail. The form sends `levels: { orders: 'read' }`, the host
  permits `levels: {}` and the model saves it.
- Widgets are plain HTML without a layout, so they take the look of the admin they are in. `table_class:` adds the
  admin's own table class. In the form, screen names are plain cells, because admins style every `th` as a header;
  on the detail they are row headers, so inside ActiveAdmin's `.attributes_table` they line up with the details
  above. The look targets ActiveAdmin's default theme; another theme is the app's to override. The matrix
  brings only an inline style scoped to `.pundit-matrix` for what makes it readable (row lines, group headings,
  centred levels, write and read in their own colours, a dash for no access), inline so no asset pipeline is
  involved, with the CSP nonce when the host has one. In ActiveAdmin the role form takes the matrix as one more
  labelled input (`f.matrix_levels_input`), not as a full-width section.
- Once a screen has a group, screens without one get the heading General, so they do not read as part of the group
  above them.
- Who holds a role (`role.holders`, `Role.holder_counts`) is shown only to those who manage roles.
- `render 'pundit/matrix/superadmin_warning', subjects: User` warns on the roles screen while nobody is an active
  superadmin.
- `render 'pundit/matrix/subject_fields', subject: @user` gives the subject form a checkbox per role, with the roles
  the actor cannot assign disabled, and the superadmin checkbox for a superadmin. In ActiveAdmin,
  `f.matrix_subject_inputs` gives the same as ordinary formtastic inputs, so the roles align with the other fields.

### ActiveAdmin

ActiveAdmin is the only admin with an adapter, loaded only when ActiveAdmin is present. It covers what every
ActiveAdmin app would otherwise find out the hard way:

- `matrix_subject` in the subject resource adds the permitted subject attributes to the host's own, shows the role
  filter (declared or default) only to admins and superadmins, because ActiveAdmin cannot render a filter Ransack
  refuses, and lists the roles on the detail.
- A page declares `screen :key`, `admin_screen` or `open_screen` in `register_page`. The page policy reads it, and a
  page that declares nothing is refused, so a new page is closed until someone decides.
- ActiveAdmin finds a single record past the policy scope, so a typed address would open a row the index hides. The
  adapter finds it through the scope.
- A refusal sends someone with a screen back and someone with none to the dashboard, which the generator declares
  open. Signing out instead is the host's choice: it points `on_unauthorized_access` to its own handler.
- The generated screens spec walks every resource and page: each has a screen, an admin screen or an open screen;
  without the level the address is refused, with read it opens and the menu shows only it and nothing can be changed,
  and with write it offers what an admin gets. It also fails on a screen under two menu parents and on levels that
  do not match the actions: a read-only screen with an action needing write, a writable one without any.

### Tests

`require 'pundit/matrix/rspec'` gives a host's specs `grant_levels`, `make_admin` and `make_superadmin` on any
subject, independent of the way the host builds subjects.

## Caching

- A subject's roles and levels are loaded once per request, in two small queries, and reused for every check in that
  request. A superadmin needs none.
- Checks against a list of subjects (`manage?`) read their roles from the association, so a list loaded with
  `includes(:roles)` adds no queries.
- Nothing is cached across requests. A change in the matrix or in a subject's roles applies on the next request.

## Translations

- The gem ships only `en.yml`. Every text it shows, error messages included, is an I18n key under `pundit_matrix`.
- A project translates into any language by defining the same keys in its own locale files.
- A key missing in the current locale falls back to the gem's English, whether or not the host app has I18n
  fallbacks enabled.
- Screen and group labels are the host app's keys `pundit_matrix.screens.<key>` and `pundit_matrix.groups.<key>`;
  without them the key itself is shown, humanized.

## What the gem does and what the host app does

The gem:

- tables for roles, role permissions and role assignments, generators, and the task that makes the first superadmin
- the subject concern: roles of a subject, validations
- resolving a subject's level for a screen
- Pundit integration: the base policy calls `extend Pundit::Matrix::Policy`, each policy declares its screen with
  `screen :orders`; `index?` and `show?` need `read`, everything else needs `write` (`history?` included), custom
  actions (run a job, import) are written as `def import? = write?`, and `admin_screen` and `actions_of_screen`
  cover screens outside the matrix and actions of another screen
- the role policy, the matrix widget and the missing superadmin warning
- the subject screen: its policy (`subject_screen`), the role fields of its form and the rules on saving roles, see
  [Who enforces what](#who-enforces-what)
- helpers: `a.access.manage?(b)`, `a.access.assign?(role)`, `a.access.assignable_roles` and `a.access.any?`, and lint
  helpers for policies without a screen and screens without a policy
- the ActiveAdmin adapter and its generator, used only with ActiveAdmin
- test helpers for the host's specs

The host app:

- the subject model with its active state, and the subject screen: rendering the gem's role fields in its form,
  permitting the attributes the policy gives (done by `matrix_subject` in ActiveAdmin), and which index columns are
  safe
- its screens, which page or policy has which, and the look of its admin
- policy scopes, for example limiting records to those of the subject; `index?` already needs read, so the gem does
  not touch scopes
- applying the same "you cannot give what you do not have" rule to its own data
- audit of changes (paper_trail or anything else, added to the gem's models through their load hooks)
