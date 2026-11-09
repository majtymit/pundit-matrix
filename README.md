# Pundit::Matrix

Roles and a permission matrix for Rails apps that authorize with [Pundit](https://github.com/varvet/pundit).

Every screen of your app is one permission with three levels: no access, read and write. Roles get a level per screen, subjects (usually users) get roles, and your policies ask the matrix. There are no pages of its own: you manage roles in the admin you already have, and the matrix is a partial that takes its look.

You create as many roles as you need, ordered by position. Access comes in three kinds:

- **Superadmin** – a flag on the subject, not a role. Has everything and manages everyone, including other superadmins.
- **Admin roles** – any role with the `admin` flag. Has every screen, including later ones, and manages roles and every subject below admin.
- **Ordinary roles** – every other role. Has what the matrix says and manages only subjects with a lower role.

Requires Ruby 3.2+, Rails 7.2+ and Pundit 2.3+.

## Installation

```bash
bundle add pundit-matrix
bin/rails generate pundit:matrix:install User
bin/rails db:migrate
bin/rails pundit_matrix:superadmin EMAIL=you@example.com
```

The install generator creates the migration for the `roles`, `permissions` and `role_assignments` tables and an initializer, and adds `has_roles` to the model, below the comment that describes the class or after its last `include` or `extend`. It adds `extend Pundit::Matrix::Policy` to an existing `app/policies/application_policy.rb` and turns `screen` into `subject_screen` in an existing policy of the subject (or adds `subject_screen :users`); what it cannot find, it lists. Without ActiveAdmin it also creates `app/policies/role_policy.rb`, the policy Pundit finds for roles. When the model does not answer `superadmin?` yet, it also adds a migration with a boolean `superadmin` column. Primary keys follow your app's generator settings, so UUID apps get UUID tables. When one of the tables already exists, it stops and asks for `--table-prefix=matrix_`. When the app has ActiveAdmin, it also does what [the ActiveAdmin generator](#activeadmin) does, and prints one list of what is left, in the order you do it.

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

Without ActiveAdmin, your subject form renders `pundit/matrix/subject_fields`, your controller permits `permitted_subject_attributes`, and your roles screen renders the matrix ([Managing roles](#managing-roles), [Managing subjects](#managing-subjects)). With ActiveAdmin, the generator writes the roles screen and the subject form needs one line, see [ActiveAdmin](#activeadmin).

## Subjects

```ruby
class User < ApplicationRecord
  has_roles active_superadmins: -> { where(superadmin: true, deactivated_at: nil) }
end
```

`has_roles` gives the model `roles`, `role_assignments` and `access`, and defines the `active_superadmins` scope. Without the argument, every subject with `superadmin: true` counts as an active superadmin.

Once a superadmin exists, the last active one cannot lose the flag, be deactivated or be deleted.

### Superadmin

`bin/rails pundit_matrix:superadmin EMAIL=you@example.com` finds the subject by its email (`MODEL=Account` for another model; an unknown email or model stops with a plain message), creates the admin role when there is none (the `admin` flag, position 1) and gives the subject the superadmin flag and that role. It is safe to run again, on any environment and at any time, also long after the first deploy.

From seeds, a console or a deploy script, call what the task calls:

```ruby
Pundit::Matrix.setup_superadmin!(User.find_by!(email: 'you@example.com'))
```

## Screens

Declare your screens in `config/initializers/pundit_matrix.rb`. Groups are optional and only order the matrix.

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

A read-only screen offers no access and read only. A new screen is closed for every ordinary role; admin roles and superadmins get it automatically.

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

Roles are an ordinary model, `Pundit::Matrix::Role`, with `name`, `position` (unique, 1 is the highest) and `admin`. The ActiveAdmin generator builds the screen; in another admin, build it like any other resource. `Pundit::Matrix::RolePolicy` lets admins and superadmins manage ordinary roles and only superadmins touch admin roles and the `admin` flag. Pundit finds it through `RolePolicy` (or `Admin::RolePolicy` in a namespace), which the generators create, because the role answers `policy_class`. Permit what the policy allows: `permitted_attributes` gives `admin` to a superadmin only. A role held by a subject cannot be deleted.

Put the matrix into the role form and onto the role detail:

```erb
<%= render 'pundit/matrix/levels_fields', role: @role %>
<%= render 'pundit/matrix/levels', role: @role %>
```

Both are plain tables that take your admin's look; pass `table_class:` to use its table style, for example `table_class: 'index_table'` in ActiveAdmin.

The form sends `role[levels][orders]=read`, so `@role.update(permitted_attributes(@role))` saves it. For another parameter name, pass `scope: 'pundit_matrix_role'` to the partial.

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
through `role_ids=` destroys the assignments it drops, so their callbacks run.

Ransack can search roles by their own columns and assignments by role, while no one acts or the actor is an admin
or a superadmin. To filter subjects by role, add `roles` and `role_assignments` to the subject's
`ransackable_associations` and see [Managing subjects](#managing-subjects).

## ActiveAdmin

The adapter loads only when the app has ActiveAdmin (3.x with `ActiveAdmin::PunditAdapter`); the rest of the gem does not need it. `bin/rails generate pundit:matrix:active_admin User` (`--namespace` defaults to `admin`), also run by the install generator:

- creates the roles screen `app/admin/roles.rb` with the matrix and the missing superadmin warning, and `Admin::RolePolicy`
- creates `Admin::ActiveAdmin::PagePolicy`, which reads what each page declares; when you let it replace a page policy of your own, it reminds you that what that policy decided now belongs in each `register_page`
- turns `screen` into `subject_screen` in `Admin::UserPolicy`
- points `config.on_unauthorized_access` to `:pundit_matrix_access_denied`, unless you have a handler of your own
- declares the Dashboard open to everyone signed in
- adds `matrix_subject` to `ActiveAdmin.register User`
- writes `spec/requests/admin/pundit_matrix_screens_spec.rb` when the app has specs

and lists what it could not do. What stays yours:

```ruby
module Admin
  class UserPolicy < ApplicationPolicy
    subject_screen :users
  end
end

ActiveAdmin.register User do
  matrix_subject

  permit_params :email

  form do |f|
    f.inputs do
      f.input :email
      li { render 'pundit/matrix/subject_fields', subject: f.object }
    end
    f.actions
  end
end

ActiveAdmin.register_page 'Reports' do
  screen :reports
end
```

### Subjects

`matrix_subject` adds the attributes the subject policy permits (`role_ids`, and `superadmin` for a superadmin) to whatever `permit_params` permits, and shows the roles in a sidebar on the detail. It also puts the role filter on the index for admins and superadmins only: it adds `filter :roles` when you have not declared it, and when you have (or ActiveAdmin adds it by default), it sets its `if:` to `access.everything?`, replacing any `if:` of your own. ActiveAdmin cannot render a filter that Ransack refuses, so without that the index would fail for everyone else ([Managing subjects](#managing-subjects)). The rest of your filters stay as they are.

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

The generated spec walks every resource and page of the namespace. Each one needs a screen, an admin screen or an open screen. Without the level its address is refused; with read it opens, the menu shows only screens with that key, and it offers no change and no action. With write it offers what an admin gets, and actions of another screen go to whoever writes there. List what knowingly stays outside the matrix in `outside_the_matrix`. Without Devise, fill in `create_subject` and `sign_in`.

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
    levels:
      none: Žiadny prístup
      read: Čítanie
      write: Zápis
    errors:
      above_ordinary_roles: musí byť nad všetkými bežnými rolami
      below_admin_roles: musí byť pod všetkými admin rolami
      screen_not_declared: nie je deklarovaná
      level_not_offered: nie je na tejto obrazovke dostupný
      admin_role: má už všetky práva
      last_superadmin: Musí ostať aspoň jeden aktívny superadmin
      roles_not_managed: Tieto roly môže zmeniť len niekto s vyššou rolou
      own_roles: Vlastné roly môže meniť len superadmin
      role_not_assignable: obsahujú rolu %{role}, ktorú nemôžete prideliť
      superadmin_only: môže zmeniť len superadmin
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
