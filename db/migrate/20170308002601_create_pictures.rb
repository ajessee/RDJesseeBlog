class CreatePictures < ActiveRecord::Migration
  def change
    create_table :pictures do |t|
      t.string :url
      t.text :caption
      t.references :user, index: true, foreign_key: true

      t.timestamps null: false
    end
  end
end
