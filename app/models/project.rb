# == Schema Information
#
# Table name: projects
#
#  id          :integer(4)      not null, primary key
#  parent_id   :integer(4)
#  lft         :integer(4)
#  rgt         :integer(4)
#  client_id   :integer(4)
#  name        :string(255)     not null
#  account     :string(255)
#  description :text
#  clockable   :boolean(1)      default(FALSE), not null
#  created_at  :datetime
#  updated_at  :datetime
#  billable    :boolean(1)      default(TRUE)
#  flat_rate   :boolean(1)      default(FALSE)
#  archived    :boolean(1)      default(FALSE)
#  pivotal_id  :integer(4)

require 'cascade'

class Project < ActiveRecord::Base

  include Cascade

  acts_as_nested_set
  belongs_to :client
  has_many :work_units
  has_many :activities

  has_many :repositories
  attr_accessor :repositories_attributes
  accepts_nested_attributes_for :repositories,
                                :allow_destroy => true,
                                :reject_if => lambda { |attr| attr['url'].blank? }

  # Rates added to sub-project will override parent project rates completely.
  # Users may see rates disappear from a child when adding rates specifically for a child.
  has_many :rates
  accepts_nested_attributes_for :rates,
                                :allow_destroy => true,
                                :reject_if => lambda { |attr| attr['name'].blank? || attr['amount'].to_i < 0  }

  scope :archived, lambda { where( :archived => true) }
  scope :unarchived, lambda { where( :archived => false) }
  # default_scope :joins => :client

  validates_presence_of :name
  cascades :account, :clockable, :pivotal_id

  before_save :no_rates_for_children, :cascade_client

  validates :parent_id, presence: true, unless: :name_is_root?
  def name_is_root?
    self.name == 'root'
  end


  def is_base_project?
    parent == root
  end

  def base_rates
    is_base_project? || parent.blank? ? rates : parent.base_rates
  end

  # _source method taken from cascade.rb
  def repositories_source
    if(ancestor = self_and_ancestors.reverse.find{|a| !a.repositories.blank? }).nil?
        nil
      else
        ancestor
      end
  end

  private

  def no_rates_for_children
    rates.clear if parent != root
  end

  def cascade_client
    if self.client_id.nil? and parent
      parent.self_and_ancestors.reverse.find do |a|
        self.client_id = a.client_id unless a.client_id.nil?
      end
    end
  end

end
