# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class WithoutMigrationTest < Redmine::IntegrationTest
  include RedmineProjectIcons::TestHelper

  fixtures :users, :email_addresses, :user_preferences, :roles, :members, :member_roles,
           :projects, :enabled_modules, :trackers, :projects_trackers, :issue_statuses, :issues,
           :enumerations

  def setup
    reset_project_icons
  end

  def teardown
    ProjectIcon.unstub(:table_exists?)
    RedmineProjectIcons::Resolver.reset!
    reset_project_icons
  end

  # Bean redmine-project-icons-00pe — Regression: ohne Migration Fehler 500.
  #
  # Symptom (lokal, 2026-11-19): Plugin eingehängt, aber
  # redmine:plugins:migrate noch nicht gelaufen – jede Seite, auch die
  # Anmeldung, antwortete mit 500, weil der Kopf jeder Seite die Tabelle
  # project_icons abfragt. Redmine muss nutzbar bleiben; das Plugin zeigt bis
  # zur Migration nichts an.
  def test_ohne_tabelle_bleibt_redmine_nutzbar
    ProjectIcon.stubs(:table_exists?).returns(false)
    ProjectIcon.stubs(:joins).raises(ActiveRecord::StatementInvalid, 'no such table: project_icons')
    RedmineProjectIcons::Resolver.reset!

    get '/login'
    assert_response :success

    get '/projects'
    assert_response :success
    assert_select '.project-icon', 0
  end
end
