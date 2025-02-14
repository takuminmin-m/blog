class Article < ApplicationRecord
  validates :title, presence: true, uniqueness: true
  validates :filename, presence: true, uniqueness: true
end
