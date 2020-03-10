module MetrcService
  module Package
    class Base < MetrcService::Base
      def validate_seeding_unit!
        super

        return if seeding_unit.name =~ /^(Testing )?Package$/

        raise InvalidBatch, "Failed: Seeding unit is not valid for Package completions: #{seeding_unit.name}. " \
          "Batch ID #{@batch_id}, completion ID #{@completion_id}"
      end
    end
  end
end
