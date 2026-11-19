# frozen_string_literal: true

# Icon eines Projekts (eigenes oder geerbtes) und seine Pflege
get 'projects/:id/icon', to: 'project_icons#show', as: 'project_icon'
post 'projects/:id/icon', to: 'project_icons#update'
delete 'projects/:id/icon', to: 'project_icons#destroy'
