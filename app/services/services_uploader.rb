module ServicesUploader
  def self.import_services_from(csv_file)
    count = 0
    csv_rows = csv_content(csv_file.path)
    csv_rows.each do |row|
      if create_service(row.to_hash)
        count += 1
      end
    end
    csv_rows.count == count
  end

  private

  def self.csv_content(file_path)
    file_content = File.read(file_path)
    CSV.parse(file_content, headers: true)
  end

  def self.create_service(service_hash)
    return if service_hash.compact.blank?
    return if Service.find_by_name(service_hash.values[0])

    service_hash = formatted_hash(service_hash.values)
    service = Service.new(service_hash)
    if service.save
      Services.generate_homoclave_for(service)
      service.save
    end
    service.valid?
  end

  def self.formatted_hash(hash_values)
    {
      name: hash_values[0],
      service_type: service_type(hash_values[1]),
      dependency: hash_values[2],
      organisation_id: Organisation.find_by(name: hash_values[2]).try(:id),
      administrative_unit: hash_values[3],
      agency_id: Agency.find_by(name: hash_values[3]).try(:id),
      cis: cis_ids(hash_values[4]),
      service_admin_id: service_admin_id_for(hash_values[5])
    }
  end

  def self.service_type(value)
    Services.service_type_options.to_h.fetch(value) { nil }
  end

  def self.cis_ids(values)
    values = Array.wrap(values.split(", "))
    values.map do |cis_name|
      cis = Services.service_cis_options.select { |c| c[:label].include?(cis_name) }.first
      if cis.present?
        cis[:id].to_s
      end
    end.reject(&:blank?)
  end

  def self.service_admin_id_for(email)
    Admin.find_by_email(email).try(:id)
  end
end
