# frozen_string_literal: true
# == Schema Information
#
# Table name: tags
#
#  id         :bigint(8)        not null, primary key
#  name       :string           default(""), not null
#  created_at :datetime         not null
#  updated_at :datetime         not null
#

class Tag < ApplicationRecord
  has_and_belongs_to_many :statuses
  has_and_belongs_to_many :accounts

  has_one :account_tag_stat, dependent: :destroy

  HASHTAG_NAME_RE = '[[:word:]_]*[[:alpha:]_·][[:word:]_]*'
  HASHTAG_RE = /(?:^|[^\/\)\w])#(#{HASHTAG_NAME_RE})/i

  validates :name, presence: true, uniqueness: true, format: { with: /\A#{HASHTAG_NAME_RE}\z/i }

  delegate :accounts_count,
           :accounts_count=,
           :increment_count!,
           :decrement_count!,
           to: :account_tag_stat

  after_save :save_account_tag_stat

  def account_tag_stat
    super || build_account_tag_stat
  end

  def to_param
    name
  end

  def history
    days = []

    7.times do |i|
      day = i.days.ago.beginning_of_day.to_i

      days << {
        day: day.to_s,
        uses: Redis.current.get("activity:tags:#{id}:#{day}") || '0',
        accounts: Redis.current.pfcount("activity:tags:#{id}:#{day}:accounts").to_s,
      }
    end

    days
  end

  class << self
    def search_for(term, limit = 5)
      pattern = sanitize_sql_like(term.strip) + '%'
      Tag.where('lower(name) like lower(?)', pattern).order(:name).limit(limit)
    end
  end

  private

  def save_account_tag_stat
    return unless account_tag_stat&.changed?
    account_tag_stat.save
  end
end
