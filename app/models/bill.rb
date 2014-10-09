# == Schema Information
#
# Table name: bills
#
#  id               :integer(4)      not null, primary key
#  user_id          :integer(4)
#  notes            :text
#  created_at       :datetime
#  updated_at       :datetime
#  due_on           :date
#  paid_on          :date
#  reference_number :string(255)
#

class Bill < ActiveRecord::Base
  include I18n::Alchemy

  belongs_to :user
  has_many :work_units

  scope :overdue, lambda { where("paid_on IS NULL AND due_on < ? ", Date.today) }
  scope :unpaid,  lambda { where(:paid_on => nil) }
  scope :paid, lambda { where("paid_on IS NOT NULL") }

  validates_presence_of :user_id

  accepts_nested_attributes_for :work_units

  before_destroy :dissociate_work_units

  def hours
    work_units.sum(:hours)
  end

  def paid?
    !paid_on.nil?
  end

  # return a flattened, deduplicated array of all clients for work units in this bill
  def clients
    @clients ||= work_units.map{ |wu| wu.project }.uniq.map{ |p| p.client }.uniq
  end

  def dissociate_work_units
    self.work_units.map do |wu|
      wu.bill = nil
      wu.save
    end
  end

end
