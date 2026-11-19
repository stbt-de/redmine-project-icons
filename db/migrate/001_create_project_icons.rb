# frozen_string_literal: true

# Icon (Datei im Redmine-Dateiverzeichnis) und Farbe je Projekt
class CreateProjectIcons < ActiveRecord::Migration[6.1]
  def change
    create_table :project_icons do |t|
      t.integer :project_id, null: false
      t.string :filename
      t.string :content_type
      t.string :digest
      t.string :color, limit: 7
      t.timestamps
    end
    add_index :project_icons, :project_id, unique: true
  end
end
