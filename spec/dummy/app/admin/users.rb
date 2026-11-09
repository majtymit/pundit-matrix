ActiveAdmin.register User do
  matrix_subject

  permit_params :email

  filter :email

  form do |f|
    f.inputs do
      f.input :email
      li { render 'pundit/matrix/subject_fields', subject: f.object }
    end
    f.actions
  end
end
