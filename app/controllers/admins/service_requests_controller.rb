class Admins::ServiceRequestsController < Admins::AdminController
  before_action :authorize_admin, only: :edit
  helper_method :service_cis_options, :service_cis_label, :classification_options
  helper_method :dependency_options
  before_action :set_title

  def index
    @search = service_requests_for_search.search(params[:q])
    @service_requests = @search.result.page(params[:page])
    flash.now[:notice] = I18n.t('flash.dashboards.requests_not_found') if @service_requests.empty?
  end

  def new
    @service_request = ServiceRequest.new
  end

  def create
    @service_request = current_admin.service_requests.build(service_request_params)
    if @service_request.save
      notify_public_servants
      redirect_to edit_admins_service_request_path(@service_request), flash: { success: I18n.t('flash.service_requests.created') }
      #enviar correo al servidor publico
      unless @service_request.public_servant_id.nil? || @service_request.public_servant_id == 0 || Admin.find(current_admin.id).is_public_servant
        AdminMailer.send_public_servant_update_request(admin: Admin.find(@service_request.public_servant_id)).deliver
      end
    else
      flash[:notice] = t('flash.service_requests.try_again')
      render :new
    end
  end

  def edit
    @service_request = ServiceRequest.find params[:id]

    @service_request.mark_as_read!(current_admin)

    @comments = @service_request.comments.order("comments.created_at ASC")
    @admins_services = Service.where(id: @service_request.service.id).last.admins
  end

  def update
    @service_request = ServiceRequest.find params[:id]
    @service_request.assign_attributes(service_request_params)
    dependency_changed = @service_request.dependency_changed?
    if @service_request.save
      if params[:message].present?
        @service_request.comments.create content: params[:message], commentable: current_admin
      end

      if dependency_changed
        admins = Admin.with_dependency(@service_request.dependency)
        admins.each do |admin|
          AdminMailer.send_public_servant_update_request(admin: admin, name: admin.dependency).deliver
        end
      end

      redirect_to edit_admins_service_request_path(@service_request), flash: { success: I18n.t('flash.service_requests.updated') }
        #enviar correo al servidor publico
      unless @service_request.public_servant_id.blank? || current_admin.is_public_servant
        admin = Admin.find(@service_request.public_servant_id)
        AdminMailer.send_public_servant_update_request(
          admin: admin,
          name: admin.name).deliver
      end
    else
     render :edit
    end
  end

  def destroy
    @service_request = ServiceRequest.find params[:id]
    erased_status = Status.where("name ILIKE ?", "%eliminado%").last
    @service_request.status_id = erased_status.id
    @service_request.save
    redirect_to :back, flash: { success: I18n.t('flash.service_requests.destroyed') }
  end

  def csv_export
    service_requests = ServiceRequest.all
    csv_file, csv_filename = ServiceRequests::ServiceRequestsFile.new(service_requests).to_csv
    send_data csv_file, filename: csv_filename, type: 'text/csv; charset=utf-8;'
  end

  private

  def classification_options
    ServiceRequests.classification_options
  end

  def set_title
    @title_page = I18n.t('admins.service_requests.index.header')
  end

  def service_cis_label(cis_id)
    Services.service_cis_label(cis_id)
  end

  def service_cis_options
    Services.service_cis_options
  end

  def service_requests_for_search
    if current_admin.is_super_admin? || current_admin.is_observer
      ServiceRequest.unscoped
    else
      Admins.service_requests_for(current_admin, {})
    end
  end

  def authorize_admin
    permissions = Admins.permissions_for_admin(current_admin)
    unless permissions.can_manage_service_requests?(current_service)
      redirect_to admins_dashboards_path
    end
  end

  def current_service
    ServiceRequest.find(params[:id]).service
  end

  def service_request_params
    service_fields = params[:service_request].delete(:service_fields)
    params
      .require(:service_request)
      .permit(:address, :status_id, :service_id, :description, :media, :anonymous, :cis,
      :public_servant_id, :classification, :dependency).tap do |whitelisted|
        whitelisted[:service_fields] = service_fields || {}
      end
  end

  def notify_public_servants
    public_servants = @service_request.service.admins
    public_servants.each do |public_servant|
      AdminMailer.notify_new_request(admin: public_servant, service_request: @service_request).deliver
    end
  end

  def dependency_options
    if current_admin.is_super_admin?
      Services.service_dependency_options
    else
      [current_admin.dependency]
    end
  end
end
