class AddExifToPictures < ActiveRecord::Migration[8.1]
  def change
    add_column :pictures, :taken_at, :datetime
    add_column :pictures, :camera, :string
    add_column :pictures, :lens, :string
    add_column :pictures, :focal_length, :float
    add_column :pictures, :f_number, :float
    add_column :pictures, :exposure_time, :float
    add_column :pictures, :iso, :integer
  end
end
