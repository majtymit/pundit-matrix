# Pundit::Matrix

Roles and a permission matrix for Rails apps that authorize with [Pundit](https://github.com/varvet/pundit).

Every screen of your app is one permission with three levels: no access, read and write. Roles get a level per screen, subjects (usually users) get roles, and your policies ask the matrix. There are no pages of its own: you manage roles in the admin you already have, and the matrix is a partial that takes its look.

You create as many roles as you need; the gem keeps them in order. Access comes in three kinds:

- **Superadmin** – a flag on the subject, held only together with the admin role. Has everything and manages everyone, including other superadmins.
- **The admin role** – one role, part of the gem, always first. Has every screen, including later ones, and manages roles and every subject below admin.
- **Ordinary roles** – every other role. Has what the matrix says and manages only subjects with a lower role.

Requires Ruby 3.2+, Rails 7.2+ and Pundit 2.3+.

## Installation

```bash
bundle add pundit-matrix
bin/rails generate pundit:matrix:install User
bin/rails db:migrate
bin/rails pundit_matrix:superadmin EMAIL=you@example.com
```

The install generator creates the migration for the `roles`, `permissions` and `role_assignments` tables, which also creates the admin role, and an initializer, and adds `has_roles` to the model, below the comment that describes the class or after its last `include` or `extend`. It adds `extend Pundit::Matrix::Policy` to an existing `app/policies/application_policy.rb` and turns `screen` into `subject_screen` in an existing policy of the subject (or adds `subject_screen :users`); what it cannot find, it lists. Without ActiveAdmin it also creates `app/policies/role_policy.rb`, the policy Pundit finds for roles. When the model does not answer `superadmin?` yet, it also adds a migration with a boolean `superadmin` column. Primary keys follow your app's generator settings, so UUID apps get UUID tables. When one of the tables already exists, it stops and asks for `--table-prefix=matrix_`. When the app has ActiveAdmin, it also does what [the ActiveAdmin generator](#activeadmin) does, and prints one list of what is left, in the order you do it.

The last command makes that subject a superadmin holding the admin role, see [Superadmin](#superadmin).

What is left for you to write is your screens, your scopes and a few lines:

```ruby
class ApplicationController < ActionController::Base
  include Pundit::Authorization
end

class ApplicationPolicy
  extend Pundit::Matrix::Policy
end

class OrderPolicy < ApplicationPolicy
  screen :orders
end

class UserPolicy < ApplicationPolicy
  subject_screen :users
end
```

Without ActiveAdmin, your subject form renders `pundit/matrix/subject_fields`, your controller permits `permitted_subject_attributes`, and your roles screen renders the matrix ([Managing roles](#managing-roles), [Managing subjects](#managing-subjects)). With ActiveAdmin, the gem registers the roles screen and the subject form needs `f.matrix_subject_inputs`, see [ActiveAdmin](#activeadmin).

## Subjects

```ruby
class User < ApplicationRecord
  has_roles active_superadmins: -> { where(superadmin: true, deactivated_at: nil) }
end
```

`has_roles` gives the model `roles`, `role_assignments` and `access`, and defines the `active_superadmins` scope. Without the argument, every subject with `superadmin: true` counts as an active superadmin.

Once a superadmin exists, the last active one cannot lose the flag, be deactivated or be deleted.

### Superadmin

Superadmin is a flag on the subject, and only a subject holding the admin role can have it: setting the flag without the role fails, and so does taking the admin role from a superadmin. Give the role and the flag in one save, or take both away in one save.

`bin/rails pundit_matrix:superadmin EMAIL=you@example.com` finds the subject by its email (`MODEL=Account` for another model; an unknown email or model stops with a plain message), creates the admin role when there is none (a database loaded from the schema has none) and gives the subject the superadmin flag and that role. It is safe to run again, on any environment and at any time, also long after the first deploy.

From seeds, a console or a deploy script, call what the task calls:

```ruby
Pundit::Matrix.setup_superadmin!(User.find_by!(email: 'you@example.com'))
```

## Screens

Declare your screens in `config/initializers/pundit_matrix.rb`: their keys and which are read-only. That is what roles, levels and policies need, in requests, the console, seeds and jobs alike. Groups are optional and only arrange the matrix; once there is one, screens outside every group are listed under General (`pundit_matrix.ungrouped`).

```ruby
Pundit::Matrix.configure do |config|
  config.screens do
    group :sales do
      screen :orders
      screen :invoices
    end

    group :access do
      screen :users
      screen :reports, read_only: true
    end
  end
end
```

A read-only screen offers no access and read only. A new screen is closed for every ordinary role; the admin role and superadmins get it automatically.

With ActiveAdmin, the matrix takes the rest from the admin menu, so the initializer shrinks to the keys:

```ruby
config.screens do
  screen :orders
  screen :invoices
  screen :users
  screen :reports, read_only: true
end
```

A screen's group is the menu parent of the registration whose policy or page declares it, groups follow the parents' menu priority and screens within a group their items' priority, and the headings fall back to the menu labels, as text only when a label renders an icon. What the initializer (`group`) or the translations (`pundit_matrix.groups.*`, `pundit_matrix.screens.*`) declare still wins. The menu is read only where the matrix is rendered inside the admin, so nothing else waits for ActiveAdmin to load. When a screen spans several registrations, the one shown in the menu gives its place; if they sit under different parents, [the screens spec](#the-screens-spec) fails.

## Policies

Extend your base policy once and declare the screen in each policy:

```ruby
class ApplicationPolicy
  extend Pundit::Matrix::Policy
end

class OrderPolicy < ApplicationPolicy
  screen :orders

  def import?
    write?
  end
end
```

`index?` and `show?` need read, `new?`, `create?`, `edit?`, `update?` and `destroy?` need write, and `history?` (who may see the history of a record) needs write too. Your own actions use `read?` or `write?`, or `write?(:invoices)` for another screen. Whatever the policy defines itself wins. The gem knows nothing about auditing; `history?` only answers who may see it. Scopes stay yours: someone without read does not get past `index?`, so use them for anything finer.

An action that belongs to another screen says so, and needs write there unless the policy defines it:

```ruby
class InvoicePolicy < ApplicationPolicy
  screen :invoices
  actions_of_screen :orders, :reopen_order
end
```

A screen too powerful for the matrix, such as an audit log of every record, is for admins and superadmins only. They read it, nobody writes it, and it never shows up in the matrix:

```ruby
class AuditLogPolicy < ApplicationPolicy
  admin_screen
end
```

Outside policies, ask the subject. Its roles and levels are loaded once per object, in two small queries:

```ruby
current_user.access.level(:orders)  # => :none, :read or :write
current_user.access.read?(:orders)
current_user.access.write?(:orders)
current_user.access.any?         # read on at least one screen, always true for admins and superadmins
current_user.access.everything?  # an admin or a superadmin, who manages roles and sees who holds them
```

## Managing roles

Roles are an ordinary model, `Pundit::Matrix::Role`, with `name` and `position` (unique, 1 is the highest). With ActiveAdmin the gem registers the screen ([The roles screen](#the-roles-screen)); in another admin, build it like any other resource. `Pundit::Matrix::RolePolicy` lets admins and superadmins manage and move ordinary roles; nobody edits the admin role. Pundit finds it through `RolePolicy` (or `Admin::RolePolicy` in a namespace), which the generators create, because the role answers `policy_class`. Permit what the policy allows: `permitted_attributes` gives `name` and `levels`, never `position`. A role held by a subject cannot be deleted.

### The admin role

The role at position 1 is the admin role, `Pundit::Matrix::Role.admin_role`, and nothing else marks it. It has every screen without rows of its own: its detail shows the highest level of each screen, and its form has no matrix. Its position never changes, it never moves, and `destroy` refuses it whoever calls it, from the console too. As no other role can get position 1, there is never a second one. Its name comes from the install and the policy lets nobody edit it, superadmins included, since there is nothing left to change.

### Positions

Nobody types a position. A new role gets the next free one (`Role.new.position`, the highest + 1, at least 2), and the order changes only by moving a role one step:

```ruby
role.movable_up?    # false for the first ordinary role and for the admin role
role.movable_down?  # false for the last ordinary role and for the admin role
role.move_up        # true when it moved
role.move_down
```

A move renumbers every ordinary role gapless (2, 3, 4…) in one transaction, and deleting a role closes its gap the same way. Saving a changed position is refused, and a position passed to `create` is replaced by the next free one. Authorize moves with the policy's `move_up?` and `move_down?`.

Show the arrows only on a list that is not filtered and is ordered by position, otherwise a move passes neighbours nobody sees. The roles screen the gem registers in ActiveAdmin does that and shows the position in its form as a disabled field.

Put the matrix into the role form and onto the role detail:

```erb
<%= render 'pundit/matrix/levels_fields', role: @role %>
<%= render 'pundit/matrix/levels', role: @role %>
```

Both are plain tables that take your admin's look; pass `table_class:` to use its table style. On the detail, screen names are row headers, so inside ActiveAdmin's `div.attributes_table` (as the gem's roles screen renders it) the levels line up with the details above. `role.level(screen)` gives the level the detail shows. In an ActiveAdmin role form, `f.matrix_levels_input` inside `f.inputs` adds the matrix as one more labelled input, as wide as the text inputs above it.

### Customizing the look

The matrix brings a small inline style made for ActiveAdmin's default theme, with the nonce of your content security policy when it has one: a line between rows and centred levels in the form (on the detail the attributes table draws the rows), bold group headings with more space above them, write in green, read in orange and a dash for no access on the detail. Its rules are kept at low specificity, so one rule in your own stylesheet overrides any of them:

- `.pundit-matrix` – the table, in the form and on the detail
- `.pundit-matrix-levels` – the form field holding it, where the table is as wide as ActiveAdmin's text inputs, `calc(80% - 22px)`
- `.pundit-matrix-level` – the level columns of the form, 20% each, the rest going to the screen names
- `.pundit-matrix-write`, `.pundit-matrix-read`, `.pundit-matrix-none` – the levels on the detail
- `th[scope="rowgroup"]` – the group headings

A theme with other input widths sets the matrix to match. arctic_admin, for one, gives its inputs 50%:

```scss
.pundit-matrix-levels .pundit-matrix { width: 50%; }
```

On the detail, the column of screen names is ActiveAdmin's `.attributes_table th`; widen it in your stylesheet and the details and the matrix follow together.

The form sends `role[levels][orders]=read`, so `@role.update(permitted_attributes(@role))` saves it. For another parameter name, pass `scope: 'pundit_matrix_role'` to the partial.

Who holds a role is for those who manage roles. `role.holders` lists its subjects and `Pundit::Matrix::Role.holder_counts(roles)` counts them for a whole list in one query, keyed by role id; show them only when `access.everything?`.

Warn on the roles screen while nobody is an active superadmin:

```erb
<%= render 'pundit/matrix/superadmin_warning', subjects: User %>
```

## Managing subjects

Subjects are compared by their highest role. You can manage a subject only when its role is strictly lower than yours, and assign only roles strictly lower than yours. Admins never manage other admins, nobody but a superadmin changes their own roles, and a superadmin manages everyone.

```ruby
current_user.access.manage?(user)     # may show, edit, deactivate or change roles of user
current_user.access.assign?(role)     # may give this role
current_user.access.assignable_roles  # roles for a select, highest first
```

Declare the subject screen with `subject_screen` instead of `screen`:

```ruby
class UserPolicy < ApplicationPolicy
  subject_screen :users

  def deactivate?
    write? && manage? && !record.deactivated?
  end

  def permitted_attributes
    [:email, :name, *permitted_subject_attributes]
  end
end
```

Only admins and superadmins may search subjects by role. For anyone else, Ransack allows no column of a role or an assignment and silently drops such a condition, so offer a role filter only when `access.everything?`. With ActiveAdmin, `matrix_subject` does that for you; a role filter you write yourself needs the `if:`:

```ruby
filter :roles, as: :select, collection: -> { Pundit::Matrix::Role.ordered.pluck(:name, :id) },
               if: proc { current_active_admin_user.access.everything? }
```

Without it, the subject index fails for everyone else with `undefined method 'roles_id_eq' for an instance of Ransack::Search`, because ActiveAdmin cannot render a filter Ransack refuses.

`index?` needs read and `create?` needs write, `show?` needs read and `update?` and `destroy?` need write, and all three need `manage?` on the record too. `manage?` is public for your own actions and allows everything on the class, where ActiveAdmin and index checks pass no record. `permitted_subject_attributes` gives `role_ids: []` to whoever may edit and `superadmin` to a superadmin only. `manage?` reads the other subject's roles from the association, so load lists with `includes(:roles)`.

Put the roles into the subject form:

```erb
<%= render 'pundit/matrix/subject_fields', subject: @user %>
```

It shows a checkbox per role, highest first. Roles you cannot assign are disabled, and the ones the subject holds stay checked. A hidden empty value lets you uncheck every role, and the superadmin checkbox shows only to a superadmin. Pass `scope:` for another parameter name, as with the matrix.

### Who acts

The rules hold when roles are saved, whichever controller or API saves them. The gem takes the one who acts from `pundit_user` in every controller that includes `Pundit::Authorization`, on first use, so your authentication runs first. Elsewhere, set it for a block:

```ruby
Pundit::Matrix::Current.set(actor: user) do
  account.update(role_ids:)
end
```

While someone acts, `role_ids=`, `roles=` and `update(role_ids:)`:

- refuse a subject the actor does not manage, and the actor's own roles unless it is a superadmin
- refuse a role the actor cannot assign, with a validation error on the subject
- keep the roles the actor cannot assign when the submitted ids leave them out, as a form with disabled checkboxes does

and only a superadmin changes the `superadmin` flag. With no actor, in the console, seeds or jobs, nothing is restricted.

## Extending the models

Each model runs a load hook once it loads, so you add an audit or anything else without reopening the class:

```ruby
ActiveSupport.on_load(:pundit_matrix_role_assignment) do
  has_paper_trail
end
```

The hooks are `:pundit_matrix_role`, `:pundit_matrix_permission` and `:pundit_matrix_role_assignment`. Changing roles
through `role_ids=` destroys the assignments it drops, so their callbacks run. Moving a role up or down saves every
ordinary role twice, to a temporary and then to its final position, so an audit records two position changes per role
and move.

Ransack can search roles by their own columns and assignments by role, while no one acts or the actor is an admin
or a superadmin. To filter subjects by role, add `roles` and `role_assignments` to the subject's
`ransackable_associations` and see [Managing subjects](#managing-subjects).

## ActiveAdmin

The adapter loads only when the app has ActiveAdmin (3.x with `ActiveAdmin::PunditAdapter`); the rest of the gem does not need it. `bin/rails generate pundit:matrix:active_admin User` (`--namespace` defaults to `admin`), also run by the install generator:

- creates `Admin::RolePolicy`, the policy ActiveAdmin finds for roles; the roles screen itself comes from the gem ([The roles screen](#the-roles-screen))
- creates `Admin::ActiveAdmin::PagePolicy`, which reads what each page declares; when you let it replace a page policy of your own, it reminds you that what that policy decided now belongs in each `register_page`
- turns `screen` into `subject_screen` in `Admin::UserPolicy`
- points `config.on_unauthorized_access` to `:pundit_matrix_access_denied`, unless you have a handler of your own
- declares the Dashboard open to everyone signed in
- adds `matrix_subject` to `ActiveAdmin.register User`
- writes the short `spec/requests/admin/pundit_matrix_screens_spec.rb` when the app has specs ([The screens spec](#the-screens-spec))

and lists what it could not do. What stays yours:

```ruby
module Admin
  class UserPolicy < ApplicationPolicy
    subject_screen :users
  end
end

ActiveAdmin.register User do
  matrix_subject
  menu parent: 'access', priority: 2 # the matrix lists users under this parent, in this order

  permit_params :email

  form do |f|
    f.inputs do
      f.input :email
      f.matrix_subject_inputs
    end
    f.actions
  end
end

ActiveAdmin.register_page 'Reports' do
  screen :reports
end
```

### The roles screen

The gem registers the roles screen in ActiveAdmin's default namespace, as `ActiveAdmin.register Pundit::Matrix::Role` at `/admin/roles`: the matrix in the form and on the detail, the missing superadmin warning, move arrows in the position column, the number of holders on the index and their list on the detail (linked where the actor may open them), and the translated model name in the breadcrumb. It is open to admins and superadmins only. It is the gem's code, so a new version brings its changes and the gem's own specs cover it; your app neither copies nor tests it.

To change the menu or another small thing, reopen it in a file of your own, such as `app/admin/roles.rb`:

```ruby
ActiveAdmin.register Pundit::Matrix::Role do
  menu parent: 'access', priority: 2
end
```

The gem registers its screen before ActiveAdmin loads your files, on every load, a reload in development included, so what the block sets wins whatever the file is called. A role registration without `as:` is named `Role`, so the block reopens the gem's screen instead of adding a second one at `/admin/pundit_matrix_roles`. What the block declares goes next to what the gem declares: `menu`, `config.sort_order`, `index`, `show` or `form` replace the gem's, while a `filter`, `sidebar`, `action_item` or `member_action` is added to them.

For a screen of your own, eject it:

```bash
bin/rails generate pundit:matrix:roles_screen
```

The generator copies the gem's screen into `app/admin/roles.rb` and sets `config.roles_screen = false` in `config/initializers/pundit_matrix.rb`, so the gem no longer registers its own. From then on the screen is your app's code: a new version of the gem does not change it, and testing and maintaining it are yours, like any other file in `app/admin`. Eject it also to put it in another namespace than the default one, and add `namespace:` to the registration.

### Subjects

`matrix_subject` adds the attributes the subject policy permits (`role_ids`, and `superadmin` for a superadmin) to whatever `permit_params` permits, and shows the roles in a sidebar on the detail. It also puts the role filter on the index for admins and superadmins only: it adds `filter :roles` when you have not declared it, and when you have (or ActiveAdmin adds it by default), it sets its `if:` to `access.everything?`, replacing any `if:` of your own. ActiveAdmin cannot render a filter that Ransack refuses, so without that the index would fail for everyone else ([Managing subjects](#managing-subjects)). The rest of your filters stay as they are.

In the form, `f.matrix_subject_inputs` inside `f.inputs` adds the roles as formtastic check boxes, stacked in position order and aligned with your other inputs, with the roles the actor cannot assign disabled and a hidden empty value so every role can be unchecked, and below them the superadmin flag for a superadmin. Apps without ActiveAdmin render `pundit/matrix/subject_fields` instead.

### Pages

A page declares its screen inside `register_page`: `screen :reports`, `admin_screen` for admins and superadmins only, or `open_screen` for everyone signed in. A page that declares nothing is refused to everyone, superadmins included. For a page action, define its predicate in your `Admin::ActiveAdmin::PagePolicy`; `write?` there means write on the screen of the page.

### Records past the scope

ActiveAdmin finds a single record (show, edit and member actions) without the policy scope, so a typed address would open a record the index hides. With the adapter it finds it through the policy scope, and a record outside it is not found.

### Refusals

ActiveAdmin calls the method named in `config.on_unauthorized_access` whenever a policy refuses. The generator sets it to the gem's handler:

```ruby
# config/initializers/active_admin.rb
ActiveAdmin.setup do |config|
  config.on_unauthorized_access = :pundit_matrix_access_denied
end
```

`pundit_matrix_access_denied` sends someone with at least one screen back where they came from and someone with no screen to the dashboard, both with ActiveAdmin's message. The dashboard must stay open (`open_screen`), otherwise someone with no screen is refused there again. To decide it yourself, point the setting to a public method of your own; nothing in the gem changes:

```ruby
class ApplicationController < ActionController::Base
  def access_denied(exception)
    return redirect_back_or_to(admin_root_path, alert: exception.message) if current_user.access.any?

    sign_out(current_user)
    redirect_to new_user_session_path, alert: exception.message
  end
end

# config/initializers/active_admin.rb: config.on_unauthorized_access = :access_denied
```

When the app already sets `on_unauthorized_access`, the generator keeps it and only names the gem's handler in its output.

### The screens spec

`require 'pundit/matrix/rspec'` brings the shared examples `'Pundit::Matrix screens'`, which hold every resource and page of a namespace to the matrix. The generator writes `spec/requests/admin/pundit_matrix_screens_spec.rb`, which holds only what your app decides:

```ruby
require 'rails_helper'
require 'pundit/matrix/rspec'

RSpec.describe 'Pundit::Matrix screens of admin', type: :request do
  include Devise::Test::IntegrationHelpers

  it_behaves_like 'Pundit::Matrix screens',
                  namespace: :admin,
                  except: %w[Comment],
                  create_subject: -> { create(:user) }
end
```

- `namespace` – the ActiveAdmin namespace the examples walk; ActiveAdmin's default namespace when left out.
- `except` – the names of the resources and pages that knowingly stay outside the matrix, such as ActiveAdmin's comments; every check leaves them out. Empty when left out.
- `create_subject` – builds a new subject without roles. The examples call it many times and run it inside the example, so FactoryBot's `create` and your own helpers work there.

The examples sign subjects in with `sign_in(subject)`, which Devise's `IntegrationHelpers` give. Without Devise, define `sign_in` in the spec; the generated one has a stub that says so.

Each resource and page needs a screen, an admin screen or an open screen. Without the level its address is refused; with read it opens, the menu shows only screens with that key, and it offers no change and no action. With write it offers what an admin gets, and actions of another screen go to whoever writes there. Admin screens open to admins only and open screens to everyone signed in. The examples also fail when a screen sits under two menu parents, when a read-only screen offers an action that needs write (`create`, `update` or `destroy` the controller defines and the policy, asked about the class, does not switch off, a member or collection action other than GET, or a page action other than GET), and when a writable screen has no such action, so its write level would grant nothing. An action of another screen (`actions_of_screen`) counts for that screen. Read-only stays declared, never inferred from the actions, so a new action never quietly opens a write level. A failure names the screen, or the screen and action, that broke.

## Testing

`require 'pundit/matrix/rspec'` (or include `Pundit::Matrix::TestHelpers` yourself) gives your specs:

```ruby
grant_levels(user, orders: :read, invoices: :write)  # through a role of its own
make_admin(user)
make_superadmin(user)
```

They work on any subject you already have, whatever builds it, and return it.

## Checking the policies

Two helpers fit a one-line spec in your app. They load the app eagerly to find every policy:

```ruby
expect(Pundit::Matrix::Lint.policies_without_screen(ApplicationPolicy, except: [HealthCheckPolicy])).to be_empty
expect(Pundit::Matrix::Lint.unused_screens(ApplicationPolicy)).to be_empty
```

The first lists the named policies built on `ApplicationPolicy` that declare neither a screen nor `admin_screen`, the second the declared screens no such policy uses.

## Translations

The gem ships English only. Every text is under `pundit_matrix` and falls back to the gem's English when the current locale lacks it:

```yaml
sk:
  pundit_matrix:
    admin_role: Admin rola má všetky práva, aj na obrazovky pridané neskôr.
    admin_role_name: Admin
    no_superadmin: Zatiaľ nie je žiadny aktívny superadmin.
    move_up: Posunúť vyššie
    move_down: Posunúť nižšie
    holder_count: Počet osôb
    holders: Držitelia
    ungrouped: Všeobecné
    no_holders: Túto rolu nemá nikto.
    levels:
      none: Žiadny prístup
      read: Čítanie
      write: Zápis
    errors:
      admin_position: ostáva 1, admin rola je prvá
      position_moved_only: sa mení len posunutím roly vyššie alebo nižšie
      admin_role_kept: Admin rolu nemožno zmazať
      screen_not_declared: nie je deklarovaná
      level_not_offered: nie je na tejto obrazovke dostupný
      admin_role: má už všetky práva
      last_superadmin: Musí ostať aspoň jeden aktívny superadmin
      roles_not_managed: Tieto roly môže zmeniť len niekto s vyššou rolou
      own_roles: Vlastné roly môže meniť len superadmin
      role_not_assignable: obsahujú rolu %{role}, ktorú nemôžete prideliť
      superadmin_only: môže zmeniť len superadmin
      superadmin_without_admin_role: potrebuje admin rolu
      admin_role_of_superadmin: musia obsahovať admin rolu superadmina
    screens:
      orders: Objednávky
    groups:
      sales: Predaj
```

Screens and groups without a translation show their humanized key.

## Renaming and removing screens

Levels are stored by screen key. Renaming a key needs a migration that moves them, otherwise ordinary roles lose the screen (mind your table prefix):

```ruby
execute "UPDATE permissions SET screen = 'sales_orders' WHERE screen = 'orders'"
```

Levels of screens you no longer declare are ignored; delete them whenever you like:

```ruby
Pundit::Matrix::Permission.where.not(screen: Pundit::Matrix.screens.map(&:key)).delete_all
```

## Upgrading from 0.6.0

The roles screen and the screens checks moved into the gem, so your app no longer keeps copies of them.

- Delete `app/admin/roles.rb` unless you changed more than its menu. If you changed only the menu, keep it as a reopening block with just your `menu` line, see [The roles screen](#the-roles-screen). If you changed more, run `bin/rails generate pundit:matrix:roles_screen`, let it overwrite the file, and port your changes into it; it also sets `config.roles_screen = false`.
- A roles screen generated for another namespace than ActiveAdmin's default one has to be ejected the same way, with `namespace:` kept in the registration.
- Replace `spec/requests/admin/pundit_matrix_screens_spec.rb` with the short one from [The screens spec](#the-screens-spec): `outside_the_matrix` becomes `except:`, the body of `create_subject` becomes `create_subject:`, and a `sign_in` of your own stays in the spec.
- Drop `app/admin/roles.rb` from your coverage filters if you excluded it there.

## Development

```bash
bin/setup
bin/ci
```

`bin/ci` runs RuboCop, Markdown lint, the specs with full line coverage, Brakeman and bundler-audit. Other Rails versions run with `BUNDLE_GEMFILE=gemfiles/rails_7_2.gemfile`.

## Contributing

Bug reports and pull requests are welcome on [GitHub](https://github.com/majtymit/pundit-matrix). Contributors are expected to follow the [code of conduct](https://github.com/majtymit/pundit-matrix/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
