class CreateOptions < ActiveRecord::Migration[5.1]
  def change
    create_table :options do |t|
      t.string :option_number
      t.integer :sequence
      t.text :text
      t.references :question, foreign_key: true
      t.boolean :correct
      t.integer :created_by
      t.integer :updated_by

      t.timestamps
    end
  end
end
