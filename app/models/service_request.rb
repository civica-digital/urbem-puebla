#encoding: utf-8
class ServiceRequest < ActiveRecord::Base
  attr_accessor :message

  belongs_to :service
  belongs_to :requester, polymorphic: true
  belongs_to :status
  has_many :comments
  has_many :public_servants, through: :service, source: :admins

  has_many :service_request_readings

  serialize :service_fields, JSON

  mount_uploader :media, ImageUploader
  acts_as_voteable

  validates :service_id, :description, presence: true
  validate :service_extra_fields
  before_create :public_servant_description_validation

  before_validation :assign_default_status, on: :create
  after_update :send_notification_for_status_update


  default_scope { order('created_at DESC') }

  scope :on_start_date, -> (from) {
    where("service_requests.created_at >= ?", from) unless from.blank?
  }

  scope :on_finish_date, -> (to) {
    where("service_requests.created_at <= ?", to) unless to.blank?
  }

  scope :with_status, -> (status_id) {
    where(status_id: status_id) unless status_id.blank?
  }

  scope :on_status_name, -> (status_name) {
    joins(:status).where('statuses.name = ?', status_name) unless status_name.blank?
  }

  scope :on_service, -> (service_ids) {
    where(service_id: service_ids.split(',')) unless service_ids.blank?
  }

  scope :find_by_ids, -> (ids) {
    where("service_requests.id IN (?)", ids.split(',')) unless ids.blank?
  }

  scope :closed, -> {
    on_status_name("Cerrado")
  }

  # Maybe we need to remove this scope
  scope :not_closed, -> {
    # At this time status 2 is closed, status 3 is deleted, you need to refactor all statuses feat.
    where('status_id NOT IN (?)', [2, 3])
  }

  scope :open, -> {
    # At this time status 2 is closed, status 3 is deleted, you need to refactor all statuses feat.
    where('status_id NOT IN (?)', [2, 3])
  }

  scope :with_status_and_dependency, -> (status_id, dependency){
    where(dependency: dependency, status_id: status_id)
  }

  scope :pending_moderation, -> do
    joins(:comments)
    .where(comments: { approved: false })
  end

  def service?
    service.present?
  end

  def self.filter_by_search(params)
    requests = ServiceRequest.order('created_at DESC')
    requests = requests.on_start_date(params[:start_date])
    requests = requests.on_finish_date(params[:end_date])
    requests = requests.with_status(params[:status_id])
    requests = requests.on_service(params[:service_id])
    requests = requests.find_by_ids(params[:service_request_ids])
    requests
  end

  def self.filter_by_search_311(params)
    requests = ServiceRequest.order('created_at DESC')
    if params[:service_request_id].present?
      requests = requests.find_by_ids(params[:service_request_id])
    else
      requests = requests.on_start_date(params[:start_date])
      requests = requests.on_finish_date(params[:end_date])
      requests = requests.on_service(params[:service_code])
      requests = requests.on_status_name(params[:status])
    end
    requests
  end

  def public_servant_description_validation
      if public_servant_id == nil
        public_servant_description = "No aplica"
      end
  end
  def service_requester
    if self.anonymous?
      { avatar_url: 'http://www.gravatar.com/avatar/foo', name: 'Anónimo' , email: 'Anónimo'}
    else
      { avatar_url: self.requester.avatar_url, name: self.requester.name,  email: self.requester.email }
    end
  end

  def requester_name
    if anonymous?
      'Anónimo'
    else
      requester.name
    end
  end

  def service_name
    service.name
  end

  def date
    created_at.to_date
  end

  def service_fields_hash
    service_fields_ids = self.service_fields.map {|key,val| key}
    service_fields = ServiceField.find(service_fields_ids)
    service_fields.map do |service_field|
      {name: service_field.name, value: self.service_fields[service_field.id.to_s]}
    end
  end

  def requested_by_user?
    self.requester_type == 'User'
  end


  ransacker :date do
    Arel.sql('date(created_at)')
  end

  def closed?
    status_id == Status.close.try(:id)
  end

  def open?
    !closed?
  end

  def active?
    # status.name != "Atendido por la Dirección de atención a Quejas y Denuncias"
    status_id != Status.close.id
  end

  def status_name
    status.name
  end

  def has_been_read_by?(admin)
    service_request_readings.exists?(admin_id: admin.id)
  end

  def unread?(admin)
    !service_request_readings.exists?(admin_id: admin.id)
  end

  def mark_as_read!(admin)
    service_request_readings.where(admin_id: admin).first_or_create
  end

  private

  def service_extra_fields
    self.service_fields.each do |k,v|
      errors.add(k.to_sym, I18n.t('errors.messages.blank')) if v.blank?
    end
  end

  def assign_default_status
    self.status = Status.where(is_default: true).first
  end

  def send_notification_for_status_update
    if self.requested_by_user? && self.status_id_changed?
      UserMailer.notify_service_request_status_change(self.id, self.status_id_was).deliver_later
    end
  end

end
