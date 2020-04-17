module MetrcService
  module Resource
    class Waste < MetrcService::Base
      WET_WASTE = 'wet_waste'.freeze

      def call
        remove_waste if waste_completions.present?
      end

      def waste_completions
        @waste_completions ||= resource_completions_by_unit_type(WET_WASTE)
      end

      def remove_waste
        call_metrc(:remove_waste, build_remove_waste_payload)
      end

      def build_remove_waste_payload
        metrc_harvest = lookup_metrc_harvest(batch.arbitrary_id)

        waste_completions.map do |completion|
          {
            Id: metrc_harvest['Id'],
            WasteType: waste_type(completion),
            UnitOfWeight: unit_of_weight(WET_WASTE),
            WasteWeight: completion.options['generated_quantity'] || completion.options['processed_quantity'],
            ActualDate: harvest_date
          }
        end
      end

      def waste_type(completion)
        validate_waste_type!(waste_resource_unit.label)

        waste_resource_unit.label
      end

      def waste_resource_unit
        @waste_resource_unit ||= get_resource_unit(completion.attributes.dig('options', 'resource_unit_id'))
      end

      def validate_waste_type!(type)
        return if metrc_supported_waste_types.include?(type)

        dictionary = DidYouMean::SpellChecker.new(dictionary: metrc_supported_waste_types)
        matches = dictionary.correct(type)

        raise InvalidAttributes,
          "The harvest waste type '#{type}' is not supported by Metrc. "\
          "#{matches.present? ? "Did you mean #{matches.map(&:inspect).join(', ')}?" : 'No similar types were found on Metrc.'}"
      end

      def metrc_supported_waste_types
        # TODO: implement this call in the Metrc gem
        @metrc_supported_waste_types ||= begin
                                           metrc_response = @client.get('harvests', 'waste/types').body
                                           JSON.parse(metrc_response).map { |entry| entry['Name']  }
                                         end
      end
    end
  end
end
