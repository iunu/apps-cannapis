module NcsService
  class Base < BaseService::Base
    RETRYABLE_ERRORS = [
      *BaseService::Base::RETRYABLE_ERRORS,
      NcsAnalytics::Errors::RequestError,
      NcsAnalytics::Errors::TooManyRequests,
      NcsAnalytics::Errors::InternalServerError
    ].freeze

    FATAL_ERRORS = [
      *BaseService::Base::FATAL_ERRORS,
      NcsAnalytics::Errors::MissingConfiguration,
      NcsAnalytics::Errors::MissingParameter
    ].freeze

    protected

    def resource_unit(unit_type)
      resource_units = get_resource_units.select do |resource_unit|
        resource_unit.name =~ /#{unit_type}(,\s|\s-\s)#{batch.crop_variety}/
      end

      raise InvalidAttributes, "Ambiguous resource unit for #{unit_type} calculation. Expected 1 resource_unit, found #{resource_units.count}" if resource_units.count > 1
      raise InvalidAttributes, "#{unit_type} resource unit not found" if resource_units.count.zero?

      resource_units.first
    end

    # Artemis API delivers resource_unit#name in the following formats:
    # (correct as of 2020-03-24)
    #
    #   (a):  [unit] of [resource type], [strain]
    #   (b):  [resource type], [strain]
    #
    # Here we are expecting format (a)
    def map_resource_unit(resource_unit)
      artemis_unit = resource_unit.name[/^(\w+)/, 1]
      service_unit = NcsService::WEIGHT_UNIT_MAP.fetch(artemis_unit, artemis_unit)

      OpenStruct.new(
        id: resource_unit.id,
        name: resource_unit.name,
        unit: service_unit,
        label: resource_unit.name[/^([\w\s]+)(,\s|\s-\s)/, 1],
        strain: resource_unit.crop_variety&.name,
        kind: resource_unit.kind,
        conversion_si: resource_unit.conversion_si
      )
    end

    def lookup_harvest(name)
      # TODO: consider date range for lookup - harvest create/finish dates?
      harvests = call_vendor(:harvest, :active)
      ncs_harvest = harvests&.find { |harvest| harvest['Name'] == name }
      raise DataMismatch, "expected to find a harvest in NCS named '#{name}' but it does not exist" if ncs_harvest.nil?

      ncs_harvest
    end

    def lookup_plant_batch(tag)
      plant_batches = call_vendor(:plant_batch, :all)
      plant_batch = plant_batches&.find { |batch| batch['Name'] == tag }
      raise DataMismatch, "expected to find a plant batch in Metrc with the tag '#{tag}' but it does not exist" if plant_batch.nil?

      plant_batch
    end
  end
end
