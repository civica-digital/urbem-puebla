task :daily_service_requests_mail => :environment do
  Admin.super_admins.each do |super_admin|
    pending_requests = ServiceRequest.open
    if pending_requests.any?
      AdminMailer.notify_pending_requests(super_admin, pending_requests).deliver
    end
  end

  Admin.service_admins.each do |service_admin|
    pending_requests = service_admin.assigned_service_requests.open
    if pending_requests.any?
      AdminMailer.notify_pending_requests(service_admin, pending_requests).deliver
    end
  end
end
