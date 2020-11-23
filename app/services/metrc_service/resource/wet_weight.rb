require_relative '../../common/resource_handling'

module MetrcService
  module Resource
    class WetWeight < Base
      include Common::ResourceHandling

      resource_name 'wet_weight'

      def call
        return if harvest_disabled?

        harvest_plants if resource_present? || @attributes['action_type'] == 'generate'

        success!
      end

      private

      def harvest_plants
        call_metrc(:harvest_plants, build_harvest_plants_payload(completion_barcodes, batch))
      end

      def build_harvest_plants_payload(completion_barcodes, batch)
        harvest_name = batch.arbitrary_id
        average_weight = calculate_average_weight(completion_barcodes)

        completion_barcodes.map do |barcode|
          {
            DryingLocation: location_name,
            PatientLicenseNumber: nil,
            ActualDate: harvest_date,
            Plant: barcode,
            Weight: average_weight,
            UnitOfWeight: unit_of_weight,
            HarvestName: harvest_name
          }
        end
      end

      def harvest_date
        @attributes['start_time']
      end

      def completion_barcodes
        completion_item_ids = @attributes.dig('content', 'crop_batch_item_ids')
        items.map { |item| item['barcode'] if completion_item_ids&.include?(item['id']) }.compact
      end

      def seeding_unit_id
        @seeding_unit_id ||= @attributes.dig(:options, :seeding_unit_id)
      end

      def unit_of_weight
        get_resource_unit(@ctx.dig('attributes', 'options', 'resource_unit_id')).unit
      end

      def total_weight
        resource_unit_id = @attributes.dig('options', 'resource_unit_id')
        resource_completions_by_unit_id(resource_unit_id).sum do |completion|
          completion.options['generated_quantity'] || completion.options['processed_quantity']
        end
      end

      def calculate_average_weight(barcodes)
        (total_weight.to_f / barcodes.size).round(2)
      end
    end
  end
end
