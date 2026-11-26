# Pundit::Matrix

Roles and a permission matrix for Rails apps that authorize with [Pundit](https://github.com/varvet/pundit).

Every screen of your app is one permission with three levels: no access, read and write. Roles get a level per screen, subjects (usually users) get roles, and your policies ask the matrix. The gem has no pages of its own: roles live in the admin you already have, and the matrix is a partial. With ActiveAdmin, the gem registers the roles screen for you.

- **Superadmin** – a flag on the subject, held only together with the admin role. Has everything and manages everyone.
- **The admin role** – the first role, created by the install. Has every screen, manages roles and every subject below admin.
- **Ordinary roles** – have what the matrix says and manage only subjects with a lower role.

Requires Ruby 3.2+, Rails 7.2+ and Pundit 2.3+. The ActiveAdmin adapter works with ActiveAdmin 3.x.

## Installation

```bash
bundle add pundit-matrix
bin/rails generate pundit:matrix:install User
bin/rails db:migrate
bin/rails pundit_matrix:superadmin EMAIL=you@example.com
```

The generator creates the migrations (the `roles`, `permissions` and `role_assignments` tables with the admin role, and a `superadmin` column when the model has none) and the initializer, adds `has_roles` to the model, `extend Pundit::Matrix::Policy` to `ApplicationPolicy` and `subject_screen` to the subject's policy. With ActiveAdmin it also runs [the ActiveAdmin generator](#activeadmin). It prints what it could not do. When one of the tables already exists, pass `--table-prefix=matrix_`.

What is left are your screens:

```ruby
class ApplicationController < ActionController::Base
  include Pundit::Authorization
end

class OrderPolicy < ApplicationPolicy
  screen :orders
end
```

## Subjects

```ruby
class User < ApplicationRecord
  has_roles active_superadmins: -> { where(superadmin: true, deactivated_at: nil) }
end
```

`has_roles` adds `roles`, `role_assignments`, `access` and the `active_superadmins` scope (every subject with `superadmin: true` without the argument). The last active superadmin cannot lose the flag, be deactivated or be deleted.

The superadmin flag needs the admin role, so give or take both in one save. `bin/rails pundit_matrix:superadmin EMAIL=you@example.com` (`MODEL=Account` for another model) does it and creates the admin role when there is none; it is safe to run again. From seeds or a console:

```ruby
Pundit::Matrix.setup_superadmin!(User.find_by!(email: 'you@example.com'))
```

## Screens

```ruby
# config/initializers/pundit_matrix.rb
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

Groups only arrange the matrix; screens outside every group go under General. A read-only screen offers no access and read. A new screen is closed for ordinary roles.

With ActiveAdmin, groups and order come from the admin menu, so a plain list of `screen` lines is enough. `group` and the translations still win.

## Policies

```ruby
class OrderPolicy < ApplicationPolicy
  screen :orders

  def import?
    write?
  end
end

class InvoicePolicy < ApplicationPolicy
  screen :invoices
  actions_of_screen :orders, :reopen_order
end

class AuditLogPolicy < ApplicationPolicy
  admin_screen
end
```

- `index?` and `show?` need read; `new?`, `create?`, `edit?`, `update?`, `destroy?` and `history?` need write. What the policy defines itself wins.
- `read?`, `write?` and `write?(:invoices)` for your own actions.
- `actions_of_screen` – actions that need write on another screen.
- `admin_screen` – admins and superadmins only, never in the matrix.
- Scopes stay yours.

Outside policies, ask the subject:

```ruby
current_user.access.level(:orders)  # => :none, :read or :write
current_user.access.read?(:orders)
current_user.access.write?(:orders)
current_user.access.any?            # read on at least one screen
current_user.access.everything?     # an admin or a superadmin
current_user.access.manage_roles?
```

## Roles

`Pundit::Matrix::Role` has `name` and `position` (1 is the highest). Pundit finds `RolePolicy` (`Admin::RolePolicy` in a namespace), which the generators create; `permitted_attributes` gives `name` and `levels`. A role held by a subject cannot be deleted.

Admins and superadmins manage roles. To leave them to superadmins:

```ruby
Pundit::Matrix.configure do |config|
  config.roles_managed_by = :superadmin
end
```

The role at position 1 is the admin role, `Role.admin_role`. It has every screen and cannot be edited, moved or deleted.

A new role gets the next free position, and the order changes only by moving a role:

```ruby
role.movable_up?
role.movable_down?
role.move_up
role.move_down
```

On a list, read `Role.ordinary_positions` once and pass it to `movable_up?(positions)` and `movable_down?(positions)`. Show the arrows only on an unfiltered list ordered by position. Authorize with the policy's `move_up?` and `move_down?`.

The matrix in the form, on the detail, and the warning while nobody is an active superadmin:

```erb
<%= render 'pundit/matrix/levels_fields', role: @role %>
<%= render 'pundit/matrix/levels', role: @role %>
<%= render 'pundit/matrix/superadmin_warning', subjects: User %>
```

Pass `table_class:` for your admin's table style and `scope:` for another parameter name than `role`. In an ActiveAdmin form, use `f.matrix_levels_input`. `role.holders` and `Role.holder_counts(roles)` list and count who holds a role; show them only when `access.manage_roles?`.

### Look

The matrix brings a small inline style for ActiveAdmin's default theme. One rule of your own overrides any of it:

- `.pundit-matrix` – the table
- `.pundit-matrix-levels` – the form field holding it
- `.pundit-matrix-level` – the level columns of the form
- `.pundit-matrix-write`, `.pundit-matrix-read`, `.pundit-matrix-none` – the levels on the detail
- `th[scope="rowgroup"]` – the group headings

The header of the form's matrix is sticky. With a fixed top bar:

```scss
.pundit-matrix { --pundit-matrix-header-offset: 60px; --pundit-matrix-header-background: #fff; }
```

## Managing subjects

You manage a subject only when its highest role is strictly lower than yours, and assign only roles strictly lower than yours. Admins never manage other admins, only a superadmin changes their own roles, and a superadmin manages everyone.

```ruby
current_user.access.manage?(user)
current_user.access.assign?(role)
current_user.access.assignable_roles

class UserPolicy < ApplicationPolicy
  subject_screen :users # or admin_subject_screen for admins and superadmins only

  def permitted_attributes
    [:email, :name, *permitted_subject_attributes]
  end
end
```

`show?`, `update?` and `destroy?` also need `manage?` on the record. `permitted_subject_attributes` gives `role_ids: []` to whoever may edit and `superadmin` to a superadmin. Load lists with `includes(:roles)`.

The roles in the subject form:

```erb
<%= render 'pundit/matrix/subject_fields', subject: @user %>
```

Only admins and superadmins may filter subjects by role; Ransack drops the condition for anyone else, so a filter of your own needs the `if:`:

```ruby
filter :roles, as: :select, collection: -> { Pundit::Matrix::Role.ordered.pluck(:name, :id) },
               if: proc { current_active_admin_user.access.everything? }
```

### Who acts

The rules hold on every save of `role_ids=`, `roles=` and `update(role_ids:)`. The actor is `current_active_admin_user` in ActiveAdmin and `pundit_user` in other controllers with `Pundit::Authorization`; elsewhere set it:

```ruby
Pundit::Matrix::Current.set(actor: user) do
  account.update(role_ids:)
end
```

Roles the actor cannot assign are kept when the submitted ids leave them out. With no actor (console, seeds, jobs) nothing is restricted; in a request with nobody signed in, no role can change.

## Extending the models

```ruby
ActiveSupport.on_load(:pundit_matrix_role_assignment) do
  has_paper_trail
end
```

The hooks are `:pundit_matrix_role`, `:pundit_matrix_permission` and `:pundit_matrix_role_assignment`. Dropped assignments, a deleted role's permissions and moved roles go through callbacks. To filter subjects by role, add `roles` and `role_assignments` to the subject's `ransackable_associations`.

## ActiveAdmin

`bin/rails generate pundit:matrix:active_admin User` (`--namespace` defaults to `admin`), also run by the install generator:

- creates `Admin::RolePolicy` and `Admin::ActiveAdmin::PagePolicy`
- turns `screen` into `subject_screen` in `Admin::UserPolicy`
- sets `config.on_unauthorized_access = :pundit_matrix_access_denied` unless you have your own
- declares the dashboard open to everyone signed in
- adds `matrix_subject` to `ActiveAdmin.register User`
- writes `spec/requests/admin/pundit_matrix_screens_spec.rb`

```ruby
ActiveAdmin.register User do
  matrix_subject
  menu parent: 'access', priority: 2

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
  screen :reports # or admin_screen, or open_screen for everyone signed in
end
```

`matrix_subject` permits what the subject policy permits, shows the roles in a sidebar (`roles_sidebar: false` to hide it) and limits the role filter to admins and superadmins. A page that declares no screen is refused to everyone. Single records are found through the policy scope.

### The roles screen

The gem registers it at `/admin/roles`. Reopen it to change small things:

```ruby
ActiveAdmin.register Pundit::Matrix::Role do
  menu parent: 'access', priority: 2
end
```

To own it, `bin/rails generate pundit:matrix:roles_screen` copies it into `app/admin/roles.rb` and sets `config.roles_screen = false`.

### Refusals

`pundit_matrix_access_denied` sends someone with at least one screen back where they came from, and someone with no screen, or refused by the page they came from, to the dashboard. After a save that takes away the actor's own access to the record, it goes to the list, or to the dashboard. The dashboard must stay `open_screen`. For your own handler, point `config.on_unauthorized_access` to a public method of your controller.

### The screens spec

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

It checks every resource and page of the namespace: each declares a screen, read opens it without changes, write offers what an admin gets, a read-only screen offers no writing action, and a writable one has one. Without Devise, define `sign_in` in the spec.

## Testing

```ruby
require 'pundit/matrix/rspec'

grant_levels(user, orders: :read, invoices: :write)
make_admin(user)
make_superadmin(user)

expect(Pundit::Matrix::Lint.policies_without_screen(ApplicationPolicy, except: [HealthCheckPolicy])).to be_empty
expect(Pundit::Matrix::Lint.unused_screens(ApplicationPolicy)).to be_empty
```

## Translations

The gem ships English. Translate the keys of [`config/locales/en.yml`](config/locales/en.yml) under `pundit_matrix`, and name your screens and groups:

```yaml
sk:
  pundit_matrix:
    screens:
      orders: Objednávky
    groups:
      sales: Predaj
```

## Renaming and removing screens

Levels are stored by screen key, so a renamed key needs a migration:

```ruby
execute "UPDATE permissions SET screen = 'sales_orders' WHERE screen = 'orders'"
```

Levels of screens no longer declared are ignored:

```ruby
Pundit::Matrix::Permission.where.not(screen: Pundit::Matrix.screens.map(&:key)).delete_all
```

## Development

```bash
bin/setup
bin/ci
```

## License

MIT, see [LICENSE.txt](LICENSE.txt).
