# frozen_string_literal: true

require File.expand_path('../test_helper', __dir__)

class StylesheetTest < ActiveSupport::TestCase
  STYLESHEET = File.expand_path('../../assets/stylesheets/project_icons.css', __dir__)

  # Regression (19.11.2026): Auf Projektseiten blendete das Plugin mobil das
  # Logo von redmine_branding (.branding-logo-mobile) aus, weil das
  # Projekt-Icon es ersetzen sollte. Damit fehlte innerhalb von Projekten der
  # Weg zurück zur Startseite. Mobil bleibt das Logo, das Projekt-Icon steht
  # in der Projektauswahl.
  def test_mobiles_logo_wird_nicht_ausgeblendet
    rules = File.read(STYLESHEET).gsub(%r{/\*.*?\*/}m, '')
    hiding = rules.scan(/([^{}]+)\{([^{}]*)\}/).select { |_selector, body| body.include?('display: none') }

    assert hiding.none? { |selector, _body| selector.include?('.branding-logo-mobile') },
           'project_icons.css darf .branding-logo-mobile nicht ausblenden'
    assert hiding.any? { |selector, _body| selector.include?('> .branding-logo') },
           'das Logo im Titel (Desktop) ersetzt weiterhin das Projekt-Icon'
  end
end
