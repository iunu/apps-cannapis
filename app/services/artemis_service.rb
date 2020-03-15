# frozen_string_literal: true

class ArtemisService
  def initialize(account, batch_id, facility_id)
    @artemis = account.client
    @batch_id = batch_id
    @facility_id = facility_id
  end

  def get_facility(id = nil)
    @artemis.facility(id || @facility_id)
  end

  def get_batch(include = 'zone,barcodes,custom_data,seeding_unit,harvest_unit,sub_zone')
    @artemis.facility(@facility_id)
            .batch(@batch_id, include: include)
  end

  def get_items(seeding_unit_id, include: 'barcodes,seeding_unit')
    @artemis.facility(@facility_id)
            .batch(@batch_id)
            .items(seeding_unit_id: seeding_unit_id, include: include)
  end

  def get_zone(zone_id, include: nil)
    @artemis.facility(@facility_id)
            .zone(zone_id, include: include)
  end

  def get_resource_unit(resource_unit_id, include: nil)
    @artemis.facility(@facility_id)
            .resource_unit(resource_unit_id, include: include)
  end

  def get_resource_units(include: nil)
    @artemis.facility(@facility_id)
            .resource_units(include: include)
  end

  def get_child_completions(parent_id, filter: {})
    ArtemisApi::Completion.find_all(
      facility_id: @facility_id,
      client: @artemis,
      filters: { parent_id: parent_id }.merge(filter)
    )
  end

  def get_related_completions(action_type = nil)
    completions = get_batch.completions
    completions = completions.select { |c| c.action_type == action_type.to_s } if action_type.present?

    completions
  end
end
