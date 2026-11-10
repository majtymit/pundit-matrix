ActiveAdmin.register User do
  matrix_subject

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
