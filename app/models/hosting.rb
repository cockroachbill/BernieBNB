class Hosting < ActiveRecord::Base
  validates :zipcode, :max_guests, presence: true
  validates :zipcode, zipcode: { country_code: :es }
  validates :comment, length: { maximum: 140 }
  geocoded_by :zipcode
  after_validation :geocode
  after_create :notify_nearby_visitors

  belongs_to :host, class_name: "User", foreign_key: :host_id
  has_many :contacts

  def first_name
    host.first_name
  end

  def was_contacted_by?(visitor)
    Contact.exists?(visitor_id: visitor.id, hosting_id: self.id)
  end

  private

  def notify_nearby_visitors
    nearby_visits = Visit
      .near(self, 25, order: "distance")
      .where("num_travelers <= ?", max_guests)
      .where("start_date >= ?", Date.today)

    # :nocov:
    if Rails.env.production? or  Rails.env.staging?
      nearby_visits = nearby_visits.where("user_id != (?)", self.host_id)
    end
    # :nocov:

    nearby_visits.each do |visit|
      UserMailer.new_host_email(visit, self).deliver_now
    end
  end
end
