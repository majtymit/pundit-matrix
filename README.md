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
```

Your subject model needs to answer `superadmin?`. A boolean column is enough:

```ruby
add_column :users, :superadmin, :boolean, null: false, default: false
```

Then run the install generator with the subject model:

```bash
bin/rails generate pundit:matrix:install User
bin/rails db:migrate
```

It creates the migration for the `roles`, `permissions` and `role_assignments` tables and an initializer, and adds `has_roles` to the model. Primary keys follow your app's generator settings, so UUID apps get UUID tables. When one of the tables already exists, it stops and asks for `--table-prefix=matrix_`.

## Subjects

```ruby
class User < ApplicationRecord
  has_roles active_superadmins: -> { where(superadmin: true, deactivated_at: nil) }
end
```

`has_roles` gives the model `roles`, `role_assignments` and `access`, and defines the `active_superadmins` scope. Without the argument, every subject with `superadmin: true` counts as an active superadmin.

Once a superadmin exists, the last active one cannot lose the flag, be deactivated or be deleted.

## Screens

Declare your screens in `config/initializers/pundit_matrix.rb`. Groups are optional and only order the matrix.

```ruby
Pundit::Matrix.configure do |config|
  config.screens do
    group :catalogs do
      screen :branches
      screen :services
    end

    group :access do
      screen :users
      screen :audit_versions, read_only: true
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

class BranchPolicy < ApplicationPolicy
  screen :branches

  def import?
    write?
  end
end
```

`index?` and `show?` need read, `new?`, `create?`, `edit?`, `update?` and `destroy?` need write, and your own actions use `read?` or `write?`. Whatever the policy defines itself wins. Scopes stay yours: someone without read does not get past `index?`, so use them for anything finer, such as a user's branches.

Outside policies, ask the subject. Its roles and levels are loaded once per object, in two small queries:

```ruby
current_user.access.level(:branches)  # => :none, :read or :write
current_user.access.read?(:branches)
current_user.access.write?(:branches)
```

## Managing roles

Roles are an ordinary model, `Pundit::Matrix::Role`, with `name`, `position` (unique, 1 is the highest) and `admin`. Build the screen in your admin like any other resource. `Pundit::Matrix::RolePolicy` lets admins and superadmins manage ordinary roles and only superadmins touch admin roles and the `admin` flag; for a namespaced policy, inherit from it (`class Admin::RolePolicy < Pundit::Matrix::RolePolicy`). A role held by a subject cannot be deleted.

Put the matrix into the role form and onto the role detail:

```erb
<%= render 'pundit/matrix/levels_fields', role: @role %>
<%= render 'pundit/matrix/levels', role: @role %>
```

Both are plain tables that take your admin's look; pass `table_class:` to use its table style, for example `table_class: 'index_table'` in ActiveAdmin.

The form sends `role[levels][branches]=read`, so `@role.update(permitted_attributes(@role))` saves it. For another parameter name, pass `scope: 'pundit_matrix_role'` to the partial.

Warn on the roles screen while nobody is an active superadmin:

```erb
<%= render 'pundit/matrix/superadmin_warning', subjects: User %>
```

## Managing subjects

Subjects are compared by their highest role. You can manage a subject only when its role is strictly lower than yours, and assign only roles strictly lower than yours. Admins never manage other admins, nobody but a superadmin changes their own roles, and a superadmin manages everyone.

```ruby
current_user.access.manage?(user)     # may edit, deactivate or change roles of user
current_user.access.assign?(role)     # may give this role
current_user.access.assignable_roles  # roles for a select, highest first
```

Combine it with the screen in your subject policy:

```ruby
class UserPolicy < ApplicationPolicy
  screen :users

  def update?
    write? && user.access.manage?(record)
  end
end
```

`manage?` reads the other subject's roles from the association, so load lists with `includes(:roles)`.

## Translations

The gem ships English only. Every text is under `pundit_matrix` and falls back to the gem's English when the current locale lacks it:

```yaml
sk:
  pundit_matrix:
    admin_role: Admin rola má všetky práva, aj na obrazovky pridané neskôr.
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
    screens:
      branches: Pobočky
    groups:
      catalogs: Katalógy
```

Screens and groups without a translation show their humanized key.

## Renaming and removing screens

Levels are stored by screen key. Renaming a key needs a migration that moves them, otherwise ordinary roles lose the screen (mind your table prefix):

```ruby
execute "UPDATE permissions SET screen = 'offices' WHERE screen = 'branches'"
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
