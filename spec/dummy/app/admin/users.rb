ActiveAdmin.register User do
  matrix_subject
  menu parent: 'access', priority: 2

  permit_params :email

  filter :email

  form do |f|
    f.inputs do
      f.input :email
      f.matrix_subject_inputs
    end
    f.actions
  end
end
