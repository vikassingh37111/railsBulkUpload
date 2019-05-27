class CreateQuestions < ActiveRecord::Migration[5.1]
  def change
    create_table :questions do |t|
      t.integer :question_number
      t.text :text
      t.string :question_type
      t.integer :created_by
      t.integer :updated_by

      t.timestamps
    end
  end
end
